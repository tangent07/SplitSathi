import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _notifyNewExpense = true;
  bool _notifySettledUp = true;
  bool _notifyGroupInvites = true;
  final String _playStoreLink = '';
  final String _privacyPolicyLink = 'https://www.termsfeed.com/live/example-privacy-policy';
  final String _supportEmail = 'splitsathi@gmail.com';

  int _versionTapCount = 0;
  DateTime? _lastTapTime;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifyNewExpense = prefs.getBool('notifyNewExpense') ?? true;
      _notifySettledUp = prefs.getBool('notifySettledUp') ?? true;
      _notifyGroupInvites = prefs.getBool('notifyGroupInvites') ?? true;
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _handleSecretTap() {
    final now = DateTime.now();
    if (_lastTapTime == null || now.difference(_lastTapTime!) > const Duration(milliseconds: 500)) {
      _versionTapCount = 1;
    } else {
      _versionTapCount++;
    }
    _lastTapTime = now;

    if (_versionTapCount == 7) {
      _versionTapCount = 0; 
      HapticFeedback.heavyImpact();
      _confettiController.play(); 
    }
  }

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

  // 👇 NEW: The Text Size Picker Menu 👇
  // 👇 UPGRADED: Horizontal Slider Text Size Picker 👇
  void _showTextSizePicker(BuildContext context) {
    final sizes = ['XS', 'S', 'M', 'L', 'XL'];
    final provider = context.read<AppProvider>();
    
    // Find where the current size sits on our 0-4 scale (Defaults to 2 / 'M' if not found)
    double currentValue = sizes.indexOf(provider.textSize).toDouble();
    if (currentValue < 0) currentValue = 2.0; 

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bottomSheetContext) {
        // StatefulBuilder allows the slider to update its position smoothly while dragging
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Adjust Text Size', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 24),
                    
                    // The Custom Slider
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: AppColors.orange,
                        inactiveTrackColor: AppColors.orange.withOpacity(0.2),
                        thumbColor: AppColors.orange,
                        overlayColor: AppColors.orange.withOpacity(0.1),
                        tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 4.5),
                        activeTickMarkColor: Colors.white,
                        inactiveTickMarkColor: AppColors.orange.withOpacity(0.4),
                      ),
                      child: Slider(
                        value: currentValue,
                        min: 0,
                        max: 4,
                        divisions: 4, // Snaps exactly to our 5 sizes
                        onChanged: (val) {
                          setModalState(() {
                            currentValue = val;
                          });
                          // Triggers the real-time scale update in the background!
                          provider.setTextSize(sizes[val.toInt()]);
                        },
                      ),
                    ),
                    
                    // The X-Axis Labels
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: sizes.map((size) => Text(
                          size, 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            // Highlight the currently selected label
                            color: sizes[currentValue.toInt()] == size 
                                ? AppColors.orange 
                                : Colors.grey.shade500
                          ),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _rateApp() async {
    if (_playStoreLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Play Store link coming soon! 🚀')),
      );
      return;
    }
    final Uri url = Uri.parse(_playStoreLink);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open store')));
    }
  }

  Future<void> _sendFeedback() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: 'subject=SplitSathi App Feedback', 
    );
    
    if (!await launchUrl(emailUri)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open email app')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;
    final bg = isDark ? AppColors.darkBg : AppColors.cream;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final sectionColor = isDark ? AppColors.darkMuted : AppColors.muted;
    
    final currentCurrency = context.watch<AppProvider>().currency;
    final currentTextSize = context.watch<AppProvider>().textSize; // <-- Grab current text size
    final isHapticsOn = context.watch<AppProvider>().hapticsEnabled;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            title: const Text('Settings', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800)),
            backgroundColor: AppColors.orange,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: ListView(
            children: [
              const SizedBox(height: 16),

              _buildSectionHeader('PREFERENCES', sectionColor),
              ListTile(
                leading: const Icon(Icons.payments_outlined, color: AppColors.orange),
                title: Text('Default Currency', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(currentCurrency, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.orange)),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
                onTap: () => _showCurrencyPicker(context),
              ),

              // 👇 NEW: The Text Size UI Option 👇
              ListTile(
                leading: const Icon(Icons.text_fields_rounded, color: AppColors.orange),
                title: Text('Text Size', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(currentTextSize, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.orange)),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
                onTap: () => _showTextSizePicker(context),
              ),

              SwitchListTile(
                activeColor: AppColors.orange,
                secondary: const Icon(Icons.vibration, color: AppColors.orange),
                title: Text('Haptic Feedback', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                subtitle: Text('Vibrations on button taps', style: TextStyle(fontSize: 12, color: sectionColor)),
                value: isHapticsOn,
                onChanged: (val) async {
                  if (val) HapticFeedback.heavyImpact();
                  context.read<AppProvider>().setHaptics(val);
                },
              ),
              
              const Divider(height: 32),

              _buildSectionHeader('PUSH NOTIFICATIONS', sectionColor),
              SwitchListTile(
                activeColor: AppColors.orange,
                secondary: const Icon(Icons.receipt_long, color: AppColors.orange),
                title: Text('New Expenses', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                subtitle: Text('When someone adds a bill you owe', style: TextStyle(fontSize: 12, color: sectionColor)),
                value: _notifyNewExpense,
                onChanged: (val) async {
                  setState(() => _notifyNewExpense = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('notifyNewExpense', val);
                },
              ),
              SwitchListTile(
                activeColor: AppColors.orange,
                secondary: const Icon(Icons.handshake_outlined, color: AppColors.orange),
                title: Text('Settlements', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                subtitle: Text('When someone pays you back', style: TextStyle(fontSize: 12, color: sectionColor)),
                value: _notifySettledUp,
                onChanged: (val) async {
                  setState(() => _notifySettledUp = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('notifySettledUp', val);
                },
              ),
              SwitchListTile(
                activeColor: AppColors.orange,
                secondary: const Icon(Icons.group_add_outlined, color: AppColors.orange),
                title: Text('Group Invites', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                subtitle: Text('When you are added to a new group', style: TextStyle(fontSize: 12, color: sectionColor)),
                value: _notifyGroupInvites,
                onChanged: (val) async {
                  setState(() => _notifyGroupInvites = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('notifyGroupInvites', val);
                },
              ),

              const Divider(height: 32),

              _buildSectionHeader('SUPPORT', sectionColor),
              ListTile(
                leading: const Icon(Icons.star_rate_rounded, color: Colors.amber),
                title: Text('Rate SplitSathi', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
                onTap: _rateApp, 
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline, color: AppColors.orange),
                title: Text('Send Feedback', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
                onTap: _sendFeedback, 
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.orange),
                title: Text('Privacy Policy', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                onTap: () async {
                  final Uri url = Uri.parse(_privacyPolicyLink); 
                  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Privacy Policy')));
                    }
                  }
                },
              ),

              const Divider(height: 32),

              _buildSectionHeader('ACCOUNT', sectionColor),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: _deleteAccount,
              ),
              
              const SizedBox(height: 48),
              
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleSecretTap, 
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'SplitSathi v1.0.0\nMade with ❤️',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: sectionColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),

        ConfettiWidget(
          confettiController: _confettiController,
          blastDirection: 3.14 / 2, 
          maxBlastForce: 5,
          minBlastForce: 3,
          emissionFrequency: 0.04,
          numberOfParticles: 80, 
          gravity: 0.2,
          createParticlePath: (size) {
            final path = Path();
            path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
            return path;
          },
          colors: const [Colors.green, Color(0xFF85BB65), Colors.amber, Color(0xFFFFD700)], 
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This action cannot be undone. All your personal data and settings will be permanently erased.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.orange)),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
        await user.delete();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst); 
        }
        
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context);
      
      if (e.code == 'requires-recent-login') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Security check: Please log out and log back in before deleting your account.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
    }
  }
}