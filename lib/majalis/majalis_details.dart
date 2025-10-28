import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:alraya_app/alrayah.dart';
import 'package:alraya_app/componenets/navigation.dart';
import 'package:intl/intl.dart';
import 'majalis_section.dart';
import 'dart:ui' as ui;

class MajalisDetails extends StatefulWidget {
  final bool darkMode;
  final String language;
  final Map<String, dynamic> event;

  const MajalisDetails({
    Key? key,
    required this.darkMode,
    required this.language,
    required this.event,
  }) : super(key: key);

  @override
  _MajalisDetailsState createState() => _MajalisDetailsState();
}

class _MajalisDetailsState extends State<MajalisDetails>
    with TickerProviderStateMixin {
  bool darkMode = false;
  String language = 'ar'; // Default to Arabic
  bool scrolled = false;
  bool _showDescription = false; // Add this line after other state variables

  ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _scrollController.addListener(() {
      setState(() {
        scrolled = _scrollController.offset > 50;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void toggleDarkMode() {
    setState(() {
      darkMode = !darkMode;
    });
  }

  void toggleLanguage() {
    setState(() {
      language = language == 'ar' ? 'en' : 'ar';
    });
  }

  void openDrawer() {
    Scaffold.of(context).openEndDrawer();
  }

  void _shareEvent(BuildContext context) {
    final text = language == 'ar'
        ? 'انضم إلينا في خطبة الجمعة المباركة\nالتاريخ: الجمعة 15 أغسطس 2025\nالوقت: 1:30 مساءً\nالمكان: مسجد النور الإسلامي'
        : 'Join us for the Blessed Friday Sermon\nDate: Friday, August 15, 2025\nTime: 1:30 PM\nLocation: Al-Noor Islamic Mosque';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          language == 'ar'
              ? 'تم نسخ التفاصيل إلى الحافظة'
              : 'Details copied to clipboard',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? currentRoute = ModalRoute.of(context)?.settings.name;
    bool isMobile = MediaQuery.of(context).size.width < 768;
    widget.event['Title'];
    widget.event['Date'];
    widget.event['Location'];
    widget.event['PreacherName']; // join from aspnetusers
    widget.event['Description'];
    widget.event['LiveBroadcastLink'];

    return Directionality(
      textDirection: language == 'ar'
          ? ui.TextDirection.rtl
          : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: darkMode
            ? DesertColors.darkBackground
            : DesertColors.lightBackground,

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

        body: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      NavigationBarWidget(
                        darkMode: darkMode,
                        language: language,
                        scrolled: scrolled,
                        toggleDarkMode: toggleDarkMode,
                        toggleLanguage: toggleLanguage,
                        openDrawer: openDrawer,
                      ),
                      Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          children: [
                            // Header with title and share icon
                            LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth > 800) {
                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          widget.event['Title'],
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: darkMode
                                                ? DesertColors.darkText
                                                : DesertColors.lightText,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _shareEvent(
                                          context,
                                        ), // pass context now
                                        icon: Icon(
                                          Icons.share,
                                          color: darkMode
                                              ? DesertColors.camelSand
                                              : DesertColors.maroon,
                                        ),
                                      ),
                                    ],
                                  );
                                } else {
                                  // Mobile: Only show title
                                  return Text(
                                    widget.event['Title'],
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: darkMode
                                          ? DesertColors.darkText
                                          : DesertColors.lightText,
                                    ),
                                  );
                                }
                              },
                            ),
                            SizedBox(height: 20),

                            // Main content area
                            LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth > 800) {
                                  return _buildDesktopLayout();
                                } else {
                                  return _buildMobileLayout();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: isMobile ? _buildMobileBottomNav(context) : null,
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main content (left side for LTR, right side for RTL)
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _buildEventBanner(),
              SizedBox(height: 24),
              _buildAboutSection(),
            ],
          ),
        ),
        SizedBox(width: 24),
        // Sidebar (right side for LTR, left side for RTL)
        Expanded(flex: 1, child: _buildSidebar()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildEventBanner(),
        SizedBox(height: 16),
        _buildSidebar(),
        SizedBox(height: 16),
        _buildDescriptionToggle(),
        SizeTransition(
          sizeFactor: _animation,
          child: Column(
            children: [
              SizedBox(height: 16),
              FadeTransition(opacity: _animation, child: _buildAboutSection()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showDescription = !_showDescription;
          if (_showDescription) {
            _animationController.forward();
          } else {
            _animationController.reverse();
          }
        });
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: darkMode
              ? DesertColors.darkSurface
              : DesertColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: darkMode
                ? DesertColors.camelSand.withOpacity(0.3)
                : DesertColors.maroon.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedRotation(
              turns: _showDescription ? 0.5 : 0,
              duration: Duration(milliseconds: 300),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: darkMode ? DesertColors.camelSand : DesertColors.maroon,
              ),
            ),
            SizedBox(width: 8),
            Text(
              _showDescription
                  ? (language == 'ar' ? 'إخفاء التفاصيل' : 'Hide Details')
                  : (language == 'ar' ? 'عرض التفاصيل' : 'Show Details'),
              style: TextStyle(
                color: darkMode
                    ? DesertColors.darkText
                    : DesertColors.lightText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventBanner() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: darkMode
              ? [DesertColors.maroon, DesertColors.primaryGoldDark]
              : [DesertColors.crimson, DesertColors.camelSand],
        ),
        boxShadow: [
          BoxShadow(
            color: (darkMode ? DesertColors.maroon : DesertColors.crimson)
                .withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern or image would go here
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(
                image: AssetImage('assets/images/logo.png'),
                fit: BoxFit.cover,
                opacity: 0.3,
              ),
            ),
          ),

          // Content overlay
          Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.mosque, color: Colors.white, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.event['Location'],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Spacer(),
                Text(
                  widget.event['Title'],
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  language == 'ar'
                      ? 'دروس من السيرة النبوية الشريفة'
                      : 'LESSONS FROM THE PROPHETIC BIOGRAPHY',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    language == 'ar'
                        ? 'مناسبة إسلامية خاصة'
                        : 'SPECIAL ISLAMIC OCCASION',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final String? liveLink = widget.event['LiveBroadcastLink'];

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : DesertColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (darkMode ? Colors.black : Colors.grey).withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSidebarItem(
            Icons.calendar_today,
            language == 'ar' ? 'التاريخ' : 'Date',
            widget.event['Date'] != null
                ? DateFormat('dd/MM/yyyy').format(widget.event['Date'])
                : '',
          ),
          SizedBox(height: 16),
          _buildSidebarItem(
            Icons.access_time,
            language == 'ar' ? 'الوقت' : 'Time',
            language == 'ar' ? '1:30 مساءً' : '1:30 PM',
          ),
          SizedBox(height: 16),
          _buildSidebarItem(
            Icons.timer,
            language == 'ar' ? 'المدة' : 'Duration',
            language == 'ar' ? '45 دقيقة' : '45 minutes',
          ),
          SizedBox(height: 16),
          _buildSidebarItem(
            Icons.person,
            language == 'ar' ? 'الخطيب' : 'Preacher',
            widget.event['PreacherName'] ?? '',
          ),
          SizedBox(height: 16),
          _buildSidebarItem(
            Icons.location_on,
            language == 'ar' ? 'المكان' : 'Location',
            widget.event['Location'] ?? '',
          ),
          SizedBox(height: 24),

          // ✅ YouTube Link Button
          GestureDetector(
            onTap: (liveLink != null && liveLink.isNotEmpty)
                ? () async {
                    final Uri url = Uri.parse(liveLink);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode
                            .externalApplication, // opens YouTube app/browser
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            language == 'ar'
                                ? 'لا يوجد فيديو متاح لهذا الحدث'
                                : 'No video is available for this event',
                          ),
                        ),
                      );
                    }
                  }
                : null,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: (liveLink != null && liveLink.isNotEmpty)
                    ? LinearGradient(colors: [Colors.red, Colors.red.shade700])
                    : LinearGradient(
                        colors: [Colors.grey, Colors.grey.shade600],
                      ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    language == 'ar' ? 'مشاهدة على يوتيوب' : 'Watch on YouTube',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: darkMode ? DesertColors.camelSand : DesertColors.maroon,
          size: 20,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color:
                      (darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText)
                          .withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: darkMode
                      ? DesertColors.darkText
                      : DesertColors.lightText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : DesertColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (darkMode ? Colors.black : Colors.grey).withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            language == 'ar' ? 'نبذة عن الخطبة' : 'About The Sermon',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
          ),
          SizedBox(height: 16),
          Text(
            widget.event['Description'] ?? 'No description added',
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBottomNav(BuildContext context) {
    final String? currentRoute = ModalRoute.of(context)?.settings.name;

    return Directionality(
      textDirection: language == 'ar'
          ? ui.TextDirection.rtl
          : ui.TextDirection.ltr,
      child: Container(
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
