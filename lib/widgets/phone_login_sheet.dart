import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class PhoneLoginSheet extends StatefulWidget {
  const PhoneLoginSheet({super.key});

  @override
  State<PhoneLoginSheet> createState() => _PhoneLoginSheetState();
}

class _PhoneLoginSheetState extends State<PhoneLoginSheet> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  
  String _selectedCountryCode = '+91';
  bool _isLoading = false;
  
  // State variables for our UI flow
  bool _isOTPSent = false;
  String? _verificationId;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _sendOTP() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty || rawPhone.length < 10) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final fullPhoneNumber = '$_selectedCountryCode $rawPhone';

    await AuthService().sendOTP(
      phoneNumber: fullPhoneNumber,
      codeSent: (verificationId) {
        setState(() {
          _verificationId = verificationId;
          _isOTPSent = true;
          _isLoading = false;
        });
        HapticFeedback.heavyImpact();
      },
      verificationFailed: (error) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${error.message}'), backgroundColor: Colors.redAccent),
        );
      },
    );
  }

  void _verifyOTP() async {
    final smsCode = _otpController.text.trim();
    if (smsCode.isEmpty || smsCode.length < 6 || _verificationId == null) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final userCred = await AuthService().verifyOTP(
      verificationId: _verificationId!,
      smsCode: smsCode,
    );

    if (userCred != null && mounted) {
      // Success! Close the sheet. 
      // The Gatekeeper in main.dart will automatically teleport them to the Setup Screen or Home!
      Navigator.pop(context); 
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid Code! Try again.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),

            Text(
              _isOTPSent ? 'Enter the code 💬' : 'What\'s your number? 📱',
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              _isOTPSent 
                ? 'We sent a 6-digit code to $_selectedCountryCode ${_phoneController.text}'
                : 'We\'ll send you a 6-digit verification code.',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),

            // DYNAMIC INPUT FIELD
            if (!_isOTPSent) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: '98765 43210',
                  filled: true, fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCountryCode,
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFF97316)),
                            style: const TextStyle(color: Colors.black87, fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 15),
                            onChanged: (String? newValue) {
                              if (newValue != null) setState(() => _selectedCountryCode = newValue);
                            },
                            items: AppConstants.countryCodes.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(value: value, child: Text(value));
                            }).toList(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(width: 1.5, height: 24, color: Colors.grey.shade300),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 8),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "000000",
                  filled: true, fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // ACTION BUTTON
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)))
                : ElevatedButton(
                    onPressed: _isOTPSent ? _verifyOTP : _sendOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(double.infinity, 54),
                      elevation: 0,
                    ),
                    child: Text(
                      _isOTPSent ? 'Verify & Login →' : 'Send Code →',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Nunito'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}