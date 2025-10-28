import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alraya_app/alrayah.dart';
import 'package:alraya_app/componenets/navigation.dart';
import 'publications_section.dart';

class ChapterData {
  final String id;
  final String titleAr;
  final String titleEn;
  final String contentAr;
  final String contentEn;
  final int chapterNumber;
  final String readTime;

  ChapterData({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.contentAr,
    required this.contentEn,
    required this.chapterNumber,
    required this.readTime,
  });
}

class BookReaderPage extends StatefulWidget {
  final bool darkMode;
  final String language;
  Publication publication;
  BookReaderPage({
    Key? key,
    required this.darkMode,
    required this.language,
    required this.publication,
  }) : super(key: key);

  @override
  _BookReaderPageState createState() => _BookReaderPageState();
}

class _BookReaderPageState extends State<BookReaderPage>
    with TickerProviderStateMixin {
  late AnimationController _contentController;
  late Animation<double> _contentAnimation;
  late AnimationController _sidebarController;
  late Animation<Offset> _sidebarAnimation;

  late bool darkMode;
  late String language;

  int currentChapterIndex = 0;
  bool sidebarOpen = true;
  ScrollController _scrollController = ScrollController();
  bool scrolled = false;

  late List<PublicationPart> chapters;

  @override
  void initState() {
    super.initState();

    darkMode = widget.darkMode;
    language = widget.language;

    chapters = widget.publication.parts;
    _contentController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _contentAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeInOut),
    );

    _sidebarController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _sidebarAnimation =
        Tween<Offset>(begin: Offset(1.0, 0.0), end: Offset(0.0, 0.0)).animate(
          CurvedAnimation(parent: _sidebarController, curve: Curves.easeInOut),
        );

    _contentController.forward();
    _sidebarController.forward();

    _scrollController.addListener(() {
      setState(() {
        scrolled = _scrollController.offset > 50;
      });
    });
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
    Scaffold.of(context).openDrawer();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _sidebarController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void navigateToChapter(int index) {
    if (index != currentChapterIndex && index >= 0 && index < chapters.length) {
      _contentController.reverse().then((_) {
        setState(() {
          currentChapterIndex = index;
        });
        _contentController.forward();
        _scrollController.animateTo(
          0,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
      HapticFeedback.lightImpact();
    }
  }

  void toggleSidebar() {
    setState(() {
      sidebarOpen = !sidebarOpen;
    });
    if (sidebarOpen) {
      _sidebarController.forward();
    } else {
      _sidebarController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = this.darkMode;
    final language = this.language;
    final String? currentRoute = ModalRoute.of(context)?.settings.name;

    final currentChapter = chapters[currentChapterIndex];
    return Directionality(
      textDirection: language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
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
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(80),
          child: LayoutBuilder(
            builder: (context, constraints) {
              bool isMobile = MediaQuery.of(context).size.width < 768;

              return NavigationBarWidget(
                darkMode: darkMode,
                language: language,
                scrolled: scrolled,
                toggleDarkMode: toggleDarkMode,
                toggleLanguage: toggleLanguage,
                openDrawer: () {
                  if (isMobile) {
                    Scaffold.of(
                      context,
                    ).openDrawer(); // <-- will open drawer on mobile
                  }
                },
              );
            },
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            bool isMobile = constraints.maxWidth < 768;

            if (isMobile) {
              return _buildMobileLayout();
            } else {
              return _buildDesktopLayout();
            }
          },
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

  Widget _buildMobileLayout() {
    final currentChapter = chapters[currentChapterIndex];

    return Directionality(
      textDirection: language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            // Back Button (Mobile)
            Container(
              width: double.infinity,
              margin: EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
                icon: Icon(
                  language == 'ar' ? Icons.arrow_forward : Icons.arrow_back,
                  color: Colors.white,
                  size: 18,
                ),
                label: Text(
                  language == 'ar'
                      ? 'العودة إلى المنشورات'
                      : 'Back to Publication',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesertColors.crimson,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),

            // Table of Contents Section (Mobile)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: DesertColors.camelSand.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: DesertColors.primaryGoldDark.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: ExpansionTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: DesertColors.primaryGoldDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.menu_book, color: Colors.white, size: 20),
                ),
                title: Text(
                  language == 'ar' ? 'جدول المحتويات' : 'Table of Contents',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                ),
                subtitle: Text(
                  currentChapter.getTitle(language),
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText)
                            .withOpacity(0.7),
                  ),
                ),
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: chapters.asMap().entries.map((entry) {
                        int index = entry.key;
                       PublicationPart chapter = entry.value;
                        bool isActive = index == currentChapterIndex;

                        return Container(
                          margin: EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? DesertColors.primaryGoldDark.withOpacity(0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isActive
                                ? Border.all(
                                    color: DesertColors.primaryGoldDark,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? DesertColors.primaryGoldDark
                                    : DesertColors.camelSand.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : DesertColors.maroon,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              chapter.getTitle(language),
                              style: TextStyle(
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText,
                              ),
                            ),
                            subtitle: Text(
                            '~ ${chapter.getContent(language).split(" ").length ~/ 150} min read',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    (darkMode
                                            ? DesertColors.darkText
                                            : DesertColors.lightText)
                                        .withOpacity(0.6),
                              ),
                            ),
                            onTap: () => navigateToChapter(index),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Book Title and Chapter Info (Mobile)
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    DesertColors.camelSand.withOpacity(0.1),
                    DesertColors.primaryGoldDark.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: DesertColors.primaryGoldDark.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Book Title
                  Text(
                    currentChapter.getTitle(language).toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: DesertColors.primaryGoldDark,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 12),

                  // Chapter Title
                  Text(
                    currentChapter.getTitle(language),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Chapter Info Row
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: DesertColors.camelSand,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.menu_book,
                              size: 16,
                              color: DesertColors.maroon,
                            ),
                            SizedBox(width: 4),
                            Text(
                              language == 'ar'
                                  ? 'الفصل ${currentChapterIndex + 1} من ${chapters.length}'
                                  : 'Chapter ${currentChapterIndex + 1} of ${chapters.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: DesertColors.maroon,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: DesertColors.primaryGoldDark.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: DesertColors.primaryGoldDark,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '~ ${currentChapter.getContent(language).split(" ").length ~/ 150} min read',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: DesertColors.primaryGoldDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content Container (Mobile)
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: darkMode
                    ? DesertColors.darkSurface
                    : DesertColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: DesertColors.camelSand.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: AnimatedBuilder(
                animation: _contentAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _contentAnimation.value,
                    child: Text(
                      currentChapter.getContent(language),
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.8,
                        color: darkMode
                            ? DesertColors.darkText
                            : DesertColors.lightText,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Navigation Buttons (Mobile)
            Container(
              margin: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Previous Chapter Button
                  if (currentChapterIndex > 0)
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: 12),
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            navigateToChapter(currentChapterIndex - 1),
                        icon: Icon(
                          language == 'ar'
                              ? Icons.arrow_forward
                              : Icons.arrow_back,
                          color: darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText,
                        ),
                        label: Text(
                          language == 'ar'
                              ? 'الفصل السابق'
                              : 'Previous Chapter',
                          style: TextStyle(
                            color: darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                  // Next Chapter Button
                  if (currentChapterIndex < chapters.length - 1)
                    Container(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            navigateToChapter(currentChapterIndex + 1),
                        icon: Icon(
                          language == 'ar'
                              ? Icons.arrow_back
                              : Icons.arrow_forward,
                          color: Colors.white,
                        ),
                        label: Text(
                          language == 'ar' ? 'الفصل التالي' : 'Next Chapter',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesertColors.primaryGoldDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final currentChapter = chapters[currentChapterIndex];

    return Stack(
      children: [
        // Main Content Area
        Positioned.fill(
          right: sidebarOpen ? 320 : 0,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button
                Container(
                  margin: EdgeInsets.only(bottom: 24),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    icon: Icon(
                      language == 'ar' ? Icons.arrow_forward : Icons.arrow_back,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: Text(
                      language == 'ar'
                          ? 'العودة إلى المنشورات'
                          : 'Back to Publication',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesertColors.crimson,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),

                // Book Title
                Text(
                  currentChapter.getTitle(language),
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText)
                            .withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 12),

                // Chapter Title
                Text(
                  currentChapter.getTitle(language),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 16),

                // Chapter Info
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: DesertColors.camelSand.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.menu_book,
                            size: 14,
                            color: darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText,
                          ),
                          SizedBox(width: 4),
                          Text(
                            language == 'ar'
                                ? 'الفصل ${currentChapterIndex + 1} من ${chapters.length}'
                                : 'Chapter ${currentChapterIndex + 1} of ${chapters.length}',

                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: DesertColors.primaryGoldDark.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '~ ${currentChapter.getContent(language).split(" ").length ~/ 150} min read',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 32),

                // Content
                AnimatedBuilder(
                  animation: _contentAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _contentAnimation.value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - _contentAnimation.value)),
                        child: Container(
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: darkMode
                                ? DesertColors.darkSurface
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentChapter.getContent(language),
                                style: TextStyle(
                                  fontSize: 18,
                                  height: 1.7,
                                  color: darkMode
                                      ? DesertColors.darkText
                                      : DesertColors.lightText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 48),

                // Navigation Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Previous Chapter
                    currentChapterIndex > 0
                        ? TextButton.icon(
                            onPressed: () =>
                                navigateToChapter(currentChapterIndex - 1),
                            icon: Icon(
                              language == 'ar'
                                  ? Icons.arrow_forward
                                  : Icons.arrow_back,
                              color: darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText,
                            ),
                            label: Text(
                              language == 'ar'
                                  ? 'الفصل السابق'
                                  : 'Previous Chapter',
                              style: TextStyle(
                                color: darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText,
                              ),
                            ),
                          )
                        : SizedBox(),

                    // Next Chapter
                    currentChapterIndex < chapters.length - 1
                        ? ElevatedButton.icon(
                            onPressed: () =>
                                navigateToChapter(currentChapterIndex + 1),
                            icon: Icon(
                              language == 'ar'
                                  ? Icons.arrow_back
                                  : Icons.arrow_forward,
                              color: Colors.white,
                            ),
                            label: Text(
                              language == 'ar'
                                  ? 'الفصل التالي'
                                  : 'Next Chapter',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DesertColors.primaryGoldDark,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                          )
                        : SizedBox(),
                  ],
                ),
                SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Sidebar
        if (sidebarOpen)
          Positioned(
            top: 0,
            bottom: 300,
            right: 0,
            child: SlideTransition(
              position: _sidebarAnimation,
              child: Container(
                width: 320,
                margin: EdgeInsets.only(top: 50, left: 20, bottom: 20),
                decoration: BoxDecoration(
                  color: darkMode
                      ? DesertColors.darkSurface
                      : DesertColors.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: Offset(-5, 0),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sidebar Header
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color:
                                (darkMode
                                        ? DesertColors.darkText
                                        : DesertColors.lightText)
                                    .withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            language == 'ar'
                                ? 'جدول المحتويات'
                                : 'Table of Contents',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText,
                            ),
                          ),
                          IconButton(
                            onPressed: toggleSidebar,
                            icon: Icon(
                              Icons.close,
                              color: darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    // Chapter List
                    Flexible(
                      child: Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.6,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.all(16),
                          itemCount: chapters.length,
                          itemBuilder: (context, index) {
                            final chapter = chapters[index];
                            final isActive = index == currentChapterIndex;

                            return Container(
                              margin: EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? DesertColors.camelSand.withOpacity(0.3)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: isActive
                                    ? Border.all(
                                        color: DesertColors.primaryGoldDark,
                                        width: 2,
                                      )
                                    : null,
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                leading: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? DesertColors.primaryGoldDark
                                        : (darkMode
                                                  ? DesertColors.darkText
                                                  : DesertColors.lightText)
                                              .withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: isActive
                                            ? Colors.white
                                            : (darkMode
                                                  ? DesertColors.darkText
                                                  : DesertColors.lightText),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  chapter.getTitle(language),
                                  style: TextStyle(
                                    color: darkMode
                                        ? DesertColors.darkText
                                        : DesertColors.lightText,
                                    fontWeight: isActive
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  '~ ${chapter.getContent(language).split(" ").length ~/ 150} min read',
                                  style: TextStyle(
                                    color:
                                        (darkMode
                                                ? DesertColors.darkText
                                                : DesertColors.lightText)
                                            .withOpacity(0.6),
                                    fontSize: 11,
                                  ),
                                ),
                                onTap: () => navigateToChapter(index),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Sidebar Toggle Button (when closed)
        if (!sidebarOpen)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: darkMode ? DesertColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(-2, 0),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: toggleSidebar,
                icon: RotatedBox(
                  quarterTurns: language == 'ar' ? 1 : 3,
                  child: Icon(
                    Icons.arrow_back_ios,
                    color: darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMobileBottomNav(BuildContext context) {
    final String? currentRoute = ModalRoute.of(context)?.settings.name;

    return Directionality(
      textDirection: language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
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
