import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alraya_app/alrayah.dart';

import 'package:alraya_app/componenets/contact_section.dart';
import 'package:alraya_app/componenets/navigation.dart';


class ContactPage extends StatefulWidget {
  final bool darkMode;
  final String language;

  const ContactPage({
    Key? key,
    required this.darkMode,
    required this.language,
  }) : super(key: key);

  @override
  _ContactPageState createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _themeController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey heroKey = GlobalKey();
  final GlobalKey contactKey = GlobalKey();

  bool darkMode = false;
  String language = 'en';

  ScrollController _pageScrollController = ScrollController();
 

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _themeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
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
    Scaffold.of(context).openDrawer();
  }

 
  @override
  void dispose() {
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
        key: _scaffoldKey,
        backgroundColor: Color.lerp(
          DesertColors.lightBackground,
          DesertColors.darkBackground,
          _themeController.value,
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
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 20,
                  ), // reduce tile width
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/'),
                    child: Container(
                      decoration: BoxDecoration(
                        color: currentRoute == '/'
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
                            language == 'ar' ? 'الرئيسية' : 'Home',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: currentRoute == '/'
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
                  selected: currentRoute == '/majalis',
                  selectedTileColor: darkMode
                      ? DesertColors.primaryGoldDark
                      : DesertColors.maroon,

                  title: Text(
                    language == 'ar'
                        ? 'إصدارات المجلس'
                        : 'Council Publications',
                    style: TextStyle(
                      color: currentRoute == '/majalis'
                          ? (darkMode ? DesertColors.lightText : Colors.white)
                          : (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText),
                    ),
                  ),
                  onTap: () => Navigator.pushNamed(context, '/majalis'),
                ),
                ListTile(
                  selected: currentRoute == '/books',
                  selectedTileColor: darkMode
                      ? DesertColors.primaryGoldDark
                      : DesertColors.maroon,

                  title: Text(
                    language == 'ar' ? 'مكتبة الرؤية' : 'Vision Library',
                    style: TextStyle(
                      color: currentRoute == '/books'
                          ? (darkMode ? DesertColors.lightText : Colors.white)
                          : (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText),
                    ),
                  ),
                  onTap: () => Navigator.pushNamed(context, '/books'),
                ),
                ListTile(
                  selected: currentRoute == '/about',
                  selectedTileColor: darkMode
                      ? DesertColors.primaryGoldDark
                      : DesertColors.maroon,

                  title: Text(
                    language == 'ar' ? 'من نحن' : 'About Us',
                    style: TextStyle(
                      color: currentRoute == '/about'
                          ? (darkMode ? DesertColors.lightText : Colors.white)
                          : (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText),
                    ),
                  ),
                  onTap: () => Navigator.pushNamed(context, '/about'),
                ),
                ListTile(
                  selected: currentRoute == '/publications',
                  selectedTileColor: darkMode
                      ? DesertColors.primaryGoldDark
                      : DesertColors.maroon,

                  title: Text(
                    language == 'ar'
                        ? 'منشورات الراية'
                        : 'Al-Rayah Publications',
                    style: TextStyle(
                      color: currentRoute == '/publications'
                          ? (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText)
                          : (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText),
                    ),
                  ),
                  onTap: () => Navigator.pushNamed(context, '/publications'),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: (currentRoute ?? '').startsWith('/favorite-books')
                        ? (darkMode
                              ? DesertColors
                                    .camelSand // ✅ your new dark mode bg
                              : DesertColors
                                    .crimson) // ✅ your new light mode bg
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    selected:
                        false, // ✅ turn off ListTile’s own selection logic
                    selectedTileColor:
                        Colors.transparent, // ✅ no background override
                    tileColor: Colors.transparent, // ✅ ensure default is clear
                    title: Text(
                      language == 'ar' ? 'المفضلة' : 'Favorites',
                      style: TextStyle(
                        color:
                            (currentRoute ?? '').startsWith('/favorite-books')
                            ? (darkMode
                                  ? DesertColors
                                        .crimson // ✅ your new dark mode text
                                  : DesertColors
                                        .lightSurface) // ✅ your new light mode text
                            : (darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText),
                      ),
                    ),
                    onTap: () =>
                        Navigator.pushNamed(context, '/favorite-books'),
                  ),
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

        body: Stack(
          children: [
            SingleChildScrollView(
              child: ContactSection(darkMode: darkMode, language: language),
            ),
            NavigationBarWidget(
              darkMode: darkMode,
              language: language,
              scrolled: true,
              toggleDarkMode: toggleDarkMode,
              toggleLanguage: toggleLanguage,
              openDrawer: openDrawer,
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
                route: '/contact', // 👈 not "/contact"
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

        if (route == '/contact') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(
                  backgroundColor: darkMode
                      ? DesertColors.darkBackground
                      : Colors.white,
                  title: Text(language == 'ar' ? 'اتصل بنا' : 'Contact'),
                ),
                body: ContactSection(language: language, darkMode: darkMode),
              ),
            ),
          );
          return;
        }
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