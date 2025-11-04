import 'package:flutter/material.dart';
import 'package:alraya_app/alrayah.dart';
import 'admin_navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'dart:convert'; // add in pubspec.yaml
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:alraya_app/notification_service.dart';

// Add after imports, before VisitorService class
class UserAnalyticsCache {
  static int? _totalUsers;
  static int? _activeUsers;
  static int? _newUsers;
  static int? _avgUsersPerDay;
  static Map<String, int>? _userDistribution;
  static int? _registrationsThisWeek;
  static int? _eventViewsThisWeek;
  static DateTime? _lastFetch;

  static bool get isCacheValid {
    if (_lastFetch == null) return false;
    return DateTime.now().difference(_lastFetch!) < Duration(minutes: 5);
  }

  static void clearCache() {
    _totalUsers = null;
    _activeUsers = null;
    _newUsers = null;
    _avgUsersPerDay = null;
    _userDistribution = null;
    _registrationsThisWeek = null;
    _eventViewsThisWeek = null;
    _lastFetch = null;
  }

  static void updateCache({
    int? total,
    int? active,
    int? newU,
    int? avg,
    Map<String, int>? distribution,
    int? registrations,
    int? eventViews,
  }) {
    _totalUsers = total ?? _totalUsers;
    _activeUsers = active ?? _activeUsers;
    _newUsers = newU ?? _newUsers;
    _avgUsersPerDay = avg ?? _avgUsersPerDay;
    _userDistribution = distribution ?? _userDistribution;
    _registrationsThisWeek = registrations ?? _registrationsThisWeek;
    _eventViewsThisWeek = eventViews ?? _eventViewsThisWeek;
    _lastFetch = DateTime.now();
  }
}

class VisitorService {
  static final _firestore = FirebaseFirestore.instance;

  static Future<void> trackVisitor() async {
    final prefs = await SharedPreferences.getInstance();
    String? visitorId = prefs.getString("visitorId");

    if (visitorId == null) {
      final deviceInfo = DeviceInfoPlugin();

      if (kIsWeb) {
        final info = await deviceInfo.webBrowserInfo;
        final rawId =
            "${info.userAgent}_${info.vendor}_${info.hardwareConcurrency}";
        visitorId = sha1.convert(utf8.encode(rawId)).toString();
      } else if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        visitorId = info.id ?? const Uuid().v4();
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        visitorId = info.identifierForVendor ?? const Uuid().v4();
      } else {
        visitorId = const Uuid().v4();
      }

      await prefs.setString("visitorId", visitorId);
      debugPrint("Generated new visitorId: $visitorId");
    } else {
      debugPrint("Loaded existing visitorId: $visitorId");
    }

    final docRef = _firestore.collection("visitors").doc(visitorId);

    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      debugPrint("New visitor doc created");
      await docRef.set({
        "firstVisit": FieldValue.serverTimestamp(),
        "lastVisit": FieldValue.serverTimestamp(),
        "visitCount": 1,
      });
    } else {
      debugPrint("Existing visitor doc updated");
      await docRef.set({
        "lastVisit": FieldValue.serverTimestamp(),
        "visitCount": FieldValue.increment(1),
      }, SetOptions(merge: true));
    }
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dailyRef = _firestore.collection("daily_stats").doc(today);

    await dailyRef.set({
      "visitors": FieldValue.increment(1),
    }, SetOptions(merge: true));

    // ✅ Notify Admin about daily visitor count
    final dailySnapshot = await dailyRef.get();
    final todayCount = dailySnapshot.data()?['visitors'] ?? 0;

    await NotificationService.notifyAdminDailyVisitors(today, todayCount);
  }
}

class DailyVisitorsChart extends StatefulWidget {
  final bool darkMode;
  const DailyVisitorsChart({super.key, required this.darkMode});

  @override
  State<DailyVisitorsChart> createState() => _DailyVisitorsChartState();
}

class _DailyVisitorsChartState extends State<DailyVisitorsChart> {
  List<Map<String, dynamic>>? _lastWeekData; // cache last good data

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1)); // Monday
    final endOfWeek = startOfWeek.add(const Duration(days: 6)); // Sunday

    final startStr = DateFormat('yyyy-MM-dd').format(startOfWeek);
    final endStr = DateFormat('yyyy-MM-dd').format(endOfWeek);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("daily_stats")
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startStr)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endStr)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _lastWeekData == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          if (_lastWeekData != null) {
            return _buildChart(_lastWeekData!);
          }
          return const Center(child: Text("No data available"));
        }

        final docs = snapshot.data!.docs;
        final docsMap = {
          for (var d in docs) d.id: d.data() as Map<String, dynamic>,
        };

        List<Map<String, dynamic>> weekData = [];
        for (int i = 0; i < 7; i++) {
          final date = startOfWeek.add(Duration(days: i));
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          final dayName = DateFormat('EEE').format(date);

          final visitors = docsMap[dateStr]?['visitors'] ?? 0;

          weekData.add({'date': dateStr, 'day': dayName, 'visitors': visitors});
        }

        _lastWeekData = weekData; // cache
        return _buildChart(weekData);
      },
    );
  }

  Widget _buildChart(List<Map<String, dynamic>> weekData) {
    final maxVisitors = weekData.isNotEmpty
        ? weekData
              .map((e) => e['visitors'] as int)
              .reduce((a, b) => a > b ? a : b)
        : 0;
    final chartMaxY = (maxVisitors * 1.2).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        maxY: chartMaxY > 0 ? chartMaxY : 100,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex < weekData.length) {
                final data = weekData[groupIndex];
                return BarTooltipItem(
                  "${data['day']}\nvisitors: ${data['visitors']}",
                  TextStyle(
                    color: widget.darkMode ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }
              return null;
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: chartMaxY > 0 ? (chartMaxY / 4) : 25,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: widget.darkMode
                          ? Colors.grey[400]
                          : Colors.grey[600],
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < weekData.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      weekData[index]['day'],
                      style: TextStyle(
                        color: widget.darkMode
                            ? Colors.grey[400]
                            : Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }
                return const Text("");
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(
              color: widget.darkMode ? Colors.grey[700]! : Colors.grey[300]!,
              width: 1,
            ),
            bottom: BorderSide(
              color: widget.darkMode ? Colors.grey[700]! : Colors.grey[300]!,
              width: 1,
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: chartMaxY > 0 ? (chartMaxY / 4) : 25,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: widget.darkMode
                  ? Colors.grey[800]!.withOpacity(0.3)
                  : Colors.grey[300]!.withOpacity(0.5),
              strokeWidth: 0.8,
            );
          },
        ),
        barGroups: weekData.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          final visitors = data['visitors'] as int;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: visitors.toDouble(),
                color: const Color(0xFFFF8C00), // Orange
                width: 32,
                borderRadius: BorderRadius.circular(3),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: chartMaxY,
                  color: widget.darkMode
                      ? Colors.grey[800]!.withOpacity(0.1)
                      : Colors.grey[200]!.withOpacity(0.3),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class UserDistributionChart extends StatelessWidget {
  final Map<String, int> data;
  final bool darkMode;
  final bool isMobile;

  UserDistributionChart(
    this.data, {
    required this.darkMode,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold(0, (a, b) => a + b);

    if (total == 0) {
      return Center(
        child: Text(
          "No user data available",
          style: TextStyle(
            color: darkMode ? DesertColors.darkText : DesertColors.lightText,
          ),
        ),
      );
    }

    if (isMobile) {
      return Column(
        children: [
          // Pie Chart centered
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: data.entries.map((entry) {
                  final percentage = (entry.value / total) * 100;
                  return PieChartSectionData(
                    value: entry.value.toDouble(),
                    title: "${percentage.toStringAsFixed(1)}%",
                    radius: 60,
                    color: _getColor(entry.key),
                    titleStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Legend below in 2x2 grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 3,
            children: data.entries.map((entry) {
              final percentage = (entry.value / total) * 100;
              final color = _getColor(entry.key);

              return Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        Text(
                          "${entry.value} (${percentage.toStringAsFixed(1)}%)",
                          style: TextStyle(
                            fontSize: 10,
                            color: darkMode
                                ? DesertColors.darkText.withOpacity(0.7)
                                : DesertColors.lightText.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      );
    }

    // Desktop layout (original)
    return Row(
      children: [
        // Pie Chart
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: data.entries.map((entry) {
                  final percentage = (entry.value / total) * 100;
                  return PieChartSectionData(
                    value: entry.value.toDouble(),
                    title: "${percentage.toStringAsFixed(1)}%",
                    radius: 60,
                    color: _getColor(entry.key),
                    titleStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        // Legend
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: data.entries.map((entry) {
              final percentage = (entry.value / total) * 100;
              final color = _getColor(entry.key);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          Text(
                            "${entry.value} (${percentage.toStringAsFixed(1)}%)",
                            style: TextStyle(
                              fontSize: 10,
                              color: darkMode
                                  ? DesertColors.darkText.withOpacity(0.7)
                                  : DesertColors.lightText.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Color _getColor(String key) {
    switch (key) {
      case "Active":
        return Color(0xFFFF8C00); // Orange
      case "Inactive":
        return Color(0xFFFFC107); // Amber
      case "EventOrganizers":
        return Color(0xFFDC143C); // Crimson
      case "New":
        return Color(0xFFFF4500); // Orange Red
      default:
        return Colors.grey;
    }
  }
}

class UserAnalyticsPage extends StatefulWidget {
  @override
  _UserAnalyticsPageState createState() => _UserAnalyticsPageState();
}

class _UserAnalyticsPageState extends State<UserAnalyticsPage> {
  bool darkMode = false;
  String language = 'en';
  String currentPage = 'User Analytics';
  String fullName = 'Admin User';

  int totalUsers = 0;
  int activeUsers = 0;
  int newUsers = 0;
  int avgUsersPerDay = 0;
  bool isLoading = true;

  int registrationsThisWeek = 0;
  int eventViewsThisWeek = 0;

  bool isDailyActivityExpanded = false;

  void onPageChange(String page) {
    setState(() {
      currentPage = page;
    });
  }

  void onLanguageToggle() {
    setState(() {
      language = language == 'en' ? 'ar' : 'en';
    });
  }

  void onThemeToggle() {
    setState(() {
      darkMode = !darkMode;
    });
  }

  Future<void> fetchAnalytics() async {
    // 🚀 Return cached data if valid
    if (UserAnalyticsCache.isCacheValid) {
      setState(() {
        totalUsers = UserAnalyticsCache._totalUsers ?? 0;
        activeUsers = UserAnalyticsCache._activeUsers ?? 0;
        newUsers = UserAnalyticsCache._newUsers ?? 0;
        avgUsersPerDay = UserAnalyticsCache._avgUsersPerDay ?? 0;
        isLoading = false;
      });
      return;
    }

    final visitors = FirebaseFirestore.instance.collection("visitors");
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    // 🚀 Fetch ALL data at once - NO sequential queries
    final totalSnapshot = await visitors.get();
    final total = totalSnapshot.docs.length;

    // 🚀 Process in memory instead of separate query
    int active = 0;
    int newU = 0;

    for (var doc in totalSnapshot.docs) {
      final data = doc.data();

      // Check active users (visited this month)
      final lastVisit = data['lastVisit'];
      if (lastVisit != null) {
        DateTime? lastVisitDate;
        if (lastVisit is Timestamp) {
          lastVisitDate = lastVisit.toDate();
        }
        if (lastVisitDate != null && lastVisitDate.isAfter(startOfMonth)) {
          active++;
        }
      }

      // Check new users (first visit this month)
      final firstVisit = data['firstVisit'];
      if (firstVisit != null) {
        DateTime? firstVisitDate;
        if (firstVisit is Timestamp) {
          firstVisitDate = firstVisit.toDate();
        }
        if (firstVisitDate != null && firstVisitDate.isAfter(startOfMonth)) {
          newU++;
        }
      }
    }

    // Avg users per day = active / days passed
    final daysPassed = now.day;
    final avg = (active / daysPassed).round();

    // Update cache
    UserAnalyticsCache.updateCache(
      total: total,
      active: active,
      newU: newU,
      avg: avg,
    );

    setState(() {
      totalUsers = total;
      activeUsers = active;
      newUsers = newU;
      avgUsersPerDay = avg;
      isLoading = false;
    });
  }

  Future<Map<String, int>> fetchUserDistribution() async {
    // 🚀 Return cached data if valid
    if (UserAnalyticsCache.isCacheValid &&
        UserAnalyticsCache._userDistribution != null) {
      return UserAnalyticsCache._userDistribution!;
    }

    final firestore = FirebaseFirestore.instance;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    // 🚀 Fetch ALL collections at once using Future.wait (parallel execution)
    final results = await Future.wait([
      firestore.collection("aspnetusers").get(),
      firestore.collection("aspnetuserclaims").get(),
      firestore.collection("visitors").get(),
    ]);

    final usersSnapshot = results[0];
    final claimsSnapshot = results[1];
    final visitorsSnapshot = results[2];

    // 🚀 Process ALL in memory - NO loops with queries
    int activeUsers = 0;
    int inactiveUsers = 0;

    for (var doc in usersSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final isDeleted = data['IsDeleted'] ?? 'False';

      if (isDeleted == 'False') {
        activeUsers++;
      } else if (isDeleted == 'True') {
        inactiveUsers++;
      }
    }

    // Count Event Organizers from claims
    int eventOrganizers = 0;
    for (var doc in claimsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['ClaimValue'] == 'Orator') {
        eventOrganizers++;
      }
    }

    // Count new users from visitors
    int newUsers = 0;
    for (var doc in visitorsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final firstVisit = data['firstVisit'];

      if (firstVisit != null) {
        DateTime? firstVisitDate;
        if (firstVisit is Timestamp) {
          firstVisitDate = firstVisit.toDate();
        }
        if (firstVisitDate != null && firstVisitDate.isAfter(startOfMonth)) {
          newUsers++;
        }
      }
    }

    final distribution = {
      "Active": activeUsers,
      "Inactive": inactiveUsers,
      "EventOrganizers": eventOrganizers,
      "New": newUsers,
    };

    // Update cache
    UserAnalyticsCache.updateCache(distribution: distribution);

    return distribution;
  }

  Future<void> fetchWeeklyActivity() async {
    // 🚀 Return cached data if valid
    if (UserAnalyticsCache.isCacheValid) {
      setState(() {
        registrationsThisWeek = UserAnalyticsCache._registrationsThisWeek ?? 0;
        eventViewsThisWeek = UserAnalyticsCache._eventViewsThisWeek ?? 0;
      });
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    // 🚀 Fetch both collections in parallel
    final results = await Future.wait([
      firestore.collection("aspnetusers").get(),
      firestore
          .collection("eventViews")
          .where(
            "viewedAt",
            isGreaterThanOrEqualTo: startOfWeek.toIso8601String(),
          )
          .where("viewedAt", isLessThanOrEqualTo: endOfWeek.toIso8601String())
          .get(),
    ]);

    final usersSnapshot = results[0];
    final viewsSnapshot = results[1];

    // 🚀 Process registrations in memory
    int weeklyRegistrations = 0;
    for (var doc in usersSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data["CreatedAt"] != null) {
        try {
          final createdAt = DateTime.parse(data["CreatedAt"]);
          if (createdAt.isAfter(startOfWeek) &&
              createdAt.isBefore(endOfWeek.add(const Duration(days: 1)))) {
            weeklyRegistrations++;
          }
        } catch (_) {}
      }
    }

    int weeklyViews = viewsSnapshot.docs.length;

    // Update cache
    UserAnalyticsCache.updateCache(
      registrations: weeklyRegistrations,
      eventViews: weeklyViews,
    );

    setState(() {
      registrationsThisWeek = weeklyRegistrations;
      eventViewsThisWeek = weeklyViews;
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

  @override
  void initState() {
    super.initState();
    fetchAnalytics();
    fetchWeeklyActivity();
  }

  void openDrawer() {}

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
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 20,
                    ), // reduce tile width
                    child: GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, '/user-analytics'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: currentRoute == '/user-analytics'
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
                              language == 'ar'
                                  ? 'تحليلات المستخدم'
                                  : 'User Analytics',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: currentRoute == '/user-analytics'
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
                      UserAnalyticsCache.clearCache();
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
                  Row(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 28,
                        color: darkMode
                            ? Color(0xFFFFD700)
                            : DesertColors.primaryGoldDark,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        language == 'ar'
                            ? 'تحليلات المستخدم'
                            : 'User Analytics',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 768;
                      final isTablet = constraints.maxWidth > 800;

                      if (isMobile) {
                        return _buildMobileLayout();
                      } else {
                        return _buildDesktopLayout(isTablet);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildMobileBottomNav(context) : null,
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Mobile Metrics Grid (2x2)
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
          children: [
            _buildMobileMetricCard(
              title: language == 'ar' ? 'إجمالي المستخدمين' : 'Total Users',
              value: isLoading ? "..." : totalUsers.toString(),
              change: '+12.5%',
              period: language == 'ar' ? 'هذا الشهر' : 'This Month',
              icon: Icons.people_outline,
              iconColor: darkMode
                  ? Color(0xFFFFD700)
                  : DesertColors.primaryGoldDark,
            ),
            _buildMobileMetricCard(
              title: language == 'ar' ? 'المستخدمون النشطون' : 'Active Users',
              value: isLoading ? "..." : activeUsers.toString(),
              change: '+8.2%',
              period: language == 'ar' ? 'هذا الشهر' : 'This Month',
              icon: Icons.timeline_outlined,
              iconColor: darkMode ? Color(0xFFFF8C00) : Color(0xFFFF8C00),
            ),
            _buildMobileMetricCard(
              title: language == 'ar' ? 'مستخدمون جدد' : 'New Users',
              value: isLoading ? "..." : newUsers.toString(),
              change: '+22.1%',
              period: language == 'ar' ? 'هذا الشهر' : 'This Month',
              icon: Icons.person_add_outlined,
              iconColor: darkMode ? Color(0xFFDC143C) : Color(0xFFDC143C),
            ),
            _buildMobileMetricCard(
              title: language == 'ar'
                  ? 'متوسط المستخدمين/اليوم'
                  : 'Avg Users/Day',
              value: isLoading ? "..." : avgUsersPerDay.toString(),
              change: '+5.4%',
              period: language == 'ar' ? 'هذا الشهر' : 'This Month',
              icon: Icons.calendar_today_outlined,
              iconColor: darkMode ? Color(0xFFFFC107) : Color(0xFFFFC107),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Daily Activity Section (Collapsible)
        _buildMobileDailyActivitySection(),

        const SizedBox(height: 20),

        // Recent User Activity Section
        _buildMobileUserActivitySection(),

        const SizedBox(height: 20),

        // User Distribution Section
        _buildMobileUserDistributionSection(),
      ],
    );
  }

  Widget _buildDesktopLayout(bool isTablet) {
    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isTablet ? 4 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildMetricCard(
              title: language == 'ar' ? 'إجمالي المستخدمين' : 'Total Users',
              value: isLoading ? "..." : totalUsers.toString(),
              change: '+12.5%',
              period: language == 'ar' ? 'هذا الشهر' : 'This Month',
              icon: Icons.people_outline,
              iconColor: darkMode
                  ? Color(0xFFFFD700)
                  : DesertColors.primaryGoldDark,
            ),
            _buildMetricCard(
              title: language == 'ar' ? 'المستخدمون النشطون' : 'Active Users',
              value: isLoading ? "..." : activeUsers.toString(),
              change: '+8.2%',
              period: language == 'ar' ? 'هذا الشهر' : 'This Month',
              icon: Icons.timeline_outlined,
              iconColor: darkMode ? Color(0xFFFF8C00) : Color(0xFFFF8C00),
            ),
            _buildMetricCard(
              title: language == 'ar' ? 'مستخدمون جدد' : 'New Users',
              value: isLoading ? "..." : newUsers.toString(),
              change: '+22.1%',
              period: language == 'ar' ? 'هذا الشهر' : 'This Month',
              icon: Icons.person_add_outlined,
              iconColor: darkMode ? Color(0xFFDC143C) : Color(0xFFDC143C),
            ),
            _buildMetricCard(
              title: language == 'ar'
                  ? 'متوسط المستخدمين/اليوم'
                  : 'Avg Users/Day',
              value: isLoading ? "..." : avgUsersPerDay.toString(),
              change: '+5.4%',
              period: language == 'ar' ? 'هذا الشهر' : 'This Month',
              icon: Icons.calendar_today_outlined,
              iconColor: darkMode ? Color(0xFFFFC107) : Color(0xFFFFC107),
            ),
          ],
        ),

        const SizedBox(height: 40),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildDailyVisitorsSection()),
            const SizedBox(width: 20),
            Expanded(child: _buildUserActivitySection()),
          ],
        ),
        const SizedBox(height: 40),
        _buildUserDistributionSection(),
      ],
    );
  }

  Widget _buildMobileMetricCard({
    required String title,
    required String value,
    required String change,
    required String period,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : DesertColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: darkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: darkMode
                  ? DesertColors.darkText.withOpacity(0.7)
                  : DesertColors.lightText.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.trending_up, color: Colors.green, size: 14),
              const SizedBox(width: 2),
              Text(
                change,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            period,
            style: TextStyle(
              fontSize: 10,
              color: darkMode
                  ? DesertColors.darkText.withOpacity(0.6)
                  : DesertColors.lightText.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDailyActivitySection() {
    return Container(
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : DesertColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: darkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                isDailyActivityExpanded = !isDailyActivityExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    language == 'ar' ? 'النشاط اليومي' : 'Daily Activity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isDailyActivityExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: darkMode
                        ? DesertColors.darkText.withOpacity(0.7)
                        : DesertColors.lightText.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ),
          if (isDailyActivityExpanded) ...[
            Container(
              height: 300,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: DailyVisitorsChart(darkMode: darkMode),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileUserActivitySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : DesertColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: darkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            language == 'ar'
                ? 'نشاط المستخدمين الأخير'
                : 'Recent User Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
          ),
          const SizedBox(height: 20),

          _buildMobileActivityItem(
            title: language == 'ar' ? 'مشاهدات الأحداث' : 'Event Views',
            value: eventViewsThisWeek.toString(),
            change: '+15%',
            period: language == 'ar' ? 'هذا الأسبوع' : 'This Week',
            icon: Icons.visibility_outlined,
            iconColor: darkMode
                ? Color(0xFFFFD700)
                : DesertColors.primaryGoldDark,
          ),

          const SizedBox(height: 16),

          _buildMobileActivityItem(
            title: language == 'ar' ? 'تحميلات الكتب' : 'Book Downloads',
            value: '567',
            change: '+28%',
            period: language == 'ar' ? 'هذا الأسبوع' : 'This Week',
            icon: Icons.download_outlined,
            iconColor: darkMode ? Color(0xFFFF8C00) : Color(0xFFFF8C00),
          ),

          const SizedBox(height: 16),

          _buildMobileActivityItem(
            title: language == 'ar' ? 'التسجيلات' : 'Registrations',
            value: registrationsThisWeek.toString(),
            change: '+12%',
            period: language == 'ar' ? 'هذا الأسبوع' : 'This Week',
            icon: Icons.person_add_outlined,
            iconColor: darkMode ? Color(0xFFDC143C) : Color(0xFFDC143C),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileActivityItem({
    required String title,
    required String value,
    required String change,
    required String period,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: darkMode
                      ? DesertColors.darkText
                      : DesertColors.lightText,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkMode
                      ? DesertColors.darkText
                      : DesertColors.lightText,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              change,
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              period,
              style: TextStyle(
                fontSize: 11,
                color: darkMode
                    ? DesertColors.darkText.withOpacity(0.6)
                    : DesertColors.lightText.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileUserDistributionSection() {
    // 🚀 Show cached data immediately if available
    if (UserAnalyticsCache.isCacheValid &&
        UserAnalyticsCache._userDistribution != null) {
      return _buildDistributionContainer(
        UserAnalyticsCache._userDistribution!,
        isMobile: true,
      );
    }

    return FutureBuilder<Map<String, int>>(
      future: fetchUserDistribution(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: darkMode
                  ? DesertColors.darkSurface
                  : DesertColors.lightSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return _buildDistributionContainer(snapshot.data!, isMobile: true);
      },
    );
  }

  // Helper method to avoid duplication
  Widget _buildDistributionContainer(
    Map<String, int> data, {
    required bool isMobile,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : DesertColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: darkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            language == 'ar' ? 'توزيع المستخدمين' : 'User Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: isMobile ? 350 : 200,
            child: UserDistributionChart(
              data,
              darkMode: darkMode,
              isMobile: isMobile,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyVisitorsSection() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : DesertColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: darkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            language == 'ar' ? 'النشاط اليومي' : 'Daily Activity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(child: DailyVisitorsChart(darkMode: darkMode)),
        ],
      ),
    );
  }

  Widget _buildUserActivitySection() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : DesertColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: darkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            language == 'ar'
                ? 'نشاط المستخدمين الأخير'
                : 'Recent User Activity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
          ),
          const SizedBox(height: 24),

          _buildActivityItem(
            title: language == 'ar' ? 'مشاهدات الأحداث' : 'Event Views',
            value: eventViewsThisWeek.toString(),
            change: '+15%',
            period: language == 'ar' ? 'هذا الأسبوع' : 'This Week',
            icon: Icons.visibility_outlined,
            iconColor: darkMode
                ? Color(0xFFFFD700)
                : DesertColors.primaryGoldDark,
          ),

          const SizedBox(height: 20),

          _buildActivityItem(
            title: language == 'ar' ? 'تحميلات الكتب' : 'Book Downloads',
            value: '567',
            change: '+28%',
            period: language == 'ar' ? 'هذا الأسبوع' : 'This Week',
            icon: Icons.download_outlined,
            iconColor: darkMode ? Color(0xFFFF8C00) : Color(0xFFFF8C00),
          ),

          const SizedBox(height: 20),

          _buildActivityItem(
            title: language == 'ar' ? 'التسجيلات' : 'Registrations',
            value: registrationsThisWeek.toString(),
            change: '+12%',
            period: language == 'ar' ? 'هذا الأسبوع' : 'This Week',
            icon: Icons.person_add_outlined,
            iconColor: darkMode ? Color(0xFFDC143C) : Color(0xFFDC143C),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDistributionSection() {
    // 🚀 Show cached data immediately if available
    if (UserAnalyticsCache.isCacheValid &&
        UserAnalyticsCache._userDistribution != null) {
      return _buildDistributionContainer(
        UserAnalyticsCache._userDistribution!,
        isMobile: false,
      );
    }

    return FutureBuilder<Map<String, int>>(
      future: fetchUserDistribution(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 300,
            decoration: BoxDecoration(
              color: darkMode
                  ? DesertColors.darkSurface
                  : DesertColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return Container(
          height: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: darkMode
                ? DesertColors.darkSurface
                : DesertColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: darkMode
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                language == 'ar' ? 'توزيع المستخدمين' : 'User Distribution',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkMode
                      ? DesertColors.darkText
                      : DesertColors.lightText,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: UserDistributionChart(
                  snapshot.data!,
                  darkMode: darkMode,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String change,
    required String period,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : DesertColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: darkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: darkMode
                  ? DesertColors.darkText.withOpacity(0.7)
                  : DesertColors.lightText.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
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
              const SizedBox(width: 8),
              Text(
                period,
                style: TextStyle(
                  fontSize: 12,
                  color: darkMode
                      ? DesertColors.darkText.withOpacity(0.6)
                      : DesertColors.lightText.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required String title,
    required String value,
    required String change,
    required String period,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: darkMode
                      ? DesertColors.darkText
                      : DesertColors.lightText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: darkMode
                      ? DesertColors.darkText
                      : DesertColors.lightText,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                Text(
                  change,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              period,
              style: TextStyle(
                fontSize: 12,
                color: darkMode
                    ? DesertColors.darkText.withOpacity(0.6)
                    : DesertColors.lightText.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ],
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
