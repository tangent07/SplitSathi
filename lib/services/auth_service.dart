import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A simple result wrapper so the UI can distinguish success, cancellation,
/// and real errors — and show a useful message to the user.
class AuthResult {
  final User? user;
  final String? errorMessage;
  final bool cancelled;

  const AuthResult.success(this.user)
      : errorMessage = null,
        cancelled = false;

  const AuthResult.failure(this.errorMessage)
      : user = null,
        cancelled = false;

  const AuthResult.cancel()
      : user = null,
        errorMessage = null,
        cancelled = true;

  bool get isSuccess => user != null;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Keys we clear on logout (everything else — theme, currency — stays).
  static const List<String> _authScopedPrefKeys = [
    // Add any auth-related keys here if you store them in the future.
    // e.g. 'last_logged_in_method', 'onboarding_step', etc.
  ];

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ======================================================================
  // GOOGLE SIGN-IN
  // ======================================================================
  Future<AuthResult> signInWithGoogle() async {
    try {
      // Force account picker every time — prevents silent re-login to a
      // previously cached Google account.
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.disconnect();
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return const AuthResult.cancel(); // User closed the picker
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      await _saveUserToDatabase(userCredential.user);
      return AuthResult.success(userCredential.user);
    } on FirebaseAuthException catch (e) {
      debugPrint('Google Sign-In FirebaseAuthException: ${e.code} ${e.message}');
      return AuthResult.failure(_mapFirebaseAuthError(e));
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return const AuthResult.failure(
        'Could not sign in with Google. Please check your connection and try again.',
      );
    }
  }

  // ======================================================================
  // ACCOUNT LINKING (adding a second credential to an existing account)
  // ======================================================================

  /// Links a Google account to the currently signed-in user.
  /// Use this when a user signed in with phone and wants to add their email.
  Future<AuthResult> linkGoogleToCurrentUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const AuthResult.failure('You need to be signed in first.');
    }

    try {
      // Force account picker every time.
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.disconnect();
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return const AuthResult.cancel();
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await currentUser.linkWithCredential(credential);

      // Backfill the email on the Firestore user doc.
      await _saveUserToDatabase(userCredential.user);
      return AuthResult.success(userCredential.user);
    } on FirebaseAuthException catch (e) {
      debugPrint('Link Google error: ${e.code} ${e.message}');
      return AuthResult.failure(_mapLinkError(e));
    } catch (e) {
      debugPrint('Link Google error: $e');
      return const AuthResult.failure(
        'Could not link your Google account. Please try again.',
      );
    }
  }

  /// Links a phone number to the currently signed-in user, using an OTP
  /// already obtained via [sendOTP].
  /// Use this when a user signed in with Google and wants to add their phone.
  Future<AuthResult> linkPhoneToCurrentUser({
    required String verificationId,
    required String smsCode,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const AuthResult.failure('You need to be signed in first.');
    }

    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final UserCredential userCredential =
          await currentUser.linkWithCredential(credential);

      await _saveUserToDatabase(userCredential.user);
      return AuthResult.success(userCredential.user);
    } on FirebaseAuthException catch (e) {
      debugPrint('Link phone error: ${e.code} ${e.message}');
      return AuthResult.failure(_mapLinkError(e));
    } catch (e) {
      debugPrint('Link phone error: $e');
      return const AuthResult.failure(
        'Could not link your phone number. Please try again.',
      );
    }
  }

  /// Specialised error messages for linking operations.
  String _mapLinkError(FirebaseAuthException e) {
    switch (e.code) {
      case 'provider-already-linked':
        return 'This provider is already linked to your account.';
      case 'credential-already-in-use':
      case 'email-already-in-use':
        return 'This is already linked to another SplitSathi account. Please use a different one.';
      case 'invalid-credential':
      case 'invalid-verification-code':
        return 'The code you entered is incorrect. Please try again.';
      case 'invalid-verification-id':
      case 'session-expired':
      case 'code-expired':
        return 'The code has expired. Please request a new one.';
      default:
        return _mapFirebaseAuthError(e);
    }
  }

  // ======================================================================
  // PHONE AUTHENTICATION
  // ======================================================================

  /// Sends an OTP to the given phone number.
  /// Returns the verificationId via [codeSent], or an error via [verificationFailed].
  ///
  /// NOTE: We intentionally do NOT handle [verificationCompleted] (Android
  /// auto-retrieval) here, because it silently signs the user in and leaves
  /// the OTP bottom sheet in a stuck state. The user will always enter the
  /// code manually. On modern Android devices, the SMS retriever API will
  /// still auto-fill the OTP into the text field.
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) codeSent,
    required Function(String errorMessage) verificationFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) {
        // Intentionally empty — see note above.
      },
      verificationFailed: (FirebaseAuthException e) {
        debugPrint('Phone verification failed: ${e.code} ${e.message}');
        verificationFailed(_mapFirebaseAuthError(e));
      },
      codeSent: (String verificationId, int? resendToken) {
        codeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<AuthResult> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      await _saveUserToDatabase(userCredential.user);
      return AuthResult.success(userCredential.user);
    } on FirebaseAuthException catch (e) {
      debugPrint('OTP verify FirebaseAuthException: ${e.code} ${e.message}');
      return AuthResult.failure(_mapFirebaseAuthError(e));
    } catch (e) {
      debugPrint('OTP verify error: $e');
      return const AuthResult.failure(
        'Could not verify the code. Please try again.',
      );
    }
  }

  // ======================================================================
  // DATABASE SAVING (merge-friendly, respects the "permanent lock" rule)
  // ======================================================================
  Future<void> _saveUserToDatabase(User? user) async {
    if (user == null) return;

    final userDoc = _db.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();

    if (!snapshot.exists) {
      // Brand new user — create the doc.
      await userDoc.set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'phone': user.phoneNumber ?? '',
        'photoUrl': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    // Existing user — only backfill empty fields.
    // Once a field is set, it is NEVER overwritten here.
    // (This matches the "permanently locked" blueprint rule.)
    final data = snapshot.data() ?? {};
    final Map<String, dynamic> updates = {};

    final existingEmail = (data['email'] ?? '') as String;
    if (existingEmail.isEmpty && (user.email ?? '').isNotEmpty) {
      updates['email'] = user.email;
    }

    final existingPhone = (data['phone'] ?? '') as String;
    if (existingPhone.isEmpty && (user.phoneNumber ?? '').isNotEmpty) {
      updates['phone'] = user.phoneNumber;
    }

    final existingPhoto = (data['photoUrl'] ?? '') as String;
    if (existingPhoto.isEmpty && (user.photoURL ?? '').isNotEmpty) {
      updates['photoUrl'] = user.photoURL;
    }

    if (updates.isNotEmpty) {
      await userDoc.set(updates, SetOptions(merge: true));
    }
  }

  // ======================================================================
  // LOGOUT (scoped — does NOT nuke app preferences)
  // ======================================================================
  Future<void> signOut() async {
    try {
      // Clear only auth-related shared prefs, not theme/currency/haptics.
      final prefs = await SharedPreferences.getInstance();
      for (final key in _authScopedPrefKeys) {
        await prefs.remove(key);
      }

      // Disconnect Google so the next sign-in shows the account picker.
      try {
        if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.disconnect();
        }
      } catch (e) {
        debugPrint('Google disconnect failed (non-fatal): $e');
      }

      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('Google signOut failed (non-fatal): $e');
      }

      await _auth.signOut();
    } catch (e) {
      debugPrint('Error during logout: $e');
      // Last-ditch — ensure Firebase session is killed no matter what.
      await _auth.signOut();
    }
  }

  // ======================================================================
  // ERROR MESSAGE MAPPING
  // ======================================================================
  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'That phone number doesn\'t look right. Please check and try again.';
      case 'invalid-verification-code':
      case 'invalid-verification-id':
        return 'The code you entered is incorrect. Please try again.';
      case 'session-expired':
      case 'code-expired':
        return 'The code has expired. Please request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a while before trying again.';
      case 'quota-exceeded':
        return 'SMS quota reached for today. Please try Google Sign-In instead.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email. Try a different sign-in method.';
      case 'credential-already-in-use':
        return 'This number is already linked to another account.';
      case 'app-not-authorized':
        return 'App verification failed. Please reinstall the app.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}