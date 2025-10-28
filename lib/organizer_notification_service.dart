import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrganizerNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    // Request permissions for iOS
    await _fcm.requestPermission();

    // Get device token
    String? token = await _fcm.getToken();

    if (token != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('user_tokens')
            .doc(uid)
            .set({'token': token}, SetOptions(merge: true));
      }
    }

    // Handle foreground notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("📩 New FCM: ${message.notification?.title}");
    });
  }
}
