import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class ExportReportSheet extends StatefulWidget {
  const ExportReportSheet({super.key});

  @override
  State<ExportReportSheet> createState() => _ExportReportSheetState();
}

class _ExportReportSheetState extends State<ExportReportSheet> {
  bool _isGenerating = false;
  String _selectedFormat = 'PDF'; // 'PDF' or 'CSV'
  String _selectedTimeframe = 'All Time'; // 'This Month', 'Last Month', 'All Time'

  Future<void> _generateAndShareReport() async {
    setState(() => _isGenerating = true);
    HapticFeedback.mediumImpact();

    try {
      final myUid = AuthService().currentUser?.uid;
      if (myUid == null) throw Exception("User not logged in");

      List<Map<String, dynamic>> allTransactions = [];

      // --- 1. FETCH DIRECT PAYMENTS ---
      final directQuery = await FirebaseFirestore.instance.collection('direct_payments').where('userId', isEqualTo: myUid).get();
      for (var doc in directQuery.docs) {
        final data = doc.data();
        allTransactions.add({
          'date': data['date'],
          'friendName': data['friendName'],
          'youPaid': data['youPaid'] == true,
          'amount': data['amount'],
          'note': data['note'] ?? 'Direct Payment',
        });
      }

      // --- 2. FETCH GROUP EXPENSES ---
      // Find all groups where "You" are a member
      final groupQuery = await FirebaseFirestore.instance.collection('groups').where('members', arrayContains: 'You').get();
      for (var gDoc in groupQuery.docs) {
        final groupName = gDoc.data()['name'] ?? 'Group';
        final expQuery = await FirebaseFirestore.instance.collection('groups').doc(gDoc.id).collection('expenses').get();
        
        for (var expDoc in expQuery.docs) {
          final exp = expDoc.data();
          // Skip deleted or ghost records so they don't clutter the report
          if (exp['deleted'] == true || exp['isGhost'] == true) continue;

          final paidBy = exp['paidBy'] ?? '';
          final splitAmong = List<String>.from(exp['splitAmong'] ?? []);
          
          // Only add it to your report if YOU are involved in this transaction!
          if (paidBy == 'You' || splitAmong.contains('You')) {
            String expName = exp['name'] ?? 'Expense';
            
            allTransactions.add({
              // Convert Firestore Timestamp to string so the PDF/CSV generators can read it
              'date': (exp['date'] as Timestamp).toDate().toIso8601String(),
              // If you paid, show who you paid for. If they paid, show their name.
              'friendName': paidBy == 'You' ? (splitAmong.length == 1 ? splitAmong.first : '${splitAmong.length} people') : paidBy,
              'youPaid': paidBy == 'You',
              'amount': exp['amount'],
              'note': 'Group [$groupName]: $expName', // Adds the group name to the note!
            });
          }
        }
      }

      // --- FILTER BY TIMEFRAME ---
      final now = DateTime.now();
      allTransactions = allTransactions.where((t) {
        final date = DateTime.parse(t['date']);
        if (_selectedTimeframe == 'This Month') {
          return date.month == now.month && date.year == now.year;
        } else if (_selectedTimeframe == 'Last Month') {
          final lastMonth = DateTime(now.year, now.month - 1);
          return date.month == lastMonth.month && date.year == lastMonth.year;
        }
        return true; // All Time
      }).toList();

      // --- SORT CHRONOLOGICALLY ---
      allTransactions.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));

      if (allTransactions.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data found for this timeframe.')));
        setState(() => _isGenerating = false);
        return;
      }

      // --- GENERATE & SHARE FILE ---
      File file;
      if (_selectedFormat == 'CSV') {
        file = await _generateCSV(allTransactions);
      } else {
        file = await _generatePDF(allTransactions);
      }

      if (mounted) {
        Navigator.pop(context); // Close sheet
        await Share.shareXFiles([XFile(file.path)], text: 'Here is my SplitSathi Report ($_selectedTimeframe)');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating report: $e')));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<File> _generateCSV(List<Map<String, dynamic>> transactions) async {
    final currency = context.read<AppProvider>().currency;
    List<List<dynamic>> rows = [];
    rows.add(["Date", "Friend", "Type", "Amount ($currency)", "Note"]); // Header

    for (var t in transactions) {
      final date = DateFormat('yyyy-MM-dd').format(DateTime.parse(t['date']));
      final type = t['youPaid'] == true ? "You Paid" : "They Paid You";
      rows.add([date, t['friendName'], type, t['amount'], t['note'] ?? '']);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/SplitSathi_Report.csv');
    return file.writeAsString(csvData);
  }

  Future<File> _generatePDF(List<Map<String, dynamic>> transactions) async {
    final currency = context.read<AppProvider>().currency;
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SplitSathi Financial Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('Timeframe: $_selectedTimeframe', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
              pw.SizedBox(height: 24),
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Date', 'Friend', 'Type', 'Amount(INR)', 'Note'],
                data: transactions.map((t) {
                  final date = DateFormat('MMM d, yyyy').format(DateTime.parse(t['date']));
                  final type = t['youPaid'] == true ? "You Paid" : "They Paid";
                  return [date, t['friendName'], type, t['amount'].toString(), t['note'] ?? ''];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.orange),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: .5))),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(8),
              ),
            ],
          );
        },
      ),
    );

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/SplitSathi_Report.pdf');
    return file.writeAsBytes(await pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);

    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          Text('Export Reports 📊', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor, fontFamily: 'Inter')),
          const SizedBox(height: 8),
          Text('Generate a clean summary of your transactions.', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          const SizedBox(height: 24),

          // Format Selection
          Text('FORMAT', style: TextStyle(color: AppColors.orange, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSelectCard('PDF', Icons.picture_as_pdf, _selectedFormat == 'PDF', () => setState(() => _selectedFormat = 'PDF'))),
              const SizedBox(width: 12),
              Expanded(child: _buildSelectCard('CSV', Icons.table_chart, _selectedFormat == 'CSV', () => setState(() => _selectedFormat = 'CSV'))),
            ],
          ),
          const SizedBox(height: 24),

          // Timeframe Selection
          Text('TIMEFRAME', style: TextStyle(color: AppColors.orange, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: ['This Month', 'Last Month', 'All Time'].map((time) {
              final isSelected = _selectedTimeframe == time;
              return ChoiceChip(
                label: Text(time, style: TextStyle(color: isSelected ? Colors.white : textColor, fontWeight: FontWeight.bold)),
                selected: isSelected,
                selectedColor: AppColors.orange,
                backgroundColor: isDark ? AppColors.darkBg : Colors.grey.shade100,
                onSelected: (val) => setState(() => _selectedTimeframe = time),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                showCheckmark: false,
              );
            }).toList(),
          ),
          
          const SizedBox(height: 32),

          // Generate Button
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateAndShareReport,
              icon: _isGenerating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.ios_share, color: Colors.white),
              label: Text(_isGenerating ? 'Generating...' : 'Generate & Share', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSelectCard(String title, IconData icon, bool isSelected, VoidCallback onTap) {
    final isDark = context.read<AppProvider>().isDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.orange.withOpacity(0.1) : (isDark ? AppColors.darkBg : Colors.grey.shade100),
          border: Border.all(color: isSelected ? AppColors.orange : Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.orange : Colors.grey.shade500),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? AppColors.orange : Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}