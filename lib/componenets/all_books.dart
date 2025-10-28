import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alraya_app/alrayah.dart';
import 'dart:math' as math;
import 'navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AllFavoriteBooksPage extends StatefulWidget {
  final String language;
  final bool darkMode;

  const AllFavoriteBooksPage({
    super.key,
    required this.language,
    required this.darkMode,
  });

  @override
  State<AllFavoriteBooksPage> createState() => _AllFavoriteBooksPageState();
}

class _AllFavoriteBooksPageState extends State<AllFavoriteBooksPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _floatingController;
  late AnimationController _themeController;

  bool _scrolled = false;
  final ScrollController _scrollController = ScrollController();
  bool darkMode = false;
  String language = 'ar';

  String _selectedCategory = 'all';
  String _sortBy = 'favorites';

  // 🔹 Add these:
  User? currentUser;
  List<Map<String, dynamic>> favoriteBooks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _getCurrentUserAndFetchFavorites();
  }

  void _getCurrentUserAndFetchFavorites() async {
    currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await _fetchFavoriteBooks(currentUser!.uid);
    } else {
      // User is not logged in
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchFavoriteBooks(String userId) async {
    print('DEBUG: Fetching favorite books for userId = $userId');

    try {
      final favoritesSnapshot = await FirebaseFirestore.instance
          .collection('favoritebooks')
          .where('userId', isEqualTo: userId)
          .get();

      print('DEBUG: favoritebooks count = ${favoritesSnapshot.docs.length}');

      List<Map<String, dynamic>> fetchedBooks = [];

      // 🔹 Define your four theme colors here
      final List<Color> bookColors = [
        DesertColors.primaryGoldDark,
        DesertColors.crimson,
        DesertColors.camelSand,
        DesertColors.maroon,
      ];

      final random = math.Random();

      for (var favorite in favoritesSnapshot.docs) {
        final rawBookId = favorite['bookId'];
        final bookId = rawBookId.toString().trim(); // ensures safe string match
        print('DEBUG: Processing favorite for bookId = $bookId');

        // 🔹 Fetch the book by its 'Id' field instead of Firestore doc ID
        final bookSnapshot = await FirebaseFirestore.instance
            .collection('tblbooks')
            .where('Id', isEqualTo: bookId)
            .limit(1)
            .get();

        if (bookSnapshot.docs.isEmpty) {
          print('WARNING: Book $bookId not found in tblbooks');
          continue;
        }

        final bookData = bookSnapshot.docs.first.data();
        final authorId = bookData['AuthorId']?.toString().trim();
        print(
          'DEBUG: Book found — title: ${bookData['Title']}, authorId: $authorId',
        );

        // 🔹 Fetch author info safely
        final authorSnapshot = await FirebaseFirestore.instance
            .collection('tblauthors')
            .where('Id', isEqualTo: authorId)
            .limit(1)
            .get();

        final authorName = authorSnapshot.docs.isNotEmpty
            ? authorSnapshot.docs.first['Name']
            : 'Unknown Author';

        print('DEBUG: Author resolved: $authorName');

        // 🔹 Assign a random color from the list
        final randomColor = bookColors[random.nextInt(bookColors.length)];

        fetchedBooks.add({
          'title': bookData['Title'],
          'author': authorName,
          'description': bookData['Description'] ?? '',
          'favorites': '1',
          'color': randomColor,
          'rating': (bookData['Rating'] ?? 4.5).toString(),
        });
      }

      print('DEBUG: Total fetched books = ${fetchedBooks.length}');

      setState(() {
        favoriteBooks = fetchedBooks;
        isLoading = false;
      });

      print(
        'DEBUG: State updated — favoriteBooks length = ${favoriteBooks.length}',
      );
    } catch (e, st) {
      print('ERROR fetching favorite books: $e');
      print(st);
      setState(() => isLoading = false);
    }
  }

  void _initializeControllers() {
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _floatingController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 6),
    )..repeat();

    _scrollController.addListener(() {
      setState(() {
        _scrolled = _scrollController.offset > 50;
      });
    });

    _themeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _pulseController.dispose();
    _scrollController.dispose();
    _themeController.dispose();
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
    // Implement your drawer logic
  }

  @override
  Widget build(BuildContext context) {
    final content = {
      'ar': {
        'title': 'جميع الكتب المفضلة',
        'subtitle': 'مكتبتك الشخصية من الكتب المحبوبة',
        'searchHint': 'ابحث في مفضلاتك...',
        'categories': {
          'all': 'الكل',
          'hadith': 'حديث',
          'literature': 'أدب',
          'prayer': 'دعاء',
          'fiqh': 'فقه',
          'history': 'تاريخ',
        },
        'sortBy': {
          'favorites': 'الأكثر إعجاباً',
          'recent': 'الأحدث',
          'title': 'العنوان',
          'author': 'المؤلف',
        },
        'noResults': 'لا توجد نتائج',
        'totalBooks': 'كتاب',
        'books': [
          {
            'title': 'الكافي في أصول الدين',
            'author': 'الشيخ الكليني',
            'favorites': '1.2K',
            'rating': '4.9',
            'category': 'hadith',
            'categoryName': 'حديث',
            'color': DesertColors.crimson,
            'dateAdded': '2024-01-15',
          },
          {
            'title': 'نهج البلاغة',
            'author': 'الإمام علي عليه السلام',
            'favorites': '2.5K',
            'rating': '5.0',
            'category': 'literature',
            'categoryName': 'أدب',
            'color': DesertColors.camelSand,
            'dateAdded': '2024-01-10',
          },
          {
            'title': 'الصحيفة السجادية',
            'author': 'الإمام زين العابدين عليه السلام',
            'favorites': '890',
            'rating': '4.8',
            'category': 'prayer',
            'categoryName': 'دعاء',
            'color': DesertColors.primaryGoldDark,
            'dateAdded': '2024-01-20',
          },
          {
            'title': 'مفاتيح الجنان',
            'author': 'الشيخ عباس القمي',
            'favorites': '3.1K',
            'rating': '4.9',
            'category': 'prayer',
            'categoryName': 'دعاء',
            'color': DesertColors.maroon,
            'dateAdded': '2024-01-05',
          },
          {
            'title': 'الوسائل الشيعة',
            'author': 'الحر العاملي',
            'favorites': '1.8K',
            'rating': '4.7',
            'category': 'fiqh',
            'categoryName': 'فقه',
            'color': DesertColors.crimson,
            'dateAdded': '2024-01-12',
          },
          {
            'title': 'بحار الأنوار',
            'author': 'العلامة المجلسي',
            'favorites': '2.2K',
            'rating': '4.8',
            'category': 'hadith',
            'categoryName': 'حديث',
            'color': DesertColors.primaryGoldDark,
            'dateAdded': '2024-01-08',
          },
          {
            'title': 'تاريخ الطبري',
            'author': 'الطبري',
            'favorites': '1.5K',
            'rating': '4.6',
            'category': 'history',
            'categoryName': 'تاريخ',
            'color': DesertColors.camelSand,
            'dateAdded': '2024-01-18',
          },
          {
            'title': 'الغدير',
            'author': 'الأميني',
            'favorites': '1.9K',
            'rating': '4.9',
            'category': 'history',
            'categoryName': 'تاريخ',
            'color': DesertColors.maroon,
            'dateAdded': '2024-01-03',
          },
        ],
      },
      'en': {
        'title': 'All Favorite Books',
        'subtitle': 'Your personal library of beloved books',
        'searchHint': 'Search your favorites...',
        'categories': {
          'all': 'All',
          'hadith': 'Hadith',
          'literature': 'Literature',
          'prayer': 'Prayer',
          'fiqh': 'Jurisprudence',
          'history': 'History',
        },
        'sortBy': {
          'favorites': 'Most Liked',
          'recent': 'Recently Added',
          'title': 'Title',
          'author': 'Author',
        },
        'noResults': 'No results found',
        'totalBooks': 'books',
        'books': [
          {
            'title': 'Al-Kafi in Principles of Religion',
            'author': 'Sheikh Al-Kulayni',
            'favorites': '1.2K',
            'rating': '4.9',
            'category': 'hadith',
            'categoryName': 'Hadith',
            'color': DesertColors.crimson,
            'dateAdded': '2024-01-15',
          },
          {
            'title': 'Nahj al-Balagha',
            'author': 'Imam Ali (AS)',
            'favorites': '2.5K',
            'rating': '5.0',
            'category': 'literature',
            'categoryName': 'Literature',
            'color': DesertColors.camelSand,
            'dateAdded': '2024-01-10',
          },
          {
            'title': 'Al-Sahifa al-Sajjadiyya',
            'author': 'Imam Zayn al-Abidin (AS)',
            'favorites': '890',
            'rating': '4.8',
            'category': 'prayer',
            'categoryName': 'Prayer',
            'color': DesertColors.primaryGoldDark,
            'dateAdded': '2024-01-20',
          },
          {
            'title': 'Mafatih al-Jinan',
            'author': 'Sheikh Abbas al-Qummi',
            'favorites': '3.1K',
            'rating': '4.9',
            'category': 'prayer',
            'categoryName': 'Prayer',
            'color': DesertColors.maroon,
            'dateAdded': '2024-01-05',
          },
          {
            'title': 'Wasail al-Shia',
            'author': 'Al-Hurr al-Amili',
            'favorites': '1.8K',
            'rating': '4.7',
            'category': 'fiqh',
            'categoryName': 'Jurisprudence',
            'color': DesertColors.crimson,
            'dateAdded': '2024-01-12',
          },
          {
            'title': 'Bihar al-Anwar',
            'author': 'Allama al-Majlisi',
            'favorites': '2.2K',
            'rating': '4.8',
            'category': 'hadith',
            'categoryName': 'Hadith',
            'color': DesertColors.primaryGoldDark,
            'dateAdded': '2024-01-08',
          },
          {
            'title': 'History of al-Tabari',
            'author': 'Al-Tabari',
            'favorites': '1.5K',
            'rating': '4.6',
            'category': 'history',
            'categoryName': 'History',
            'color': DesertColors.camelSand,
            'dateAdded': '2024-01-18',
          },
          {
            'title': 'Al-Ghadir',
            'author': 'Al-Amini',
            'favorites': '1.9K',
            'rating': '4.9',
            'category': 'history',
            'categoryName': 'History',
            'color': DesertColors.maroon,
            'dateAdded': '2024-01-03',
          },
        ],
      },
    };

    final currentContent = content[language]!;
    final String? currentRoute = ModalRoute.of(context)?.settings.name;
    return Scaffold(
      backgroundColor: darkMode
          ? DesertColors.darkBackground
          : DesertColors.lightBackground,

      endDrawer: Drawer(
        child: Container(
          color: darkMode
              ? DesertColors.darkBackground
              : DesertColors.lightBackground,
          child: Directionality(
            textDirection: language == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr,
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
                    scrolled: _scrolled,
                    toggleDarkMode: toggleDarkMode,
                    toggleLanguage: toggleLanguage,
                    openDrawer: openDrawer,
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    MediaQuery.of(context).size.width < 768 ? 16 : 24,
                    40,
                    MediaQuery.of(context).size.width < 768 ? 16 : 24,
                    32,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: darkMode
                          ? [
                              DesertColors.darkBackground,
                              DesertColors.maroon.withOpacity(0.15),
                              DesertColors.darkSurface,
                            ]
                          : [
                              DesertColors.lightBackground,
                              DesertColors.camelSand.withOpacity(0.15),
                              DesertColors.lightSurface,
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Header Row with Back Button and Title
                      Row(
                        children: [
                          // Red Back Button
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: DesertColors.crimson,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: DesertColors.crimson.withOpacity(
                                      0.3,
                                    ),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(), // Spacer
                          ),
                        ],
                      ),

                      SizedBox(height: 24),

                      // Mobile Container for Title Section
                      MediaQuery.of(context).size.width < 768
                          ? Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 20,
                              ),
                              margin: EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: darkMode
                                    ? DesertColors.darkSurface.withOpacity(0.3)
                                    : Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: DesertColors.primaryGoldDark
                                      .withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                children: [
                                  ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: [
                                        DesertColors.crimson,
                                        DesertColors.primaryGoldDark,
                                        DesertColors.maroon,
                                      ],
                                    ).createShader(bounds),
                                    child: Text(
                                      currentContent['title'] as String,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    currentContent['subtitle'] as String,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: darkMode
                                          ? DesertColors.darkText.withOpacity(
                                              0.8,
                                            )
                                          : DesertColors.lightText.withOpacity(
                                              0.8,
                                            ),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  // Books Count Indicator
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: darkMode
                                          ? DesertColors.darkSurface
                                                .withOpacity(0.7)
                                          : Colors.white.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: DesertColors.primaryGoldDark
                                            .withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      '${(currentContent['books'] as List?)?.length ?? 0} ${currentContent['totalBooks']}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: DesertColors.primaryGoldDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    colors: [
                                      DesertColors.crimson,
                                      DesertColors.primaryGoldDark,
                                      DesertColors.maroon,
                                    ],
                                  ).createShader(bounds),
                                  child: Text(
                                    currentContent['title'] as String,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  currentContent['subtitle'] as String,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: darkMode
                                        ? DesertColors.darkText.withOpacity(0.8)
                                        : DesertColors.lightText.withOpacity(
                                            0.8,
                                          ),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 16),
                                // Books Count Indicator
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: darkMode
                                        ? DesertColors.darkSurface.withOpacity(
                                            0.7,
                                          )
                                        : Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: DesertColors.primaryGoldDark
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    '${(currentContent['books'] as List?)?.length ?? 0} ${currentContent['totalBooks']}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: DesertColors.primaryGoldDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 768 ? 16 : 24,
                vertical: 20,
              ),
              child: Column(
                children: [
                  // Sort By Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.tune,
                        size: 18,
                        color: darkMode
                            ? DesertColors.primaryGoldDark
                            : DesertColors.crimson,
                      ),
                      SizedBox(width: 8),
                      Text(
                        language == 'ar' ? 'ترتيب حسب:' : 'Sort by:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Mobile Container for Sort Options
                  MediaQuery.of(context).size.width < 768
                      ? Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          margin: EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: darkMode
                                ? DesertColors.darkSurface.withOpacity(0.3)
                                : Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: DesertColors.primaryGoldDark.withOpacity(
                                0.2,
                              ),
                            ),
                          ),
                          child: Column(
                            children: [
                              // First Row - 2 filters
                              Row(
                                children:
                                    (currentContent['sortBy']
                                            as Map<String, String>)
                                        .entries
                                        .take(2)
                                        .map(
                                          (entry) => Expanded(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 4,
                                              ),
                                              child: _buildSortChip(
                                                entry.key,
                                                entry.value,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                              SizedBox(height: 12),
                              // Second Row - Remaining 2 filters
                              Row(
                                children:
                                    (currentContent['sortBy']
                                            as Map<String, String>)
                                        .entries
                                        .skip(2)
                                        .take(2)
                                        .map(
                                          (entry) => Expanded(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 4,
                                              ),
                                              child: _buildSortChip(
                                                entry.key,
                                                entry.value,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ],
                          ),
                        )
                      : Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 10,
                          children:
                              (currentContent['sortBy'] as Map<String, String>)
                                  .entries
                                  .map(
                                    (entry) =>
                                        _buildSortChip(entry.key, entry.value),
                                  )
                                  .toList(),
                        ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width < 768 ? 16 : 24,
            ),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                if (isLoading) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 50),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                }

                // Check if user is not logged in
                if (currentUser == null) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 40,
                          horizontal: 24,
                        ),
                        child: Container(
                          padding: EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: darkMode
                                  ? [
                                      DesertColors.darkSurface,
                                      DesertColors.darkBackground,
                                    ]
                                  : [Colors.white, DesertColors.lightSurface],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: DesertColors.primaryGoldDark.withOpacity(
                                0.3,
                              ),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Lock Icon
                              Container(
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: DesertColors.crimson.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.lock_outline_rounded,
                                  size: 48,
                                  color: DesertColors.crimson,
                                ),
                              ),
                              SizedBox(height: 24),

                              // Title
                              Text(
                                language == 'ar'
                                    ? 'يجب تسجيل الدخول'
                                    : 'Login Required',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: darkMode
                                      ? DesertColors.darkText
                                      : DesertColors.lightText,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 12),

                              // Message
                              Text(
                                language == 'ar'
                                    ? 'لعرض كتبك المفضلة، يرجى تسجيل الدخول أو التسجيل كزائر'
                                    : 'To view your favorite books, please sign in or sign up as a visitor',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: darkMode
                                      ? DesertColors.darkText.withOpacity(0.7)
                                      : DesertColors.lightText.withOpacity(0.7),
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 32),

                              // Buttons Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Sign In Button
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        Navigator.pushNamed(context, '/login');
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              DesertColors.crimson,
                                              DesertColors.maroon,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: DesertColors.crimson
                                                  .withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.login_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              language == 'ar'
                                                  ? 'تسجيل الدخول'
                                                  : 'Sign In',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16),

                                  // Sign Up Button
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        Navigator.pushNamed(context, '/login');
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: darkMode
                                              ? DesertColors.darkSurface
                                              : Colors.white,
                                          border: Border.all(
                                            color: DesertColors.primaryGoldDark,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.person_add_rounded,
                                              color:
                                                  DesertColors.primaryGoldDark,
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              language == 'ar'
                                                  ? 'التسجيل'
                                                  : 'Sign Up',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: DesertColors
                                                    .primaryGoldDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final books = favoriteBooks;

                print(
                  'DEBUG: Building grid with ${books.length} favorite books',
                );

                if (books.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.favorite_border_rounded,
                              size: 64,
                              color: darkMode
                                  ? DesertColors.darkText.withOpacity(0.5)
                                  : DesertColors.lightText.withOpacity(0.5),
                            ),
                            SizedBox(height: 16),
                            Text(
                              language == 'ar'
                                  ? 'لم يتم العثور على كتب مفضلة'
                                  : 'No favorite books found',
                              style: TextStyle(
                                fontSize: 16,
                                color: darkMode
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final sortedBooks = _getSortedBooks(books);

                return MediaQuery.of(context).size.width < 768
                    ? SliverPadding(
                        padding: EdgeInsets.all(8),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2, // Always 2 for mobile
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.55,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final book = sortedBooks[index];
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TweenAnimationBuilder(
                                duration: Duration(
                                  milliseconds: 600 + (index * 100),
                                ),
                                tween: Tween<double>(begin: 0, end: 1),
                                builder: (context, double value, child) {
                                  return Transform.translate(
                                    offset: Offset(0, 30 * (1 - value)),
                                    child: Opacity(
                                      opacity: value,
                                      child: _buildBookCard(book),
                                    ),
                                  );
                                },
                              ),
                            );
                          }, childCount: sortedBooks.length),
                        ),
                      )
                    : SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: constraints.crossAxisExtent > 1200
                              ? 4
                              : constraints.crossAxisExtent > 800
                              ? 3
                              : 2,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          childAspectRatio: 0.65,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final book = sortedBooks[index];
                          return TweenAnimationBuilder(
                            duration: Duration(
                              milliseconds: 600 + (index * 100),
                            ),
                            tween: Tween<double>(begin: 0, end: 1),
                            builder: (context, double value, child) {
                              return Transform.translate(
                                offset: Offset(0, 50 * (1 - value)),
                                child: Opacity(
                                  opacity: value,
                                  child: _buildBookCard(book),
                                ),
                              );
                            },
                          );
                        }, childCount: sortedBooks.length),
                      );
              },
            ),
          ),

          // Bottom Spacing
          SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
      bottomNavigationBar: isMobile(context)
          ? _buildMobileBottomNav(context)
          : null,
    );
  }

  bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  Widget _buildSortChip(String key, String label) {
    final isSelected = _sortBy == key;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _sortBy = key;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 8 : 10,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [DesertColors.crimson, DesertColors.maroon],
                )
              : null,
          color: !isSelected
              ? (darkMode
                    ? DesertColors.darkSurface.withOpacity(0.8)
                    : Colors.white.withOpacity(0.9))
              : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? DesertColors.crimson
                : (darkMode
                      ? DesertColors.primaryGoldDark.withOpacity(0.3)
                      : DesertColors.lightText.withOpacity(0.2)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: DesertColors.crimson.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: darkMode
                        ? Colors.black.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isMobile ? 11 : 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (darkMode ? DesertColors.darkText : DesertColors.lightText),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getSortedBooks(List<Map<String, dynamic>> books) {
    final sorted = List<Map<String, dynamic>>.from(books);

    switch (_sortBy) {
      case 'favorites':
        sorted.sort(
          (a, b) => (b['favorites'] ?? '0').toString().compareTo(
            (a['favorites'] ?? '0').toString(),
          ),
        );
        break;

      case 'rating':
        sorted.sort((a, b) {
          final double aRating =
              double.tryParse((a['rating'] ?? '0').toString()) ?? 0.0;
          final double bRating =
              double.tryParse((b['rating'] ?? '0').toString()) ?? 0.0;
          return bRating.compareTo(aRating);
        });
        break;

      case 'title':
        sorted.sort(
          (a, b) => (a['title'] ?? '').toString().compareTo(
            (b['title'] ?? '').toString(),
          ),
        );
        break;

      case 'author':
        sorted.sort(
          (a, b) => (a['author'] ?? '').toString().compareTo(
            (b['author'] ?? '').toString(),
          ),
        );
        break;

      default:
        break;
    }

    return sorted;
  }

  Widget _buildBookCard(Map<String, dynamic> book) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final screenWidth = MediaQuery.of(context).size.width;

    // Dynamic sizing based on screen width
    final cardPadding = isMobile ? 8.0 : 16.0;
    final titleFontSize = isMobile ? (screenWidth < 350 ? 11.0 : 12.0) : 15.0;
    final authorFontSize = isMobile ? (screenWidth < 350 ? 9.0 : 10.0) : 12.0;
    final buttonFontSize = isMobile ? (screenWidth < 350 ? 9.0 : 10.0) : 12.0;
    final categoryFontSize = isMobile ? (screenWidth < 350 ? 8.0 : 9.0) : 10.0;
    final likesFontSize = isMobile ? (screenWidth < 350 ? 8.0 : 9.0) : 10.0;
    final iconSize = isMobile ? (screenWidth < 350 ? 12.0 : 14.0) : 16.0;
    final bookIconSize = isMobile ? (screenWidth < 350 ? 30.0 : 35.0) : 40.0;
    final bookContainerWidth = isMobile
        ? (screenWidth < 350 ? 50.0 : 60.0)
        : 70.0;
    final bookContainerHeight = isMobile
        ? (screenWidth < 350 ? 60.0 : 70.0)
        : 80.0;

    return MouseRegion(
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: darkMode
                  ? [
                      DesertColors.darkSurface,
                      DesertColors.darkSurface.withOpacity(0.9),
                    ]
                  : [Colors.white, DesertColors.lightSurface],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
            boxShadow: [
              BoxShadow(
                color: (book['color'] as Color).withOpacity(0.2),
                blurRadius: isMobile ? 8 : 12,
                offset: Offset(0, isMobile ? 4 : 6),
              ),
              BoxShadow(
                color: darkMode
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.1),
                blurRadius: isMobile ? 6 : 8,
                offset: Offset(0, isMobile ? 2 : 4),
              ),
            ],
            border: Border.all(
              color: (book['color'] as Color).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              // Enhanced Book Cover Section
              Expanded(
                flex: 4,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (book['color'] as Color).withOpacity(0.9),
                        book['color'] as Color,
                        (book['color'] as Color).withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isMobile ? 16 : 20),
                      topRight: Radius.circular(isMobile ? 16 : 20),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Enhanced Book Spine Effect
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: isMobile ? 4 : 6,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(isMobile ? 16 : 20),
                            ),
                          ),
                        ),
                      ),

                      // Enhanced Favorite Heart
                      Positioned(
                        top: isMobile ? 8 : 12,
                        right: isMobile ? 8 : 12,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale:
                                  1.0 +
                                  (math.sin(
                                        _pulseController.value * 2 * math.pi,
                                      ) *
                                      0.1),
                              child: Container(
                                padding: EdgeInsets.all(isMobile ? 6 : 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.95),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: DesertColors.crimson.withOpacity(
                                        0.3,
                                      ),
                                      blurRadius: 6,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.favorite,
                                  color: DesertColors.crimson,
                                  size: isMobile ? 12 : 16,
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Enhanced Book Icon/Illustration
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: bookContainerWidth,
                              height: bookContainerHeight,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(
                                  isMobile ? 8 : 12,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: isMobile ? 6 : 10,
                                    offset: Offset(0, isMobile ? 3 : 5),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.menu_book_rounded,
                                color: book['color'] as Color,
                                size: bookIconSize,
                              ),
                            ),
                            SizedBox(height: isMobile ? 8 : 12),

                            // Enhanced Rating Badge
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 8 : 12,
                                vertical: isMobile ? 4 : 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(
                                  isMobile ? 12 : 15,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    color: DesertColors.primaryGoldDark,
                                    size: isMobile ? 10 : 14,
                                  ),
                                  SizedBox(width: isMobile ? 2 : 4),
                                  Text(
                                    book['rating']!,
                                    style: TextStyle(
                                      fontSize: isMobile ? 9 : 12,
                                      fontWeight: FontWeight.bold,
                                      color: book['color'] as Color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Enhanced Book Details Section
              Expanded(
                flex: 3,
                child: Container(
                  padding: EdgeInsets.all(cardPadding),
                  decoration: BoxDecoration(
                    color: darkMode
                        ? DesertColors.darkSurface.withOpacity(0.5)
                        : Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(isMobile ? 16 : 20),
                      bottomRight: Radius.circular(isMobile ? 16 : 20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Enhanced Title
                      Flexible(
                        child: Text(
                          book['title']!,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                            color: darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText,
                            height: 1.2,
                          ),
                          maxLines: isMobile ? 2 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: isMobile ? 6 : 6),

                      // Enhanced Author
                      Text(
                        book['author']!,
                        style: TextStyle(
                          fontSize: authorFontSize,
                          color: darkMode
                              ? DesertColors.darkText.withOpacity(0.7)
                              : DesertColors.lightText.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      Spacer(),

                      // Enhanced Action Buttons
                      Row(
                        children: [
                          // Enhanced Read Button
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  vertical: isMobile ? 6 : 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      book['color'] as Color,
                                      (book['color'] as Color).withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    isMobile ? 8 : 12,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (book['color'] as Color)
                                          .withOpacity(0.3),
                                      blurRadius: isMobile ? 4 : 6,
                                      offset: Offset(0, isMobile ? 2 : 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.menu_book,
                                      size: iconSize,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: isMobile ? 3 : 6),
                                    Flexible(
                                      child: Text(
                                        language == 'ar' ? 'اقرأ' : 'Read',
                                        style: TextStyle(
                                          fontSize: buttonFontSize,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: isMobile ? 6 : 10),

                          // Enhanced Download Button
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  vertical: isMobile ? 6 : 10,
                                ),
                                decoration: BoxDecoration(
                                  color: darkMode
                                      ? DesertColors.darkSurface
                                      : Colors.white,
                                  border: Border.all(
                                    color: book['color'] as Color,
                                    width: isMobile ? 1.5 : 2,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    isMobile ? 8 : 12,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (book['color'] as Color)
                                          .withOpacity(0.2),
                                      blurRadius: isMobile ? 3 : 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.download_rounded,
                                      size: iconSize,
                                      color: book['color'] as Color,
                                    ),
                                    SizedBox(width: isMobile ? 3 : 6),
                                    Flexible(
                                      child: Text(
                                        language == 'ar' ? 'تحميل' : 'Download',
                                        style: TextStyle(
                                          fontSize: buttonFontSize,
                                          fontWeight: FontWeight.w700,
                                          color: book['color'] as Color,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isMobile ? 6 : 8),

                      // Enhanced Favorites Count
                      Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 6 : 8,
                            vertical: isMobile ? 3 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: DesertColors.crimson.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              isMobile ? 8 : 10,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite,
                                size: isMobile ? 10 : 12,
                                color: DesertColors.crimson,
                              ),
                              SizedBox(width: isMobile ? 2 : 4),
                              Flexible(
                                child: Text(
                                  '${book['favorites']} ${language == 'ar' ? 'إعجاب' : 'likes'}',
                                  style: TextStyle(
                                    fontSize: likesFontSize,
                                    fontWeight: FontWeight.w600,
                                    color: DesertColors.crimson,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
