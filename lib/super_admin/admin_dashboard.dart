import 'package:flutter/material.dart';
import 'package:alraya_app/alrayah.dart';
import 'admin_navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';


// Add these classes right after your imports and before AdminDashboardPage class

class DashboardCache {
  static final DashboardCache _instance = DashboardCache._internal();
  factory DashboardCache() => _instance;
  DashboardCache._internal();

  // Cache storage
  int? _weeklyVisitors;
  int? _weeklyActiveEvents;
  int? _weeklyBooks;
  List<ActivityItem>? _activities;
  int? _pendingEvents;
  
  // Timestamps for cache expiry (5 minutes)
  DateTime? _visitorsTimestamp;
  DateTime? _eventsTimestamp;
  DateTime? _booksTimestamp;
  DateTime? _activitiesTimestamp;
  DateTime? _pendingTimestamp;

  final Duration _cacheExpiry = Duration(minutes: 5);

  bool _isCacheValid(DateTime? timestamp) {
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  // Getters with cache validation
  int? get weeklyVisitors => _isCacheValid(_visitorsTimestamp) ? _weeklyVisitors : null;
  int? get weeklyActiveEvents => _isCacheValid(_eventsTimestamp) ? _weeklyActiveEvents : null;
  int? get weeklyBooks => _isCacheValid(_booksTimestamp) ? _weeklyBooks : null;
  List<ActivityItem>? get activities => _isCacheValid(_activitiesTimestamp) ? _activities : null;
  int? get pendingEvents => _isCacheValid(_pendingTimestamp) ? _pendingEvents : null;

  // Setters
  void setWeeklyVisitors(int value) {
    _weeklyVisitors = value;
    _visitorsTimestamp = DateTime.now();
  }

  void setWeeklyActiveEvents(int value) {
    _weeklyActiveEvents = value;
    _eventsTimestamp = DateTime.now();
  }

  void setWeeklyBooks(int value) {
    _weeklyBooks = value;
    _booksTimestamp = DateTime.now();
  }

  void setActivities(List<ActivityItem> value) {
    _activities = value;
    _activitiesTimestamp = DateTime.now();
  }

  void setPendingEvents(int value) {
    _pendingEvents = value;
    _pendingTimestamp = DateTime.now();
  }

  void clearAll() {
    _weeklyVisitors = null;
    _weeklyActiveEvents = null;
    _weeklyBooks = null;
    _activities = null;
    _pendingEvents = null;
    _visitorsTimestamp = null;
    _eventsTimestamp = null;
    _booksTimestamp = null;
    _activitiesTimestamp = null;
    _pendingTimestamp = null;
  }
}


class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool darkMode = false;
  String language = 'en';
  String currentPage = 'Dashboard';
  String fullName = 'Admin User';

  Map<String, String> get translations => {
    'welcome': language == 'ar'
        ? 'مرحباً بكم في لوحة تحكم المشرف'
        : 'Welcome to Admin Dashboard',
    'system_overview': language == 'ar'
        ? 'نظرة عامة على النظام'
        : 'System Overview',
    'total_users': language == 'ar' ? 'إجمالي المستخدمين' : 'Total Users',
    'active_events': language == 'ar' ? 'الأحداث النشطة' : 'Active Events',
    'published_books': language == 'ar' ? 'الكتب المنشورة' : 'Published Books',
    'publications': language == 'ar' ? 'المنشورات' : 'Publications',
    'this_week': language == 'ar' ? 'هذا الأسبوع' : 'This Week',
    'recent_activity': language == 'ar' ? 'النشاط الحديث' : 'Recent Activity',
    'pending_approvals': language == 'ar'
        ? 'الموافقات المعلقة'
        : 'Pending Approvals',
    'events': language == 'ar' ? 'أحداث' : 'events',
    'books': language == 'ar' ? 'كتب' : 'books',
    'publications_lower': language == 'ar' ? 'منشورات' : 'publications',
  };

Stream<int> getWeeklyVisitors() {
  final cache = DashboardCache();
  
  // Return cached value immediately if available
  if (cache.weeklyVisitors != null) {
    return Stream.value(cache.weeklyVisitors!);
  }

  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final weekEnd = weekStart.add(const Duration(days: 6));

  return FirebaseFirestore.instance
      .collection("daily_stats")
      .get() // ✅ Get all documents at once, not snapshots
      .asStream()
      .map((snapshot) {
    int total = 0;
    // Process all docs in memory
    for (var doc in snapshot.docs) {
      try {
        final date = DateTime.parse(doc.id);
        if (date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
            date.isBefore(weekEnd.add(const Duration(days: 1)))) {
          total += (doc['visitors'] ?? 0) as int;
        }
      } catch (e) {
        print("⚠️ Failed to parse date: ${doc.id}");
      }
    }
    // Cache the result
    cache.setWeeklyVisitors(total);
    return total;
  });
}

Stream<int> getWeeklyActiveEvents() {
  final cache = DashboardCache();
  
  if (cache.weeklyActiveEvents != null) {
    return Stream.value(cache.weeklyActiveEvents!);
  }

  final now = DateTime.now();
  final weekStart = DateTime(
    now.year,
    now.month,
    now.day - (now.weekday - 1),
    0, 0, 0,
  );
  final weekEnd = weekStart.add(
    const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
  );

  final formatter = DateFormat("d/M/yyyy HH:mm");

  return FirebaseFirestore.instance
      .collection("tblboards")
      .where("IsDeleted", isEqualTo: "False")
      .get() // ✅ Single query instead of snapshots
      .asStream()
      .map((snapshot) {
    int count = 0;

    // Process all docs in memory
    for (var doc in snapshot.docs) {
      dynamic rawDate = doc.data()['BoardDateTime'];
      DateTime? date;

      if (rawDate is Timestamp) {
        date = rawDate.toDate();
      } else if (rawDate is String) {
        try {
          date = formatter.parse(rawDate);
        } catch (e) {
          continue;
        }
      }

      if (date != null &&
          date.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
          date.isBefore(weekEnd.add(const Duration(seconds: 1)))) {
        count++;
      }
    }

    cache.setWeeklyActiveEvents(count);
    return count;
  });
}

Stream<int> getWeeklyBooks() {
  final cache = DashboardCache();
  
  if (cache.weeklyBooks != null) {
    return Stream.value(cache.weeklyBooks!);
  }

  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final weekEnd = weekStart.add(const Duration(days: 6));

  return FirebaseFirestore.instance
      .collection("tblbooks")
      .where("IsDeleted", isEqualTo: "False")
      .get() // ✅ Single query
      .asStream()
      .map((snapshot) {
    int count = 0;
    
    for (var doc in snapshot.docs) {
      try {
        final date = DateTime.parse(doc.data()['CreatedAt']);
        if (date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
            date.isBefore(weekEnd.add(const Duration(days: 1)))) {
          count++;
        }
      } catch (e) {
        print("⚠️ Failed to parse CreatedAt: ${doc.id}");
      }
    }
    
    cache.setWeeklyBooks(count);
    return count;
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

  Stream<List<ActivityItem>> getRecentActivities() {
    final now = DateTime.now();
    // Get Monday of current week at 00:00:00
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1),
      0,
      0,
      0,
    );

    return FirebaseFirestore.instance
        .collection("admin_notifications")
        .orderBy("timestamp", descending: true)
        .snapshots()
        .map((snapshot) {
          List<ActivityItem> activities = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            DateTime? notificationTime;

            // Parse timestamp
            final timestampValue = data['timestamp'];
            if (timestampValue is Timestamp) {
              notificationTime = timestampValue.toDate();
            } else if (timestampValue is String) {
              try {
                notificationTime = DateTime.parse(timestampValue);
              } catch (e) {
                continue; // Skip invalid dates
              }
            }

            // Check if within current week
            if (notificationTime == null ||
                notificationTime.isBefore(weekStart)) {
              continue;
            }

            final type = data['type'] ?? '';
            IconData icon;
            Color iconColor;
            String status = 'New';
            String statusAr = 'جديد';
            Color statusColor = DesertColors.camelSand;

            switch (type) {
              case 'new_event':
                icon = Icons.event_note;
                iconColor = DesertColors.primaryGoldDark;
                status = 'Pending';
                statusAr = 'قيد الانتظار';
                statusColor = DesertColors.crimson;
                break;
              case 'new_user':
                icon = Icons.person_add_alt_1;
                iconColor = DesertColors.maroon;
                status = 'Registered';
                statusAr = 'مسجل';
                statusColor = Colors.green;
                break;
              default:
                icon = Icons.notifications_active;
                iconColor = DesertColors.camelSand;
            }

            activities.add(
              ActivityItem(
                title: data['message'] ?? 'New notification',
                titleAr: data['message'] ?? 'إشعار جديد',
                time: _calculateTimeAgo(timestampValue),
                timeAr: _calculateTimeAgo(timestampValue),
                status: status,
                statusAr: statusAr,
                statusColor: statusColor,
                icon: icon,
                iconColor: iconColor,
              ),
            );
          }

          return activities;
        });
  }

Stream<List<ActivityItem>> getCombinedActivities() {
  final cache = DashboardCache();
  
  if (cache.activities != null) {
    return Stream.value(cache.activities!);
  }

  final now = DateTime.now();
  final weekStart = DateTime(
    now.year,
    now.month,
    now.day - (now.weekday - 1),
    0, 0, 0,
  );
  final weekEnd = weekStart.add(
    const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
  );

  final formatter = DateFormat("d/M/yyyy HH:mm");

  // ✅ Fetch ALL data in parallel using Future.wait
  return Stream.fromFuture(
    Future.wait([
      FirebaseFirestore.instance
          .collection("admin_notifications")
          .orderBy("timestamp", descending: true)
          .limit(50) // Limit for performance
          .get(),
      FirebaseFirestore.instance
          .collection("tblboards")
          .where("IsDeleted", isEqualTo: "False")
          .get(),
      FirebaseFirestore.instance
          .collection("tblboardads")
          .get(), // Get all ads at once
    ]).then((results) async {
      List<ActivityItem> activities = [];
      
      final notificationsSnapshot = results[0];
      final boardsSnapshot = results[1];
      final adsSnapshot = results[2];

      // Create a map of boardAdsId -> Title for fast lookup
      Map<String, String> adsTitleMap = {};
      for (var doc in adsSnapshot.docs) {
        adsTitleMap[doc.id] = doc.data()['Title'] ?? 'Scheduled Event';
      }

      // Process user notifications
      for (var doc in notificationsSnapshot.docs) {
        final data = doc.data();
        if (data['type'] == 'daily_visitors') continue;

        DateTime? notificationTime;
        final timestampValue = data['timestamp'];
        
        if (timestampValue is Timestamp) {
          notificationTime = timestampValue.toDate();
        } else if (timestampValue is String) {
          try {
            notificationTime = DateTime.parse(timestampValue);
          } catch (e) {
            continue;
          }
        }

        if (notificationTime == null || notificationTime.isBefore(weekStart)) {
          continue;
        }

        activities.add(
          ActivityItem(
            title: data['message'] ?? 'New notification',
            titleAr: data['message'] ?? 'إشعار جديد',
            time: _calculateTimeAgo(timestampValue),
            timeAr: _calculateTimeAgo(timestampValue),
            status: 'Registered',
            statusAr: 'مسجل',
            statusColor: Colors.green,
            icon: Icons.person_add_alt_1,
            iconColor: DesertColors.maroon,
          ),
        );
      }

      // Process events (already in memory, no more queries)
      for (var boardDoc in boardsSnapshot.docs) {
        dynamic rawDate = boardDoc.data()['BoardDateTime'];
        DateTime? eventDate;

        if (rawDate is Timestamp) {
          eventDate = rawDate.toDate();
        } else if (rawDate is String) {
          try {
            eventDate = formatter.parse(rawDate);
          } catch (e) {
            continue;
          }
        }

        if (eventDate == null ||
            eventDate.isBefore(weekStart) ||
            eventDate.isAfter(weekEnd)) {
          continue;
        }

        // ✅ Fast lookup from map instead of database query
        final boardAdsId = boardDoc.data()['BoardAdsId'];
        String eventTitle = adsTitleMap[boardAdsId] ?? 'Scheduled Event';

        final timeUntil = eventDate.difference(now);
        String timeText;
        
        if (timeUntil.isNegative) {
          timeText = language == 'ar' ? 'انتهى' : 'Completed';
        } else if (timeUntil.inDays > 0) {
          timeText = language == 'ar'
              ? 'بعد ${timeUntil.inDays} يوم'
              : 'In ${timeUntil.inDays} day${timeUntil.inDays > 1 ? 's' : ''}';
        } else if (timeUntil.inHours > 0) {
          timeText = language == 'ar'
              ? 'بعد ${timeUntil.inHours} ساعة'
              : 'In ${timeUntil.inHours} hour${timeUntil.inHours > 1 ? 's' : ''}';
        } else {
          timeText = language == 'ar' ? 'قريباً' : 'Soon';
        }

        activities.add(
          ActivityItem(
            title: 'Event: $eventTitle',
            titleAr: 'حدث: $eventTitle',
            time: timeText,
            timeAr: timeText,
            status: 'Scheduled',
            statusAr: 'مجدول',
            statusColor: DesertColors.primaryGoldDark,
            icon: Icons.event_note,
            iconColor: DesertColors.camelSand,
          ),
        );
      }

      // Cache and return
      cache.setActivities(activities);
      return activities;
    }),
  );
}
  // 🔹 Helper to calculate "time ago"
  String _calculateTimeAgo(dynamic timestamp) {
    try {
      DateTime notificationTime;

      if (timestamp is Timestamp) {
        notificationTime = timestamp.toDate();
      } else if (timestamp is String) {
        notificationTime = DateTime.parse(timestamp);
      } else {
        return language == 'ar' ? 'الآن' : 'Just now';
      }

      final difference = DateTime.now().difference(notificationTime);

      if (difference.inMinutes < 1) {
        return language == 'ar' ? 'الآن' : 'Just now';
      }
      if (difference.inMinutes < 60) {
        return language == 'ar'
            ? 'منذ ${difference.inMinutes} دقيقة'
            : '${difference.inMinutes} min ago';
      }
      if (difference.inHours < 24) {
        return language == 'ar'
            ? 'منذ ${difference.inHours} ساعة'
            : '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      }
      return language == 'ar'
          ? 'منذ ${difference.inDays} يوم'
          : '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } catch (e) {
      return language == 'ar' ? 'مؤخراً' : 'Recently';
    }
  }

Stream<int> getPendingEventsCount() {
  final cache = DashboardCache();
  
  if (cache.pendingEvents != null) {
    return Stream.value(cache.pendingEvents!);
  }

  return FirebaseFirestore.instance
      .collection("tblboardads")
      .where("IsDeleted", isEqualTo: "False")
      .where("status", isEqualTo: "Pending")
      .get() // ✅ Single query
      .asStream()
      .map((snapshot) {
    final count = snapshot.docs.length;
    cache.setPendingEvents(count);
    return count;
  });
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
    final bool isMobile = MediaQuery.of(context).size.width < 768;
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

                  // ✅ Navigation Tiles
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 20,
                    ), // reduce tile width
                    child: GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, '/admin_dashboard'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: currentRoute == '/admin_dashboard'
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
                                color: currentRoute == '/admin_dashboard'
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

                  // ✅ Events Tile
                  ListTile(
                    selected: currentRoute == '/events',
                    selectedTileColor: darkMode
                        ? DesertColors.primaryGoldDark
                        : DesertColors.maroon,
                    title: Text(
                      language == 'ar' ? 'الفعاليات' : 'Events',
                      style: TextStyle(
                        color: currentRoute == '/events'
                            ? (darkMode ? DesertColors.lightText : Colors.white)
                            : (darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText),
                      ),
                    ),
                    onTap: () => Navigator.pushNamed(context, '/events'),
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
                          DashboardCache().clearAll();
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildStatsGrid(),
                  const SizedBox(height: 32),
                  _buildActivitySection(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildMobileBottomNav(context) : null,
    );
  }


  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        
        return Column(
          crossAxisAlignment: language == 'ar'
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              translations['welcome']!,
              style: TextStyle(
                fontSize: isMobile ? 20 : 28,
                fontWeight: FontWeight.bold,
                color: darkMode ? DesertColors.darkText : DesertColors.lightText,
              ),
              textAlign: language == 'ar' ? TextAlign.right : TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              translations['system_overview']!,
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
                    .withOpacity(0.7),
              ),
              textAlign: language == 'ar' ? TextAlign.right : TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        if (isMobile) {
          return Column(
            children: [
              StreamBuilder<int>(
                stream: getWeeklyVisitors(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: _buildStatCard(
                      title: translations['total_users']!,
                      value: snapshot.data.toString(),
                      change: '+12.5%',
                      changeText: translations['this_week']!,
                      icon: Icons.people_outline,
                      color: DesertColors.primaryGoldDark,
                    ),
                  );
                },
              ),
              StreamBuilder<int>(
                stream: getWeeklyActiveEvents(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: _buildStatCard(
                      title: translations['active_events']!,
                      value: snapshot.data.toString(),
                      change: '+3',
                      changeText: translations['this_week']!,
                      icon: Icons.event_outlined,
                      color: DesertColors.camelSand,
                    ),
                  );
                },
              ),
              StreamBuilder<int>(
                stream: getWeeklyBooks(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: _buildStatCard(
                      title: translations['published_books']!,
                      value: snapshot.data.toString(),
                      change: '+8',
                      changeText: translations['this_week']!,
                      icon: Icons.book_outlined,
                      color: DesertColors.crimson,
                    ),
                  );
                },
              ),
              _buildStatCard(
                title: translations['publications']!,
                value: '89',
                change: '+5',
                changeText: translations['this_week']!,
                icon: Icons.article_outlined,
                color: DesertColors.maroon,
              ),
            ],
          );
        }

        final crossAxisCount = 4;
        final childAspectRatio = 1.5;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: childAspectRatio,
          children: [
            StreamBuilder<int>(
              stream: getWeeklyVisitors(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                return _buildStatCard(
                  title: translations['total_users']!,
                  value: snapshot.data.toString(),
                  change: '+12.5%',
                  changeText: translations['this_week']!,
                  icon: Icons.people_outline,
                  color: DesertColors.primaryGoldDark,
                );
              },
            ),
            StreamBuilder<int>(
              stream: getWeeklyActiveEvents(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                return _buildStatCard(
                  title: translations['active_events']!,
                  value: snapshot.data.toString(),
                  change: '+3',
                  changeText: translations['this_week']!,
                  icon: Icons.event_outlined,
                  color: DesertColors.camelSand,
                );
              },
            ),
            StreamBuilder<int>(
              stream: getWeeklyBooks(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                return _buildStatCard(
                  title: translations['published_books']!,
                  value: snapshot.data.toString(),
                  change: '+8',
                  changeText: translations['this_week']!,
                  icon: Icons.book_outlined,
                  color: DesertColors.crimson,
                );
              },
            ),
            _buildStatCard(
              title: translations['publications']!,
              value: '89',
              change: '+5',
              changeText: translations['this_week']!,
              icon: Icons.article_outlined,
              color: DesertColors.maroon,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String change,
    required String changeText,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : DesertColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: language == 'ar'
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (language == 'en') Icon(icon, color: color, size: 24),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color:
                      (darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText)
                          .withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (language == 'ar') Icon(icon, color: color, size: 24),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.trending_up, color: Colors.green, size: 16),
              const SizedBox(width: 4),
              Text(
                change,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                changeText,
                style: TextStyle(
                  color:
                      (darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText)
                          .withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        if (isMobile) {
          return Column(
            children: [
              _buildRecentActivity(),
              const SizedBox(height: 24),
              _buildPendingApprovals(),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildRecentActivity()),
            const SizedBox(width: 24),
            Expanded(child: _buildPendingApprovals()),
          ],
        );
      },
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(24),
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
              Text(
                translations['recent_activity']!,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkMode
                      ? DesertColors.darkText
                      : DesertColors.lightText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: DesertColors.camelSand.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule, size: 14, color: DesertColors.maroon),
                    const SizedBox(width: 4),
                    Text(
                      translations['this_week']!,
                      style: TextStyle(
                        fontSize: 12,
                        color: DesertColors.maroon,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          StreamBuilder<List<ActivityItem>>(
            stream: getCombinedActivities(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(
                      color: darkMode
                          ? DesertColors.camelSand
                          : DesertColors.maroon,
                      strokeWidth: 2.5,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 48,
                          color:
                              (darkMode
                                      ? DesertColors.darkText
                                      : DesertColors.lightText)
                                  .withOpacity(0.3),
                        ),
                        SizedBox(height: 12),
                        Text(
                          language == 'ar'
                              ? 'لا توجد أنشطة هذا الأسبوع'
                              : 'No activities this week',
                          style: TextStyle(
                            color:
                                (darkMode
                                        ? DesertColors.darkText
                                        : DesertColors.lightText)
                                    .withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: snapshot.data!
                    .map((activity) => _buildActivityItem(activity))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(ActivityItem activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (darkMode ? DesertColors.darkBackground : Colors.white)
            .withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activity.iconColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: activity.iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(activity.icon, color: activity.iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  language == 'ar' ? activity.titleAr : activity.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  language == 'ar' ? activity.timeAr : activity.time,
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
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: activity.statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              language == 'ar' ? activity.statusAr : activity.status,
              style: TextStyle(
                fontSize: 12,
                color: activity.statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovals() {
    return Container(
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        minHeight: 180, // Ensures minimum height
      ),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            translations['pending_approvals']!,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
          ),
          const SizedBox(height: 24),
          StreamBuilder<int>(
            stream: getPendingEventsCount(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(
                      color: darkMode
                          ? DesertColors.camelSand
                          : DesertColors.maroon,
                      strokeWidth: 2,
                    ),
                  ),
                );
              }

              final count = snapshot.data ?? 0;

              if (count == 0) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        DesertColors.primaryGoldDark.withOpacity(0.1),
                        DesertColors.primaryGoldDark.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: DesertColors.primaryGoldDark.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 48,
                        color: Colors.green.withOpacity(0.6),
                      ),
                      SizedBox(height: 12),
                      Text(
                        language == 'ar'
                            ? 'لا توجد موافقات معلقة'
                            : 'No Pending Approvals',
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              (darkMode
                                      ? DesertColors.darkText
                                      : DesertColors.lightText)
                                  .withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return _buildApprovalCard(
                count.toString(),
                translations['events']!,
                DesertColors.primaryGoldDark,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalCard(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
                  .withOpacity(0.7),
              fontWeight: FontWeight.w500,
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

class ActivityItem {
  final String title;
  final String titleAr;
  final String time;
  final String timeAr;
  final String status;
  final String statusAr;
  final Color statusColor;
  final IconData icon;
  final Color iconColor;

  ActivityItem({
    required this.title,
    required this.titleAr,
    required this.time,
    required this.timeAr,
    required this.status,
    required this.statusAr,
    required this.statusColor,
    required this.icon,
    required this.iconColor,
  });
}
