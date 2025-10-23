import 'dart:io'; // Needed for Image.file
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:finsight/services/ocr_service.dart';
import 'package:finsight/models/transaction_model.dart'; // Import TransactionModel for the enum

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
          _recognizedText = result;
        });
      } else {
        setState(() { _recognizedText = "Image selection cancelled."; });
      }
    } catch (e) {
      setState(() {
        _recognizedText = "Error processing image: $e";
      });
    } finally {
      // Check if the widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // Function to parse transaction details from OCR text
  Map<String, dynamic> _parseTransactionDetails(String text) {
    double? amount;
    // Use TransactionType enum from transaction_model.dart
    TransactionType transactionType = TransactionType.debit; // Default to debit, adjust later
    bool typeFound = false;

    // --- Try to extract Amount ---
    final amountRegex = RegExp(
      r"(?:rs\.?|inr\.?|₹)\s*([\d,]+\.?\d*)",
      caseSensitive: false,
    );

    final amountMatch = amountRegex.firstMatch(text);
    if (amountMatch != null) {
      final amountString = amountMatch.group(1)?.replaceAll(',', '');
      if (amountString != null) {
        amount = double.tryParse(amountString);
      }
    }

    // --- Try to determine Transaction Type ---
    final lowerText = text.toLowerCase();
    if (lowerText.contains("credited") || lowerText.contains("received") || lowerText.contains("deposit")) {
      transactionType = TransactionType.credit;
      typeFound = true;
    } else if (lowerText.contains("paid") || lowerText.contains("debited") || lowerText.contains("sent") || lowerText.contains("spent") || lowerText.contains("payment")) {
      transactionType = TransactionType.debit;
      typeFound = true;
    }

    // TODO: Add RegEx for Merchant/Recipient and Date

    return {
      'amount': amount,
      'type': typeFound ? transactionType : null, // Return null if no keyword found
    };
  }


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

            // Display selected image
            if (_selectedImage != null)
              Container(
                height: 200,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  image: DecorationImage(
                    image: FileImage(File(_selectedImage!.path)),
                    fit: BoxFit.contain, // Show the whole image
                  ),
                ),
              ),

            // Display processing status or results
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
              // Disable button if still processing, if text is placeholder, error, or empty
              onPressed: (_isProcessing ||
                  _recognizedText.startsWith("Placeholder") ||
                  _recognizedText.startsWith("Error") ||
                  _recognizedText.startsWith("No text") ||
                  _recognizedText.startsWith("No image") ||
                  _recognizedText.isEmpty)
                  ? null
                  : () {
                final details = _parseTransactionDetails(_recognizedText);
                final double? extractedAmount = details['amount'] as double?;
                final TransactionType? extractedType = details['type'] as TransactionType?; // Can be null now

                print("--- Parsed Details ---");
                print("Amount: $extractedAmount");
                print("Type: $extractedType");

                if (extractedAmount == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Could not parse amount from text."))
                  );
                  return;
                }
                if (extractedType == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Could not determine transaction type (credit/debit)."))
                  );
                  // Optionally, you could default to debit or ask the user
                  return;
                }

                // TODO: Navigate to AddTransactionScreen pre-filled, or save directly
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Parsed Amount: $extractedAmount, Type: $extractedType. TODO: Save it."))
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 12), // Added padding
              ),
              child: const Text(
                  "Process & Save Transaction", // Updated Text
                  style: TextStyle(color: Colors.white, fontSize: 16)
              ),
            ),
          ],
        ),
      ),
    );
  }
}