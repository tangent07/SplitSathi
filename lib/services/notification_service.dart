import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    try {
      // 1. Request permission from the user (Required for iOS and Android 13+)
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted notification permissions!');
        
        // 2. Get the unique FCM Token for this specific device
        String? token = await _fcm.getToken();
        if (token != null) {
          await _saveTokenToDatabase(token);
        }

        // 3. Listen for token changes (happens if the user reinstalls the app, etc.)
        _fcm.onTokenRefresh.listen(_saveTokenToDatabase);
      } else {
        debugPrint('User declined or has not accepted permission');
      }
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  Future<void> _saveTokenToDatabase(String token) async {
    // Save the token to this user's Firestore profile so we can target them later!
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await FirebaseFirestore.instance.collection('users').doc(userId).set(
        {'fcmToken': token},
        SetOptions(merge: true), // Merge so we don't overwrite their profile/friends!
      );
    }
  }
}