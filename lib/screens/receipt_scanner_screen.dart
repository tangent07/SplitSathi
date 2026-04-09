import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';

// Helper model for scanned items
class ScannedItem {
  String name;
  double price;
  ScannedItem({required this.name, required this.price});
}

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  bool _isScanning = false;
  File? _imageFile;
  List<ScannedItem> _extractedItems = [];

  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  // --- 1. PICK IMAGE & START SCAN ---
  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 80);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _isScanning = true;
          _extractedItems.clear();
        });
        await _processImage(_imageFile!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error taking picture: $e')));
      setState(() => _isScanning = false);
    }
  }

  // --- 2. AI TEXT RECOGNITION & SMART PARSING ---
  Future<void> _processImage(File image) async {
    final inputImage = InputImage.fromFile(image);
    try {
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      List<ScannedItem> foundItems = [];
      
      // REGEX: Looks for numbers that look like prices (e.g., 12.50, 400.00, $15)
      final priceRegExp = RegExp(r'[$₹€£]?\s*(\d+[\.,]\d{2})');

      // We read the receipt line by line
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          final text = line.text;
          final match = priceRegExp.firstMatch(text);
          
          if (match != null) {
            // If we found a price, extract the number
            String priceStr = match.group(1)!.replaceAll(',', '.');
            double price = double.tryParse(priceStr) ?? 0.0;
            
            // The item name is whatever text comes BEFORE the price on that line
            String name = text.substring(0, match.start).trim();
            // Clean up common receipt garbage
            name = name.replaceAll(RegExp(r'[^a-zA-Z\s]'), '').trim();
            
            // Ignore taxes, subtotals, and empty names to keep the list clean
            if (name.isNotEmpty && price > 0 && 
                !name.toLowerCase().contains('tax') && 
                !name.toLowerCase().contains('total') &&
                !name.toLowerCase().contains('tip')) {
              foundItems.add(ScannedItem(name: name, price: price));
            }
          }
        }
      }

      setState(() {
        _extractedItems = foundItems;
        _isScanning = false;
      });
      HapticFeedback.heavyImpact();

    } catch (e) {
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to read receipt.')));
    }
  }

  // --- 3. RETURN DATA TO PREVIOUS SCREEN ---
  void _confirmAndReturn() {
    if (_extractedItems.isEmpty) return;
    HapticFeedback.mediumImpact();
    // Calculate the total of all scanned items
    final total = _extractedItems.fold(0.0, (sum, item) => sum + item.price);
    
    // Return the total back to the Quick Split screen!
    Navigator.pop(context, total);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.orange), onPressed: () => Navigator.pop(context)),
        title: const Text('Scan Receipt', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
        centerTitle: true,
      ),
      body: _isScanning 
        ? _buildScanningAnimation() 
        : _extractedItems.isEmpty 
            ? _buildPlaceholder(isDark) 
            : _buildResultsList(isDark),
            
      // FLOATING ACTION BUTTONS FOR CAMERA/GALLERY
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isScanning || _extractedItems.isNotEmpty ? null : Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton.extended(
            heroTag: "gallery_btn",
            onPressed: () => _getImage(ImageSource.gallery),
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            icon: Icon(Icons.image, color: isDark ? Colors.white : Colors.black87),
            label: Text('Gallery', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            heroTag: "camera_btn",
            onPressed: () => _getImage(ImageSource.camera),
            backgroundColor: AppColors.orange,
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            label: const Text('Take Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      
      // BOTTOM CONFIRM BUTTON (Only shows when items are scanned)
      bottomNavigationBar: _extractedItems.isNotEmpty ? Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          height: 60,
          child: ElevatedButton(
            onPressed: _confirmAndReturn,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: Text('Confirm ₹${_extractedItems.fold(0.0, (s, i) => s + i.price).toStringAsFixed(0)} & Split', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ) : null,
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.document_scanner_outlined, size: 100, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 24),
          Text('Let AI do the math.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          Text('Take a photo of your restaurant bill\nand we will extract the prices.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildScanningAnimation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.orange),
          const SizedBox(height: 24),
          const Text('Reading receipt...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Extracting items and prices', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildResultsList(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _extractedItems.length,
      separatorBuilder: (_, __) => Divider(color: isDark ? Colors.white10 : Colors.black12, height: 24),
      itemBuilder: (context, index) {
        final item = _extractedItems[index];
        return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.fastfood_rounded, color: AppColors.orange, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(item.name.isEmpty ? 'Unknown Item' : item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            Text('₹${item.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.orange)),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey, size: 18),
              onPressed: () => setState(() => _extractedItems.removeAt(index)),
            )
          ],
        );
      },
    );
  }
}