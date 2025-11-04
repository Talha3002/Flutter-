import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alraya_app/alrayah.dart';
import 'event_creation.dart';
import 'majalis_navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:async/async.dart';

class EventCacheService {
  static const String _cacheKeyPrefix = 'dashboard_events_cache_';
  static const String _timestampKeyPrefix = 'dashboard_events_cache_timestamp_';
  static const Duration _cacheDuration = Duration(hours: 24);

  // ✅ Generate user-specific cache keys
  static String _getCacheKey(String userId) => '$_cacheKeyPrefix$userId';
  static String _getTimestampKey(String userId) =>
      '$_timestampKeyPrefix$userId';

  // Save events to cache (USER-SPECIFIC)
  static Future<void> saveToCache(
    String userId,
    List<Map<String, dynamic>> events,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_getCacheKey(userId), jsonEncode(events));
      await prefs.setInt(
        _getTimestampKey(userId),
        DateTime.now().millisecondsSinceEpoch,
      );
      print('✅ Cached ${events.length} events for user $userId');
    } catch (e) {
      print('❌ Error saving cache: $e');
    }
  }

  // Load events from cache (USER-SPECIFIC)
  static Future<List<Map<String, dynamic>>?> loadFromCache(
    String userId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if cache exists and is valid
      final timestamp = prefs.getInt(_getTimestampKey(userId));
      if (timestamp == null) {
        print('⚠️ No cache found for user $userId');
        return null;
      }

      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge > _cacheDuration.inMilliseconds) {
        // Cache expired
        await clearCache(userId);
        print('⏰ Cache expired for user $userId');
        return null;
      }

      final String? cachedData = prefs.getString(_getCacheKey(userId));
      if (cachedData == null) return null;

      // Parse JSON
      final List<dynamic> jsonList = jsonDecode(cachedData);
      print('✅ Loaded ${jsonList.length} events from cache for user $userId');
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Error loading cache: $e');
      return null;
    }
  }

  // Clear cache (USER-SPECIFIC)
  static Future<void> clearCache(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getCacheKey(userId));
    await prefs.remove(_getTimestampKey(userId));
    print('🗑️ Cache cleared for user $userId');
  }

  // ✅ NEW: Clear all user caches (useful on logout)
  static Future<void> clearAllCaches() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (var key in keys) {
      if (key.startsWith(_cacheKeyPrefix) ||
          key.startsWith(_timestampKeyPrefix)) {
        await prefs.remove(key);
      }
    }
    print('🗑️ All caches cleared');
  }
}

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  bool darkMode = false;
  String currentPage = 'Dashboard';
  bool showProfileMenu = false;
  String language = 'ar';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  List<Map<String, dynamic>>? _cachedEvents;

  Map<String, Map<String, String>> translations = {
    'dashboard': {'ar': 'لوحة القيادة', 'en': 'Dashboard'},
    'profile': {'ar': 'الملف الشخصي', 'en': 'Profile'},
    'reports': {'ar': 'التقارير', 'en': 'Reports'},
    'ministry_dashboard': {
      'ar': 'لوحة قيادة الوزارة',
      'en': 'Ministry Dashboard',
    },
    'welcome_back': {
      'ar': 'مرحبًا بعودتك! إليك نظرة عامة على فعاليات وزارتك.',
      'en': 'Welcome back! Here\'s an overview of your ministry events.',
    },
    'total_events': {'ar': 'إجمالي الفعاليات', 'en': 'Total Events'},
    'this_month': {'ar': 'هذا الشهر', 'en': 'This Month'},
    'total_attendees': {'ar': 'إجمالي الحضور', 'en': 'Total Attendees'},
    'online_events': {'ar': 'الفعاليات الرقمية', 'en': 'Online Events'},
    'my_events': {'ar': 'فعالياتي', 'en': 'My Events'},
    'events_description': {
      'ar': 'فعاليات وزارتك وتفاصيلها',
      'en': 'Your ministry events and their details',
    },
    'create_event': {'ar': 'إنشاء فعالية', 'en': 'Create Event'},
    'create_new_event': {'ar': 'إنشاء فعالية جديدة', 'en': 'Create New Event'},
    'sunday_service': {
      'ar': 'خدمة الأحد الصباحية',
      'en': 'Sunday Morning Service',
    },
    'main_sanctuary': {'ar': 'المقدس الرئيسي', 'en': 'Main Sanctuary'},
    'bible_study': {'ar': 'دراسة الكتاب المقدس', 'en': 'Midweek Bible Study'},
    'online_event': {'ar': 'فعالية رقمية', 'en': 'Online Event'},
    'youth_revival': {'ar': 'ليلة إحياء الشباب', 'en': 'Youth Revival Night'},
    'fellowship_hall': {'ar': 'قاعة الزمالة', 'en': 'Fellowship Hall'},
    'john_doe': {'ar': 'يوحنا دو', 'en': 'John Doe'},
    'ministry_admin': {'ar': 'مدير الوزارة', 'en': 'Ministry Administrator'},
    'analytics_coming': {
      'ar': 'التحليلات والرؤى قادمة قريبا',
      'en': 'Analytics and insights coming soon',
    },
    'edit_profile': {'ar': 'تعديل الملف الشخصي', 'en': 'Edit Profile'},
    'settings': {'ar': 'الإعدادات', 'en': 'Settings'},
    'logout': {'ar': 'تسجيل الخروج', 'en': 'Logout'},
    'logout_confirm': {
      'ar': 'هل أنت متأكد من أنك تريد تسجيل الخروج؟',
      'en': 'Are you sure you want to logout?',
    },
    'cancel': {'ar': 'إلغاء', 'en': 'Cancel'},
  };

  String getText(String key) {
    return translations[key]?[language] ?? key;
  }

  void toggleLanguage() {
    setState(() {
      language = language == 'ar' ? 'en' : 'ar';
    });
  }

  bool isEventToday(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return false;
    try {
      final now = DateTime.now();
      final eventDateTime = DateFormat("d/M/yyyy HH:mm").parse(dateTimeString);

      return eventDateTime.year == now.year &&
          eventDateTime.month == now.month &&
          eventDateTime.day == now.day;
    } catch (e) {
      return false;
    }
  }

  String formatDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return "";
    try {
      final dt = DateTime.parse(dateTimeString);
      return DateFormat("yyyy-MM-dd HH:mm").format(dt);
    } catch (e) {
      return dateTimeString;
    }
  }

  late Stream<List<Map<String, dynamic>>> _eventsStream;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    // 🔥 Initialize stream with cache-first approach (broadcast for multiple listeners)
    _eventsStream = _getCachedOrFetchEvents().asBroadcastStream();
  }

  Stream<List<Map<String, dynamic>>> _getCachedOrFetchEvents() async* {
    // ✅ Get current user ID FIRST
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      return;
    }

    final userId = user.uid;
    print('👤 Loading events for user: $userId');

    // Try loading from cache first (USER-SPECIFIC)
    final cachedData = await EventCacheService.loadFromCache(userId);

    if (cachedData != null && cachedData.isNotEmpty) {
      // Cache hit - instant load!
      print('✅ Loaded ${cachedData.length} events from cache for user $userId');
      if (mounted) {
        setState(() {
          _cachedEvents = cachedData;
        });
      }
      yield cachedData;

      // Optionally: fetch fresh data in background and update cache
      _fetchAndCacheEventsInBackground();
    } else {
      // Cache miss - fetch from Firestore
      print('⏳ Cache miss - fetching from Firestore for user $userId...');
      await for (final events in getEventsOptimized()) {
        if (mounted) {
          setState(() {
            _cachedEvents = events;
          });
        }
        yield events;
      }
    }
  }

  Future<void> _fetchAndCacheEventsInBackground() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userId = user.uid;
      final events = await _fetchEventsOnce();
      await EventCacheService.saveToCache(userId, events); // ✅ USER-SPECIFIC
      print('🔄 Background cache refresh complete for user $userId');
    } catch (e) {
      print('❌ Background refresh failed: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void toggleDarkMode() {
    setState(() {
      darkMode = !darkMode;
    });
  }

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

  // 🔥 NEW: Optimized single-fetch method (no streaming)
  Future<List<Map<String, dynamic>>> _fetchEventsOnce() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final userId = user.uid;
    print("🔥 Firebase UID: $userId");

    try {
      // STEP 1: Resolve OratorId
      String? migratedGuid;
      String? oratorIdToUse;

      final aspUserSnap = await FirebaseFirestore.instance
          .collection("aspnetusers")
          .where("authUid", isEqualTo: userId)
          .limit(1)
          .get();

      if (aspUserSnap.docs.isNotEmpty) {
        migratedGuid = aspUserSnap.docs.first.data()["Id"];
        print("✅ Migrated user. GUID: $migratedGuid");
        oratorIdToUse = userId;
      } else {
        final aspUserById = await FirebaseFirestore.instance
            .collection("aspnetusers")
            .doc(userId)
            .get();
        if (aspUserById.exists) {
          oratorIdToUse = aspUserById.data()?["Id"];
          print("✅ New user. Using aspnetusers.Id as OratorId: $oratorIdToUse");
        } else {
          print("❌ No aspnetusers record found.");
          return [];
        }
      }

      // STEP 2: Fetch ALL boards at once (batch query)
      List<Map<String, dynamic>> allBoards = [];

      if (oratorIdToUse != null) {
        final boardsSnap1 = await FirebaseFirestore.instance
            .collection("tblboards")
            .where("IsDeleted", isEqualTo: "False")
            .where("OratorId", isEqualTo: oratorIdToUse)
            .get();
        allBoards.addAll(boardsSnap1.docs.map((doc) => doc.data()).toList());
      }

      if (migratedGuid != null) {
        final boardsSnap2 = await FirebaseFirestore.instance
            .collection("tblboards")
            .where("IsDeleted", isEqualTo: "False")
            .where("OratorId", isEqualTo: migratedGuid)
            .get();
        allBoards.addAll(boardsSnap2.docs.map((doc) => doc.data()).toList());
      }

      print("📋 Fetched ${allBoards.length} boards");

      if (allBoards.isEmpty) return [];

      // STEP 3: Extract all unique BoardAdsIds
      final Set<String> boardAdsIds = allBoards
          .map((board) => board["BoardAdsId"] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet();

      print("🔍 Unique BoardAdsIds: ${boardAdsIds.length}");

      // STEP 4: Fetch ALL ads at once (batch query with 'in' operator)
      Map<String, Map<String, dynamic>> adsMap = {};

      if (boardAdsIds.isNotEmpty) {
        final boardAdsIdsList = boardAdsIds.toList();

        // Firestore 'in' query supports up to 10 items, so we batch
        for (int i = 0; i < boardAdsIdsList.length; i += 10) {
          final batch = boardAdsIdsList.skip(i).take(10).toList();

          final adsSnapshot = await FirebaseFirestore.instance
              .collection("tblboardads")
              .where("Id", whereIn: batch)
              .get();

          for (var adsDoc in adsSnapshot.docs) {
            final data = adsDoc.data();
            adsMap[data["Id"]] = data;
          }
        }
      }

      print("📦 Fetched ${adsMap.length} ads");

      // STEP 5: Build events in memory (no more loops!)
      List<Map<String, dynamic>> allEvents = [];

      for (var boardData in allBoards) {
        final boardAdsId = boardData["BoardAdsId"];
        final adsData = adsMap[boardAdsId];

        if (adsData != null) {
          allEvents.add({
            "title": adsData["Title"] ?? "",
            "dateTime": boardData["BoardDateTime"] ?? "",
            "location": adsData["Location"] ?? "",
            "liveLink": adsData["LiveBroadcastLink"],
            "status": adsData["status"] ?? "Pending",
          });
        }
      }

      print("✅ Built ${allEvents.length} events in memory");

      // Save to cache
      // Save to cache (USER-SPECIFIC)
      await EventCacheService.saveToCache(userId, allEvents);

      return allEvents;
    } catch (e) {
      print("❌ Error fetching events: $e");
      return [];
    }
  }

  // 🔥 NEW: Optimized streaming version
  Stream<List<Map<String, dynamic>>> getEventsOptimized() async* {
    final events = await _fetchEventsOnce();
    yield events;

    // Optional: Listen for real-time updates
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;

    // Get OratorIds
    String? migratedGuid;
    String? oratorIdToUse;

    final aspUserSnap = await FirebaseFirestore.instance
        .collection("aspnetusers")
        .where("authUid", isEqualTo: userId)
        .limit(1)
        .get();

    if (aspUserSnap.docs.isNotEmpty) {
      migratedGuid = aspUserSnap.docs.first.data()["Id"];
      oratorIdToUse = userId;
    } else {
      final aspUserById = await FirebaseFirestore.instance
          .collection("aspnetusers")
          .doc(userId)
          .get();
      if (aspUserById.exists) {
        oratorIdToUse = aspUserById.data()?["Id"];
      }
    }

    // Listen to boards changes
    final queries = <Query<Map<String, dynamic>>>[];
    if (oratorIdToUse != null) {
      queries.add(
        FirebaseFirestore.instance
            .collection("tblboards")
            .where("IsDeleted", isEqualTo: "False")
            .where("OratorId", isEqualTo: oratorIdToUse),
      );
    }
    if (migratedGuid != null) {
      queries.add(
        FirebaseFirestore.instance
            .collection("tblboards")
            .where("IsDeleted", isEqualTo: "False")
            .where("OratorId", isEqualTo: migratedGuid),
      );
    }

    if (queries.isEmpty) return;

    final streams = queries.map((q) => q.snapshots());

    await for (final _ in StreamGroup.merge(streams)) {
      // When any board changes, re-fetch everything
      final freshEvents = await _fetchEventsOnce();
      if (mounted) {
        setState(() {
          _cachedEvents = freshEvents;
        });
      }
      yield freshEvents;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? currentRoute = ModalRoute.of(context)?.settings.name;
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Theme(
      data: ThemeData(
        brightness: darkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: darkMode
            ? DesertColors.darkBackground
            : DesertColors.lightBackground,
      ),
      child: Scaffold(
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

                    // 🌍 Language & 🌙 Theme Toggle Buttons (like desktop style)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Language Toggle
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
                                          DesertColors.camelSand.withOpacity(
                                            0.8,
                                          ),
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

                          // Dark Mode Toggle
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

                    // ✅ Navigation Tiles
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 20,
                      ), // reduce tile width
                      child: GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/dashboard'),
                        child: Container(
                          decoration: BoxDecoration(
                            color: currentRoute == '/dashboard'
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
                                language == 'ar' ? 'لوحة التحكم' : 'Dashboard',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: currentRoute == '/dashboard'
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

                    ListTile(
                      selected: currentRoute == '/profile',
                      selectedTileColor: darkMode
                          ? DesertColors.primaryGoldDark
                          : DesertColors.maroon,

                      title: Text(
                        language == 'ar' ? 'الملف الشخصي' : 'Profile',
                        style: TextStyle(
                          color: currentRoute == '/profile'
                              ? (darkMode
                                    ? DesertColors.lightText
                                    : Colors.white)
                              : (darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText),
                        ),
                      ),
                      onTap: () => Navigator.pushNamed(context, '/profile'),
                    ),
                    ListTile(
                      selected: currentRoute == '/reports',
                      selectedTileColor: darkMode
                          ? DesertColors.primaryGoldDark
                          : DesertColors.maroon,

                      title: Text(
                        language == 'ar' ? 'التقارير' : 'Reports',
                        style: TextStyle(
                          color: currentRoute == '/reports'
                              ? (darkMode
                                    ? DesertColors.lightText
                                    : Colors.white)
                              : (darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText),
                        ),
                      ),
                      onTap: () => Navigator.pushNamed(context, '/reports'),
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
                        // ✅ Clear user-specific cache before logout
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await EventCacheService.clearCache(user.uid);
                        }

                        await FirebaseAuth.instance.signOut();
                        print('✅ User signed out successfully.');

                        Navigator.pushReplacementNamed(context, '/login');
                      },
                    ),

                    Divider(),

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
        body: Directionality(
          textDirection: language == 'ar'
              ? ui.TextDirection.rtl
              : ui.TextDirection.ltr,
          child: Column(
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
                    onLanguageToggle: toggleLanguage,
                    onThemeToggle: toggleDarkMode,
                    fullName: fullName,
                    openDrawer: () => Scaffold.of(context).openEndDrawer(),
                  );
                },
              ),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildDashboardView(isMobile),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: isMobile
            ? FloatingActionButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateEventPage(
                        darkMode: darkMode,
                        language: language,
                        currentPage: currentPage,
                        onPageChange: (page) {
                          setState(() {
                            currentPage = page;
                          });
                        },
                        onLanguageToggle: toggleLanguage,
                        onThemeToggle: toggleDarkMode,
                      ),
                      settings: const RouteSettings(name: '/createEvent'),
                    ),
                  );
                },
                backgroundColor: DesertColors.primaryGoldDark,
                child: Icon(Icons.add, color: Colors.white),
              )
            : null,
        bottomNavigationBar: isMobile ? _buildMobileBottomNav(context) : null,
      ),
    );
  }

  Widget _buildDashboardView(bool isMobile) {
    return RefreshIndicator(
      onRefresh: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await EventCacheService.clearCache(user.uid); // ✅ USER-SPECIFIC
        }
        setState(() {
          _eventsStream = _getCachedOrFetchEvents().asBroadcastStream();
        });
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  // ✅ Add this wrapper
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        getText('dashboard'),
                        style: TextStyle(
                          fontSize: isMobile ? 24 : 32,
                          fontWeight: FontWeight.bold,
                          color: darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        getText('welcome_back'),
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 16, // Reduced size
                          color:
                              (darkMode
                                      ? DesertColors.darkText
                                      : DesertColors.lightText)
                                  .withOpacity(0.7),
                        ),
                        maxLines: 2, // Allow wrapping to 2 lines
                        overflow:
                            TextOverflow.visible, // or TextOverflow.ellipsis
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 24 : 32),

            /// 🔥 StreamBuilder for dynamic stats
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _eventsStream,
              builder: (context, snapshot) {
                final now = DateTime.now();

                Widget totalEventsWidget = CircularProgressIndicator();
                Widget thisMonthWidget = CircularProgressIndicator();
                Widget totalAttendeesWidget = CircularProgressIndicator();
                Widget onlineEventsWidget = CircularProgressIndicator();

                if (snapshot.hasData) {
                  final events = snapshot.data!;
                  final totalEvents = events.length;

                  final thisMonth = events.where((event) {
                    final dtString = event["dateTime"] ?? "";
                    try {
                      final dt = DateFormat("d/M/yyyy HH:mm").parse(dtString);
                      return dt.month == now.month && dt.year == now.year;
                    } catch (_) {
                      return false;
                    }
                  }).length;

                  final onlineEvents = events.where((event) {
                    final liveLink = event["liveLink"];
                    return liveLink != null &&
                        liveLink.toString().trim().isNotEmpty;
                  }).length;

                  final totalAttendees = 0; // placeholder

                  // 👇 Replace loaders with Text when data ready
                  totalEventsWidget = Text(
                    totalEvents.toString(),
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  );
                  thisMonthWidget = Text(
                    thisMonth.toString(),
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  );
                  totalAttendeesWidget = Text(
                    totalAttendees.toString(),
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  );
                  onlineEventsWidget = Text(
                    onlineEvents.toString(),
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  );
                }

                if (isMobile) {
                  // Mobile: 2x2 Grid Layout
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              getText('total_events'),
                              totalEventsWidget,
                              Icons.calendar_today,
                              DesertColors.primaryGoldDark,
                              isMobile,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              getText('this_month'),
                              thisMonthWidget,
                              Icons.schedule,
                              DesertColors.camelSand,
                              isMobile,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              getText('total_attendees'),
                              totalAttendeesWidget,
                              Icons.people,
                              DesertColors.crimson,
                              isMobile,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              getText('online_events'),
                              onlineEventsWidget,
                              Icons.language,
                              DesertColors.maroon,
                              isMobile,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                } else {
                  // Desktop: Row Layout
                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildStatCard(
                          getText('total_events'),
                          totalEventsWidget,
                          Icons.calendar_today,
                          DesertColors.primaryGoldDark,
                          isMobile,
                        ),
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        flex: 3,
                        child: _buildStatCard(
                          getText('this_month'),
                          thisMonthWidget,
                          Icons.schedule,
                          DesertColors.camelSand,
                          isMobile,
                        ),
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        flex: 3,
                        child: _buildStatCard(
                          getText('total_attendees'),
                          totalAttendeesWidget,
                          Icons.people,
                          DesertColors.crimson,
                          isMobile,
                        ),
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        flex: 3,
                        child: _buildStatCard(
                          getText('online_events'),
                          onlineEventsWidget,
                          Icons.language,
                          DesertColors.maroon,
                          isMobile,
                        ),
                      ),
                      Expanded(flex: 2, child: SizedBox()),
                    ],
                  );
                }
              },
            ),

            SizedBox(height: isMobile ? 24 : 40),

            // My Events Section
            _buildMyEventsSection(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    Widget valueWidget, // 👈 instead of String
    IconData icon,
    Color color,
    bool isMobile,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => HapticFeedback.selectionClick(),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            color: darkMode
                ? DesertColors.darkSurface
                : DesertColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: darkMode
                  ? DesertColors.camelSand.withOpacity(0.2)
                  : DesertColors.maroon.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: (darkMode ? Colors.black : Colors.grey).withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 2),
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
                      title,
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        color:
                            (darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText)
                                .withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(isMobile ? 6 : 8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: isMobile ? 16 : 20, color: color),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 8 : 12),

              /// 👇 Either number or loader
              Center(child: valueWidget),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyEventsSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : DesertColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: darkMode
              ? DesertColors.camelSand.withOpacity(0.2)
              : DesertColors.maroon.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_note,
                color: DesertColors.primaryGoldDark,
                size: isMobile ? 20 : 24,
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    getText('my_events'),
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                  Text(
                    getText('events_description'),
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      color:
                          (darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText)
                              .withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: isMobile ? 16 : 24),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _eventsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Text(
                    language == "ar" ? "لا توجد فعاليات" : "No events found",
                  ),
                );
              }

              final events = snapshot.data!;

              return Column(
                children: events.map((event) {
                  final isOnline =
                      event["liveLink"] != null &&
                      event["liveLink"].toString().trim().isNotEmpty;

                  // Add this line to check if event is today
                  final eventIsToday = isEventToday(event["dateTime"]);

                  print(
                    "Event: ${event['title']} - LiveLink: ${event['liveLink']}",
                  );

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: _buildEventCard(
                      event["title"] ?? "Untitled",
                      event["dateTime"] ?? "",
                      isOnline
                          ? getText("online_event")
                          : (event["location"]?.toString() ?? ""),
                      "0", // attendees count (can be dynamic later)
                      isOnline ? Icons.language : Icons.location_on,
                      isOnline
                          ? DesertColors.camelSand
                          : DesertColors.primaryGoldDark,
                      isMobile,
                      eventIsToday, // Add this parameter
                      status: event["status"] ?? "Pending",
                    ),
                  );
                }).toList(),
              );
            },
          ),

          if (!isMobile) ...[
            SizedBox(height: 24),
            Center(child: _buildCreateNewEventButton()),
          ],
        ],
      ),
    );
  }

  Widget _buildCreateNewEventButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateEventPage(
                darkMode: darkMode,
                language: language,
                currentPage: currentPage, // keep it "dashboard"
                onPageChange: (page) {
                  setState(() {
                    currentPage =
                        page; // still can change if you want from inside
                  });
                },
                onLanguageToggle: toggleLanguage,
                onThemeToggle: toggleDarkMode,
              ),
              settings: const RouteSettings(name: '/createEvent'),
            ),
          );
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [DesertColors.primaryGoldDark, DesertColors.camelSand],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: DesertColors.primaryGoldDark.withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text(
                getText('create_new_event'),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(
    String title,
    String time,
    String location,
    String attendees,
    IconData locationIcon,
    Color accentColor,
    bool isMobile,
    bool isToday, {
    String status = "approved", // ✅ Add optional status
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => HapticFeedback.selectionClick(),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            color: isToday
                ? (darkMode
                      ? DesertColors.camelSand.withOpacity(0.1)
                      : DesertColors.primaryGoldDark.withOpacity(0.05))
                : (darkMode
                      ? DesertColors.darkBackground.withOpacity(0.5)
                      : Colors.white.withOpacity(0.7)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isToday
                  ? DesertColors.primaryGoldDark.withOpacity(0.5)
                  : accentColor.withOpacity(0.2),
              width: isToday ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Show status badge
              if (status == "Pending") ...[
                Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber[600], // yellow badge for Pending
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Pending",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ] else if (status == "approved") ...[
                Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green[600], // green badge for Approved
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Approved",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],

              // Existing Today indicator
              if (isToday) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        DesertColors.primaryGoldDark,
                        DesertColors.camelSand,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.today, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        language == 'ar' ? 'اليوم' : 'Today',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
              ],

              // Rest of your event card (title, location, attendees, etc.)
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 8 : 12),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      locationIcon,
                      color: accentColor,
                      size: isMobile ? 20 : 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            fontWeight: isToday
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isToday
                                ? DesertColors.primaryGoldDark
                                : (darkMode
                                          ? DesertColors.darkText
                                          : DesertColors.lightText)
                                      .withOpacity(0.6),
                          ),
                        ),
                        Text(
                          location,
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            color:
                                (darkMode
                                        ? DesertColors.darkText
                                        : DesertColors.lightText)
                                    .withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: isMobile ? 14 : 16,
                        color:
                            (darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText)
                                .withOpacity(0.7),
                      ),
                      SizedBox(width: 4),
                      Text(
                        attendees,
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          fontWeight: FontWeight.w600,
                          color: darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
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
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context,
                icon: Icons.dashboard_outlined,
                label: language == "ar" ? "لوحة القيادة" : "Dashboard",
                route: '/dashboard',
                currentRoute: currentRoute,
              ),
              _buildNavItem(
                context,
                icon: Icons.person_outline,
                label: language == "ar" ? "الملف الشخصي" : "Profile",
                route: '/profile',
                currentRoute: currentRoute,
              ),
              _buildNavItem(
                context,
                icon: Icons.analytics_outlined,
                label: language == "ar" ? "التقارير" : "Reports",
                route: '/reports',
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
