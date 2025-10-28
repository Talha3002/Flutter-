import 'package:alraya_app/componenets/all_books.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:alraya_app/alrayah.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Add this RIGHT AFTER your imports, BEFORE the FavoriteBookSection class
class FavoriteBooksCache {
  static final FavoriteBooksCache _instance = FavoriteBooksCache._internal();
  factory FavoriteBooksCache() => _instance;
  FavoriteBooksCache._internal();

  // Cache structure: userId -> List of enriched book data
  final Map<String, List<Map<String, dynamic>>> _cache = {};

  bool hasCache(String userId) => _cache.containsKey(userId);

  List<Map<String, dynamic>>? getCache(String userId) => _cache[userId];

  void setCache(String userId, List<Map<String, dynamic>> data) {
    _cache[userId] = data;
  }

  void clearCache(String userId) {
    _cache.remove(userId);
  }

  void clearAllCache() {
    _cache.clear();
  }
}

class FavoriteBookSection extends StatefulWidget {
  final String language;
  final bool darkMode;

  const FavoriteBookSection({
    super.key,
    required this.language,
    required this.darkMode,
  });

  @override
  State<FavoriteBookSection> createState() => _FavoriteBookSectionState();
}

class _FavoriteBookSectionState extends State<FavoriteBookSection>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _floatingController;
  late AnimationController _scrollController;
  late AnimationController _pulseController;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? currentUser;
  Stream<QuerySnapshot>? _favoritesStream;

  final FavoriteBooksCache _cache = FavoriteBooksCache();
  List<Map<String, dynamic>>? _cachedBooks;
  bool _isLoadingFromFirestore = false;

  @override
  void initState() {
    super.initState();
    currentUser = _auth.currentUser;

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _scrollController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    if (currentUser != null) {
      print('DEBUG: currentUser found: ${currentUser!.uid}');
      _favoritesStream = _firestore
          .collection('favoritebooks')
          .where('userId', isEqualTo: currentUser!.uid)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots();
    } else {
      print('DEBUG: No user signed in');
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _floatingController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = widget.darkMode;
    final language = widget.language;
    final content = {
      'ar': {
        'title': 'الكتب المفضلة',
        'subtitle': 'مجموعة مختارة من أفضل الكتب المحبوبة لدى المجتمع',
        'viewAll': 'عرض جميع المفضلة',
        'addedBy': 'أضيف بواسطة',
        'favoritedBy': 'أعجب به',
        'books': [
          {
            'title': 'الكافي في أصول الدين',
            'author': 'الشيخ الكليني',
            'addedBy': ' أنت',
            'favorites': '1.2K',
            'rating': '4.9',
            'category': 'حديث',
            'color': DesertColors.crimson,
          },
          {
            'title': 'نهج البلاغة',
            'author': 'الإمام علي عليه السلام',
            'addedBy': ' أنت',
            'favorites': '2.5K',
            'rating': '5.0',
            'category': 'أدب',
            'color': DesertColors.camelSand,
          },
          {
            'title': 'الصحيفة السجادية',
            'author': 'الإمام زين العابدين عليه السلام',
            'addedBy': ' أنت',
            'favorites': '890',
            'rating': '4.8',
            'category': 'دعاء',
            'color': DesertColors.primaryGoldDark,
          },
        ],
      },
      'en': {
        'title': 'Favorite Books',
        'subtitle':
            'A curated collection of the most beloved books by our community',
        'viewAll': 'View All Favorites',
        'addedBy': 'Added by',
        'favoritedBy': 'Favorited by',
        'books': [
          {
            'title': 'Al-Kafi in Principles of Religion',
            'author': 'Sheikh Al-Kulayni',
            'addedBy': 'You',
            'favorites': '1.2K',
            'rating': '4.9',
            'category': 'Hadith',
            'color': DesertColors.crimson,
          },
          {
            'title': 'Nahj al-Balagha',
            'author': 'Imam Ali (AS)',
            'addedBy': 'You',
            'favorites': '2.5K',
            'rating': '5.0',
            'category': 'Literature',
            'color': DesertColors.camelSand,
          },
          {
            'title': 'Al-Sahifa al-Sajjadiyya',
            'author': 'Imam Zayn al-Abidin (AS)',
            'addedBy': 'You',
            'favorites': '890',
            'rating': '4.8',
            'category': 'Prayer',
            'color': DesertColors.primaryGoldDark,
          },
        ],
      },
    };

    final currentContent = content[language]!;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 80, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: darkMode
              ? [
                  DesertColors.darkBackground,
                  DesertColors.maroon.withOpacity(0.1),
                  DesertColors.darkSurface,
                ]
              : [
                  DesertColors.lightBackground,
                  DesertColors.camelSand.withOpacity(0.1),
                  DesertColors.lightSurface,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        children: [
          // Section Header with Crown Icon
          TweenAnimationBuilder(
            duration: Duration(milliseconds: 1000),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Transform.translate(
                offset: Offset(0, 50 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: Column(
                    children: [
                      // Crown Icon Animation
                      AnimatedBuilder(
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
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    DesertColors.primaryGoldDark,
                                    DesertColors.camelSand,
                                    DesertColors.primaryGoldDark.withOpacity(
                                      0.3,
                                    ),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: DesertColors.primaryGoldDark
                                        .withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.favorite,
                                size: 35,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 24),

                      // Title with Gradient
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
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Subtitle
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              DesertColors.camelSand.withOpacity(0.1),
                              DesertColors.primaryGoldDark.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: DesertColors.primaryGoldDark.withOpacity(
                              0.3,
                            ),
                          ),
                        ),
                        child: Text(
                          currentContent['subtitle'] as String,
                          style: TextStyle(
                            fontSize: 18,
                            color: darkMode
                                ? DesertColors.darkText.withOpacity(0.9)
                                : DesertColors.lightText.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 64),

          // Books Horizontal Scroll
          SizedBox(
            height: 450,
            child: Center(
              child: currentUser == null
                  ? Text(
                      language == 'ar'
                          ? 'لرؤية كتبك المفضلة، يرجى التسجيل.'
                          : 'To view your favorite books, please sign up.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: darkMode
                            ? DesertColors.darkText
                            : DesertColors.lightText,
                      ),
                      textAlign: TextAlign.center,
                    )
                  : _buildCachedFavoritesList(),
            ),
          ),

          SizedBox(height: 48),

          // View All Button with Special Styling
          TweenAnimationBuilder(
            duration: Duration(milliseconds: 1000),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AllFavoriteBooksPage(
                            language: language,
                            darkMode: darkMode,
                          ),
                          settings: const RouteSettings(name: '/'),
                        ),
                      );
                    },
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 50,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                DesertColors.primaryGoldDark,
                                DesertColors.camelSand,
                                DesertColors.crimson,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: DesertColors.primaryGoldDark.withOpacity(
                                  0.4,
                                ),
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Text(
                                currentContent['viewAll'] as String,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              AnimatedBuilder(
                                animation: _rotationController,
                                builder: (context, child) {
                                  return Transform.rotate(
                                    angle:
                                        math.sin(
                                          _pulseController.value * 2 * math.pi,
                                        ) *
                                        0.1,
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCachedFavoritesList() {
    final darkMode = widget.darkMode;
    final language = widget.language;

    // Check cache first
    if (_cachedBooks != null) {
      print('DEBUG: Rendering from CACHE (${_cachedBooks!.length} books)');

      if (_cachedBooks!.isEmpty) {
        return Text(
          language == 'ar'
              ? 'لم تحدد أي كتاب كمفضل حتى الآن.'
              : 'You havent marked any favorite book yet.',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: darkMode ? DesertColors.darkText : DesertColors.lightText,
          ),
          textAlign: TextAlign.center,
        );
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _cachedBooks!.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 280,
                child: _buildEnrichedBookCard(data, index),
              ),
            );
          }).toList(),
        ),
      );
    }

    // If no cache and not loading, start loading
    if (!_isLoadingFromFirestore) {
      _isLoadingFromFirestore = true;
      _loadFavoritesOptimized();
    }

    return CircularProgressIndicator();
  }

  Future<void> _loadFavoritesOptimized() async {
    if (currentUser == null) return;

    final userId = currentUser!.uid;
    print('DEBUG: Starting optimized load for user $userId');

    try {
      // Check memory cache
      if (_cache.hasCache(userId)) {
        print('DEBUG: Loading from MEMORY CACHE');
        setState(() {
          _cachedBooks = _cache.getCache(userId);
          _isLoadingFromFirestore = false;
        });
        return;
      }

      // STEP 1: Get all favorite book IDs in ONE query
      final favoritesSnapshot = await _firestore
          .collection('favoritebooks')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();

      if (favoritesSnapshot.docs.isEmpty) {
        print('DEBUG: No favorites found');
        setState(() {
          _cachedBooks = [];
          _isLoadingFromFirestore = false;
        });
        _cache.setCache(userId, []);
        return;
      }

      final bookIds = favoritesSnapshot.docs
          .map((doc) => (doc.data()['bookId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();

      print('DEBUG: Found ${bookIds.length} favorite book IDs: $bookIds');

      // STEP 2: Fetch ALL books in ONE query (batch fetch)
      final booksSnapshot = await _firestore
          .collection('tblbooks')
          .where('Id', whereIn: bookIds)
          .get();

      print('DEBUG: Fetched ${booksSnapshot.docs.length} books from tblbooks');

      // STEP 3: Extract unique author IDs
      final authorIds = booksSnapshot.docs
          .map((doc) => (doc.data()['AuthorId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      print('DEBUG: Found ${authorIds.length} unique author IDs: $authorIds');

      // STEP 4: Fetch ALL authors in ONE query (batch fetch)
      final authorsSnapshot = await _firestore
          .collection('tblauthors')
          .where('Id', whereIn: authorIds)
          .get();

      print('DEBUG: Fetched ${authorsSnapshot.docs.length} authors');

      // STEP 5: Fetch ALL like counts in ONE query (batch fetch)
      final likesSnapshot = await _firestore
          .collection('favoritebooks')
          .where('bookId', whereIn: bookIds)
          .get();

      print('DEBUG: Fetched ${likesSnapshot.docs.length} like records');

      // STEP 6: Build lookup maps IN MEMORY (no more queries!)
      final Map<String, Map<String, dynamic>> booksMap = {
        for (var doc in booksSnapshot.docs)
          doc.data()['Id'].toString(): doc.data(),
      };

      final Map<String, String> authorsMap = {
        for (var doc in authorsSnapshot.docs)
          doc.data()['Id'].toString(): doc.data()['Name'] ?? 'Unknown Author',
      };

      final Map<String, int> likesMap = {};
      for (var doc in likesSnapshot.docs) {
        final bookId = doc.data()['bookId'].toString();
        likesMap[bookId] = (likesMap[bookId] ?? 0) + 1;
      }

      // STEP 7: Combine all data IN MEMORY
      final List<Map<String, dynamic>> enrichedBooks = [];
      for (var bookId in bookIds) {
        final bookData = booksMap[bookId];
        if (bookData == null) continue;

        final authorId = bookData['AuthorId']?.toString() ?? '';
        final authorName = authorsMap[authorId] ?? 'Unknown Author';
        final likeCount = likesMap[bookId] ?? 0;

        enrichedBooks.add({
          'bookId': bookId,
          'title': bookData['Title'] ?? 'Untitled',
          'authorName': authorName,
          'description': bookData['Description'] ?? '',
          'likeCount': likeCount,
        });
      }

      print('DEBUG: Successfully enriched ${enrichedBooks.length} books');

      // STEP 8: Cache and update UI
      _cache.setCache(userId, enrichedBooks);
      setState(() {
        _cachedBooks = enrichedBooks;
        _isLoadingFromFirestore = false;
      });

      print('DEBUG: ✅ Load complete! Cached for future use.');
    } catch (e) {
      print('ERROR: Failed to load favorites: $e');
      setState(() {
        _cachedBooks = [];
        _isLoadingFromFirestore = false;
      });
    }
  }

  Widget _buildEnrichedBookCard(Map<String, dynamic> data, int index) {
    final darkMode = widget.darkMode;
    final language = widget.language;

    final title = data['title'] ?? 'Untitled';
    final authorName = data['authorName'] ?? 'Unknown Author';
    final likeCount = data['likeCount'] ?? 0;

    // Color cycle
    final List<Color> colorCycle = [
      DesertColors.crimson,
      DesertColors.primaryGoldDark,
      DesertColors.camelSand,
    ];
    final Color cardTopColor = colorCycle[index % colorCycle.length];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: darkMode
              ? [
                  DesertColors.darkSurface,
                  DesertColors.darkSurface.withOpacity(0.8),
                ]
              : [Colors.white, DesertColors.lightSurface.withOpacity(0.9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cardTopColor.withOpacity(0.15),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
        border: Border.all(color: cardTopColor.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardTopColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.favorite,
                        color: cardTopColor,
                        size: 14,
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 50,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.menu_book,
                        color: cardTopColor,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    authorName,
                    style: TextStyle(
                      fontSize: 11,
                      color: darkMode
                          ? DesertColors.darkText.withOpacity(0.7)
                          : DesertColors.lightText.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            debugPrint("DEBUG: Download clicked for '$title'");
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: cardTopColor,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.download_rounded,
                                  size: 14,
                                  color: cardTopColor,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  language == 'ar' ? 'تحميل' : 'Download',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: cardTopColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            debugPrint("DEBUG: Read clicked for '$title'");
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: cardTopColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.menu_book,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  language == 'ar' ? 'اقرأ' : 'Read',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$likeCount ${language == 'ar' ? 'أعجب به' : 'favorited'}',
                        style: TextStyle(
                          fontSize: 9,
                          color: cardTopColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.favorite, size: 10, color: cardTopColor),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteBookCard(Map<String, dynamic> data, int index) {
    final darkMode = widget.darkMode;
    final language = widget.language;
    final bookId = data['bookId'];
    debugPrint("DEBUG: Building favorite card for bookId = $bookId");

    // 🔄 Cycle color pattern for each book
    final List<Color> colorCycle = [
      DesertColors.crimson,
      DesertColors.primaryGoldDark,
      DesertColors.camelSand,
    ];
    final Color cardTopColor = colorCycle[index % colorCycle.length];

    return FutureBuilder<QuerySnapshot>(
      future: _firestore
          .collection('tblbooks')
          .where('Id', isEqualTo: bookId.toString())
          .limit(1)
          .get(),
      builder: (context, bookSnapshot) {
        if (bookSnapshot.hasError) {
          debugPrint("DEBUG: Error fetching book data: ${bookSnapshot.error}");
          return Text("Error fetching book data");
        }

        if (!bookSnapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final docs = bookSnapshot.data!.docs;
        if (docs.isEmpty) {
          debugPrint("DEBUG: No document found in tblbooks for bookId=$bookId");
          return Text("Book data not found");
        }

        final bookData = docs.first.data() as Map<String, dynamic>;
        final title = bookData['Title'] ?? 'Untitled';
        final description = bookData['Description'] ?? '';
        final authorId = bookData['AuthorId'];

        debugPrint(
          "DEBUG: Book loaded -> title='$title', authorId=$authorId, description length=${description.length}",
        );

        return FutureBuilder<QuerySnapshot>(
          future: _firestore
              .collection('tblauthors')
              .where('Id', isEqualTo: authorId.toString())
              .limit(1)
              .get(),

          builder: (context, authorSnapshot) {
            if (authorSnapshot.hasError) {
              debugPrint(
                "DEBUG: Error fetching author: ${authorSnapshot.error}",
              );
              return Text("Error fetching author");
            }

            if (!authorSnapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            final docs = authorSnapshot.data!.docs;
            if (docs.isEmpty) {
              debugPrint("DEBUG: No author found for authorId=$authorId");
              return Text("Author not found");
            }

            final authorData = docs.first.data() as Map<String, dynamic>;
            final authorName = authorData['Name'] ?? 'Unknown Author';

            debugPrint("DEBUG: Author name resolved -> $authorName");

            return StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('favoritebooks')
                  .where('bookId', isEqualTo: bookId)
                  .snapshots(),
              builder: (context, favSnapshot) {
                int likeCount = 0;
                if (favSnapshot.hasData) {
                  likeCount = favSnapshot.data!.docs.length;
                }

                debugPrint(
                  "DEBUG: Final rendering -> Book='$title', Author='$authorName', Likes=$likeCount",
                );

                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: darkMode
                          ? [
                              DesertColors.darkSurface,
                              DesertColors.darkSurface.withOpacity(0.8),
                            ]
                          : [
                              Colors.white,
                              DesertColors.lightSurface.withOpacity(0.9),
                            ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: cardTopColor.withOpacity(0.15),
                        blurRadius: 15,
                        offset: Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: cardTopColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: cardTopColor,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.favorite,
                                    color: cardTopColor,
                                    size: 14,
                                  ),
                                ),
                              ),
                              Center(
                                child: Container(
                                  width: 50,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 6,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.menu_book,
                                    color: cardTopColor,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: darkMode
                                      ? DesertColors.darkText
                                      : DesertColors.lightText,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 4),
                              Text(
                                authorName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: darkMode
                                      ? DesertColors.darkText.withOpacity(0.7)
                                      : DesertColors.lightText.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                              Spacer(),
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        debugPrint(
                                          "DEBUG: Download clicked for '$title'",
                                        );
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: cardTopColor,
                                            width: 1.5,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.download_rounded,
                                              size: 14,
                                              color: cardTopColor,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              language == 'ar'
                                                  ? 'تحميل'
                                                  : 'Download',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: cardTopColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        debugPrint(
                                          "DEBUG: Read clicked for '$title'",
                                        );
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: cardTopColor,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.menu_book,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              language == 'ar'
                                                  ? 'اقرأ'
                                                  : 'Read',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$likeCount ${language == 'ar' ? 'أعجب به' : 'favorited'}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: cardTopColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.favorite,
                                    size: 10,
                                    color: cardTopColor,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
