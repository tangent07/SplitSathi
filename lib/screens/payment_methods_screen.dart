import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final _user = AuthService().currentUser;

  void _showAddUpiSheet(BuildContext context, String currentUpi) {
    final upiController = TextEditingController(text: currentUpi);
    final isDark = Provider.of<AppProvider>(context, listen: false).isDark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24, right: 24, top: 24,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Link UPI ID', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
            const SizedBox(height: 8),
            Text('Friends will see this when they settle up with you.', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
            const SizedBox(height: 24),
            
            TextField(
              controller: upiController,
              decoration: InputDecoration(
                hintText: 'e.g. mayank@okhdfcbank',
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.orange),
                filled: true,
                fillColor: isDark ? AppColors.darkBg : Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  final newUpi = upiController.text.trim();
                  if (newUpi.isNotEmpty) {
                    HapticFeedback.mediumImpact();
                    await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
                      'upiId': newUpi,
                    });
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Save UPI ID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;

    if (_user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.orange, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('Payment Methods', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w900, fontFamily: 'Inter')),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(_user!.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.orange));

          final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final upiId = userData['upiId'] as String?;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('RECEIVE MONEY', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 16),
              
              if (upiId == null || upiId.isEmpty)
                _buildAddUpiCard(context, isDark)
              else
                _buildLinkedUpiCard(context, upiId, isDark),
                
              const SizedBox(height: 32),
              
              // Placeholder for future bank account additions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance_outlined, color: Colors.grey.shade400),
                    const SizedBox(width: 12),
                    Text('Bank Account (Coming Soon)', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildAddUpiCard(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => _showAddUpiSheet(context, ''),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.orange.withOpacity(0.8), AppColors.orange], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppColors.orange.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 32),
            SizedBox(height: 16),
            Text('Link UPI ID', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Get paid back faster directly to your bank.', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedUpiCard(BuildContext context, String upiId, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Primary UPI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: AppColors.orange, size: 20),
                onPressed: () => _showAddUpiSheet(context, upiId),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(upiId, style: const TextStyle(fontSize: 18, letterSpacing: 1, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}