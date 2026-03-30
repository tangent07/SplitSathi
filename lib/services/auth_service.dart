import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Google Sign-In Logic
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Triggers the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      // If the user closes the popup without logging in, stop here
      if (googleUser == null) return null; 

      // Obtain the secure auth tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new Firebase credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign into Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      // IMPORTANT: Save the user's basic info to our Firestore database!
      await _saveUserToDatabase(userCredential.user);

      return userCredential;
      
    } catch (e) {
      print("Error during Google Sign-In: $e");
      return null;
    }
  }

  // 2. Save new users to our Database
  Future<void> _saveUserToDatabase(User? user) async {
    if (user != null) {
      final userDoc = _db.collection('users').doc(user.uid);
      final docSnapshot = await userDoc.get();

      // Only save if they are a brand new user (don't overwrite existing data)
      if (!docSnapshot.exists) {
        await userDoc.set({
          'uid': user.uid,
          'name': user.displayName ?? 'SplitSathi User',
          'email': user.email ?? '',
          'phone': user.phoneNumber ?? '',
          'photoUrl': user.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // 3. Log Out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}