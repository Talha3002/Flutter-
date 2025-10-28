import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _db = FirebaseFirestore.instance;
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize FCM + Local Notifications
  static Future<void> init() async {
    // Request permissions
    await _fcm.requestPermission(alert: true, sound: true, badge: true);

    // Get token (for debugging, send to backend if needed)
    final token = await _fcm.getToken();
    if (token != null) {
      await _db.collection("admin_devices").doc(token).set({
        "token": token,
        "createdAt": FieldValue.serverTimestamp(),
      });
    }

    print("✅ Admin FCM Token: $token");

    // Local notifications setup
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
    );
    await _localNotifications.initialize(initSettings);

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // App opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((msg) {
      if (msg != null) {
        _showLocalNotification(msg);
      }
    });

    // App opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _showLocalNotification(msg);
    });

    // Background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Background handler (must be top-level or static)
  static Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    _showLocalNotification(message);
  }

  /// Show local notification with sound
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null) {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'admin_channel',
            'Admin Notifications',
            'Channel for admin notifications', // ✅ third positional arg
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        notification.title ?? "New Notification",
        notification.body ?? "",
        details,
      );
    }
  }

  /// Existing Firestore-based notification methods remain same
  static Future<void> notifyAdminNewUser(
    String fullName,
    String email,
    String accountType,
    String userId,
  ) async {
    final notifRef = _db.collection("admin_notifications").doc();
    await notifRef.set({
      "id": notifRef.id,
      "type": "new_user",
      "title": "🆕 New User Registered",
      "message": "$fullName ($email) signed up as $accountType",
      "userId": userId,
      "timestamp": DateTime.now().toIso8601String(),
      "read": false,
    });
  }

  static Future<void> notifyAdminNewEvent(
    String eventTitle,
    String eventId,
    String ownerId,
  ) async {
    final notifRef = _db.collection("admin_notifications").doc();
    final title = "📢 New Event Created";
    final body = "Event '$eventTitle' is awaiting admin approval.";

    // 1. Save in Firestore
    await notifRef.set({
      "id": notifRef.id,
      "type": "new_event",
      "title": title,
      "message": body,
      "eventId": eventId,
      "ownerId": ownerId,
      "timestamp": DateTime.now().toIso8601String(),
      "read": false,
    });

    // 2. ⚠️ Push notification (same as user notify) requires backend/Admin SDK
    print(
      "⚠️ New Event Notification saved to Firestore. Push requires backend!",
    );
  }

  static Future<void> notifyAdminDailyVisitors(String date, int count) async {
    final notifRef = _db.collection("admin_notifications").doc();
    await notifRef.set({
      "id": notifRef.id,
      "type": "daily_visitors",
      "title": "📊 Daily Visitors Update",
      "message": "On $date, total visitors so far: $count",
      "date": date,
      "count": count,
      "timestamp": DateTime.now().toIso8601String(),
      "read": false,
    });
  }

  // ✅ Call this once after login to save the token with role
  Future<void> saveDeviceToken(String userId, String role) async {
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _firestore.collection("user_tokens").doc(userId).set({
        "token": token,
        "role": role, // "Administrator" or "Orator"
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // ✅ Send notification for organizer: Approved
  Future<void> notifyOrganizerEventApproved(
    String organizerId,
    String eventTitle,
  ) async {
    await _firestore.collection("organizer_notifications").add({
      "organizerId": organizerId,
      "title": "Event Approved",
      "message": "Your event \"$eventTitle\" has been approved.",
      "timestamp": FieldValue.serverTimestamp(),
      "type": "approved",
      "isRead": false,
    });
  }

  // ✅ Send notification for organizer: Rejected
  Future<void> notifyOrganizerEventRejected(
    String organizerId,
    String eventTitle,
  ) async {
    await _firestore.collection("organizer_notifications").add({
      "organizerId": organizerId,
      "title": "Event Rejected",
      "message": "Your event \"$eventTitle\" has been rejected.",
      "timestamp": FieldValue.serverTimestamp(),
      "type": "rejected",
      "isRead": false,
    });
  }
}
