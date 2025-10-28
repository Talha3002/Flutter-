import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../alrayah.dart'; // Adjust path as needed

class NavigationBarWidget extends StatelessWidget {
  final bool darkMode;
  final String language;
  final bool scrolled;
  final VoidCallback toggleDarkMode;
  final VoidCallback toggleLanguage;
  final VoidCallback openDrawer; // ADD THIS

  const NavigationBarWidget({
    Key? key,
    required this.darkMode,
    required this.language,
    required this.scrolled,
    required this.toggleDarkMode,
    required this.toggleLanguage,
    required this.openDrawer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '/';
    final menuItems = {
      'ar': [
        {'name': 'الرئيسية', 'href': '/'},
        {'name': 'إصدارات المجلس', 'href': '/majalis'},
        {'name': 'مكتبة الرؤية', 'href': '/books'},
        {'name': 'من نحن', 'href': '/about'},
        {'name': 'منشورات الراية', 'href': '/publications'},
      ],
      'en': [
        {'name': 'Home', 'href': '/'},
        {'name': 'Council Publications', 'href': '/majalis'},
        {'name': 'Vision Library', 'href': '/books'},
        {'name': 'About Us', 'href': '/about'},
        {'name': 'Al-Rayah Publications', 'href': '/publications'},
      ],
    };

    return AnimatedContainer(
      duration: Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: scrolled
            ? LinearGradient(
                colors: darkMode
                    ? [
                        DesertColors.darkSurface.withOpacity(0.95),
                        DesertColors.maroon.withOpacity(0.9),
                      ]
                    : [
                        DesertColors.lightSurface.withOpacity(0.95),
                        Colors.white.withOpacity(0.9),
                      ],
              )
            : null,
        boxShadow: scrolled
            ? [
                BoxShadow(
                  color: DesertColors.maroon.withOpacity(0.2),
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isPhone = constraints.maxWidth < 600;

              return isPhone
                  ? _buildMobileNav(context)
                  : _buildDesktopNav(context, currentRoute, menuItems);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopNav(
    BuildContext context,
    String currentRoute,
    Map<String, List<Map<String, String>>> menuItems,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Logo + Title
        GestureDetector(
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                language == 'ar' ? 'الرايــة' : 'Al-Rayah',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkMode
                      ? DesertColors.darkText
                      : DesertColors.lightText,
                ),
              ),
            ],
          ),
        ),

        // Navigation Tabs
        Row(
          children: menuItems[language]!.map<Widget>((item) {
            final isActive = currentRoute == item['href'];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, item['href']!);
                  },
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: isActive
                          ? (darkMode
                                ? DesertColors.primaryGoldDark
                                : DesertColors.crimson)
                          : Colors.transparent,
                    ),
                    child: Text(
                      item['name']!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.white
                            : (darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // Language & Theme Toggles
        Row(
          children: [
            // Language Toggle
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                toggleLanguage();
              },
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                padding: EdgeInsets.all(8),
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
            SizedBox(width: 8),

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
                        ? [DesertColors.camelSand, DesertColors.primaryGoldDark]
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
                    darkMode ? Icons.wb_sunny : Icons.nightlight_round,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileNav(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // LOGO
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SizedBox(width: 8),
            Text(
              language == 'ar' ? 'الرايــة' : 'Al-Rayah',
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

        // HAMBURGER ICON
        IconButton(
          icon: Icon(Icons.menu, color: darkMode ? Colors.white : Colors.black),
          onPressed: () {
            Scaffold.of(context).openEndDrawer();
          },
        ),
      ],
    );
  }
}
