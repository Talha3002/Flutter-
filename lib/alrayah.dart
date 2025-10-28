import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

import 'componenets/navigation.dart';
import 'componenets/hero_section.dart';
import 'componenets/publications_section.dart';
import 'componenets/app_section.dart';
import 'componenets/contact_section.dart';
import 'componenets/footer_section.dart';
import 'componenets/favorite_book_section.dart';


// Replace the entire DesertColors class with:
class DesertColors {
  static const Color camelSand = Color(0xFFFFD670);
  static const Color crimson = Color(0xFFE63946);
  static const Color maroon = Color(0xFF6F1D1B);
  static const Color primaryGoldDark = Color(0xFFFF8F00);

  // Light mode colors
  static const Color lightBackground = Color(0xFFFFF8E7);
  static const Color lightSurface = Color(0xFFFFFBF0);
  static const Color lightText = Color(0xFF4A2C17);

  // Dark mode colors
  static const Color darkBackground = Color(0xFF2D1810);
  static const Color darkSurface = Color(0xFF3D2419);
  static const Color darkText = Color(0xFFFFE4B5);
}
// ------------------ COMPONENT CLASSES ------------------

class HoverIconButton extends StatefulWidget {
  final IconData icon;
  final Color hoverColor;

  const HoverIconButton({
    Key? key,
    required this.icon,
    required this.hoverColor,
  }) : super(key: key);

  @override
  HoverIconButtonState createState() => HoverIconButtonState();
}

class HoverIconButtonState extends State<HoverIconButton>
    with SingleTickerProviderStateMixin {
  bool _hovering = false;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovering = true);
        _scaleController.forward();
      },
      onExit: (_) {
        setState(() => _hovering = false);
        _scaleController.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: EdgeInsets.only(right: 12),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hovering
                  ? [widget.hoverColor, widget.hoverColor.withOpacity(0.8)]
                  : [DesertColors.maroon, DesertColors.maroon.withOpacity(0.9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _hovering
                    ? widget.hoverColor.withOpacity(0.4)
                    : DesertColors.maroon.withOpacity(0.3),
                blurRadius: _hovering ? 12 : 8,
                offset: Offset(0, _hovering ? 6 : 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(widget.icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class MouseReactiveTilt extends StatefulWidget {
  final Widget Function(Offset offset) builder;
  final double maxAngle;

  const MouseReactiveTilt({
    super.key,
    required this.builder,
    this.maxAngle = 0.9,
  });

  @override
  State<MouseReactiveTilt> createState() => _MouseReactiveTiltState();
}

class _MouseReactiveTiltState extends State<MouseReactiveTilt>
    with SingleTickerProviderStateMixin {
  Offset _targetOffset = Offset.zero;
  Offset _currentOffset = Offset.zero;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 16),
        )..addListener(() {
          setState(() {
            _currentOffset = Offset.lerp(_currentOffset, _targetOffset, 0.1)!;
          });
        });
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateOffset(PointerHoverEvent event, BuildContext context) {
    final size = context.size ?? Size.zero;
    final localPos = event.localPosition;
    final dx = ((localPos.dx / size.width) - 0.5) * 2;
    final dy = ((localPos.dy / size.height) - 0.5) * 2;
    setState(() {
      _targetOffset = Offset(dx, dy);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) => _updateOffset(event, context),
      onExit: (_) => setState(() => _targetOffset = Offset.zero),
      child: widget.builder(_currentOffset),
    );
  }
}

class AlrayaPage extends StatefulWidget {
  @override
  _AlrayaPageState createState() => _AlrayaPageState();
}

class _AlrayaPageState extends State<AlrayaPage> with TickerProviderStateMixin {
  bool darkMode = false;
  String language = 'ar';


  late AnimationController _rotationController;
  late AnimationController _floatingController;
  late AnimationController _pulseController;
  late AnimationController _scrollController;
  late AnimationController _themeController;
  late Animation<double> _floatingAnimation;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey heroKey = GlobalKey();


  ScrollController _pageScrollController = ScrollController();
  bool _scrolled = false;
  bool _showQRDialog = false;
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadPreferences();
    _setupScrollListener();
  }
  
  void _initializeControllers() {
    _rotationController = AnimationController(
      duration: Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _floatingController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _floatingAnimation = Tween<double>(
      begin: 0,
      end: math.pi,
    ).animate(_floatingController);

    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _scrollController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _themeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
  }

  void _setupScrollListener() {
    _pageScrollController.addListener(() {
      final heroContext = heroKey.currentContext;
      if (heroContext != null) {
        final heroBox = heroContext.findRenderObject() as RenderBox;
        final heroHeight = heroBox.size.height;

        setState(() {
          // Show button only after scrolling past hero section
          _scrolled = _pageScrollController.offset > heroHeight;
        });
      }
    });
  }

  void _scrollToTop() {
    _pageScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
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
    Scaffold.of(context).openDrawer();
  }

  void toggleQRDialog(bool show) {
    setState(() {
      _showQRDialog = show;
    });
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
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, child) {
        return Directionality(
          textDirection: language == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
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
                              ? (darkMode
                                    ? DesertColors.lightText
                                    : Colors.white)
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
                              ? (darkMode
                                    ? DesertColors.lightText
                                    : Colors.white)
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
                              ? (darkMode
                                    ? DesertColors.lightText
                                    : Colors.white)
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
                      onTap: () =>
                          Navigator.pushNamed(context, '/publications'),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color:
                            (currentRoute ?? '').startsWith('/favorite-books')
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
                        tileColor:
                            Colors.transparent, // ✅ ensure default is clear
                        title: Text(
                          language == 'ar' ? 'المفضلة' : 'Favorites',
                          style: TextStyle(
                            color:
                                (currentRoute ?? '').startsWith(
                                  '/favorite-books',
                                )
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

            body: isMobile(context) ? _buildMobileHome() : _buildWebHome(),
            bottomNavigationBar: isMobile(context)
                ? _buildMobileBottomNav(context)
                : null,
          ),
        );
      },
    );
  }

  bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  Widget _buildWebHome() {
    return Stack(
      children: [
        SingleChildScrollView(
          controller: _pageScrollController,
          child: Column(
            children: [
              HeroSection(
                key: heroKey, // ✅ Pass the key
                language: language,
                darkMode: darkMode,
              ),
              PublicationSection(darkMode: darkMode, language: language),
              FavoriteBookSection(language: language, darkMode: darkMode),
              MobileAppSection(
                darkMode: darkMode,
                language: language,
                onShowQR: () => toggleQRDialog(true),
              ),
              ContactSection(language: language, darkMode: darkMode),
              FooterSection(language: language, darkMode: darkMode),
            ],
          ),
        ),
        NavigationBarWidget(
          darkMode: darkMode,
          language: language,
          scrolled: _scrolled,
          toggleDarkMode: toggleDarkMode,
          toggleLanguage: toggleLanguage,
          openDrawer: openDrawer,
        ),
        if (_showQRDialog) _buildQRDialog(),

        // Scroll-to-top button
        if (!isMobile(context))
          AnimatedBuilder(
            animation: _floatingAnimation,
            builder: (context, child) {
              return Positioned(
                bottom: 32,
                right: language == 'ar' ? null : 32,
                left: language == 'ar' ? 32 : null,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _scrolled ? 1.0 : 0.0,
                  child: Transform.translate(
                    offset: Offset(0, math.sin(_floatingAnimation.value) * -5),
                    child: FloatingActionButton(
                      onPressed: _scrollToTop,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [DesertColors.crimson, DesertColors.maroon],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: DesertColors.crimson.withOpacity(0.4),
                              blurRadius: 25,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_up,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMobileHome() {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _pageScrollController,
                child: Column(
                  children: [
                    HeroSection(
                      language: language,
                      darkMode: darkMode,
                      key: heroKey,
                    ),
                    PublicationSection(language: language, darkMode: darkMode),
                    // 👆 ONLY Hero + Recent Events here
                  ],
                ),
              ),
            ),
          ],
        ),

        // 👇 Put your top NavigationBarWidget back here
        NavigationBarWidget(
          darkMode: darkMode,
          language: language,
          scrolled: _scrolled,
          toggleDarkMode: toggleDarkMode,
          toggleLanguage: toggleLanguage,
          openDrawer: openDrawer,
        ),
      ],
    );
  }

  Widget _buildQRDialog() {
    final qrContent = {
      'ar': {
        'title': 'حمل التطبيق الآن',
        'subtitle': 'امسح الكود للتحميل',
        'android': 'أندرويد',
        'ios': 'آيفون',
        'scanText': 'امسح الكود بكاميرا هاتفك',
      },
      'en': {
        'title': 'Download App Now',
        'subtitle': 'Scan QR Code to Download',
        'android': 'Android',
        'ios': 'iPhone',
        'scanText': 'Scan with your phone camera',
      },
    };

    final currentQRContent = qrContent[language]!;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      color: Colors.black.withOpacity(_showQRDialog ? 0.7 : 0.0),
      child: _showQRDialog
          ? Center(
              child: TweenAnimationBuilder(
                duration: Duration(milliseconds: 400),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: 0.8 + (0.2 * value),
                    child: Opacity(
                      opacity: value,
                      child: Container(
                        width: 400,
                        padding: EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: darkMode
                                ? [
                                    DesertColors.darkSurface,
                                    DesertColors.maroon.withOpacity(0.3),
                                    DesertColors.darkBackground,
                                  ]
                                : [
                                    Colors.white,
                                    DesertColors.lightSurface,
                                    DesertColors.camelSand.withOpacity(0.1),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: DesertColors.crimson.withOpacity(0.3),
                              blurRadius: 30,
                              offset: Offset(0, 15),
                            ),
                          ],
                          border: Border.all(
                            color: DesertColors.camelSand.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Close Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      _showQRDialog = false;
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          DesertColors.crimson,
                                          DesertColors.maroon,
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: DesertColors.crimson
                                              .withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),

                            // Title with Animation
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale:
                                      1.0 +
                                      (math.sin(
                                            _pulseController.value *
                                                2 *
                                                math.pi,
                                          ) *
                                          0.05),
                                  child: ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: [
                                        DesertColors.crimson,
                                        DesertColors.primaryGoldDark,
                                      ],
                                    ).createShader(bounds),
                                    child: Text(
                                      currentQRContent['title'] as String,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              },
                            ),
                            SizedBox(height: 8),

                            Text(
                              currentQRContent['subtitle'] as String,
                              style: TextStyle(
                                fontSize: 16,
                                color: darkMode
                                    ? DesertColors.darkText.withOpacity(0.8)
                                    : DesertColors.lightText.withOpacity(0.8),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 32),

                            // QR Code Container with Animation
                            AnimatedBuilder(
                              animation: _rotationController,
                              builder: (context, child) {
                                return Container(
                                  width: 200,
                                  height: 200,
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white,
                                        DesertColors.camelSand.withOpacity(0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: DesertColors.primaryGoldDark
                                            .withOpacity(0.3),
                                        blurRadius: 15,
                                        offset: Offset(0, 8),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: DesertColors.camelSand.withOpacity(
                                        0.5,
                                      ),
                                      width: 3,
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      // QR Code Pattern
                                      Container(
                                        width: double.infinity,
                                        height: double.infinity,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: CustomPaint(
                                          painter: QRCodePainter(
                                            darkMode: darkMode,
                                          ),
                                        ),
                                      ),
                                      // Center Logo
                                      Center(
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                DesertColors.crimson,
                                                DesertColors.maroon,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: DesertColors.crimson
                                                    .withOpacity(0.4),
                                                blurRadius: 8,
                                                offset: Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              'ر',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            SizedBox(height: 24),

                            // Platform Icons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Android
                                _buildPlatformButton(
                                  Icons.android,
                                  currentQRContent['android'] as String,
                                  Color(0xFF3DDC84),
                                ),
                                // iOS
                                _buildPlatformButton(
                                  Icons.phone_iphone,
                                  currentQRContent['ios'] as String,
                                  Color(0xFF007AFF),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),

                            // Scan Text
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    DesertColors.camelSand.withOpacity(0.1),
                                    DesertColors.primaryGoldDark.withOpacity(
                                      0.1,
                                    ),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: DesertColors.camelSand.withOpacity(
                                    0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                currentQRContent['scanText'] as String,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: darkMode
                                      ? DesertColors.darkText.withOpacity(0.8)
                                      : DesertColors.lightText.withOpacity(0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          : SizedBox.shrink(),
    );
  }

  Widget _buildPlatformButton(IconData icon, String label, Color color) {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            0,
            math.sin(_floatingController.value * 2 * math.pi) * 3,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: darkMode
                        ? DesertColors.darkText.withOpacity(0.8)
                        : DesertColors.lightText.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
