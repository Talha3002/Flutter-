import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alraya_app/alrayah.dart';
import 'majalis_navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Add this AFTER imports, BEFORE ReportsAnalyticsPage class
class ReportsEventCacheService {
  static const String _cacheKey = 'reports_events_cache';
  static const String _timestampKey = 'reports_events_cache_timestamp';
  static const Duration _cacheDuration = Duration(hours: 24);

// Save events to cache
static Future<void> saveToCache(List<Map<String, dynamic>> events) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Convert DateTime objects to ISO strings before encoding
    final List<Map<String, dynamic>> serializableEvents = events.map((event) {
      return {
        'title': event['title'],
        'date': (event['date'] as DateTime).toIso8601String(), // ✅ Convert DateTime to String
        'attendance': event['attendance'],
        'isOnline': event['isOnline'],
      };
    }).toList();
    
    await prefs.setString(_cacheKey, jsonEncode(serializableEvents));
    await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
    print('✅ Cached ${events.length} events for reports');
  } catch (e) {
    print('❌ Error saving reports cache: $e');
  }
}

 // Load events from cache
static Future<List<Map<String, dynamic>>?> loadFromCache() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if cache exists and is valid
    final timestamp = prefs.getInt(_timestampKey);
    if (timestamp == null) return null;
    
    final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (cacheAge > _cacheDuration.inMilliseconds) {
      // Cache expired
      await clearCache();
      return null;
    }

    final String? cachedData = prefs.getString(_cacheKey);
    if (cachedData == null) return null;

    // Parse JSON
    final List<dynamic> jsonList = jsonDecode(cachedData);
    
    // Convert date strings back to DateTime objects
    final List<Map<String, dynamic>> events = jsonList.map((json) {
      return {
        'title': json['title'],
        'date': DateTime.parse(json['date']), // ✅ Convert String back to DateTime
        'attendance': json['attendance'],
        'isOnline': json['isOnline'],
      };
    }).toList();
    
    return events;
  } catch (e) {
    print('❌ Error loading reports cache: $e');
    return null;
  }
}

  // Clear cache
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_timestampKey);
    print('🗑️ Reports cache cleared');
  }
}

class ReportsAnalyticsPage extends StatefulWidget {
  @override
  _ReportsAnalyticsPageState createState() => _ReportsAnalyticsPageState();
}

class _ReportsAnalyticsPageState extends State<ReportsAnalyticsPage> {
  bool darkMode = false;
  String language = 'ar';
  String currentPage = 'reports';
  String selectedFilter = 'latest';
  DateTime? customSelectedMonth;
  bool isLoading = false;

  List<Map<String, dynamic>> allEvents = [];

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

  void onFilterChanged(String filter) {
    setState(() {
      selectedFilter = filter;
      if (filter != 'custom') {
        customSelectedMonth = null;
      }
    });
  }

  void showCustomMonthPicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: customSelectedMonth ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: DesertColors.primaryGoldDark,
              onPrimary: Colors.white,
              surface: darkMode
                  ? DesertColors.darkSurface
                  : DesertColors.lightSurface,
              onSurface: darkMode
                  ? DesertColors.darkText
                  : DesertColors.lightText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        customSelectedMonth = picked;
        selectedFilter = 'custom';
      });
    }
  }

  List<Map<String, dynamic>> getFilteredEvents() {
    final now = DateTime.now();
    List<Map<String, dynamic>> filteredEvents = List.from(allEvents);

    switch (selectedFilter) {
      case 'latest':
        filteredEvents.sort((a, b) => b['date'].compareTo(a['date']));
        break;
      case 'thisMonth':
        filteredEvents = filteredEvents.where((event) {
          final eventDate = event['date'] as DateTime;
          return eventDate.year == now.year && eventDate.month == now.month;
        }).toList();
        filteredEvents.sort((a, b) => b['date'].compareTo(a['date']));
        break;
      case 'lastMonth':
        final lastMonth = DateTime(now.year, now.month - 1);
        filteredEvents = filteredEvents.where((event) {
          final eventDate = event['date'] as DateTime;
          return eventDate.year == lastMonth.year &&
              eventDate.month == lastMonth.month;
        }).toList();
        filteredEvents.sort((a, b) => b['date'].compareTo(a['date']));
        break;
      case 'custom':
        if (customSelectedMonth != null) {
          filteredEvents = filteredEvents.where((event) {
            final eventDate = event['date'] as DateTime;
            return eventDate.year == customSelectedMonth!.year &&
                eventDate.month == customSelectedMonth!.month;
          }).toList();
          filteredEvents.sort((a, b) => b['date'].compareTo(a['date']));
        }
        break;
    }

    return filteredEvents;
  }

  String getCustomMonthText() {
    if (customSelectedMonth == null) return '';
    final months = language == 'ar'
        ? [
            'يناير',
            'فبراير',
            'مارس',
            'أبريل',
            'مايو',
            'يونيو',
            'يوليو',
            'أغسطس',
            'سبتمبر',
            'أكتوبر',
            'نوفمبر',
            'ديسمبر',
          ]
        : [
            'January',
            'February',
            'March',
            'April',
            'May',
            'June',
            'July',
            'August',
            'September',
            'October',
            'November',
            'December',
          ];

    return '${months[customSelectedMonth!.month - 1]} ${customSelectedMonth!.year}';
  }

  Map<String, String> getTexts() {
    return {
      'title': language == 'ar' ? 'التقارير والتحليلات' : 'Reports & Analytics',
      'subtitle': language == 'ar'
          ? 'تتبع نمو الوزارة ومشاركتها'
          : 'Track your ministry\'s growth and engagement',
      'totalEvents': language == 'ar' ? 'إجمالي الأحداث' : 'Total Events',
      'totalAttendees': language == 'ar' ? 'إجمالي الحضور' : 'Total Attendees',
      'averageAttendance': language == 'ar'
          ? 'متوسط الحضور'
          : 'Average Attendance',
      'growthRate': language == 'ar' ? 'معدل النمو' : 'Growth Rate',
      'allEvents': language == 'ar' ? 'جميع الأحداث' : 'All Events',
      'allEventsSubtitle': language == 'ar'
          ? 'عرض جميع أحداث الوزارة مع إحصائيات الحضور'
          : 'View all ministry events with attendance statistics',
      'sundayMorning': language == 'ar'
          ? 'خدمة الأحد الصباحية'
          : 'Sunday Morning Service',
      'midweekBible': language == 'ar'
          ? 'دراسة الكتاب المقدس'
          : 'Midweek Bible Study',
      'youthRevival': language == 'ar'
          ? 'ليلة إحياء الشباب'
          : 'Youth Revival Night',
      'christmasEve': language == 'ar'
          ? 'خدمة ليلة عيد الميلاد'
          : 'Christmas Eve Service',
      'easterSunday': language == 'ar' ? 'أحد القيامة' : 'Easter Sunday',
      'offline': language == 'ar' ? 'حضوري' : 'Offline',
      'prayerMeeting': language == 'ar' ? 'اجتماع الصلاة' : 'Prayer Meeting',
      'womenConference': language == 'ar'
          ? 'مؤتمر السيدات'
          : 'Women\'s Conference',

      // Filter texts
      'sortBy': language == 'ar' ? 'ترتيب حسب' : 'Sort By',
      'latest': language == 'ar' ? 'الأحدث' : 'Latest',
      'thisMonth': language == 'ar' ? 'هذا الشهر' : 'This Month',
      'lastMonth': language == 'ar' ? 'الشهر الماضي' : 'Last Month',
      'customMonth': language == 'ar' ? 'شهر مخصص' : 'Custom Month',
      'selectMonth': language == 'ar' ? 'اختر الشهر' : 'Select Month',
      'online': language == 'ar' ? 'أونلاين' : 'Online',

      // Event distribution texts
      'eventDistribution': language == 'ar'
          ? 'توزيع أنواع الأحداث'
          : 'Event Type Distribution',
      'eventDistributionSubtitle': language == 'ar'
          ? 'مقارنة بين الأحداث الحضورية والأونلاين'
          : 'Comparison of in-person and online events',
      'inPerson': language == 'ar' ? 'حضوري' : 'In-Person',
    };
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

Future<void> fetchEvents() async {
  try {
    // ✅ Check cache first
    final cachedData = await ReportsEventCacheService.loadFromCache();
    
    if (cachedData != null && cachedData.isNotEmpty) {
      print("✅ Loaded ${cachedData.length} events from cache");
      setState(() {
        allEvents = cachedData;
        isLoading = false;
      });
      return;
    }

    // Cache miss - fetch from Firestore
    print('⏳ Cache miss - fetching from Firestore...');
    
    setState(() {
      isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("❌ No Firebase user");
      setState(() {
        isLoading = false;
      });
      return;
    }

    final userId = user.uid;
    print("🔥 Firebase UID: $userId");

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
        setState(() => isLoading = false);
        return;
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

    if (allBoards.isEmpty) {
      setState(() {
        allEvents = [];
        isLoading = false;
      });
      return;
    }

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
    List<Map<String, dynamic>> events = [];

    for (var boardData in allBoards) {
      final boardAdsId = boardData["BoardAdsId"];
      final adsData = adsMap[boardAdsId];

      if (adsData != null) {
        // ✅ Parse event date (handle both migrated and new formats)
        final dateString = boardData["BoardDateTime"]?.toString();
        DateTime? parsedDate;

        if (dateString != null) {
          // First try ISO / migrated format
          parsedDate = DateTime.tryParse(dateString);

          if (parsedDate == null) {
            try {
              // Then try new user format (with slashes)
              parsedDate = DateFormat("d/M/yyyy HH:mm").parse(dateString);
            } catch (e) {
              print("⚠️ Could not parse date in any format: $dateString");
            }
          }
        }

        if (parsedDate != null) {
          // Safely parse viewed as int
          final viewedStr = adsData["Viewed"]?.toString() ?? "0";
          final attendance = int.tryParse(viewedStr) ?? 0;

          events.add({
            "title": adsData["Title"] ?? "Untitled",
            "date": parsedDate,
            "attendance": attendance,
            "isOnline": (adsData["LiveBroadcastLink"] != null &&
                adsData["LiveBroadcastLink"].toString().isNotEmpty),
          });
        }
      }
    }

    print("✅ Built ${events.length} events in memory");

    // ✅ Save to cache
    await ReportsEventCacheService.saveToCache(events);

    setState(() {
      allEvents = events;
      isLoading = false;
    });

    print("🎉 Total user events fetched: ${events.length}");
  } catch (e) {
    print("❌ Error fetching events: $e");
    setState(() {
      isLoading = false;
    });
  }
}

  Map<String, dynamic> calculateStats() {
    final totalEvents = allEvents.length;

    final totalAttendees = allEvents.fold<int>(
      0,
      (sum, event) => sum + (event["attendance"] as int),
    );

    final averageAttendance = totalEvents > 0
        ? (totalAttendees / totalEvents).round()
        : 0;

    // Growth Rate: compare thisMonth vs lastMonth
    final now = DateTime.now();
    final thisMonthCount = allEvents.where((event) {
      final date = event["date"] as DateTime;
      return date.year == now.year && date.month == now.month;
    }).length;

    final lastMonth = DateTime(now.year, now.month - 1);
    final lastMonthCount = allEvents.where((event) {
      final date = event["date"] as DateTime;
      return date.year == lastMonth.year && date.month == lastMonth.month;
    }).length;

    double growthRate = 0;
    if (lastMonthCount > 0) {
      growthRate = ((thisMonthCount - lastMonthCount) / lastMonthCount) * 100;
    } else if (thisMonthCount > 0) {
      growthRate = 100; // if no events last month but some this month
    }

    // Distribution
    final inPersonCount = allEvents
        .where((event) => event["isOnline"] == false)
        .length;
    final onlineCount = allEvents
        .where((event) => event["isOnline"] == true)
        .length;

    return {
      "totalEvents": totalEvents,
      "totalAttendees": totalAttendees,
      "averageAttendance": averageAttendance,
      "growthRate": growthRate,
      "inPerson": inPersonCount,
      "online": onlineCount,
    };
  }

  @override
  void initState() {
    super.initState();
    fetchEvents();
  }

  @override
  Widget build(BuildContext context) {
    final texts = getTexts();
    final String? currentRoute = ModalRoute.of(context)?.settings.name;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Directionality(
      textDirection: language == 'ar'
          ? ui.TextDirection.rtl
          : ui.TextDirection.ltr,
      child: Scaffold(
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
                      selected: currentRoute == '/dashboard',
                      selectedTileColor: darkMode
                          ? DesertColors.primaryGoldDark
                          : DesertColors.maroon,
                      title: Text(
                        language == 'ar' ? 'لوحة التحكم' : 'Dashboard',
                        style: TextStyle(
                          color: currentRoute == '/dashboard'
                              ? (darkMode
                                    ? DesertColors.lightText
                                    : Colors.white)
                              : (darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText),
                        ),
                      ),
                      onTap: () => Navigator.pushNamed(context, '/dashboard'),
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

                    // ✅ Reports Tile
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 20,
                      ), // reduce tile width
                      child: GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/reports'),
                        child: Container(
                          decoration: BoxDecoration(
                            color: currentRoute == '/reports'
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
                                language == 'ar' ? 'التقارير' : 'Reports',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: currentRoute == '/reports'
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
                  onLanguageToggle: toggleLanguage,
                  onThemeToggle: toggleDarkMode,
                  fullName: fullName,
                  openDrawer: () => Scaffold.of(context).openEndDrawer(),
                );
              },
            ),
           Expanded(
  child: RefreshIndicator(
    onRefresh: () async {
      await ReportsEventCacheService.clearCache();
      await fetchEvents();
    },
    child: SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 20 : 40),
      child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      texts['title']!,
                      style: TextStyle(
                        fontSize: isMobile ? 28 : 32,
                        fontWeight: FontWeight.bold,
                        color: darkMode
                            ? DesertColors.darkText
                            : DesertColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      texts['subtitle']!,
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        color:
                            (darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText)
                                .withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Stats Cards - Mobile: Swipable Carousel, Desktop: Row
                    if (isMobile)
                      _buildMobileStatsCarousel(texts)
                    else
                      _buildDesktopStatsRow(texts),

                    const SizedBox(height: 40),

                    // Filter Controls - Mobile: Scrollable, Desktop: Wrap
                    _buildFilterSection(isMobile),

                    const SizedBox(height: 24),

                    // Single Full-Width Events Section
                    _buildAllEventsSection(
                      title: texts['allEvents']!,
                      subtitle: texts['allEventsSubtitle']!,
                      isMobile: isMobile,
                    ),

                    const SizedBox(height: 32),

                    // Event Type Distribution
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isMobile ? 20 : 24),
                      decoration: BoxDecoration(
                        color: darkMode
                            ? DesertColors.darkSurface
                            : DesertColors.lightSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              (darkMode
                                      ? DesertColors.darkText
                                      : DesertColors.lightText)
                                  .withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            texts['eventDistribution']!,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            texts['eventDistributionSubtitle']!,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  (darkMode
                                          ? DesertColors.darkText
                                          : DesertColors.lightText)
                                      .withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDistributionCard(
                                  title: texts['inPerson']!,
                                  value: calculateStats()['inPerson']
                                      .toString(),
                                  icon: Icons.location_on,
                                  color: DesertColors.primaryGoldDark,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDistributionCard(
                                  title: texts['online']!,
                                  value: calculateStats()['online'].toString(),
                                  icon: Icons.public,
                                  color: DesertColors.camelSand,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
           ),
          ],
        ),
        bottomNavigationBar: isMobile ? _buildMobileBottomNav(context) : null,
      ),
    );
  }

  Widget _buildMobileStatsCarousel(Map<String, String> texts) {
    final statsData = calculateStats();
    final List<Map<String, dynamic>> stats = [
      {
        'title': texts['totalEvents']!,
        'value': statsData['totalEvents'].toString(),
        'icon': Icons.calendar_today,
        'color': DesertColors.primaryGoldDark,
      },
      {
        'title': texts['totalAttendees']!,
        'value': statsData['totalAttendees'].toString(),
        'icon': Icons.people_outline,
        'color': DesertColors.camelSand,
      },
      {
        'title': texts['averageAttendance']!,
        'value': statsData['averageAttendance'].toString(),
        'icon': Icons.bar_chart,
        'color': DesertColors.crimson,
      },
      {
        'title': texts['growthRate']!,
        'value': '${statsData['growthRate'].toStringAsFixed(1)}%',
        'icon': Icons.trending_up,
        'color': Colors.green,
      },
    ];

    return Container(
      height: 140,
      child: PageView.builder(
        itemCount: stats.length,
        controller: PageController(viewportFraction: 0.85),
        itemBuilder: (context, index) {
          final stat = stats[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: _buildStatCard(
              title: stat['title'],
              value: stat['value'],
              icon: stat['icon'],
              iconColor: stat['color'],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopStatsRow(Map<String, String> texts) {
    final statsData = calculateStats();
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: texts['totalEvents']!,
            value: statsData['totalEvents'].toString(),
            icon: Icons.calendar_today,
            iconColor: DesertColors.primaryGoldDark,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: texts['totalAttendees']!,
            value: statsData['totalAttendees'].toString(),
            icon: Icons.people_outline,
            iconColor: DesertColors.camelSand,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: texts['averageAttendance']!,
            value: statsData['averageAttendance'].toString(),
            icon: Icons.bar_chart,
            iconColor: DesertColors.crimson,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: texts['growthRate']!,
            value: '${statsData['growthRate'].toStringAsFixed(1)}%',
            icon: Icons.trending_up,
            iconColor: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection(bool isMobile) {
    final texts = getTexts();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : DesertColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
              .withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            texts['sortBy']!,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
          ),
          const SizedBox(height: 16),
          if (isMobile)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    label: texts['latest']!,
                    value: 'latest',
                    icon: Icons.access_time,
                  ),
                  const SizedBox(width: 12),
                  _buildFilterChip(
                    label: texts['thisMonth']!,
                    value: 'thisMonth',
                    icon: Icons.calendar_month,
                  ),
                  const SizedBox(width: 12),
                  _buildFilterChip(
                    label: texts['lastMonth']!,
                    value: 'lastMonth',
                    icon: Icons.calendar_today,
                  ),
                  const SizedBox(width: 12),
                  _buildCustomMonthChip(),
                ],
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildFilterChip(
                  label: texts['latest']!,
                  value: 'latest',
                  icon: Icons.access_time,
                ),
                _buildFilterChip(
                  label: texts['thisMonth']!,
                  value: 'thisMonth',
                  icon: Icons.calendar_month,
                ),
                _buildFilterChip(
                  label: texts['lastMonth']!,
                  value: 'lastMonth',
                  icon: Icons.calendar_today,
                ),
                _buildCustomMonthChip(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = selectedFilter == value;

    return GestureDetector(
      onTap: () => onFilterChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? DesertColors.primaryGoldDark
              : (darkMode
                    ? DesertColors.darkBackground
                    : DesertColors.lightBackground),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? DesertColors.primaryGoldDark
                : (darkMode ? DesertColors.darkText : DesertColors.lightText)
                      .withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (darkMode ? DesertColors.darkText : DesertColors.lightText)
                        .withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : (darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomMonthChip() {
    final texts = getTexts();
    final isSelected = selectedFilter == 'custom';
    final displayText = isSelected && customSelectedMonth != null
        ? getCustomMonthText()
        : texts['customMonth']!;

    return GestureDetector(
      onTap: showCustomMonthPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? DesertColors.primaryGoldDark
              : (darkMode
                    ? DesertColors.darkBackground
                    : DesertColors.lightBackground),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? DesertColors.primaryGoldDark
                : (darkMode ? DesertColors.darkText : DesertColors.lightText)
                      .withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (darkMode ? DesertColors.darkText : DesertColors.lightText)
                        .withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            Text(
              displayText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : (darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : DesertColors.lightSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
              .withOpacity(0.1),
        ),
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
                    fontSize: 14,
                    color:
                        (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText)
                            .withOpacity(0.7),
                  ),
                ),
              ),
              Icon(icon, color: iconColor, size: 20),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllEventsSection({
    required String title,
    required String subtitle,
    required bool isMobile,
  }) {
    final filteredEvents = getFilteredEvents();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : DesertColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
              .withOpacity(0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // 👈 Important
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
                  .withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),

          if (isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: darkMode
                      ? DesertColors.darkText
                      : DesertColors.lightText,
                ),
              ),
            )
          else if (filteredEvents.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  language == 'ar'
                      ? 'لا توجد أحداث في هذه الفترة'
                      : 'No events found for this period',
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText)
                            .withOpacity(0.6),
                  ),
                ),
              ),
            )
          else
            GridView.count(
              shrinkWrap: true, // 👈 Let grid size itself
              physics:
                  const NeverScrollableScrollPhysics(), // 👈 Prevent scroll conflicts
              crossAxisCount: isMobile ? 1 : 2,
              crossAxisSpacing: isMobile ? 0 : 20,
              mainAxisSpacing: 16,
              childAspectRatio: isMobile ? 3 : 4,
              children: filteredEvents.map((event) {
                return _buildEventItem(
                  name: event['title'],
                  date:
                      '${event['date'].year}-${event['date'].month.toString().padLeft(2, '0')}-${event['date'].day.toString().padLeft(2, '0')}',
                  attendance: event['attendance'].toString(),
                  isOnline: event['isOnline'],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEventItem({
    required String name,
    required String date,
    required String attendance,
    required bool isOnline,
  }) {
    final texts = getTexts();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkMode
            ? DesertColors.darkBackground
            : DesertColors.lightBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
              .withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isOnline
                  ? DesertColors.camelSand
                  : DesertColors.primaryGoldDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isOnline ? Icons.public : Icons.location_on,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            (darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText)
                                .withOpacity(0.6),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isOnline
                            ? DesertColors.camelSand
                            : DesertColors.primaryGoldDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isOnline ? 'Online' : texts['offline']!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people,
                size: 16,
                color:
                    (darkMode ? DesertColors.darkText : DesertColors.lightText)
                        .withOpacity(0.6),
              ),
              const SizedBox(height: 4),
              Text(
                attendance,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: darkMode
                      ? DesertColors.darkText
                      : DesertColors.lightText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkMode
            ? DesertColors.darkBackground
            : DesertColors.lightBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
                  .withOpacity(0.7),
            ),
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
