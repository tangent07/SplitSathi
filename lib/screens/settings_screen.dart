import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Local state for our notification/haptic toggles
  bool _hapticsEnabled = true;
  bool _notifyNewExpense = true;
  bool _notifySettledUp = true;
  bool _notifyGroupInvites = true;

  // A quick dialog for picking currency, now wired to the AppProvider!
  void _showCurrencyPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['₹ (INR)', '\$ (USD)', '€ (EUR)', '£ (GBP)'].map((currency) {
              return ListTile(
                title: Text(currency, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                onTap: () {
                  // Tell the global provider to save the new currency!
                  context.read<AppProvider>().setCurrency(currency.split(' ')[0]);
                  Navigator.pop(bottomSheetContext);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // Placeholder for App Store redirect
  void _redirectToAppStore() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Redirecting to App Store... 🚀')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;
    final bg = isDark ? AppColors.darkBg : AppColors.cream;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final sectionColor = isDark ? AppColors.darkMuted : AppColors.muted;
    
    // <-- NEW: Grab the live currency from the provider! -->
    final currentCurrency = context.watch<AppProvider>().currency;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),

          // --- PREFERENCES SECTION ---
          _buildSectionHeader('PREFERENCES', sectionColor),
          ListTile(
            leading: const Icon(Icons.payments_outlined, color: AppColors.orange),
            title: Text('Default Currency', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // <-- NEW: Display the live currency here! -->
                Text(currentCurrency, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.orange)),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
            onTap: () => _showCurrencyPicker(context),
          ),
          SwitchListTile(
            activeColor: AppColors.orange,
            secondary: const Icon(Icons.vibration, color: AppColors.orange),
            title: Text('Haptic Feedback', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
            subtitle: Text('Vibrations on button taps', style: TextStyle(fontSize: 12, color: sectionColor)),
            value: _hapticsEnabled,
            onChanged: (val) {
              if (val) HapticFeedback.heavyImpact();
              setState(() => _hapticsEnabled = val);
            },
          ),
          
          const Divider(height: 32),

          // --- NOTIFICATIONS SECTION ---
          _buildSectionHeader('PUSH NOTIFICATIONS', sectionColor),
          SwitchListTile(
            activeColor: AppColors.orange,
            secondary: const Icon(Icons.receipt_long, color: AppColors.orange),
            title: Text('New Expenses', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
            subtitle: Text('When someone adds a bill you owe', style: TextStyle(fontSize: 12, color: sectionColor)),
            value: _notifyNewExpense,
            onChanged: (val) => setState(() => _notifyNewExpense = val),
          ),
          SwitchListTile(
            activeColor: AppColors.orange,
            secondary: const Icon(Icons.handshake_outlined, color: AppColors.orange),
            title: Text('Settlements', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
            subtitle: Text('When someone pays you back', style: TextStyle(fontSize: 12, color: sectionColor)),
            value: _notifySettledUp,
            onChanged: (val) => setState(() => _notifySettledUp = val),
          ),
          SwitchListTile(
            activeColor: AppColors.orange,
            secondary: const Icon(Icons.group_add_outlined, color: AppColors.orange),
            title: Text('Group Invites', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
            subtitle: Text('When you are added to a new group', style: TextStyle(fontSize: 12, color: sectionColor)),
            value: _notifyGroupInvites,
            onChanged: (val) => setState(() => _notifyGroupInvites = val),
          ),

          const Divider(height: 32),

          // --- SUPPORT & FEEDBACK ---
          _buildSectionHeader('SUPPORT', sectionColor),
          ListTile(
            leading: const Icon(Icons.star_rate_rounded, color: Colors.amber),
            title: Text('Rate SplitSathi', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
            onTap: _redirectToAppStore,
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline, color: AppColors.orange),
            title: Text('Send Feedback', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
            onTap: _redirectToAppStore, 
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.orange),
            title: Text('Privacy Policy', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
            onTap: () {},
          ),

          const Divider(height: 32),

          // --- DANGER ZONE ---
          _buildSectionHeader('ACCOUNT', sectionColor),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete Account logic coming soon!'), backgroundColor: Colors.red),
              );
            },
          ),
          
          const SizedBox(height: 48),
          
          // App Version
          Center(
            child: Text(
              'SplitSathi v1.0.0\nMade with ❤️',
              textAlign: TextAlign.center,
              style: TextStyle(color: sectionColor, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}