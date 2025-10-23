import 'dart:io';
import 'dart:math'; // For the 'max' function
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:finsight/services/ocr_service.dart';
import 'package:finsight/models/transaction_model.dart';
import 'package:finsight/screens/add_transaction_screen.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();
  String _recognizedText = "No image selected yet.";
  bool _isProcessing = false;
  XFile? _selectedImage;

  Future<void> _pickAndProcessImage(ImageSource source) async {
    setState(() {
      _isProcessing = true;
      _recognizedText = "Processing...";
      _selectedImage = null;
    });

    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() { _selectedImage = image; });
        final result = await _ocrService.processImage(image.path);
        setState(() {
          _recognizedText = result.isEmpty ? "No text detected." : result;
        });
      } else {
        setState(() { _recognizedText = "Image selection cancelled."; });
      }
    } catch (e) {
      setState(() {
        _recognizedText = "Error processing image: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // --- This is the fixed parsing function ---
  TransactionModel? _parseTransactionDetails(String text) {
    String merchant = "Unknown";
    double? finalAmount;
    TransactionType type = TransactionType.debit; // Default to debit for receipts

    final List<String> lines = text.split('\n');
    final lowerText = text.toLowerCase();

    // --- 1. Extract Merchant ---
    for (String line in lines) {
      String trimmedLine = line.trim();
      // Find the first line that is > 3 chars and not just a number
      if (trimmedLine.length > 3 && double.tryParse(trimmedLine) == null) {
        // And isn't a generic receipt line
        if (!trimmedLine.toLowerCase().contains("invoice") &&
            !trimmedLine.toLowerCase().contains("receipt")) {
          merchant = trimmedLine;
          break; // Found it
        }
      }
    }

    // --- 2. Determine Transaction Type ---
    if (lowerText.contains("credited") || lowerText.contains("received")) {
      type = TransactionType.credit;
    }

    // --- 3. Extract Amount ---
    // This regex finds 1,234.56 or 1234.56
    final RegExp amountRegex = RegExp(r"(\d{1,3}(?:,?\d{3})*\.\d{2})");
    double savedAmount = 0.0;

    // First, find the "saved" amount so we can ignore it.
    for (int i = 0; i < lines.length; i++) {
      String lowerLine = lines[i].toLowerCase();
      // Look for the "saved" keyword
      if (lowerLine.contains("saved")) {
        // Check the *next* line (if it exists) for the amount
        if (i + 1 < lines.length) {
          String nextLine = lines[i+1];
          // We must remove commas for parsing (e.g., "1,234.00" -> "1234.00")
          Match? amountMatch = amountRegex.firstMatch(nextLine.replaceAll(',', ''));
          if (amountMatch != null) {
            double? parsedAmount = double.tryParse(amountMatch.group(1)!);
            if (parsedAmount != null) {
              savedAmount = parsedAmount;
              break; // Found it, stop looking
            }
          }
        }
      }
    }

    // Now, find all other amounts
    List<double> allAmounts = [];
    for (String line in lines) {
      // Find all matches on this line
      Iterable<Match> matches = amountRegex.allMatches(line.replaceAll(',', ''));
      for (Match match in matches) {
        double? parsedAmount = double.tryParse(match.group(1)!);
        if (parsedAmount != null) {
          allAmounts.add(parsedAmount);
        }
      }
    }

    // Filter out the saved amount
    List<double> filteredAmounts = allAmounts.where((amount) => amount != savedAmount).toList();

    // If we have no amounts left, we failed.
    if (filteredAmounts.isEmpty) {
      return null;
    }

    // The total is the largest remaining amount.
    finalAmount = filteredAmounts.reduce(max);

    // --- 4. Return a partial TransactionModel ---
    if (finalAmount != null) {
      return TransactionModel(
        userId: '', // This will be filled by AuthService on the next screen
        senderAddress: merchant,
        messageBody: text, // Save the full OCR text
        transactionDate: DateTime.now(), // Use current time
        amount: finalAmount,
        type: type,
      );
    }

    return null; // Return null if no valid amount was found
  }
  // --- END OF UPDATED FUNCTION ---


  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Receipt (OCR)"),
        backgroundColor: const Color(0xFF006241),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : () => _pickAndProcessImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text("Camera", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006241)),
                ),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : () => _pickAndProcessImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, color: Colors.white),
                  label: const Text("Gallery", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006241)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_selectedImage != null)
              Container(
                height: 200,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  image: DecorationImage(
                    image: FileImage(File(_selectedImage!.path)),
                    fit: BoxFit.contain,
                  ),
                ),
              ),

            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Recognized Text:",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  _isProcessing
                      ? const Center(child: CircularProgressIndicator())
                      : SelectableText(_recognizedText),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: (_isProcessing ||
                  _recognizedText.startsWith("Error") ||
                  _recognizedText.startsWith("No text") ||
                  _recognizedText.isEmpty)
                  ? null
                  : () {

                // 1. Parse the text
                final TransactionModel? parsedData = _parseTransactionDetails(_recognizedText);

                if (parsedData == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Could not parse an amount from the text. Please enter manually."))
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
                  );
                } else {
                  // 2. Navigate to the AddTransactionScreen with the pre-filled data
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddTransactionScreen(prefillData: parsedData),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                  "Process & Confirm Transaction",
                  style: TextStyle(color: Colors.white, fontSize: 16)
              ),
            ),
          ],
        ),
      ),
    );
  }
}