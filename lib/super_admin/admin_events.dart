import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alraya_app/alrayah.dart';
import 'admin_navigation.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:alraya_app/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

// Add this AFTER imports, BEFORE EventManagementPage class
class EventsCacheService {
  static const String _pendingCacheKey = 'events_pending_cache';
  static const String _approvedCacheKey = 'events_approved_cache';
  static const String _pendingTimestampKey = 'events_pending_timestamp';
  static const String _approvedTimestampKey = 'events_approved_timestamp';
  static const Duration _cacheDuration = Duration(hours: 24);

  // Save pending events to cache
  static Future<void> savePendingToCache(
    List<Map<String, dynamic>> events,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final serializableEvents = events.map((event) {
        return {
          'id': event['id'],
          'title': event['title'],
          'preacherName': event['preacherName'],
          'location': event['location'],
          'description': event['description'],
          'submittedOn': event['submittedOn'],
          'liveLink': event['liveLink'],
          'repeatDay': event['repeatDay'],
          'organizerId': event['organizerId'],
        };
      }).toList();

      await prefs.setString(_pendingCacheKey, jsonEncode(serializableEvents));
      await prefs.setInt(
        _pendingTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      print('✅ Cached ${events.length} pending events');
    } catch (e) {
      print('❌ Error saving pending events cache: $e');
    }
  }

  // Save approved events to cache
  static Future<void> saveApprovedToCache(
    List<Map<String, dynamic>> events,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final serializableEvents = events.map((event) {
        return {
          'id': event['id'],
          'title': event['title'],
          'preacherName': event['preacherName'],
          'location': event['location'],
          'description': event['description'],
          'submittedOn': event['submittedOn'],
          'liveLink': event['liveLink'],
          'repeatDay': event['repeatDay'],
          'organizerId': event['organizerId'],
        };
      }).toList();

      await prefs.setString(_approvedCacheKey, jsonEncode(serializableEvents));
      await prefs.setInt(
        _approvedTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      print('✅ Cached ${events.length} approved events');
    } catch (e) {
      print('❌ Error saving approved events cache: $e');
    }
  }

  // Load pending events from cache
  static Future<List<Map<String, dynamic>>?> loadPendingFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final timestamp = prefs.getInt(_pendingTimestampKey);
      if (timestamp == null) return null;

      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge > _cacheDuration.inMilliseconds) {
        await clearPendingCache();
        return null;
      }

      final String? cachedData = prefs.getString(_pendingCacheKey);
      if (cachedData == null) return null;

      final List<dynamic> jsonList = jsonDecode(cachedData);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Error loading pending events cache: $e');
      return null;
    }
  }

  // Load approved events from cache
  static Future<List<Map<String, dynamic>>?> loadApprovedFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final timestamp = prefs.getInt(_approvedTimestampKey);
      if (timestamp == null) return null;

      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge > _cacheDuration.inMilliseconds) {
        await clearApprovedCache();
        return null;
      }

      final String? cachedData = prefs.getString(_approvedCacheKey);
      if (cachedData == null) return null;

      final List<dynamic> jsonList = jsonDecode(cachedData);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Error loading approved events cache: $e');
      return null;
    }
  }

  // Clear caches
  static Future<void> clearPendingCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingCacheKey);
    await prefs.remove(_pendingTimestampKey);
  }

  static Future<void> clearApprovedCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_approvedCacheKey);
    await prefs.remove(_approvedTimestampKey);
  }

  static Future<void> clearAllCache() async {
    await clearPendingCache();
    await clearApprovedCache();
    print('🗑️ All events cache cleared');
  }

  // ✅ NEW: Session flag management
  static const String _pendingLoadedKey = 'events_pending_loaded_flag';
  static const String _approvedLoadedKey = 'events_approved_loaded_flag';

  static Future<bool> getPendingLoadedFlag() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingLoadedKey) ?? false;
  }

  static Future<void> setPendingLoadedFlag(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingLoadedKey, value);
  }

  static Future<bool> getApprovedLoadedFlag() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_approvedLoadedKey) ?? false;
  }

  static Future<void> setApprovedLoadedFlag(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_approvedLoadedKey, value);
  }

  static Future<void> clearAllFlags() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingLoadedKey);
    await prefs.remove(_approvedLoadedKey);
  }
}

class EventManagementPage extends StatefulWidget {
  const EventManagementPage({Key? key}) : super(key: key);

  @override
  State<EventManagementPage> createState() => _EventManagementPageState();
}

class _EventManagementPageState extends State<EventManagementPage> {
  bool darkMode = false;
  String language = 'en';
  String currentPage = 'Events';
  String fullName = 'Admin User';

  List<EventItem> pendingEvents = [];
  List<EventItem> approvedEvents = [];
  bool _loading = false;

  // Mobile pagination variables
  int _pendingEventsToShow = 3;
  int _approvedEventsToShow = 3;

  // ✅ NEW: Flags to track if data has been loaded in this session
  bool _pendingEventsLoadedFromCache = false;
  bool _approvedEventsLoadedFromCache = false;

  bool get isMobile => MediaQuery.of(context).size.width < 768;

  Future<void> _fetchPendingEvents() async {
    // ✅ Check persistent flag first
    final loadedFlag = await EventsCacheService.getPendingLoadedFlag();

    if (loadedFlag) {
      print("⚡ Already loaded in session - checking cache");
      final cachedData = await EventsCacheService.loadPendingFromCache();

      if (cachedData != null && cachedData.isNotEmpty) {
        print("✅ Loaded ${cachedData.length} pending events from cache");
        setState(() {
          pendingEvents = cachedData
              .map(
                (data) => EventItem(
                  id: data['id'] ?? '',
                  title: data['title'] ?? '',
                  preacherName: data['preacherName'] ?? '',
                  location: data['location'] ?? '',
                  description: data['description'] ?? '',
                  submittedOn: data['submittedOn'] ?? '',
                  liveLink: data['liveLink'] ?? '',
                  repeatDay: data['repeatDay'],
                  organizerId: data['organizerId'] ?? '',
                  status: "Pending",
                  statusAr: "معلق",
                  statusColor: Colors.amber[700]!,
                  initials: (data['preacherName'] ?? '').isNotEmpty
                      ? data['preacherName'][0].toUpperCase()
                      : 'A',
                ),
              )
              .toList();
          _loading = false;
        });
        return;
      }
    }

    // Fetch from Firestore
    print('⏳ Fetching pending events from Firestore...');
    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('aspnetuserclaims')
            .where('ClaimValue', isEqualTo: 'Orator')
            .get(),
        FirebaseFirestore.instance
            .collection('tblboardads')
            .where('IsDeleted', isEqualTo: 'False')
            .where('status', isEqualTo: 'Pending')
            .get(),
        FirebaseFirestore.instance
            .collection('tblboards')
            .where('IsDeleted', isEqualTo: 'False')
            .get(),
      ]);

      final oratorClaimsSnap = results[0];
      final adsSnap = results[1];
      final boardsSnap = results[2];

      print("📋 Fetched: ${oratorClaimsSnap.docs.length} orator claims");
      print("📦 Fetched: ${adsSnap.docs.length} pending ads");
      print("🗂️ Fetched: ${boardsSnap.docs.length} boards");

      final oratorIds = oratorClaimsSnap.docs
          .map((doc) => doc['UserId'] as String)
          .toSet()
          .toList();

      if (oratorIds.isEmpty) {
        print("⚠️ No orators found");
        setState(() {
          pendingEvents = [];
          _loading = false;
        });
        return;
      }

      Map<String, Map<String, dynamic>> usersMap = {};
      List<Future<QuerySnapshot>> userFutures = [];

      for (int i = 0; i < oratorIds.length; i += 30) {
        final batch = oratorIds.skip(i).take(30).toList();
        userFutures.add(
          FirebaseFirestore.instance
              .collection('aspnetusers')
              .where('Id', whereIn: batch)
              .get(),
        );
      }

      final userSnapshots = await Future.wait(userFutures);
      for (var snap in userSnapshots) {
        for (var doc in snap.docs) {
          usersMap[doc['Id']] = doc.data() as Map<String, dynamic>;
        }
      }

      final adsMap = <String, Map<String, dynamic>>{};
      for (var doc in adsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        adsMap[data['Id']] = {...data, 'docId': doc.id};
      }

      List<Map<String, dynamic>> eventsData = [];

      for (var boardDoc in boardsSnap.docs) {
        final board = boardDoc.data() as Map<String, dynamic>;
        final boardAdsId = board['BoardAdsId'];
        final oratorId = board['OratorId'];

        final ad = adsMap[boardAdsId];
        final user = usersMap[oratorId];

        if (ad != null && user != null) {
          final rawDate = board['BoardDateTime'] ?? '';
          DateTime date;
          try {
            date = DateTime.parse(rawDate);
          } catch (_) {
            try {
              date = DateFormat("d/M/yyyy HH:mm").parse(rawDate);
            } catch (e) {
              date = DateTime.now();
            }
          }

          eventsData.add({
            'id': ad['docId'],
            'title': ad['Title'] ?? 'Untitled',
            'preacherName': user['FullName'] ?? 'Unknown',
            'location':
                (ad['LiveBroadcastLink'] != null &&
                    ad['LiveBroadcastLink'].toString().trim().isNotEmpty)
                ? 'Online'
                : ad['Location'] ?? 'Unknown',
            'description': ad['Description'] ?? 'Not Added',
            'submittedOn': DateFormat("yyyy-MM-dd").format(date),
            'liveLink': ad['LiveBroadcastLink'] ?? '',
            'repeatDay': ad['RepeatDay'] is int
                ? ad['RepeatDay']
                : (ad['RepeatDay'] != null
                      ? int.tryParse(ad['RepeatDay'].toString())
                      : null),
            'organizerId': ad['OwnerId'] ?? '',
          });
        }
      }

      if (eventsData.isNotEmpty) {
        await EventsCacheService.savePendingToCache(eventsData);
        await EventsCacheService.setPendingLoadedFlag(true); // ✅ Set flag
      }

      final events = eventsData
          .map(
            (data) => EventItem(
              id: data['id'],
              title: data['title'],
              preacherName: data['preacherName'],
              location: data['location'],
              description: data['description'],
              submittedOn: data['submittedOn'],
              liveLink: data['liveLink'],
              repeatDay: data['repeatDay'],
              organizerId: data['organizerId'],
              status: "Pending",
              statusAr: "معلق",
              statusColor: Colors.amber[700]!,
              initials: data['preacherName'].isNotEmpty
                  ? data['preacherName'][0].toUpperCase()
                  : 'A',
            ),
          )
          .toList();

      setState(() {
        pendingEvents = events;
        _loading = false;
      });

      print("🎉 Pending events loaded successfully");
    } catch (e) {
      print("❌ Error fetching pending events: $e");
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchApprovedEvents() async {
    // ✅ STEP 1: If already loaded from cache in this session, skip entirely
    if (_approvedEventsLoadedFromCache) {
      print("⚡ Skipping fetch - already loaded from cache this session");
      return;
    }

    // ✅ STEP 2: Try cache first
    final cachedData = await EventsCacheService.loadApprovedFromCache();

    if (cachedData != null && cachedData.isNotEmpty) {
      print("✅ Loaded ${cachedData.length} approved events from cache");
      setState(() {
        approvedEvents = cachedData
            .map(
              (data) => EventItem(
                id: data['id'] ?? '',
                title: data['title'] ?? '',
                preacherName: data['preacherName'] ?? '',
                location: data['location'] ?? '',
                description: data['description'] ?? '',
                submittedOn: data['submittedOn'] ?? '',
                liveLink: data['liveLink'] ?? '',
                repeatDay: data['repeatDay'],
                organizerId: data['organizerId'] ?? '',
                status: "Approved",
                statusAr: "معتمد",
                statusColor: Colors.green,
                initials: (data['preacherName'] ?? '').isNotEmpty
                    ? data['preacherName'][0].toUpperCase()
                    : 'A',
              ),
            )
            .toList();
        _loading = false;
        _approvedEventsLoadedFromCache = true; // ✅ Mark as loaded from cache
      });
      return; // ✅ Exit early - don't fetch from Firestore
    }

    // STEP 2: Cache miss - fetch from Firestore (OPTIMIZED - NO LOOPS!)
    print('⏳ Cache miss - fetching approved events from Firestore...');
    setState(() => _loading = true);

    try {
      // 🚀 Fetch ALL data in parallel
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('aspnetuserclaims')
            .where('ClaimValue', isEqualTo: 'Orator')
            .get(),
        FirebaseFirestore.instance
            .collection('tblboardads')
            .where('IsDeleted', isEqualTo: 'False')
            .where('status', isEqualTo: 'approved')
            .get(),
        FirebaseFirestore.instance
            .collection('tblboards')
            .where('IsDeleted', isEqualTo: 'False')
            .get(),
      ]);

      final oratorClaimsSnap = results[0];
      final adsSnap = results[1];
      final boardsSnap = results[2];

      print("📋 Fetched: ${oratorClaimsSnap.docs.length} orator claims");
      print("📦 Fetched: ${adsSnap.docs.length} approved ads");
      print("🗂️ Fetched: ${boardsSnap.docs.length} boards");

      final oratorIds = oratorClaimsSnap.docs
          .map((doc) => doc['UserId'] as String)
          .toSet()
          .toList();

      if (oratorIds.isEmpty) {
        print("⚠️ No orators found");
        setState(() {
          approvedEvents = [];
          _loading = false;
        });
        return;
      }

      // 🚀 Batch fetch users in parallel
      Map<String, Map<String, dynamic>> usersMap = {};
      List<Future<QuerySnapshot>> userFutures = [];

      for (int i = 0; i < oratorIds.length; i += 30) {
        final batch = oratorIds.skip(i).take(30).toList();
        userFutures.add(
          FirebaseFirestore.instance
              .collection('aspnetusers')
              .where('Id', whereIn: batch)
              .get(),
        );
      }

      final userSnapshots = await Future.wait(userFutures);
      for (var snap in userSnapshots) {
        for (var doc in snap.docs) {
          usersMap[doc['Id']] = doc.data() as Map<String, dynamic>;
        }
      }
      print("👥 Loaded ${usersMap.length} users");

      final adsMap = <String, Map<String, dynamic>>{};
      for (var doc in adsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        adsMap[data['Id']] = {...data, 'docId': doc.id};
      }

      // 🧠 Match in memory
      List<Map<String, dynamic>> eventsData = [];

      for (var boardDoc in boardsSnap.docs) {
        final board = boardDoc.data() as Map<String, dynamic>;
        final boardAdsId = board['BoardAdsId'];
        final oratorId = board['OratorId'];

        final ad = adsMap[boardAdsId];
        final user = usersMap[oratorId];

        if (ad != null && user != null) {
          final rawDate = board['BoardDateTime'] ?? '';
          DateTime date;
          try {
            date = DateTime.parse(rawDate);
          } catch (_) {
            try {
              date = DateFormat("d/M/yyyy HH:mm").parse(rawDate);
            } catch (e) {
              date = DateTime.now();
            }
          }

          eventsData.add({
            'id': ad['docId'],
            'title': ad['Title'] ?? 'Untitled',
            'preacherName': user['FullName'] ?? 'Unknown',
            'location':
                (ad['LiveBroadcastLink'] != null &&
                    ad['LiveBroadcastLink'].toString().trim().isNotEmpty)
                ? 'Online'
                : ad['Location'] ?? 'Unknown',
            'description': ad['Description'] ?? 'Not Added',
            'submittedOn': DateFormat("yyyy-MM-dd").format(date),
            'liveLink': ad['LiveBroadcastLink'] ?? '',
            'repeatDay': ad['RepeatDay'] is int
                ? ad['RepeatDay']
                : (ad['RepeatDay'] != null
                      ? int.tryParse(ad['RepeatDay'].toString())
                      : null),
            'organizerId': ad['OwnerId'] ?? '',
          });
        }
      }

      print("✅ Built ${eventsData.length} approved events in memory");

      // ✅ Save to cache
      if (eventsData.isNotEmpty) {
        await EventsCacheService.saveApprovedToCache(eventsData);
      }

      final events = eventsData
          .map(
            (data) => EventItem(
              id: data['id'],
              title: data['title'],
              preacherName: data['preacherName'],
              location: data['location'],
              description: data['description'],
              submittedOn: data['submittedOn'],
              liveLink: data['liveLink'],
              repeatDay: data['repeatDay'],
              organizerId: data['organizerId'],
              status: "Approved",
              statusAr: "معتمد",
              statusColor: Colors.green,
              initials: data['preacherName'].isNotEmpty
                  ? data['preacherName'][0].toUpperCase()
                  : 'A',
            ),
          )
          .toList();

      setState(() {
        approvedEvents = events;
        _loading = false;
      });

      print("🎉 Approved events loaded successfully");
    } catch (e) {
      print("❌ Error fetching approved events: $e");
      setState(() => _loading = false);
    }
  }

  bool _isEventExpired(EventItem event) {
    try {
      // Parse the event date from submittedOn or boardDateTime
      final eventDate = DateTime.parse(event.submittedOn);

      // Get repeat days from the event (you'll need to add this to EventItem)
      final repeatDays = event.repeatDay ?? 0;

      // Calculate expiry date
      final expiryDate = eventDate.add(Duration(days: repeatDays));

      // Check if current date is past expiry
      return DateTime.now().isAfter(expiryDate);
    } catch (e) {
      print("Error checking expiry: $e");
      return false;
    }
  }

  Map<String, String> get translations => {
    'event_management': language == 'ar' ? 'إدارة الأحداث' : 'Event Management',
    'pending_events': language == 'ar' ? 'الأحداث المعلقة' : 'Pending Events',
    'approved_events': language == 'ar'
        ? 'الأحداث المعتمدة'
        : 'Approved Events',
    'submitted_by': language == 'ar' ? 'مقدم من:' : 'Submitted by:',
    'submitted_on': language == 'ar' ? 'مقدم في:' : 'Submitted on:',
    'approve': language == 'ar' ? 'موافقة' : 'Approve',
    'reject': language == 'ar' ? 'رفض' : 'Reject',
    'view_details': language == 'ar' ? 'عرض التفاصيل' : 'View Details',
    'show_more': language == 'ar' ? 'عرض المزيد' : 'Show More',
  };

  Future<String> getUserFullName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "User";

    final doc = await FirebaseFirestore.instance
        .collection("aspnetusers")
        .doc(user.uid)
        .get();

    if (doc.exists) {
      return doc.data()?["FullName"] ?? "User";
    }
    return "User";
  }

  Future<void> _deleteExpiredEvent(EventItem event) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(language == 'ar' ? 'تأكيد الحذف' : 'Confirm Deletion'),
        content: Text(
          language == 'ar'
              ? 'هل أنت متأكد من حذف هذا الحدث المنتهي؟'
              : 'Are you sure you want to delete this expired event?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(language == 'ar' ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(language == 'ar' ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // 🔥 STEP 1: Get the BoardAds document to find the image ID
      final boardAdsDoc = await firestore
          .collection('tblboardads')
          .doc(event.id)
          .get();

      if (!boardAdsDoc.exists) {
        throw Exception('Event not found');
      }

      final boardAdsData = boardAdsDoc.data();
      final imageId = boardAdsData?['BoardAdsImageId'];

      print("✅ Found event with image ID: $imageId");

      // 🗑️ STEP 2: Delete the image from Supabase (if imageId exists)
      if (imageId != null && imageId.toString().isNotEmpty) {
        try {
          // Get the upload file document
          final uploadFileQuery = await firestore
              .collection('tbluploadedfiles')
              .where('Id', isEqualTo: imageId)
              .limit(1)
              .get();

          if (uploadFileQuery.docs.isNotEmpty) {
            final uploadFileData = uploadFileQuery.docs.first.data();
            final supabaseUrl = uploadFileData['SupabaseUrl'] as String?;

            if (supabaseUrl != null && supabaseUrl.isNotEmpty) {
              // Extract the file path from Supabase URL
              // URL format: https://wsbtujhacpnwdzyqboud.supabase.co/storage/v1/object/public/library-assets/newfile/Boards/Images/2-4a83160e-92dc-4707-8880-7d172dce5c59.jpeg
              final uri = Uri.parse(supabaseUrl);
              final pathSegments = uri.pathSegments;

              // Find where "library-assets" starts and get everything after it
              final bucketIndex = pathSegments.indexOf('library-assets');
              if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
                final filePath = pathSegments
                    .sublist(bucketIndex + 1)
                    .join('/');

                print("🗑️ Deleting from Supabase: $filePath");

                // Delete from Supabase
                await Supabase.instance.client.storage
                    .from('library-assets')
                    .remove([filePath]);

                print("✅ Deleted image from Supabase");
              }
            }

            // 🗑️ STEP 3: Delete the tbluploadedfiles document
            await uploadFileQuery.docs.first.reference.delete();
            print("✅ Deleted tbluploadedfiles document");
          }
        } catch (e) {
          print("⚠️ Error deleting image from Supabase: $e");
          // Continue with other deletions even if Supabase deletion fails
        }
      }

      // 🗑️ STEP 4: Delete from tblboardads
      await firestore.collection('tblboardads').doc(event.id).delete();
      print("✅ Deleted tblboardads document");

      // 🗑️ STEP 5: Delete associated board entries
      final boardsSnap = await firestore
          .collection('tblboards')
          .where('BoardAdsId', isEqualTo: event.id)
          .get();

      for (var doc in boardsSnap.docs) {
        await doc.reference.delete();
      }
      print("✅ Deleted ${boardsSnap.docs.length} tblboards documents");

      if (!mounted) return;

      // ✅ Update UI
      setState(() {
        approvedEvents.removeWhere((e) => e.id == event.id);
      });

      // ✅ Update cache with new state
      await _updateApprovedCache();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            language == 'ar'
                ? 'تم حذف الحدث والصور بنجاح'
                : 'Event and images deleted successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("❌ Error deleting expired event: $e");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            language == 'ar'
                ? 'فشل في الحذف: $e'
                : 'Failed to delete event: $e',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  // ✅ Helper method to update pending cache with current state
  Future<void> _updatePendingCache() async {
    final eventsData = pendingEvents
        .map(
          (event) => {
            'id': event.id,
            'title': event.title,
            'preacherName': event.preacherName,
            'location': event.location,
            'description': event.description,
            'submittedOn': event.submittedOn,
            'liveLink': event.liveLink,
            'repeatDay': event.repeatDay,
            'organizerId': event.organizerId,
          },
        )
        .toList();

    await EventsCacheService.savePendingToCache(eventsData);
  }

  // ✅ Helper method to update approved cache with current state
  Future<void> _updateApprovedCache() async {
    final eventsData = approvedEvents
        .map(
          (event) => {
            'id': event.id,
            'title': event.title,
            'preacherName': event.preacherName,
            'location': event.location,
            'description': event.description,
            'submittedOn': event.submittedOn,
            'liveLink': event.liveLink,
            'repeatDay': event.repeatDay,
            'organizerId': event.organizerId,
          },
        )
        .toList();

    await EventsCacheService.saveApprovedToCache(eventsData);
  }

  @override
  void initState() {
    super.initState();
    _fetchApprovedEvents();
    _fetchPendingEvents();
  }

  void toggleLanguage() {
    setState(() {
      language = language == 'ar' ? 'en' : 'ar';
    });
  }

  void toggleDarkMode() {
    setState(() {
      darkMode = !darkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? currentRoute = ModalRoute.of(context)?.settings.name;
    return Scaffold(
      backgroundColor: darkMode
          ? DesertColors.darkBackground
          : DesertColors.lightBackground,
      endDrawer: FutureBuilder<String>(
        future: getUserFullName(),
        builder: (context, snapshot) {
          final fullName = snapshot.data ?? "User";

          return Drawer(
            child: Container(
              color: darkMode
                  ? DesertColors.darkBackground
                  : DesertColors.lightBackground,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // 🔹 Drawer Header
                  DrawerHeader(
                    decoration: BoxDecoration(
                      color: darkMode ? Colors.black54 : Colors.grey[200],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              'assets/images/logo.png',
                              height: 60,
                              width: 60,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'الراية',
                              style: TextStyle(
                                color: darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12), // spacing before name
                        Text(
                          fullName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 🔹 Language & Theme Toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 🌍 Language Toggle
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            toggleLanguage();
                          },
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: darkMode
                                    ? [
                                        DesertColors.maroon,
                                        DesertColors.maroon.withOpacity(0.8),
                                      ]
                                    : [
                                        DesertColors.camelSand,
                                        DesertColors.camelSand.withOpacity(0.8),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (darkMode
                                              ? DesertColors.maroon
                                              : DesertColors.camelSand)
                                          .withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.language,
                                  size: 16,
                                  color: darkMode
                                      ? Colors.white
                                      : DesertColors.maroon,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  language == 'ar' ? 'EN' : 'عر',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: darkMode
                                        ? Colors.white
                                        : DesertColors.maroon,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 🌙 Dark Mode Toggle
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            toggleDarkMode();
                          },
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: darkMode
                                    ? [
                                        DesertColors.camelSand,
                                        DesertColors.primaryGoldDark,
                                      ]
                                    : [
                                        DesertColors.maroon,
                                        DesertColors.crimson,
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (darkMode
                                              ? DesertColors.camelSand
                                              : DesertColors.maroon)
                                          .withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: AnimatedRotation(
                              turns: darkMode ? 0.5 : 0,
                              duration: Duration(milliseconds: 400),
                              child: Icon(
                                darkMode
                                    ? Icons.wb_sunny
                                    : Icons.nightlight_round,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 12),

                  // ✅ Dashboard Tile
                  ListTile(
                    selected: currentRoute == '/admin_dashboard',
                    selectedTileColor: darkMode
                        ? DesertColors.primaryGoldDark
                        : DesertColors.maroon,
                    title: Text(
                      language == 'ar' ? 'لوحة التحكم' : 'Dashboard',
                      style: TextStyle(
                        color: currentRoute == '/admin_dashboard'
                            ? (darkMode ? DesertColors.lightText : Colors.white)
                            : (darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText),
                      ),
                    ),
                    onTap: () =>
                        Navigator.pushNamed(context, '/admin_dashboard'),
                  ),

                  // ✅ Events Tile
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 20,
                    ), // reduce tile width
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/events'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: currentRoute == '/events'
                              ? (darkMode
                                    ? DesertColors.camelSand
                                    : DesertColors.crimson) // your background
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            12,
                          ), // 🎯 rounded background
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Text(
                              language == 'ar' ? 'الفعاليات' : 'Events',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: currentRoute == '/events'
                                    ? (darkMode
                                          ? DesertColors.crimson
                                          : DesertColors.lightSurface)
                                    : (darkMode
                                          ? DesertColors.darkText
                                          : DesertColors.lightText),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ✅ Books Tile
                  ListTile(
                    selected: currentRoute == '/admin_books',
                    selectedTileColor: darkMode
                        ? DesertColors.primaryGoldDark
                        : DesertColors.maroon,
                    title: Text(
                      language == 'ar' ? 'الكتب' : 'Books',
                      style: TextStyle(
                        color: currentRoute == '/admin_books'
                            ? (darkMode ? DesertColors.lightText : Colors.white)
                            : (darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText),
                      ),
                    ),
                    onTap: () => Navigator.pushNamed(context, '/admin_books'),
                  ),

                  // ✅ Publications Tile
                  ListTile(
                    selected: currentRoute == '/admin_publication',
                    selectedTileColor: darkMode
                        ? DesertColors.primaryGoldDark
                        : DesertColors.maroon,
                    title: Text(
                      language == 'ar' ? 'المنشورات' : 'Publications',
                      style: TextStyle(
                        color: currentRoute == '/admin_publication'
                            ? (darkMode ? DesertColors.lightText : Colors.white)
                            : (darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText),
                      ),
                    ),
                    onTap: () =>
                        Navigator.pushNamed(context, '/admin_publication'),
                  ),

                  // ✅ User Analytics Tile
                  ListTile(
                    selected: currentRoute == '/user-analytics',
                    selectedTileColor: darkMode
                        ? DesertColors.primaryGoldDark
                        : DesertColors.maroon,
                    title: Text(
                      language == 'ar' ? 'تحليلات المستخدم' : 'User Analytics',
                      style: TextStyle(
                        color: currentRoute == '/user-analytics'
                            ? (darkMode ? DesertColors.lightText : Colors.white)
                            : (darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText),
                      ),
                    ),
                    onTap: () =>
                        Navigator.pushNamed(context, '/user-analytics'),
                  ),

                  ListTile(
                    leading: Icon(
                      Icons.logout,
                      color: darkMode ? Colors.red[300] : Colors.red[700],
                    ),
                    title: Text(
                      language == 'ar' ? 'تسجيل الخروج' : 'Logout',
                      style: TextStyle(
                        color: darkMode ? Colors.red[300] : Colors.red[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.pushReplacementNamed(
                        context,
                        '/login',
                      ); // redirect to login
                    },
                  ),

                  Divider(),

                  // ❌ Close Button
                  ListTile(
                    leading: Icon(
                      Icons.close,
                      color: darkMode ? Colors.white : Colors.black,
                    ),
                    title: Text(
                      language == 'ar' ? 'إغلاق' : 'Close',
                      style: TextStyle(
                        color: darkMode
                            ? DesertColors.darkText
                            : DesertColors.lightText,
                      ),
                    ),
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      body: Column(
        children: [
          FutureBuilder<String>(
            future: getUserFullName(),
            builder: (context, snapshot) {
              final fullName = snapshot.data ?? "Loading...";
              return NavigationBarWidget(
                darkMode: darkMode,
                language: language,
                currentPage: currentPage,
                onPageChange: (page) {
                  setState(() {
                    currentPage = page;
                  });
                },
                onLanguageToggle: () =>
                    setState(() => language = language == 'en' ? 'ar' : 'en'),
                onThemeToggle: () => setState(() => darkMode = !darkMode),
                fullName: fullName,
                openDrawer: () => Scaffold.of(context).openEndDrawer(),
              );
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await EventsCacheService.clearAllCache();
                await EventsCacheService.clearAllFlags(); // ✅ Clear persistent flags

                await Future.wait([
                  _fetchPendingEvents(),
                  _fetchApprovedEvents(),
                ]);
              },
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildPendingEventsSection(),
                    const SizedBox(height: 32),
                    _buildApprovedEventsSection(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildMobileBottomNav(context) : null,
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DesertColors.primaryGoldDark.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.event,
            color: DesertColors.primaryGoldDark,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            translations['event_management']!,
            style: TextStyle(
              fontSize: isMobile ? 24 : 28,
              fontWeight: FontWeight.bold,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingEventsSection() {
    final eventsToShow = isMobile
        ? pendingEvents.take(_pendingEventsToShow).toList()
        : pendingEvents;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : DesertColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: DesertColors.maroon.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  translations['pending_events']!,
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${pendingEvents.length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.amber[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (pendingEvents.isEmpty)
            Text("No pending events found")
          else ...[
            ...eventsToShow.map((event) => _buildPendingEventCard(event)),
            if (isMobile && _pendingEventsToShow < pendingEvents.length)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _pendingEventsToShow += 3;
                      });
                    },
                    icon: const Icon(Icons.keyboard_arrow_down),
                    label: Text(translations['show_more']!),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildApprovedEventsSection() {
    final eventsToShow = isMobile
        ? approvedEvents.take(_approvedEventsToShow).toList()
        : approvedEvents;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : DesertColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: DesertColors.maroon.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  translations['approved_events']!,
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${approvedEvents.length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (approvedEvents.isEmpty)
            Text("No approved events found")
          else ...[
            ...eventsToShow.map((event) => _buildApprovedEventCard(event)),
            if (isMobile && _approvedEventsToShow < approvedEvents.length)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _approvedEventsToShow += 3;
                      });
                    },
                    icon: const Icon(Icons.keyboard_arrow_down),
                    label: Text(translations['show_more']!),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildApprovedEventCard(EventItem event) {
    final location = event.liveLink.isNotEmpty ? "Online" : event.location;

    if (isMobile) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (darkMode ? DesertColors.darkBackground : Colors.white)
              .withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                ),
                // Check if expired
                _isEventExpired(event)
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              language == 'ar' ? 'منتهي' : 'Expired',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _deleteExpiredEvent(event),
                            child: Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          language == 'ar' ? 'معتمد' : 'Approved',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              location,
              style: TextStyle(
                fontSize: 14,
                color:
                    (darkMode ? DesertColors.darkText : DesertColors.lightText)
                        .withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Submitted by: ${event.preacherName}",
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText)
                            .withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Submitted on: ${event.submittedOn}",
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText)
                            .withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Desktop layout remains unchanged
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (darkMode ? DesertColors.darkBackground : Colors.white)
            .withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.2), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.green.withOpacity(0.1),
            child: Text(
              event.initials,
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText,
                        ),
                      ),
                    ),
                    _isEventExpired(event)
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  language == 'ar'
                                      ? 'منتهي الصلاحية'
                                      : 'Expired',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteExpiredEvent(event),
                                tooltip: language == 'ar' ? 'حذف' : 'Delete',
                              ),
                            ],
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              language == 'ar' ? 'معتمد' : 'Approved',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  location,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText)
                            .withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      "Submitted by: ${event.preacherName}",
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            (darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText)
                                .withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "Submitted on: ${event.submittedOn}",
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            (darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText)
                                .withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingEventCard(EventItem event) {
    final location = event.liveLink.isNotEmpty ? "Online" : event.location;

    if (isMobile) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (darkMode ? DesertColors.darkBackground : Colors.white)
              .withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withOpacity(0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Pending",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              location,
              style: TextStyle(
                fontSize: 14,
                color:
                    (darkMode ? DesertColors.darkText : DesertColors.lightText)
                        .withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Submitted by: ${event.preacherName}",
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText)
                            .withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Submitted on: ${event.submittedOn}",
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText)
                            .withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        // ✅ Update Firestore
                        await FirebaseFirestore.instance
                            .collection('tblboardads')
                            .doc(event.id)
                            .update({'status': 'approved'});

                        // ✅ Send notification
                        await NotificationService()
                            .notifyOrganizerEventApproved(
                              event.organizerId,
                              event.title,
                            );

                        // ✅ Check if still mounted before any UI updates
                        if (!mounted) return;

                        // ✅ Update UI immediately - remove from pending, add to approved
                        setState(() {
                          // Remove from pending list
                          pendingEvents.removeWhere((e) => e.id == event.id);

                          // Add to approved list
                          approvedEvents.insert(
                            0,
                            event.copyWith(
                              status: "Approved",
                              statusAr: "معتمد",
                              statusColor: Colors.green,
                            ),
                          );
                        });

                        // ✅ Update cache with new state (do this AFTER setState)
                        await _updatePendingCache();
                        await _updateApprovedCache();

                        // ✅ Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Event approved successfully"),
                            duration: Duration(seconds: 2),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        print("Error approving event: $e");

                        // ✅ Check mounted before showing error
                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Failed to approve event: $e"),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check, size: 14),
                    label: Text(
                      translations['approve']!,
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        // ✅ Delete from tblboardads
                        await FirebaseFirestore.instance
                            .collection('tblboardads')
                            .doc(event.id)
                            .delete();

                        // ✅ Delete associated boards
                        final boardsSnap = await FirebaseFirestore.instance
                            .collection('tblboards')
                            .where('BoardAdsId', isEqualTo: event.id)
                            .get();

                        for (var doc in boardsSnap.docs) {
                          await doc.reference.delete();
                        }

                        // ✅ Send notification
                        await NotificationService()
                            .notifyOrganizerEventRejected(
                              event.organizerId,
                              event.title,
                            );

                        // ✅ Check if still mounted
                        if (!mounted) return;

                        // ✅ Update UI immediately
                        setState(() {
                          pendingEvents.removeWhere((e) => e.id == event.id);
                        });

                        // ✅ Update cache with new state
                        await _updatePendingCache();

                        // ✅ Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Event rejected successfully"),
                            duration: Duration(seconds: 2),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      } catch (e) {
                        print("Error rejecting event: $e");

                        // ✅ Check mounted before showing error
                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Failed to reject event: $e"),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.close, size: 14),
                    label: Text(
                      translations['reject']!,
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesertColors.crimson,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _showEventDetailsDialog(event);
                },
                icon: const Icon(Icons.visibility, size: 14),
                label: Text(
                  translations['view_details']!,
                  style: TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Desktop layout remains unchanged
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (darkMode ? DesertColors.darkBackground : Colors.white)
            .withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  "Pending",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            location,
            style: TextStyle(
              fontSize: 14,
              color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
                  .withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                "Submitted by: ${event.preacherName}",
                style: TextStyle(
                  fontSize: 12,
                  color:
                      (darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText)
                          .withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                "Submitted on: ${event.submittedOn}",
                style: TextStyle(
                  fontSize: 12,
                  color:
                      (darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText)
                          .withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await FirebaseFirestore.instance
                        .collection('tblboardads')
                        .doc(event.id)
                        .update({'status': 'approved'});

                    await NotificationService().notifyOrganizerEventApproved(
                      event.organizerId,
                      event.title,
                    );

                    if (!mounted) return;

                    setState(() {
                      pendingEvents.removeWhere((e) => e.id == event.id);
                      approvedEvents.insert(
                        0,
                        event.copyWith(
                          status: "Approved",
                          statusAr: "معتمد",
                          statusColor: Colors.green,
                        ),
                      );
                    });

                    // ✅ Update cache with new state
                    await _updatePendingCache();
                    await _updateApprovedCache();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Event approved successfully"),
                        duration: Duration(seconds: 2),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    print("Error approving event: $e");
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Failed to approve event: $e"),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check, size: 16),
                label: Text(translations['approve']!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await FirebaseFirestore.instance
                        .collection('tblboardads')
                        .doc(event.id)
                        .delete();

                    final boardsSnap = await FirebaseFirestore.instance
                        .collection('tblboards')
                        .where('BoardAdsId', isEqualTo: event.id)
                        .get();

                    for (var doc in boardsSnap.docs) {
                      await doc.reference.delete();
                    }

                    await NotificationService().notifyOrganizerEventRejected(
                      event.organizerId,
                      event.title,
                    );

                    if (!mounted) return;

                    setState(() {
                      pendingEvents.removeWhere((e) => e.id == event.id);
                    });

                    // ✅ Update cache with new state
                    await _updatePendingCache();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Event rejected successfully"),
                        duration: Duration(seconds: 2),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  } catch (e) {
                    print("Error rejecting event: $e");
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Failed to reject event: $e"),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.close, size: 16),
                label: Text(translations['reject']!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesertColors.crimson,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  _showEventDetailsDialog(event);
                },
                icon: const Icon(Icons.visibility, size: 16),
                label: Text(translations['view_details']!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEventDetailsDialog(EventItem event) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(event.title),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Description: ${event.description}"),
            Text("Submitted by: ${event.preacherName}"),
            Text("Submitted on: ${event.submittedOn}"),
            Text(
              "Location: ${event.liveLink.isNotEmpty ? 'Online' : event.location}",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBottomNav(BuildContext context) {
    final String? currentRoute = ModalRoute.of(context)?.settings.name;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: darkMode
              ? [
                  DesertColors.darkSurface.withOpacity(0.95),
                  DesertColors.darkBackground,
                ]
              : [
                  DesertColors.lightSurface.withOpacity(0.95),
                  DesertColors.lightBackground,
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: darkMode
                ? DesertColors.maroon.withOpacity(0.3)
                : DesertColors.camelSand.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context,
                icon: Icons.dashboard_outlined,
                label: language == "ar" ? "لوحة التحكم" : "Dashboard",
                route: '/admin_dashboard',
                currentRoute: currentRoute,
              ),
              _buildNavItem(
                context,
                icon: Icons.event_outlined,
                label: language == "ar" ? "الفعاليات" : "Events",
                route: '/events',
                currentRoute: currentRoute,
              ),
              _buildNavItem(
                context,
                icon: Icons.menu_book_outlined,
                label: language == "ar" ? "الكتب" : "Books",
                route: '/admin_books',
                currentRoute: currentRoute,
              ),
              _buildNavItem(
                context,
                icon: Icons.analytics_outlined,
                label: language == "ar" ? "تحليلات " : "Analytics",
                route: '/user-analytics',
                currentRoute: currentRoute,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    required String? currentRoute,
  }) {
    final bool isSelected = currentRoute == route;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pushNamed(context, route);
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: Duration(milliseconds: 300),
              child: Icon(
                icon,
                size: 24,
                color: isSelected
                    ? (darkMode ? DesertColors.camelSand : DesertColors.crimson)
                    : darkMode
                    ? DesertColors.darkText.withOpacity(0.7)
                    : DesertColors.lightText.withOpacity(0.7),
              ),
            ),
            SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: isSelected ? 12 : 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? (darkMode ? DesertColors.camelSand : DesertColors.crimson)
                    : darkMode
                    ? DesertColors.darkText.withOpacity(0.8)
                    : DesertColors.lightText.withOpacity(0.8),
                letterSpacing: 0.3,
              ),
              child: Text(label, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class EventItem {
  final String id;
  final String title;
  final String preacherName;
  final String location;
  final String description;
  final String submittedOn;
  final String liveLink;
  final int? repeatDay;

  final String status;
  final String statusAr;
  final Color statusColor;
  final String initials;
  final String organizerId;

  EventItem({
    required this.id,
    required this.title,
    required this.preacherName,
    required this.location,
    required this.description,
    required this.submittedOn,
    required this.liveLink,
    required this.status,
    required this.statusAr,
    required this.statusColor,
    required this.initials,
    required this.organizerId,
    this.repeatDay,
  });

  EventItem copyWith({String? status, String? statusAr, Color? statusColor}) {
    return EventItem(
      id: id,
      title: title,
      preacherName: preacherName,
      location: location,
      description: description,
      submittedOn: submittedOn,
      liveLink: liveLink,
      status: status ?? this.status,
      statusAr: statusAr ?? this.statusAr,
      statusColor: statusColor ?? this.statusColor,
      initials: initials,
      organizerId: organizerId,
      repeatDay: repeatDay,
    );
  }

  static DateTime _parseDate(String raw) {
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return DateFormat("d/M/yyyy HH:mm").parse(raw);
    }
  }

  static int? _parseRepeatDay(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        print("⚠️ Failed to parse RepeatDay: $value");
        return null;
      }
    }
    return null;
  }

  factory EventItem.fromFirestore(
    String docId,
    Map<String, dynamic> adsData,
    Map<String, dynamic> boardData,
    Map<String, dynamic> userData,
  ) {
    final rawDate = boardData['BoardDateTime'] ?? '';
    final date = rawDate is String ? _parseDate(rawDate) : DateTime.now();

    final preacher = userData['FullName'] ?? 'Unknown';
    final title = adsData['Title'] ?? 'Untitled';
    final location =
        (adsData['LiveBroadcastLink'] != null &&
            adsData['LiveBroadcastLink'].toString().trim().isNotEmpty)
        ? 'Online'
        : adsData['Location'] ?? 'Unknown';
    final ownerId = adsData['OwnerId'] ?? '';
    return EventItem(
      id: docId,
      title: title,
      preacherName: preacher,
      location: location,
      description: adsData['Description'] ?? 'Not Added',
      submittedOn: DateFormat("yyyy-MM-dd").format(date),
      liveLink: adsData['LiveBroadcastLink'] ?? '',
      status: 'Pending',
      statusAr: 'معلق',
      statusColor: Colors.orange,
      initials: preacher.isNotEmpty ? preacher[0].toUpperCase() : 'A',
      organizerId: ownerId,
      repeatDay: _parseRepeatDay(adsData['RepeatDay']),
    );
  }
}
