import '../screens/login_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'export_report_sheet.dart';
import 'package:flutter/services.dart';
import '../screens/receipt_scanner_screen.dart';
import '../screens/quick_split_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:splitsathi/screens/payment_methods_screen.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../screens/settings_screen.dart';
import '../screens/profile_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final isDark = context.watch<AppProvider>().isDark;

    return Drawer(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(32)),
      ),
      child: user == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.orange));
                }

                final userData =
                    snapshot.data?.data() as Map<String, dynamic>? ?? {};
                final name = userData['name'] ?? 'Guest User';

                // Show email if present, otherwise phone.
                final email = userData['email'] ?? '';
                final phone = userData['phone'] ?? '';
                final subtitle = email.isNotEmpty ? email : phone;

                final photoUrl = userData['photoUrl'];

                return Column(
                  children: [
                    // 1. HEADER
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ProfileScreen()),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 20,
                          bottom: 24,
                          left: 24,
                          right: 20,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.orange, Color(0xFFFB923C)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.orange.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8)
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.white,
                                // 👇 THE FIX: If there is no photoUrl, it loads the initials! 👇
                                backgroundImage: (photoUrl != null && photoUrl.toString().isNotEmpty)
                                    ? NetworkImage(photoUrl)
                                    : NetworkImage('https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=F97316&color=fff&bold=true&size=200') as ImageProvider,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Inter'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle.isNotEmpty
                                        ? subtitle
                                        : 'Complete your profile',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 2. MENU
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        children: [
                          _buildSectionHeader('ACCOUNT', isDark),
                          _buildDrawerItem(
                            context: context,
                            icon: Icons.person_outline_rounded,
                            title: 'Profile',
                            isDark: isDark,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const ProfileScreen()),
                              );
                            },
                          ),
                          _buildDrawerItem(
                            context: context,
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'Payment Methods',
                            isDark: isDark,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const PaymentMethodsScreen()),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildSectionHeader('TOOLS', isDark),
                          _buildDrawerItem(
                            context: context,
                            icon: Icons.document_scanner_outlined,
                            title: 'Scan Receipt',
                            isDark: isDark,
                            onTap: () async {
                              Navigator.pop(context);
                              HapticFeedback.lightImpact();

                              final scannedTotal = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const ReceiptScannerScreen()),
                              );

                              if (scannedTotal != null &&
                                  scannedTotal is double) {
                                if (context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => QuickSplitScreen(
                                          initialTotal: scannedTotal),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          _buildDrawerItem(
                            context: context,
                            icon: Icons.insert_chart_outlined,
                            title: 'Export Reports',
                            isDark: isDark,
                            onTap: () {
                              Navigator.pop(context);
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => ExportReportSheet(),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildSectionHeader('PREFERENCES', isDark),
                          _buildDrawerItem(
                            context: context,
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy Policy',
                            isDark: isDark,
                            onTap: () async {
                              Navigator.pop(context);
                              final Uri url = Uri.parse(
                                  'https://www.termsfeed.com/live/example-privacy-policy');

                              try {
                                if (!await launchUrl(url,
                                    mode: LaunchMode.externalApplication)) {
                                  throw Exception('Could not launch URL');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Could not open Privacy Policy')),
                                  );
                                }
                              }
                            },
                          ),
                          _buildDrawerItem(
                            context: context,
                            icon: Icons.settings_outlined,
                            title: 'Settings',
                            isDark: isDark,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const SettingsScreen()),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildSectionHeader('COMMUNITY', isDark),
                          _buildDrawerItem(
                            context: context,
                            icon: Icons.person_add_alt_1_outlined,
                            title: 'Invite Friends',
                            isDark: isDark,
                            onTap: () async {
                              Navigator.pop(context);
                              await Share.share(
                                  'I use SplitSathi to split bills and track expenses. It makes settling up so easy! Download it here: https://splitsathi.com/download');
                            },
                          ),
                          _buildDrawerItem(
                            context: context,
                            icon: Icons.help_outline_rounded,
                            title: 'Help & Support',
                            isDark: isDark,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),

                    // 3. FOOTER WITH LOGOUT
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(
                              height: 1,
                              color: isDark
                                  ? Colors.white10
                                  : Colors.black12),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () => _confirmLogout(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                    child: const Icon(Icons.logout_rounded,
                                        color: Colors.redAccent, size: 20),
                                  ),
                                  const SizedBox(width: 16),
                                  const Text('Logout',
                                      style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Text(
                              'Splitsathi v1.0.0',
                              style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  // Logout flow: close drawer -> confirm -> wipe provider data -> sign out.
  // AuthGate will then automatically route back to LoginScreen.
  //
  // IMPORTANT: we capture Navigator / ScaffoldMessenger / AppProvider refs
  // BEFORE popping the drawer. Using the drawer's context after the pop
  // would reference a disposed widget, which causes the dialog's future
  // to hang indefinitely.
  Future<void> _confirmLogout(BuildContext context) async {
    final navigator = Navigator.of(context);
    final rootContext = navigator.context;
    final appProvider = context.read<AppProvider>();

    Navigator.pop(context); // Close the drawer first.

    final confirmed = await showDialog<bool>(
      context: rootContext,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out of SplitSathi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 1. Immediately wipe in-memory data so the UI doesn't flash old state.
    appProvider.clearAllData();

    // 2. Sign out of Firebase + Google.
    try {
      await AuthService().signOut();
    } catch (e) {
      debugPrint('Logout error (non-fatal): $e');
    }

    // 3. Force-pop back to the root route so AuthGate re-renders cleanly.
    // Guards against any Navigator.push that may have happened after login.
    navigator.popUntil((route) => route.isFirst);
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8, top: 8),
      child: Text(
        title,
        style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon,
          color: isDark ? Colors.white70 : Colors.black87, size: 22),
      title: Text(
        title,
        style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87),
      ),
      trailing: Icon(Icons.chevron_right_rounded,
          color: Colors.grey.withOpacity(0.4), size: 18),
      hoverColor: AppColors.orange.withOpacity(0.05),
      splashColor: AppColors.orange.withOpacity(0.1),
    );
  }
}