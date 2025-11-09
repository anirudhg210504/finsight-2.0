import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:finsight/services/ocr_service.dart';
import 'package:finsight/models/transaction_model.dart';
import 'package:finsight/screens/add_transaction_screen.dart';
import 'package:intl/intl.dart';

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

    // --- Enhanced merchant name detection ---
    merchant = _extractMerchantName(lines);

    // --- Detect transaction type ---
    if (lowerText.contains("credited") ||
        lowerText.contains("refund") ||
        lowerText.contains("received") ||
        lowerText.contains("deposit")) {
      type = TransactionType.credit;
    }

    // --- Extract amount using improved logic ---
    final extraction = _extractSmartAmount(text);
    amount = extraction['amount'] as double?;

    if (amount == null) return null;

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
      transactionDate: now,
      amount: amount,
      type: type,
    );
  }

  // ============= IMPROVED MERCHANT EXTRACTION =============
  String _extractMerchantName(List<String> lines) {
    if (lines.isEmpty) return "Unknown";

    // Common noise patterns to skip
    final skipPatterns = RegExp(
      r'(road|layout|stage|block|gst|bill|no\.|operator|mc#|invoice|'
      r'receipt|tax|invoice|customer|copy|original|duplicate|'
      r'^\d+$|^[\d\s\-\(\)]+$|phone|mobile|email|@|www\.|\.com)',
      caseSensitive: false,
    );

    // Look for merchant in first 5 lines (usually at top)
    for (int i = 0; i < min(5, lines.length); i++) {
      final line = lines[i].trim();
      final lower = line.toLowerCase();

      // Skip if too short or just numbers
      if (line.length < 3 || RegExp(r'^[\d\s\-\(\)]+$').hasMatch(line)) {
        continue;
      }

      // Skip noise patterns
      if (skipPatterns.hasMatch(lower)) continue;

      // Must contain letters
      if (!RegExp(r'[a-zA-Z]{3,}').hasMatch(line)) continue;

      // Clean and format - FIXED REGEX
      String cleaned = line
          .replaceAll(RegExp(r'[^\w\s&\-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      // Skip if still too short or all caps with numbers (likely code)
      if (cleaned.length < 3) continue;
      if (RegExp(r'^[A-Z0-9\s]+$').hasMatch(cleaned) &&
          RegExp(r'\d').hasMatch(cleaned)) continue;

      // Capitalize properly
      return _toTitleCase(cleaned);
    }

    return "Unknown Merchant";
  }

  String _toTitleCase(String text) {
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      if (word.length == 1) return word.toUpperCase();
      // Keep all-caps acronyms
      if (word == word.toUpperCase() && word.length <= 4) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // ============= ENHANCED AMOUNT DETECTION =============
  Map<String, dynamic> _extractSmartAmount(String ocrText) {
    final lines = ocrText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // More flexible amount regex supporting various formats
    final amountRegex = RegExp(
      r'(?:₹|rs\.?|inr|rupees?)?\s*\b(\d{1,5}(?:[,\s]?\d{3})*(?:[.,]\s*\d{1,2})?)\b',
      caseSensitive: false,
    );

    double bestScore = -999;
    double? bestValue;
    String bestLine = "";
    String bestReason = "";

    // Enhanced total keywords
    final totalKeywords = [
      'total', 'payable', 'amount', 'grand', 'balance',
      'bill amt', 'bill amount', 'net amount', 'amount payable',
      'you paid', 'paid', 'payment', 'to pay', 'final'
    ];

    debugPrint("🔍 ===== Analyzing OCR text for total amount =====");

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineLower = line.toLowerCase();

      // Skip irrelevant lines
      if (RegExp(r'(gstin|gst\s*no|phone|tel|mobile|batch|txn\s*id|transaction\s*id|upi|order\s*id)')
          .hasMatch(lineLower)) continue;

      // Check for total keywords (more flexible matching)
      final isTotalLike = totalKeywords.any((kw) => lineLower.contains(kw)) ||
          line.replaceAll('1', 'l').toLowerCase().contains('total') ||
          line.replaceAll('i', 'l').toLowerCase().contains('total');

      final matches = amountRegex.allMatches(line);

      // ✅ Handle "total" line with amount on next/previous line
      if (isTotalLike && matches.isEmpty) {
        // Look ahead (next 2 lines)
        for (int lookAhead = 1; lookAhead <= 2; lookAhead++) {
          if (i + lookAhead < lines.length) {
            final next = lines[i + lookAhead];
            final nextMatches = amountRegex.allMatches(next);
            for (final nm in nextMatches) {
              final parsed = _parseAmount(nm.group(1));
              if (parsed != null && parsed > 1 && parsed < 500000) {
                double score = 25 - lookAhead * 3;
                if (score > bestScore) {
                  bestScore = score;
                  bestValue = parsed;
                  bestLine = lines[i + lookAhead];
                  bestReason = "[Total label, amount on next line +$score]";
                }
              }
            }
          }
        }

        // Look back (previous line)
        if (i > 0) {
          final prev = lines[i - 1];
          final prevMatches = amountRegex.allMatches(prev);
          for (final pm in prevMatches) {
            final parsed = _parseAmount(pm.group(1));
            if (parsed != null && parsed > 1 && parsed < 500000) {
              double score = 22;
              if (score > bestScore) {
                bestScore = score;
                bestValue = parsed;
                bestLine = lines[i - 1];
                bestReason = "[Total label, amount on prev line +$score]";
              }
            }
          }
        }
      }

      // Process amounts on the current line
      for (final m in matches) {
        final parsed = _parseAmount(m.group(1));
        if (parsed == null) continue;

        double score = 0;
        String reason = "";

        // ✅ Strong positive signals
        if (isTotalLike) {
          score += 15;
          reason += "[Total keyword +15] ";
        }

        // Currency symbol present
        if (m.group(0)!.contains(RegExp(r'₹|rs|inr|rupees?', caseSensitive: false))) {
          score += 4;
          reason += "[Currency +4] ";
        }

        // Has decimal (more precise)
        if (parsed % 1 != 0) {
          score += 3;
          reason += "[Decimal +3] ";
        }

        // Reasonable amount range
        if (parsed >= 50 && parsed <= 10000) {
          score += 3;
          reason += "[Good range +3] ";
        } else if (parsed > 10000 && parsed <= 50000) {
          score += 2;
          reason += "[High but valid +2] ";
        } else if (parsed < 10) {
          score -= 8;
          reason += "[Too small -8] ";
        } else if (parsed > 50000) {
          score -= 5;
          reason += "[Unusually high -5] ";
        }

        // ✅ Strong negative signals
        if (lineLower.contains(RegExp(r'saved|discount|save|you save'))) {
          score -= 20;
          reason += "[Discount -20] ";
        }

        if (lineLower.contains('%') || lineLower.contains('cgst') ||
            lineLower.contains('sgst') || lineLower.contains('tax')) {
          score -= 12;
          reason += "[Tax line -12] ";
        }

        if (lineLower.contains(RegExp(
            r'\b(order|ord|bill\s*#|invoice|pi|no\.|id|ref|txn)\b'))) {
          score -= 15;
          reason += "[ID/Reference -15] ";
        }

        // Alphanumeric codes (likely not amounts)
        if (!isTotalLike && RegExp(r'[A-Z]{2,}\d+|\d+[A-Z]{2,}').hasMatch(line)) {
          score -= 18;
          reason += "[Code pattern -18] ";
        }

        // Short numeric lines (likely codes)
        if (line.length < 10 && RegExp(r'^\d+$').hasMatch(line.trim())) {
          score -= 20;
          reason += "[Standalone number -20] ";
        }

        // Item rows (multiple numbers)
        if (RegExp(r'\b\d+(?:\.\d+)?\s+\d+(?:\.\d+)?\s+\d+(?:\.\d+)?')
            .hasMatch(line)) {
          score -= 6;
          reason += "[Item row -6] ";
        }

        // ✅ Position bonus (totals usually near bottom)
        final positionBonus = (i / max(1, lines.length - 1)) * 2.5;
        score += positionBonus;
        reason += "[Position +${positionBonus.toStringAsFixed(1)}] ";

        // Context check for tiny amounts
        if (parsed < 20) {
          final context = lines.skip(max(0, i - 2)).take(5).join(' ');
          if (RegExp(r'(\d{3,}\.\d{1,2})').hasMatch(context)) {
            score -= 12;
            reason += "[Tiny vs context -12] ";
          }
        }

        debugPrint(
            "Line ${i + 1}: '$line' => ₹$parsed | Score: ${score.toStringAsFixed(1)} | $reason");

        if (score > bestScore) {
          bestScore = score;
          bestValue = parsed;
          bestLine = lines[i];
          bestReason = reason;
        }
      }
    }

    // ✅ Improved fallback
    if (bestValue == null || bestScore < 0) {
      final allAmounts = amountRegex
          .allMatches(ocrText)
          .map((m) => _parseAmount(m.group(1)))
          .whereType<double>()
          .where((v) => v >= 10 && v < 100000)
          .toList();

      if (allAmounts.isNotEmpty) {
        // Use median instead of max for better accuracy
        allAmounts.sort();
        bestValue = allAmounts[allAmounts.length ~/ 2];
        bestLine = "(fallback median)";
        bestReason = "No confident match — using median value";
        bestScore = 5;
      }
    }

    // Calculate confidence (0-1 scale)
    final confidence = bestScore <= 0
        ? 0.0
        : min(1.0, max(0.0, (bestScore + 5) / 25.0));

    // ✅ Adaptive threshold based on score distribution
    final minConfidence = bestScore > 15 ? 0.3 : 0.5;

    if (confidence < minConfidence) {
      debugPrint(
          "⚠️ Low confidence (${confidence.toStringAsFixed(2)}) — rejecting amount.");
      return {
        'amount': null,
        'confidence': confidence,
        'line': bestLine,
        'reason': "$bestReason [Rejected: confidence < $minConfidence]",
      };
    }

    debugPrint(
        "✅ Selected ₹$bestValue | Line: '$bestLine' | Score: ${bestScore.toStringAsFixed(1)} | Confidence: ${confidence.toStringAsFixed(2)}");
    debugPrint("============================================");

    return {
      'amount': bestValue,
      'confidence': confidence,
      'line': bestLine,
      'reason': bestReason,
    };
  }

  // Helper to parse amount string
  double? _parseAmount(String? raw) {
    if (raw == null) return null;

    // Remove commas and spaces
    final cleaned = raw.replaceAll(',', '').replaceAll(' ', '').trim();

    // Handle both dot and comma as decimal separator
    final normalized = cleaned.replaceAll(',', '.');

    return double.tryParse(normalized);
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
                            "Could not extract amount confidently. Please enter manually."),
                        duration: Duration(seconds: 3)),
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