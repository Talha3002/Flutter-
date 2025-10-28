import 'package:alraya_app/publications/publications_chapters.dart';
import 'package:alraya_app/publications/publications_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alraya_app/alrayah.dart';
import 'package:alraya_app/componenets/navigation.dart';

class PublicationDetailPage extends StatefulWidget {
  Publication publication;
  final bool darkMode;
  final String language;

  PublicationDetailPage({
    Key? key,
    required this.publication,
    required this.darkMode,
    required this.language,
  }) : super(key: key);

  @override
  _PublicationDetailPageState createState() => _PublicationDetailPageState();
}

class _PublicationDetailPageState extends State<PublicationDetailPage> {
  bool darkMode = false;
  String language = 'en';
  bool scrolled = false;
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
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
  Widget build(BuildContext context) {
    final String? currentRoute = ModalRoute.of(context)?.settings.name;
    bool isMobile = MediaQuery.of(context).size.width < 768;
    widget.publication.getTitle(language);
    widget.publication.getAuthor(language);
    widget.publication.getDescription(language);
    return Scaffold(
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
                            darkMode ? Icons.wb_sunny : Icons.nightlight_round,
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
                  language == 'ar' ? 'إصدارات المجلس' : 'Council Publications',
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
                  language == 'ar' ? 'منشورات الراية' : 'Al-Rayah Publications',
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
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Directionality(
                  textDirection: language == 'ar'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: NavigationBarWidget(
                    darkMode: darkMode,
                    language: language,
                    scrolled: scrolled,
                    toggleDarkMode: toggleDarkMode,
                    toggleLanguage: toggleLanguage,
                    openDrawer: openDrawer,
                  ),
                ),

                // Mobile layout
                if (isMobile) _buildMobileLayout(),

                // Desktop layout (unchanged)
                if (!isMobile) _buildDesktopLayout(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildMobileBottomNav(context) : null,
    );
  }

  Widget _buildMobileLayout() {
    return Directionality(
      textDirection: language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMobileBackButton(),
            SizedBox(height: 20),
            _buildMobileMainContent(),
            SizedBox(height: 32),
            _buildMobileChaptersSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Directionality(
              textDirection: language == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBackButton(),
                  SizedBox(height: 32),
                  _buildMainContent(),
                  SizedBox(height: 48),
                  _buildChaptersSection(),
                ],
              ),
            ),
          ),
          SizedBox(width: 48),
          Expanded(flex: 1, child: _buildSidebar()),
        ],
      ),
    );
  }

  Widget _buildMobileBackButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [DesertColors.crimson, DesertColors.maroon],
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: DesertColors.crimson.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back, size: 18, color: Colors.white),
            SizedBox(width: 8),
            Text(
              language == 'ar'
                  ? 'العودة إلى المنشورات'
                  : 'Back to Publications',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          widget.publication.getTitle(language),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            height: 1.3,
          ),
          textAlign: language == 'ar' ? TextAlign.right : TextAlign.left,
        ),
        SizedBox(height: 16),

        // Author and date
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 16,
                  color: DesertColors.primaryGoldDark,
                ),
                SizedBox(width: 8),
                Text(
                  language == 'ar'
                      ? 'أ.د. ليلى الكندي'
                      : 'Prof. Layla Al-Kindi',
                  style: TextStyle(
                    fontSize: 14,
                    color: DesertColors.primaryGoldDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: darkMode
                      ? DesertColors.darkText.withOpacity(0.7)
                      : DesertColors.lightText.withOpacity(0.7),
                ),
                SizedBox(width: 8),
                Text(
                  language == 'ar'
                      ? 'نُشر في 20 فبراير 2024'
                      : 'Published on February 20, 2024',
                  style: TextStyle(
                    fontSize: 14,
                    color: darkMode
                        ? DesertColors.darkText.withOpacity(0.7)
                        : DesertColors.lightText.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 20),

        // Description
        Text(
          language == 'ar'
              ? 'دراسة معمقة للابتكارات الرياضية خلال العصر الذهبي الإسلامي وتأثيرها الدائم على العلوم الحديثة.'
              : 'An in-depth study of mathematical innovations during the Islamic Golden Age and their lasting impact on modern science.',
          style: TextStyle(
            fontSize: 16,
            color: darkMode
                ? DesertColors.darkText.withOpacity(0.8)
                : DesertColors.lightText.withOpacity(0.8),
            height: 1.6,
          ),
          textAlign: language == 'ar' ? TextAlign.right : TextAlign.left,
        ),
        SizedBox(height: 20),

        // Mobile info tags
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildMobileInfoTag(
              language == 'ar' ? 'ثنائية اللغة' : 'Bilingual',
              DesertColors.camelSand,
            ),
            _buildMobileInfoTag(
              language == 'ar' ? 'الرياضيات' : 'Mathematics',
              DesertColors.primaryGoldDark,
            ),
            _buildMobileInfoTag(
              language == 'ar' ? '2 فصول' : '2 Chapters',
              DesertColors.crimson,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileInfoTag(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }


Widget _buildMobileChaptersSection() {
  final parts = widget.publication.parts;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        language == 'ar' ? 'الفصول' : 'Chapters',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: darkMode ? DesertColors.darkText : DesertColors.lightText,
        ),
        textAlign: language == 'ar' ? TextAlign.right : TextAlign.left,
      ),
      SizedBox(height: 20),

      // Mobile chapter cards - single column
      ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: parts.length,
        itemBuilder: (context, index) {
          final part = parts[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookReaderPage(
                    darkMode: darkMode,
                    language: language,
                    publication: widget.publication,
                  ),
                  settings: const RouteSettings(name: '/publications'),
                ),
              );
            },
            child: Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: darkMode
                      ? [DesertColors.darkSurface, DesertColors.darkBackground]
                      : [Colors.white, DesertColors.lightSurface],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DesertColors.camelSand.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Chapter number circle
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          DesertColors.primaryGoldDark,
                          DesertColors.camelSand,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: DesertColors.primaryGoldDark.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),

                  // Chapter content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          part.getTitle(language),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText,
                          ),
                          textAlign: language == 'ar'
                              ? TextAlign.right
                              : TextAlign.left,
                        ),
                        SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: DesertColors.crimson,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '~ ${part.getContent(language).split(" ").length ~/ 150} min read',
                              style: TextStyle(
                                fontSize: 12,
                                color: DesertColors.crimson,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Arrow icon
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: DesertColors.primaryGoldDark,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );
}
  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: DesertColors.crimson,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: DesertColors.crimson.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back, size: 16, color: Colors.white),
            SizedBox(width: 8),
            Text(
              language == 'ar'
                  ? 'العودة إلى المنشورات'
                  : 'Back to Publications',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.publication.getTitle(language),
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            height: 1.2,
          ),
        ),
        SizedBox(height: 24),
        Row(
          children: [
            Icon(
              Icons.person,
              size: 16,
              color: darkMode
                  ? DesertColors.darkText.withOpacity(0.7)
                  : DesertColors.lightText.withOpacity(0.7),
            ),
            SizedBox(width: 8),
            Text(
              widget.publication.getAuthor(language),
              style: TextStyle(
                fontSize: 16,
                color: darkMode
                    ? DesertColors.darkText.withOpacity(0.7)
                    : DesertColors.lightText.withOpacity(0.7),
              ),
            ),
            SizedBox(width: 24),
            Icon(
              Icons.calendar_today,
              size: 16,
              color: darkMode
                  ? DesertColors.darkText.withOpacity(0.7)
                  : DesertColors.lightText.withOpacity(0.7),
            ),
            SizedBox(width: 8),
            Text(
              language == 'ar'
                  ? 'نُشر في 20 فبراير 2024'
                  : 'Published on February 20, 2024',
              style: TextStyle(
                fontSize: 16,
                color: darkMode
                    ? DesertColors.darkText.withOpacity(0.7)
                    : DesertColors.lightText.withOpacity(0.7),
              ),
            ),
          ],
        ),
        SizedBox(height: 32),
        Text(
          widget.publication.getDescription(language),
          style: TextStyle(
            fontSize: 18,
            color: darkMode
                ? DesertColors.darkText.withOpacity(0.8)
                : DesertColors.lightText.withOpacity(0.8),
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildChaptersSection() {
    bool isMobile = MediaQuery.of(context).size.width < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          language == 'ar' ? 'الفصول' : 'Chapters',
          style: TextStyle(
            fontSize: isMobile ? 24 : 32,
            fontWeight: FontWeight.bold,
            color: darkMode ? DesertColors.darkText : DesertColors.lightText,
          ),
        ),
        SizedBox(height: isMobile ? 16 : 24),

        // Desktop grid layout
        if (!isMobile) _buildDesktopChapterGrid(widget.publication),

        // Mobile list layout
        if (isMobile) _buildMobileChaptersList(),
      ],
    );
  }


  Widget _buildDesktopChapterGrid(Publication publication) {
    final parts = widget.publication.parts;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.8,
      ),
      itemCount: parts.length,
      itemBuilder: (context, index) {
        final part = parts[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookReaderPage(
                  darkMode: darkMode,
                  language: language,
                  publication: publication,
                ),
                settings: const RouteSettings(name: '/publications'),
              ),
            );
          },
          child: HoverableChapterCard(
            darkMode: darkMode,
            language: language,
            chapterNumber: index + 1,
            title: part.getTitle(widget.language),
            readTime: "20 min read",
          )
        );
      },
    );
  }

Widget _buildMobileChaptersList() {
  final parts = widget.publication.parts;
  return ListView.builder(
    shrinkWrap: true,
    physics: NeverScrollableScrollPhysics(),
    itemCount: parts.length,
    itemBuilder: (context, index) {
      final part = parts[index];
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookReaderPage(
                darkMode: darkMode,
                language: language,
                publication: widget.publication,
              ),
              settings: const RouteSettings(name: '/publications'),
            ),
          );
        },
        child: Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: darkMode
                  ? [DesertColors.darkSurface, DesertColors.darkBackground]
                  : [Colors.white, DesertColors.lightSurface],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DesertColors.camelSand.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Chapter number circle
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      DesertColors.primaryGoldDark,
                      DesertColors.camelSand,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: DesertColors.primaryGoldDark.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),

              // Chapter content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      part.getTitle(language),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: darkMode
                            ? DesertColors.darkText
                            : DesertColors.lightText,
                      ),
                      textAlign: language == 'ar'
                          ? TextAlign.right
                          : TextAlign.left,
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: DesertColors.crimson,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '~ ${part.getContent(language).split(" ").length ~/ 150} min read',
                          style: TextStyle(
                            fontSize: 12,
                            color: DesertColors.crimson,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: DesertColors.primaryGoldDark,
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildSidebar() {
    return Padding(
      padding: EdgeInsets.only(top: 50),
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: darkMode
              ? DesertColors.darkSurface
              : DesertColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: DesertColors.camelSand.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              language == 'ar' ? 'الوصف' : 'Description',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: darkMode
                    ? DesertColors.darkText
                    : DesertColors.lightText,
              ),
            ),
            SizedBox(height: 16),
            _buildSidebarItem(
              language == 'ar' ? 'الفئة' : 'Category',
              '',
              isCategory: true,
            ),
            SizedBox(height: 16),
            _buildSidebarItem(
              language == 'ar' ? 'اللغة' : 'Language',
              language == 'ar' ? 'ثنائية اللغة' : 'Bilingual',
            ),
            SizedBox(height: 16),
            _buildSidebarItem(
              language == 'ar' ? 'الفصول' : 'Chapters',
              '${widget.publication.parts.length}',
              isChapters: true,
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
    String label,
    String value, {
    bool isCategory = false,
    bool isChapters = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: darkMode
                ? DesertColors.darkText.withOpacity(0.7)
                : DesertColors.lightText.withOpacity(0.7),
          ),
        ),
        SizedBox(height: 8),
        if (isCategory)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: DesertColors.camelSand,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              widget.publication.getCategory(language),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: DesertColors.maroon,
              ),
            ),
          )
        else if (isChapters)
          Row(
            children: [
              Icon(Icons.book, size: 16, color: DesertColors.primaryGoldDark),
              SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: DesertColors.primaryGoldDark,
                ),
              ),
            ],
          )
        else
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
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

class HoverableChapterCard extends StatefulWidget {
  final bool darkMode;
  final String language;
  final int chapterNumber;
  final String title;
  final String readTime;

  const HoverableChapterCard({
    Key? key,
    required this.darkMode,
    required this.language,
    required this.chapterNumber,
    required this.title,
    required this.readTime,
  }) : super(key: key);

  @override
  _HoverableChapterCardState createState() => _HoverableChapterCardState();
}

class _HoverableChapterCardState extends State<HoverableChapterCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _translateAnimation;
  late Animation<double> _shadowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    _translateAnimation = Tween<double>(begin: 0.0, end: -4.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _shadowAnimation = Tween<double>(begin: 8.0, end: 16.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
        _animationController.forward();
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
        _animationController.reverse();
      },
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _translateAnimation.value),
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: widget.darkMode
                    ? DesertColors.darkSurface
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: DesertColors.camelSand.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isHovered
                        ? DesertColors.camelSand.withOpacity(0.4)
                        : DesertColors.maroon.withOpacity(0.1),
                    blurRadius: _shadowAnimation.value,
                    offset: Offset(0, _shadowAnimation.value / 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          DesertColors.primaryGoldDark,
                          DesertColors.camelSand,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.chapterNumber}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: widget.darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: widget.darkMode
                                  ? DesertColors.darkText.withOpacity(0.6)
                                  : DesertColors.lightText.withOpacity(0.6),
                            ),
                            SizedBox(width: 4),
                            Text(
                              widget.readTime,
                              style: TextStyle(
                                fontSize: 14,
                                color: widget.darkMode
                                    ? DesertColors.darkText.withOpacity(0.6)
                                    : DesertColors.lightText.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: DesertColors.primaryGoldDark,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
