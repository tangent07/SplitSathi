import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

/// Bottom sheet for adding (linking) a phone number to an already-signed-in
/// user. Similar to [PhoneLoginSheet] but uses linkWithCredential instead
/// of signInWithCredential, so the user's account stays the same.
class PhoneLinkSheet extends StatefulWidget {
  const PhoneLinkSheet({super.key});

  @override
  State<PhoneLinkSheet> createState() => _PhoneLinkSheetState();
}

class _PhoneLinkSheetState extends State<PhoneLinkSheet> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  String _selectedCountryCode = '+91';
  bool _isLoading = false;

  bool _isOTPSent = false;
  String? _verificationId;

  static const int _resendCooldownSeconds = 30;
  int _resendSecondsLeft = 0;
  Timer? _resendTimer;

  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _resendSecondsLeft = 0);
      } else {
        setState(() => _resendSecondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    FocusScope.of(context).unfocus();
    final rawPhone = _phoneController.text.trim();

    if (_selectedCountryCode == '+91') {
      if (rawPhone.length != 10) {
        _showError('Please enter exactly 10 digits');
        return;
      }
      if (!RegExp(r'^[6-9]').hasMatch(rawPhone)) {
        _showError('Indian mobile numbers must start with 6, 7, 8 or 9');
        return;
      }
    } else if (rawPhone.length < 7) {
      _showError('Please enter a valid phone number');
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final fullPhoneNumber = '$_selectedCountryCode$rawPhone';

    await AuthService().sendOTP(
      phoneNumber: fullPhoneNumber,
      codeSent: (verificationId) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _isOTPSent = true;
          _isLoading = false;
        });
        _startResendCountdown();
        HapticFeedback.heavyImpact();
      },
      verificationFailed: (errorMessage) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showError(errorMessage);
      },
    );
  }

  Future<void> _verifyAndLink() async {
    FocusScope.of(context).unfocus();
    final smsCode = _otpController.text.trim();

    if (smsCode.length != 6) {
      _showError('Please enter the 6-digit code');
      return;
    }
    if (_verificationId == null) {
      _showError('Session expired. Please request a new code.');
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final result = await AuthService().linkPhoneToCurrentUser(
      verificationId: _verificationId!,
      smsCode: smsCode,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      Navigator.pop(context, true); // Signal success to the caller.
      return;
    }

    setState(() => _isLoading = false);
    _otpController.clear();
    _showError(result.errorMessage ?? 'Could not link phone. Please try again.');
  }

  Future<void> _resendOTP() async {
    if (_resendSecondsLeft > 0 || _isLoading) return;
    final rawPhone = _phoneController.text.trim();
    final fullPhoneNumber = '$_selectedCountryCode$rawPhone';

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    await AuthService().sendOTP(
      phoneNumber: fullPhoneNumber,
      codeSent: (verificationId) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _isLoading = false;
        });
        _otpController.clear();
        _startResendCountdown();
        _messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: const Text('A new code has been sent'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      verificationFailed: (errorMessage) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showError(errorMessage);
      },
    );
  }

  void _changeNumber() {
    _resendTimer?.cancel();
    setState(() {
      _isOTPSent = false;
      _verificationId = null;
      _resendSecondsLeft = 0;
      _otpController.clear();
    });
  }

  void _showError(String message) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sheet = Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: _buildContents(),
        ),
      ),
    );

    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Align(alignment: Alignment.bottomCenter, child: sheet),
      ),
    );
  }

  List<Widget> _buildContents() {
    return [
      Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
      const SizedBox(height: 24),
      Text(
        _isOTPSent ? 'Enter the code 💬' : 'Add your phone number 📱',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: Colors.black87,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        _isOTPSent
            ? 'We sent a 6-digit code to $_selectedCountryCode ${_phoneController.text}'
            : 'We\'ll send an OTP to verify ownership. Once linked, this number cannot be changed.',
        style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 32),
      if (!_isOTPSent) ...[
        _buildPhoneField(),
      ] else ...[
        _buildOTPField(),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed:
                  (_resendSecondsLeft > 0 || _isLoading) ? null : _resendOTP,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _resendSecondsLeft > 0
                    ? 'Resend in ${_resendSecondsLeft}s'
                    : 'Resend OTP',
                style: TextStyle(
                  color: _resendSecondsLeft > 0
                      ? Colors.grey.shade500
                      : const Color(0xFFF97316),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: _isLoading ? null : _changeNumber,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Change number',
                style: TextStyle(
                  color: Color(0xFFF97316),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 24),
      _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF97316)))
          : ElevatedButton(
              onPressed: _isOTPSent ? _verifyAndLink : _sendOTP,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 54),
                elevation: 0,
              ),
              child: Text(
                _isOTPSent ? 'Verify & Link →' : 'Send Code →',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
            ),
    ];
  }

  Widget _buildPhoneField() {
    final maxDigits = _selectedCountryCode == '+91' ? 10 : 15;
    return TextField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxDigits),
      ],
      style: const TextStyle(
          color: Colors.black87, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: '98765 43210',
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontWeight: FontWeight.w400,
          fontSize: 15,
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCountryCode,
                  icon: const Icon(Icons.arrow_drop_down,
                      color: Color(0xFFF97316)),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() => _selectedCountryCode = newValue);
                    }
                  },
                  items: AppConstants.countryCodes
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
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
    );
  }

  Widget _buildOTPField() {
    return TextField(
      controller: _otpController,
      keyboardType: TextInputType.number,
      maxLength: 6,
      textAlign: TextAlign.center,
      autofocus: true,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.w900,
        fontSize: 24,
        letterSpacing: 8,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: '000000',
        hintStyle: TextStyle(
          color: Colors.grey.shade300,
          fontWeight: FontWeight.w400,
          fontSize: 24,
          letterSpacing: 8,
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}