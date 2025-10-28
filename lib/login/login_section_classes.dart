import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_page.dart'; // Import your widget
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../alrayah.dart';
import '../componenets/navigation.dart';

class LoginSectionPage extends StatefulWidget {
  const LoginSectionPage({super.key});

  @override
  _LoginSectionPageState createState() => _LoginSectionPageState();
}

class _LoginSectionPageState extends State<LoginSectionPage>
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
      textDirection: language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
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
                                      DesertColors.maroon.withOpacity(
                                        0.8,
                                      ),
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
                ListTile(
                  title: Text(
                    language == 'ar'
                        ? 'إصدارات المجلس'
                        : 'Council Publications',
                    style: TextStyle(
                      color: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                  onTap: () => Navigator.pushNamed(context, '/majalis'),
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
              child: SignupPage(
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
      ),
    );
  }
}
