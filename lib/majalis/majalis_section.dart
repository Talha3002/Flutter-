import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'majalis_hero_section.dart'; // Import your widget
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../../alrayah.dart';
import '../../componenets/navigation.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

/// Serializable version of Event for caching
class CachedEvent {
  final String id;
  final String title;
  final String startTime; // Store as ISO string
  final String preacherName;
  final String location;
  final String description;
  final String liveLink;
  final String? imageUrl; // Supabase URL or null for asset

  CachedEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.preacherName,
    required this.location,
    required this.description,
    required this.liveLink,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'startTime': startTime,
    'preacherName': preacherName,
    'location': location,
    'description': description,
    'liveLink': liveLink,
    'imageUrl': imageUrl,
  };

  factory CachedEvent.fromJson(Map<String, dynamic> json) => CachedEvent(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    startTime: json['startTime'] ?? '',
    preacherName: json['preacherName'] ?? '',
    location: json['location'] ?? '',
    description: json['description'] ?? '',
    liveLink: json['liveLink'] ?? '',
    imageUrl: json['imageUrl'],
  );

  Event toEvent() {
    DateTime date;
    try {
      date = DateTime.parse(startTime);
    } catch (_) {
      date = DateTime.now();
    }

    Image eventImage = imageUrl != null && imageUrl!.isNotEmpty
        ? Image.network(
            imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Image.asset('assets/images/logo.png', fit: BoxFit.cover),
          )
        : Image.asset('assets/images/logo.png', fit: BoxFit.cover);

    return Event(
      id: id,
      title: title,
      startTime: date,
      preacherName: preacherName,
      location: location,
      description: description,
      liveLink: liveLink,
      image: eventImage,
    );
  }
}

class Event {
  final String id;
  final String title;
  final DateTime startTime;
  final String preacherName;
  final String location;
  final String description;
  final String liveLink;
  final Image image;

  Event({
    required this.id,
    required this.title,
    required this.startTime,
    required this.preacherName,
    required this.location,
    required this.description,
    required this.liveLink,
    required this.image,
  });

  // Helper to safely parse both ISO-style and dd/MM/yyyy HH:mm
  static DateTime _parseDate(String raw) {
    try {
      return DateTime.parse(raw); // e.g. "2024-12-14 19:00:00.0000000"
    } catch (_) {
      return DateFormat("d/M/yyyy HH:mm").parse(raw); // e.g. "10/8/2025 22:25"
    }
  }

  /// Factory method to create an Event from Firestore documents
  factory Event.fromFirestore(
    Map<String, dynamic> adsData,
    Map<String, dynamic> boardData,
    Map<String, dynamic> userData, {
    Map<String, dynamic>? uploadedFilesData,
  }) {
    final rawDate = boardData['BoardDateTime'] ?? '';
    final date = rawDate is String ? _parseDate(rawDate) : DateTime.now();

    // Extract Supabase URL if available
    String? imageUrl;
    if (uploadedFilesData != null) {
      final entityType = uploadedFilesData['EntityType']?.toString() ?? '';
      final fileId = uploadedFilesData['Id']?.toString() ?? '';
      final boardAdsImageId = adsData['BoardAdsImageId']?.toString() ?? '';

      if (entityType.toLowerCase() == 'boardads' &&
          fileId == boardAdsImageId &&
          uploadedFilesData['SupabaseUrl'] != null &&
          uploadedFilesData['SupabaseUrl'].toString().isNotEmpty) {
        imageUrl = uploadedFilesData['SupabaseUrl'].toString();
      }
    }

    Image eventImage = imageUrl != null
        ? Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Image.asset('assets/images/logo.png', fit: BoxFit.cover),
          )
        : Image.asset('assets/images/logo.png', fit: BoxFit.cover);

    return Event(
      id: adsData['Id'] ?? '',
      title: adsData['Title'] ?? 'Untitled',
      startTime: date,
      preacherName: userData['FullName'] ?? 'Unknown',
      location: adsData['Location'] ?? 'Unknown',
      description: adsData['Description'] ?? 'Not Added',
      liveLink: adsData['LiveBroadcastLink'] ?? 'No Link',
      image: eventImage,
    );
  }

  /// Convert Event to CachedEvent for storage
  CachedEvent toCachedEvent() {
    // Extract URL if it's a network image
    String? imageUrl;
    // Note: We can't easily extract URL from Image widget,
    // so we'll handle this differently in the caching logic

    return CachedEvent(
      id: id,
      title: title,
      startTime: startTime.toIso8601String(),
      preacherName: preacherName,
      location: location,
      description: description,
      liveLink: liveLink,
      imageUrl: null, // Will be set during fetch
    );
  }
}

List<Event> globalEvents = [];

class MajalisSectionPage extends StatefulWidget {
  const MajalisSectionPage({super.key});

  @override
  _MajalisSectionPageState createState() => _MajalisSectionPageState();
}

class _MajalisSectionPageState extends State<MajalisSectionPage>
    with TickerProviderStateMixin {
  bool darkMode = false;
  String language = 'ar';
  double _mouseX = 0.0;
  double _mouseY = 0.0;

  late AnimationController _rotationController;
  late AnimationController _floatingController;
  late AnimationController _pulseController;
  late AnimationController _scrollController;
  late AnimationController _themeController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Offset _mousePosition = Offset.zero;
  Offset _targetOffset = Offset.zero;

  ScrollController _pageScrollController = ScrollController();
  bool _scrolled = false;

  String searchTerm = '';
  String filterType = 'all';
  int displayedBooks = 9;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadPreferences();
    _setupScrollListener();
  }

  void _initializeControllers() {
    _rotationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 20),
    )..repeat();
    _floatingController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
    _scrollController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
    _themeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
  }

  void _setupScrollListener() {
    _pageScrollController.addListener(() {
      setState(() {
        _scrolled = _pageScrollController.offset > 50;
      });
    });
  }

  void _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      darkMode = prefs.getBool('darkMode') ?? false;
      language = prefs.getString('language') ?? 'ar';
    });
    if (darkMode) {
      _themeController.forward();
    }
  }

  void _savePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', darkMode);
    await prefs.setString('language', language);
  }

  void toggleDarkMode() {
    setState(() {
      darkMode = !darkMode;
    });
    if (darkMode) {
      _themeController.forward();
    } else {
      _themeController.reverse();
    }
    _savePreferences();
  }

  void toggleLanguage() {
    setState(() {
      language = language == 'ar' ? 'en' : 'ar';
    });
    _savePreferences();
  }

  void openDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _floatingController.dispose();
    _pulseController.dispose();
    _scrollController.dispose();
    _themeController.dispose();
    _pageScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? currentRoute = ModalRoute.of(context)?.settings.name;
    return Directionality(
      textDirection: language == 'ar'
          ? ui.TextDirection.rtl
          : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Color.lerp(
          DesertColors.lightBackground,
          DesertColors.darkBackground,
          darkMode ? 1.0 : 0.0,
        ),
        endDrawer: Drawer(
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        height: 60,
                        width: 60,
                      ),
                      SizedBox(width: 12),
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
                                  : [DesertColors.maroon, DesertColors.crimson],
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
                ListTile(
                  title: Text(
                    language == 'ar' ? 'الرئيسية' : 'Home',
                    style: TextStyle(
                      color: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                  onTap: () => Navigator.pushNamed(context, '/'),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 20,
                  ), // reduce tile width
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/majalis'),
                    child: Container(
                      decoration: BoxDecoration(
                        color: currentRoute == '/majalis'
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
                                ? 'إصدارات المجلس'
                                : 'Council Publications',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: currentRoute == '/majalis'
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
                  title: Text(
                    language == 'ar' ? 'مكتبة الرؤية' : 'Vision Library',
                    style: TextStyle(
                      color: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                  onTap: () => Navigator.pushNamed(context, '/books'),
                ),
                ListTile(
                  title: Text(
                    language == 'ar' ? 'من نحن' : 'About Us',
                    style: TextStyle(
                      color: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                  onTap: () => Navigator.pushNamed(context, '/about'),
                ),
                ListTile(
                  title: Text(
                    language == 'ar'
                        ? 'منشورات الراية'
                        : 'Al-Rayah Publications',
                    style: TextStyle(
                      color: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                  onTap: () => Navigator.pushNamed(context, '/publications'),
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
        ),

        body: Column(
          children: [
            NavigationBarWidget(
              darkMode: darkMode,
              language: language,
              scrolled: _scrolled,
              toggleDarkMode: toggleDarkMode,
              toggleLanguage: toggleLanguage,
              openDrawer: openDrawer,
            ),
            Expanded(
              child: MajalisHeroSection(
                darkMode: darkMode,
                language: language,
                scrolled: _scrolled,
                searchTerm: searchTerm,
                filterType: filterType,
                displayedBooks: displayedBooks,
              ),
            ),
          ],
        ),
        bottomNavigationBar: isMobile(context)
            ? _buildMobileBottomNav(context)
            : null,
      ),
    );
  }

  bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
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
                icon: Icons.home_rounded,
                label: language == 'ar' ? 'الرئيسية' : 'Home',
                route: '/',
                currentRoute: currentRoute,
              ),
              _buildNavItem(
                context,
                icon: Icons.menu_book_rounded,
                label: language == 'ar' ? 'كتب' : 'Books',
                route: '/books',
                currentRoute: currentRoute,
              ),
              _buildNavItem(
                context,
                icon: Icons.event_rounded,
                label: language == 'ar' ? 'فعاليات' : 'Events',
                route: '/majalis',
                currentRoute: currentRoute,
              ),
              _buildNavItem(
                context,
                icon: Icons.menu_book_rounded, // <-- Book style icon
                label: language == 'ar' ? 'منشورات' : 'Publications',
                route: '/publications',
                currentRoute: currentRoute,
              ),
              _buildNavItem(
                context,
                icon: Icons.contact_mail_rounded,
                label: language == 'ar' ? 'اتصل بنا' : 'Contact',
                route: '/contact',
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
