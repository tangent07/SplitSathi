import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // <-- NEW IMPORT
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class SettleUpSheet extends StatefulWidget {
  final String receiverName;
  final String receiverUid;
  final String? receiverUpiId;
  final double amount;
  final String groupId;

  const SettleUpSheet({
    super.key,
    required this.receiverName,
    required this.receiverUid,
    this.receiverUpiId,
    required this.amount,
    required this.groupId,
  });

  @override
  State<SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends State<SettleUpSheet> {
  bool _isLoading = false;

  // --- LOGIC 1: Record Cash Payment ---
  Future<void> _recordManualPayment() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final currentUser = AuthService().currentUser;
      if (currentUser == null) return;

      if (widget.groupId == 'DIRECT') {
        await FirebaseFirestore.instance.collection('direct_payments').add({
          'userId': currentUser.uid,
          'friendName': widget.receiverName,
          'youPaid': true,
          'amount': widget.amount,
          'note': 'Settled via UPI/Cash',
          'date': DateTime.now().toIso8601String(),
        });
      } else {
        await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).collection('expenses').add({
          'name': 'Settled Up',
          'category': '🤝',
          'amount': widget.amount,
          'paidBy': 'You',
          'splitAmong': [widget.receiverName],
          'isSettlement': true,
          'date': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recorded payment of ₹${widget.amount.toStringAsFixed(0)} to ${widget.receiverName}'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIC 2: Pay via UPI ---
  Future<void> _launchUpiApp() async {
    // 1. Check if UPI is missing and show in-app warning
    if (widget.receiverUpiId == null || widget.receiverUpiId!.isEmpty) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ ${widget.receiverName} hasn\'t linked a UPI ID yet. You can only record a cash payment for now.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return; 
    }

    // 2. Format the UPI URL
    final upiUrl = Uri.parse(
      'upi://pay?pa=${widget.receiverUpiId}&pn=${Uri.encodeComponent(widget.receiverName)}&am=${widget.amount.toStringAsFixed(2)}&cu=INR'
    );

    // 3. Launch the app
    try {
      if (await canLaunchUrl(upiUrl)) {
        await launchUrl(upiUrl, mode: LaunchMode.externalApplication);
        
        // When they return to Splitsathi, ask if it worked!
        if (mounted) {
          _showConfirmPaymentDialog();
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No UPI app found on this device.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch UPI app.')));
    }
  }

  // --- DIALOG: Confirm successful UPI transfer ---
  void _showConfirmPaymentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Did the payment succeed?'),
        content: Text('Did you successfully send ₹${widget.amount.toStringAsFixed(0)} to ${widget.receiverName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('No, it failed', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              _recordManualPayment(); // Treat it like a cash payment to zero out the debt!
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Yes, Paid', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );
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
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),

          CircleAvatar(
            radius: 30, backgroundColor: AppColors.orange.withOpacity(0.1),
            child: Text(widget.receiverName[0].toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.orange)),
          ),
          const SizedBox(height: 16),
          Text('You are paying ${widget.receiverName}', style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('₹${widget.amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: textColor, fontFamily: 'Nunito')),
          const SizedBox(height: 32),

          // Option 1: Cash
          _buildOptionButton(
            icon: Icons.check_circle_outline_rounded, title: 'Record a cash payment', subtitle: 'Mark as paid without opening an app.',
            iconColor: Colors.green, isDark: isDark, onTap: _isLoading ? null : _recordManualPayment,
          ),
          const SizedBox(height: 16),
          
          // Option 2: UPI (Always clickable so we can show the warning if missing)
          _buildOptionButton(
            icon: Icons.qr_code_scanner_rounded, title: 'Pay via UPI',
            subtitle: 'Send exactly ₹${widget.amount.toStringAsFixed(0)} to their UPI app.',
            iconColor: AppColors.orange, isDark: isDark, 
            onTap: _isLoading ? null : _launchUpiApp,
          ),
          
          const SizedBox(height: 20),
          if (_isLoading) const CircularProgressIndicator(color: AppColors.orange),
        ],
      ),
    );
  }

  Widget _buildOptionButton({required IconData icon, required String title, required String subtitle, required Color iconColor, required bool isDark, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBg : Colors.grey.shade100, 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: iconColor.withOpacity(0.3))
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 2), Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12))])),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}