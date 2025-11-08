import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:finsight/services/ocr_service.dart';
import 'package:finsight/models/transaction_model.dart';
import 'package:finsight/screens/add_transaction_screen.dart';
import 'package:intl/intl.dart'; // ✅ for formatting date/time

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
        setState(() => _selectedImage = image);
        final result = await _ocrService.processImage(image.path);
        setState(() =>
        _recognizedText = result.isEmpty ? "No text detected." : result);
      } else {
        setState(() => _recognizedText = "Image selection cancelled.");
      }
    } catch (e) {
      setState(() => _recognizedText = "Error processing image: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  TransactionModel? _parseTransactionDetails(String text) {
    String merchant = "Unknown";
    double? amount;
    TransactionType type = TransactionType.debit;

    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final lowerText = text.toLowerCase();

    // --- Detect merchant name ---
    for (String line in lines) {
      final lower = line.toLowerCase();
      if (!RegExp(r'(road|layout|stage|block|gst|bill|no\.|operator|mc#|invoice)')
          .hasMatch(lower) &&
          RegExp(r'[a-zA-Z]').hasMatch(line)) {
        merchant =
            line.replaceAll(RegExp(r'[^a-zA-Z0-9 &]'), '').trim().toUpperCase();
        break;
      }
    }

    // --- Detect transaction type ---
    if (lowerText.contains("credited") ||
        lowerText.contains("refund") ||
        lowerText.contains("received")) {
      type = TransactionType.credit;
    }

    // --- Extract amount using smart logic ---
    final extraction = _extractSmartAmount(text);
    amount = extraction['amount'] as double?;

    if (amount == null) return null;

    // ✅ Use local system date and time
    final DateTime now = DateTime.now().toLocal();
    final formatted = DateFormat('dd-MM-yyyy hh:mm a').format(now);
    debugPrint("🕓 Transaction captured at (local): $formatted");

    debugPrint("✅ Best Match Line: '${extraction['line']}'");
    debugPrint(
        "💡 Confidence: ${(extraction['confidence'] as double).toStringAsFixed(2)}");
    debugPrint("🎯 Reason: ${extraction['reason']}");

    return TransactionModel(
      userId: '',
      senderAddress: merchant,
      messageBody: text,
      transactionDate: now, // ✅ Local system time
      amount: amount,
      type: type,
    );
  }

  // ---------------- SMART AMOUNT DETECTION + CONFIDENCE ----------------
  Map<String, dynamic> _extractSmartAmount(String ocrText) {
    final lines = ocrText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final amountRegex = RegExp(
      r'(?:₹|rs\.?|inr)?\s*\b(\d{1,5}(?:,?\d{3})*(?:[.,]\s*\d{1,2})?)\b',
      caseSensitive: false,
    );

    double bestScore = -999;
    double? bestValue;
    String bestLine = "";
    String bestReason = "";

    debugPrint("🔍 ===== Analyzing OCR text for total amount =====");

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      if (RegExp(r'(gstin|phone|tel|batch|txn\s*id)').hasMatch(line)) continue;

      final isTotalLike = line.contains(RegExp(
          r'total|payable|amount|grand|balance|bill amt|bill amount',
          caseSensitive: false)) ||
          line.replaceAll('1', 'l').contains('total');

      final matches = amountRegex.allMatches(line);

      // ✅ Handle "total" line with amount on next line
      if (isTotalLike && matches.isEmpty) {
        for (int lookAhead = 1; lookAhead <= 2; lookAhead++) {
          if (i + lookAhead < lines.length) {
            final next = lines[i + lookAhead].toLowerCase();
            final nextMatches = amountRegex.allMatches(next);
            for (final nm in nextMatches) {
              final raw = nm.group(1);
              if (raw == null) continue;
              final parsed =
              double.tryParse(raw.replaceAll(',', '').replaceAll(' ', ''));
              if (parsed != null && parsed > 1 && parsed < 100000) {
                double score = 20 - lookAhead * 2;
                if (score > bestScore) {
                  bestScore = score;
                  bestValue = parsed;
                  bestLine = lines[i + lookAhead];
                  bestReason = "[Total on next line +$score]";
                }
              }
            }
          }
        }
      }

      for (final m in matches) {
        final raw = m.group(1);
        if (raw == null) continue;

        final parsed =
        double.tryParse(raw.replaceAll(',', '').replaceAll(' ', ''));
        if (parsed == null) continue;

        double score = 0;
        String reason = "";

        if (isTotalLike) {
          score += 12;
          reason += "[Total keyword +12] ";
        }
        if (m.group(0)!.contains(RegExp(r'₹|rs|inr', caseSensitive: false))) {
          score += 3;
          reason += "[Currency symbol +3] ";
        }
        if (raw.contains('.')) {
          score += 2;
          reason += "[Has decimal +2] ";
        }
        if (parsed >= 50 && parsed < 50000) {
          score += 2;
          reason += "[Reasonable amount +2] ";
        } else if (parsed < 5) {
          score -= 5;
          reason += "[Tiny value -5] ";
        }

        if (line.contains(RegExp(r'saved|discount|save'))) {
          score -= 15;
          reason += "[Discount/Saved line -15] ";
        }

        if (line.contains('%') ||
            line.contains('cgst') ||
            line.contains('sgst')) {
          score -= 10;
          reason += "[Tax line (%) -10] ";
        }

        if (line.contains(RegExp(
            r'\b(order|ord|bill#|invoice|pi|no\.|id|ref)\b',
            caseSensitive: false))) {
          score -= 12;
          reason += "[Order/Invoice line -12] ";
        }

        if (!isTotalLike && RegExp(r'[a-zA-Z]+\d+').hasMatch(line)) {
          score -= 15;
          reason += "[AlphaNumeric code -15] ";
        }

        if (line.length < 8 && parsed >= 100 && parsed <= 999) {
          score -= 15;
          reason += "[Short numeric code -15] ";
        }

        if (RegExp(r'\b\d+(\.\d+)?\s+\d+(\.\d+)?\s+\d+(\.\d+)?')
            .hasMatch(line)) {
          score -= 4;
          reason += "[Item row -4] ";
        }

        score += (i / lines.length) * 1.5;
        reason += "[Bottom +${(i / lines.length * 1.5).toStringAsFixed(1)}] ";

        if (parsed < 10) {
          final nearby = lines.skip(max(0, i - 3)).take(6).join(' ');
          if (RegExp(r'(\d{2,3}\.\d{1,2})').hasMatch(nearby)) {
            score -= 10;
            reason += "[Tiny vs nearby large -10] ";
          }
        }

        debugPrint(
            "Line ${i + 1}: '$line' => ₹$parsed | Score: $score | $reason");

        if (score > bestScore) {
          bestScore = score;
          bestValue = parsed;
          bestLine = lines[i];
          bestReason = reason;
        }
      }
    }

    // Fallback if nothing detected
    if (bestValue == null) {
      final all = amountRegex
          .allMatches(ocrText)
          .map((m) {
        final raw = m.group(1);
        if (raw == null) return null;
        return double.tryParse(raw.replaceAll(',', '').replaceAll(' ', ''));
      })
          .whereType<double>()
          .where((v) => v > 1 && v < 20000)
          .toList();

      if (all.isNotEmpty) bestValue = all.reduce(max);
      bestLine = "(fallback largest)";
      bestReason = "No confident match — fallback to largest";
    }

    final confidence =
    (bestScore <= 0) ? 0 : min(1.0, (bestScore / 18.0));

    if (confidence < 0.4) {
      debugPrint(
          "⚠️ Low confidence (${confidence.toStringAsFixed(2)}) — ignoring amount.");
      return {
        'amount': null,
        'confidence': confidence,
        'line': bestLine,
        'reason': "$bestReason [Rejected: confidence < 0.4]",
      };
    }

    debugPrint(
        "✅ Selected ₹$bestValue | Line: '$bestLine' | Score: $bestScore | Confidence: ${confidence.toStringAsFixed(2)}");
    debugPrint("============================================");

    return {
      'amount': bestValue,
      'confidence': confidence,
      'line': bestLine,
      'reason': bestReason,
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
                  onPressed: _isProcessing
                      ? null
                      : () => _pickAndProcessImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text("Camera",
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006241)),
                ),
                ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _pickAndProcessImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, color: Colors.white),
                  label: const Text("Gallery",
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006241)),
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
                  Text("Recognized Text:",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700])),
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
                final TransactionModel? parsed =
                _parseTransactionDetails(_recognizedText);

                if (parsed == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            "Could not extract amount confidently. Please enter manually.")),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AddTransactionScreen()),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddTransactionScreen(prefillData: parsed),
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
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
