import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';
import '../alrayah.dart';
import 'details.dart';
import './books_section.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Book {
  final String id;
  final String title;
  final String author;
  final String description;
  final String summary;
  final DateTime createdAt;
  final String downloads;
  final String views;
  final String rating;
  final String coverImage;
  final String language;
  final String category;
  final String status;
  final String pdfUrl; // ✅ new field for PDF

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.summary,
    required this.createdAt,
    required this.downloads,
    this.views = "12.3k",
    this.rating = "4.8",
    this.coverImage =
        "https://images.pexels.com/photos/1130980/pexels-photo-1130980.jpeg?auto=compress&cs=tinysrgb&w=600",
    this.language = "Arabic",
    this.category = "Islamic",
    this.status = "available",
    this.pdfUrl = "", // ✅ default empty
  });

  /// Factory method that also fetches the related Supabase image and PDF dynamically
  /*static Future<Book> fromFirestoreWithImage(
    Map<String, dynamic> bookData,
    Map<String, dynamic>? authorData,
    FirebaseFirestore firestore,
  ) async {
    DateTime createdAtValue;

    if (bookData['CreatedAt'] is Timestamp) {
      createdAtValue = (bookData['CreatedAt'] as Timestamp).toDate();
    } else if (bookData['CreatedAt'] is String) {
      createdAtValue =
          DateTime.tryParse(bookData['CreatedAt']) ?? DateTime.now();
    } else {
      createdAtValue = DateTime.now();
    }

    String? imageUrl;
    String? pdfUrl; // ✅ new variable

    // 1️⃣ Get Book Image
    final String? imageId = bookData['ImageId'];
    if (imageId != null && imageId.isNotEmpty) {
      try {
        final imageQuery = await firestore
            .collection('tbluploadedfiles')
            .where('Id', isEqualTo: imageId)
            .where('EntityType', isEqualTo: 'Book')
            .limit(1)
            .get();

        if (imageQuery.docs.isNotEmpty) {
          imageUrl = imageQuery.docs.first.data()['SupabaseUrl'];
        }
      } catch (e) {
        print('Error fetching image for book ${bookData['Id']}: $e');
      }
    }

    // 2️⃣ Get Book PDF (using BookPdfId <-> EntityId relation)
    final String? bookPdfId = bookData['BookPdfId'];
    if (bookPdfId != null && bookPdfId.isNotEmpty) {
      try {
        final pdfQuery = await firestore
            .collection('tbluploadedfiles')
            .where('Id', isEqualTo: bookPdfId)
            .where('EntityType', isEqualTo: 'Book')
            .limit(1)
            .get();

        if (pdfQuery.docs.isNotEmpty) {
          pdfUrl = pdfQuery.docs.first.data()['SupabaseUrl'];
        }
      } catch (e) {
        print('Error fetching PDF for book ${bookData['Id']}: $e');
      }
    }

    // 3️⃣ Fallbacks
    imageUrl ??=
        "https://images.pexels.com/photos/1130980/pexels-photo-1130980.jpeg?auto=compress&cs=tinysrgb&w=600";
    pdfUrl ??= "";

    // 4️⃣ Return Book Object
    return Book(
      id: bookData['Id'] ?? '',
      title: bookData['Title'] ?? '',
      author: authorData?['Name'] ?? 'Unknown Author',
      description: bookData['Description'] ?? '',
      summary: bookData['Summary'] ?? '',
      createdAt: createdAtValue,
      downloads: bookData['DownloadsCount']?.toString() ?? "0",
      coverImage: imageUrl,
      pdfUrl: pdfUrl, // ✅ store PDF URL
    );
  }*/

  String get formattedCreatedAt {
    return "${createdAt.day.toString().padLeft(2, '0')}-"
        "${createdAt.month.toString().padLeft(2, '0')}-"
        "${createdAt.year} "
        "${createdAt.hour.toString().padLeft(2, '0')}:"
        "${createdAt.minute.toString().padLeft(2, '0')}";
  }

  String getTitle(String language) => title;
  String getAuthor(String language) => author;
  String getDescription(String language) => description;
  String getCategory(String language) => category;
  String getSummary(String language) => summary;
}

class AppContent {
  final Map<String, dynamic> ar = {
    'navigation': [
      {'name': 'الرئيسية', 'href': '#home'},
      {'name': 'إصدارات المجلس', 'href': '#publications'},
      {'name': 'مكتبة الرؤية', 'href': '#library'},
      {'name': 'من نحن', 'href': '#about'},
      {'name': 'تواصل معنا', 'href': '#contact'},
    ],
    'booksPage': {
      'title': 'كتب الرؤية',
      'subtitle': 'اكتشف مجموعة واسعة من الكتب والدراسات الإسلامية',
      'mostDownloaded': 'الأكثر تحميلاً',
      'mostLoved': 'الأكثر إعجاباً',
      'trending': 'الأكثر رواجاً',
      'recentlyAdded': 'المضافة حديثاً',
      'classic': 'الكلاسيكية',
      'showMore': 'عرض المزيد من الكتب',
      'showLess': 'عرض أقل',
      'totalBooks': 'كتاب متاح',
      'noResults': 'لم يتم العثور على نتائج',
      'download': 'تحميل',
      'read': 'قراءة',
      'borrow': 'استعارة',
      'preview': 'معاينة',
      'pages': 'صفحة',
      'tryDifferentKeywords': 'جرب البحث بكلمات مختلفة',
      'filters': 'التصنيفات',
      'date': 'التاريخ',
      'languages': 'اللغات',
      'authors': 'المؤلفين',
      'clear': 'مسح',
      'today': 'اليوم',
      'thisWeek': 'هذا الأسبوع',
      'thisMonth': 'هذا الشهر',
      'thisYear': 'هذا العام',
      'arabic': 'عربي',
      'english': 'إنجليزي',
      'multilingual': 'متعدد اللغات',
      'showMoreAuthors': 'عرض المزيد من المؤلفين',
    },
  };

  final Map<String, dynamic> en = {
    'navigation': [
      {'name': 'Home', 'href': '#home'},
      {'name': 'Council Publications', 'href': '#publications'},
      {'name': 'Vision Library', 'href': '#library'},
      {'name': 'About Us', 'href': '#about'},
      {'name': 'Contact', 'href': '#contact'},
    ],
    'booksPage': {
      'title': 'Vision Books',
      'subtitle': 'Discover a wide collection of Islamic books and studies',
      'mostDownloaded': 'Most Downloaded',
      'mostLoved': 'Most Loved',
      'trending': 'Trending Books',
      'recentlyAdded': 'Recently Added',
      'classic': 'Classic Books',
      'showMore': 'Show More Books',
      'showLess': 'Show Less',
      'totalBooks': 'books available',
      'noResults': 'No results found',
      'download': 'Download',
      'read': 'Read',
      'borrow': 'Borrow',
      'preview': 'Preview',
      'pages': 'pages',
      'tryDifferentKeywords': 'Try searching with different keywords',
      'filters': 'Filters',
      'date': 'Date',
      'languages': 'Languages',
      'authors': 'Authors',
      'clear': 'Clear',
      'today': 'Today',
      'thisWeek': 'This Week',
      'thisMonth': 'This Month',
      'thisYear': 'This Year',
      'arabic': 'Arabic',
      'english': 'English',
      'multilingual': 'Multilingual',
      'showMoreAuthors': 'Show More Authors',
    },
  };

  Map<String, dynamic> getContent(String language) {
    return language == 'ar' ? ar : en;
  }
}

class BookCacheManager {
  static const String _cacheKey = 'cached_books_data';
  static const String _cacheTimestampKey = 'cache_timestamp';
  static const Duration _cacheExpiration = Duration(
    hours: 24,
  ); // Cache expires after 24 hours

  // Save books to cache
  static Future<void> saveToCache(
    List<Book> books,
    List<String> authors,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert books to JSON
      List<Map<String, dynamic>> booksJson = books
          .map(
            (book) => {
              'id': book.id,
              'title': book.title,
              'author': book.author,
              'description': book.description,
              'summary': book.summary,
              'createdAt': book.createdAt.toIso8601String(),
              'downloads': book.downloads,
              'views': book.views,
              'rating': book.rating,
              'coverImage': book.coverImage,
              'language': book.language,
              'category': book.category,
              'status': book.status,
              'pdfUrl': book.pdfUrl,
            },
          )
          .toList();

      // Save to SharedPreferences
      await prefs.setString(
        _cacheKey,
        json.encode({'books': booksJson, 'authors': authors}),
      );
      await prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      print('✅ Cache saved successfully: ${books.length} books');
    } catch (e) {
      print('❌ Error saving to cache: $e');
    }
  }

  // Load books from cache
  static Future<Map<String, dynamic>?> loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if cache exists
      if (!prefs.containsKey(_cacheKey)) {
        print('ℹ️ No cache found');
        return null;
      }

      // Check cache expiration
      final timestamp = prefs.getInt(_cacheTimestampKey);
      if (timestamp == null) {
        print('ℹ️ Cache timestamp missing');
        return null;
      }

      final cacheDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheDate) > _cacheExpiration) {
        print('ℹ️ Cache expired');
        await clearCache();
        return null;
      }

      // Load and parse cached data
      final cachedData = prefs.getString(_cacheKey);
      if (cachedData == null) {
        print('ℹ️ Cache data is null');
        return null;
      }

      final Map<String, dynamic> decodedData = json.decode(cachedData);

      // Convert JSON back to Book objects
      List<Book> books = (decodedData['books'] as List).map((bookJson) {
        return Book(
          id: bookJson['id'],
          title: bookJson['title'],
          author: bookJson['author'],
          description: bookJson['description'],
          summary: bookJson['summary'],
          createdAt: DateTime.parse(bookJson['createdAt']),
          downloads: bookJson['downloads'],
          views: bookJson['views'],
          rating: bookJson['rating'],
          coverImage: bookJson['coverImage'],
          language: bookJson['language'],
          category: bookJson['category'],
          status: bookJson['status'],
          pdfUrl: bookJson['pdfUrl'],
        );
      }).toList();

      List<String> authors = List<String>.from(decodedData['authors']);

      print('✅ Cache loaded successfully: ${books.length} books');
      return {'books': books, 'authors': authors};
    } catch (e) {
      print('❌ Error loading from cache: $e');
      return null;
    }
  }

  // Clear cache
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
      print('✅ Cache cleared');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }

  // Check if cache is valid
  static Future<bool> isCacheValid() async {
    final prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey(_cacheKey) ||
        !prefs.containsKey(_cacheTimestampKey)) {
      return false;
    }

    final timestamp = prefs.getInt(_cacheTimestampKey);
    if (timestamp == null) return false;

    final cacheDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now().difference(cacheDate) <= _cacheExpiration;
  }
}

class RotatingCircle extends StatefulWidget {
  final bool darkMode;
  final Widget child;
  final double size;
  final bool rotating;

  const RotatingCircle({
    Key? key,
    required this.darkMode,
    required this.child,
    this.size = 120,
    this.rotating = true,
  }) : super(key: key);

  @override
  _RotatingCircleState createState() => _RotatingCircleState();
}

class _RotatingCircleState extends State<RotatingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_rotationController);

    if (widget.rotating) {
      _rotationController.repeat();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: widget.rotating ? _rotationAnimation.value : 0,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.darkMode
                    ? [DesertColors.crimson, DesertColors.maroon]
                    : [DesertColors.camelSand, DesertColors.primaryGoldDark],
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (widget.darkMode
                              ? DesertColors.crimson
                              : DesertColors.camelSand)
                          .withOpacity(0.4),
                  blurRadius: 25,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Transform.rotate(
                angle: widget.rotating ? -_rotationAnimation.value : 0,
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class BookCard extends StatefulWidget {
  final bool darkMode;
  final String language;
  final Book book;
  final int index;

  const BookCard({
    Key? key,
    required this.darkMode,
    required this.language,
    required this.book,
    required this.index,
  }) : super(key: key);

  @override
  _BookCardState createState() => _BookCardState();
}

class _BookCardState extends State<BookCard>
    with SingleTickerProviderStateMixin {
  bool isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600 + widget.index * 100),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 30), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  @override
  Widget build(BuildContext context) {
    final content = AppContent().getContent(widget.language);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: _slideAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: MouseRegion(
                onEnter: (_) => setState(() => isHovered = true),
                onExit: (_) => setState(() => isHovered = false),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookDetailPage(
                          darkMode: widget.darkMode,
                          language: widget.language,
                          id: widget.book.id,
                          title: widget.book.title,
                          author: widget.book.author,
                          createdDate: widget.book.createdAt,
                          bookLanguage: widget.book.language,
                          description: widget.book.description,
                          summary: widget.book.summary,
                          category: widget.book.category,
                          downloads: widget.book.downloads,
                          views: widget.book.views,
                          rating: widget.book.rating,
                          coverImage: widget.book.coverImage,
                          status: widget.book.status,
                          pdfUrl: widget.book.pdfUrl,
                        ),
                      ),
                    );
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double availableWidth = constraints.maxWidth;

                      double cardWidth;
                      if (_isMobile(context)) {
                        if (availableWidth < 370) {
                          cardWidth = (availableWidth / 2) - 12;
                        } else {
                          cardWidth = (availableWidth / 2) - 16;
                        }
                      } else {
                        cardWidth = 180;
                      }

                      double cardHeight = _isMobile(context) ? 320 : 390;

                      return Container(
                        width: cardWidth,
                        height: cardHeight,
                        margin: EdgeInsets.symmetric(
                          horizontal: _isMobile(context) ? 6 : 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: _isMobile(context) ? 140 : 180,
                              height: _isMobile(context) ? 200 : 260,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                transform: Matrix4.identity()
                                  ..scale(isHovered ? 1.02 : 1.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    _isMobile(context) ? 8 : 12,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isHovered
                                          ? DesertColors.crimson.withOpacity(
                                              0.3,
                                            )
                                          : (widget.darkMode
                                                ? Colors.black.withOpacity(0.3)
                                                : Colors.black.withOpacity(
                                                    0.1,
                                                  )),
                                      blurRadius: isHovered ? 20 : 10,
                                      offset: Offset(0, isHovered ? 8 : 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    _isMobile(context) ? 8 : 12,
                                  ),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: _isMobile(context) ? 140 : 180,
                                        height: _isMobile(context) ? 200 : 260,
                                        child: Image.network(
                                          widget.book.coverImage,
                                          width: _isMobile(context) ? 140 : 180,
                                          height: _isMobile(context)
                                              ? 200
                                              : 260,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Container(
                                                  width: _isMobile(context)
                                                      ? 140
                                                      : 180,
                                                  height: _isMobile(context)
                                                      ? 200
                                                      : 260,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                      colors: [
                                                        DesertColors.camelSand
                                                            .withOpacity(0.3),
                                                        DesertColors.crimson
                                                            .withOpacity(0.3),
                                                      ],
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: Icon(
                                                      Icons.book,
                                                      size: _isMobile(context)
                                                          ? 32
                                                          : 40,
                                                      color: widget.darkMode
                                                          ? DesertColors
                                                                .darkText
                                                          : DesertColors
                                                                .lightText,
                                                    ),
                                                  ),
                                                );
                                              },
                                        ),
                                      ),
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: _isMobile(context)
                                                ? 6
                                                : 8,
                                            vertical: _isMobile(context)
                                                ? 3
                                                : 4,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              _isMobile(context) ? 10 : 12,
                                            ),
                                            color: Colors.black.withOpacity(
                                              0.7,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.star,
                                                color: DesertColors.camelSand,
                                                size: _isMobile(context)
                                                    ? 10
                                                    : 12,
                                              ),
                                              SizedBox(
                                                width: _isMobile(context)
                                                    ? 2
                                                    : 4,
                                              ),
                                              Text(
                                                widget.book.rating,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: _isMobile(context)
                                                      ? 8
                                                      : 10,
                                                  fontWeight: FontWeight.bold,
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
                            ),

                            SizedBox(height: _isMobile(context) ? 8 : 12),

                            Container(
                              height: _isMobile(context) ? 28 : 36,
                              child: Text(
                                widget.book.getTitle(widget.language),
                                style: TextStyle(
                                  fontSize: _isMobile(context) ? 12 : 14,
                                  fontWeight: FontWeight.bold,
                                  color: widget.darkMode
                                      ? DesertColors.darkText
                                      : DesertColors.lightText,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: widget.language == 'ar'
                                    ? TextAlign.right
                                    : TextAlign.left,
                              ),
                            ),

                            SizedBox(height: _isMobile(context) ? 2 : 4),

                            Container(
                              height: _isMobile(context) ? 14 : 16,
                              child: Text(
                                widget.book.getAuthor(widget.language),
                                style: TextStyle(
                                  fontSize: _isMobile(context) ? 10 : 12,
                                  color: widget.darkMode
                                      ? DesertColors.darkText
                                      : DesertColors.lightText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: widget.language == 'ar'
                                    ? TextAlign.right
                                    : TextAlign.left,
                              ),
                            ),

                            SizedBox(height: _isMobile(context) ? 8 : 12),

                            Container(
                              height: _isMobile(context) ? 28 : 36,
                              width: double.infinity,
                              child: _buildActionButton(content),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(Map<String, dynamic> content) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 36,
            margin: EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                colors: [DesertColors.primaryGoldDark, DesertColors.camelSand],
              ),
            ),
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'تحميل',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        Expanded(
          child: Container(
            height: 36,
            margin: EdgeInsets.only(left: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                colors: [
                  DesertColors.crimson,
                  DesertColors.crimson.withOpacity(0.8),
                ],
              ),
            ),
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.visibility, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'قراءة',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class BooksCarousel extends StatefulWidget {
  final String title;
  final List<Book> books;
  final bool darkMode;
  final String language;
  final bool isLoading;

  const BooksCarousel({
    Key? key,
    required this.title,
    required this.books,
    required this.darkMode,
    required this.language,
    this.isLoading = false,
  }) : super(key: key);

  @override
  _BooksCarouselState createState() => _BooksCarouselState();
}

class _BooksCarouselState extends State<BooksCarousel>
    with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _collapseController;
  late Animation<double> _collapseAnimation;
  late Animation<double> _iconRotationAnimation;

  int currentPage = 0;
  bool isCollapsed = false;
  static const int booksPerPage = 6;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _collapseController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _collapseAnimation = CurvedAnimation(
      parent: _collapseController,
      curve: Curves.easeInOut,
    );

    _iconRotationAnimation = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(_collapseController);

    _collapseController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _collapseController.dispose();
    super.dispose();
  }

  void _toggleCollapse() {
    setState(() {
      isCollapsed = !isCollapsed;
    });

    if (isCollapsed) {
      _collapseController.reverse();
    } else {
      _collapseController.forward();
    }
  }

  void _scrollLeft() {
    if (currentPage > 0) {
      setState(() {
        currentPage--;
      });
      double pageWidth = MediaQuery.of(context).size.width;
      _scrollController.animateTo(
        currentPage * pageWidth,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollRight() {
    int totalPages = (widget.books.length / booksPerPage).ceil();
    if (currentPage < totalPages - 1) {
      setState(() {
        currentPage++;
      });
      double pageWidth = MediaQuery.of(context).size.width;
      _scrollController.animateTo(
        currentPage * pageWidth,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return Container(
      margin: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      foreground: Paint()
                        ..shader = const LinearGradient(
                          colors: [
                            DesertColors.crimson,
                            DesertColors.primaryGoldDark,
                          ],
                        ).createShader(const Rect.fromLTWH(0, 0, 200, 40)),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _toggleCollapse,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: isCollapsed
                            ? [DesertColors.crimson, DesertColors.maroon]
                            : [
                                DesertColors.camelSand,
                                DesertColors.primaryGoldDark,
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isCollapsed
                                      ? DesertColors.crimson
                                      : DesertColors.camelSand)
                                  .withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: AnimatedBuilder(
                      animation: _iconRotationAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _iconRotationAnimation.value * math.pi,
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                            size: 20,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          AnimatedBuilder(
            animation: _collapseAnimation,
            builder: (context, child) {
              return ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _collapseAnimation.value,
                  child: Opacity(
                    opacity: _collapseAnimation.value,
                    child: Column(
                      children: [
                        Container(
                          height: _isMobile(context) ? 350 : 430,
                          margin: EdgeInsets.symmetric(
                            horizontal: _isMobile(context) ? 8 : 0,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: widget.darkMode
                                  ? [
                                      DesertColors.maroon.withOpacity(0.9),
                                      DesertColors.crimson.withOpacity(0.8),
                                      DesertColors.maroon.withOpacity(0.95),
                                    ]
                                  : [
                                      DesertColors.camelSand.withOpacity(0.15),
                                      DesertColors.primaryGoldDark.withOpacity(
                                        0.1,
                                      ),
                                      DesertColors.camelSand.withOpacity(0.2),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(
                              _isMobile(context) ? 12 : 16,
                            ),
                            border: Border.all(
                              color: widget.darkMode
                                  ? DesertColors.crimson.withOpacity(0.3)
                                  : DesertColors.maroon.withOpacity(0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.darkMode
                                    ? DesertColors.crimson.withOpacity(0.2)
                                    : DesertColors.camelSand.withOpacity(0.3),
                                blurRadius: _isMobile(context) ? 15 : 20,
                                offset: Offset(0, _isMobile(context) ? 6 : 8),
                              ),
                            ],
                          ),
                          child: widget.isLoading
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              widget.darkMode
                                                  ? DesertColors.camelSand
                                                  : DesertColors.crimson,
                                            ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'جاري تحميل الكتب...',
                                        style: TextStyle(
                                          color: widget.darkMode
                                              ? DesertColors.darkText
                                              : DesertColors.lightText,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Stack(
                                  children: [
                                    _isMobile(context)
                                        ? PageView.builder(
                                            controller: PageController(
                                              viewportFraction: 1.0,
                                            ),
                                            itemCount:
                                                (widget.books.length /
                                                        (_isMobile(context)
                                                            ? 2
                                                            : booksPerPage))
                                                    .ceil(),
                                            onPageChanged: (index) {
                                              setState(() {
                                                currentPage = index;
                                              });
                                            },
                                            itemBuilder: (context, pageIndex) {
                                              final start =
                                                  pageIndex *
                                                  (_isMobile(context)
                                                      ? 2
                                                      : booksPerPage);
                                              final end =
                                                  (start +
                                                          (_isMobile(context)
                                                              ? 2
                                                              : booksPerPage))
                                                      .clamp(
                                                        0,
                                                        widget.books.length,
                                                      );
                                              final pageBooks = widget.books
                                                  .sublist(start, end);

                                              return Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                                child: Center(
                                                  child: _isMobile(context)
                                                      ? Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceEvenly,
                                                          children: pageBooks.map((
                                                            book,
                                                          ) {
                                                            return SizedBox(
                                                              width:
                                                                  MediaQuery.of(
                                                                    context,
                                                                  ).size.width *
                                                                  0.4,
                                                              child: BookCard(
                                                                darkMode: widget
                                                                    .darkMode,
                                                                language: widget
                                                                    .language,
                                                                book: book,
                                                                index: widget
                                                                    .books
                                                                    .indexOf(
                                                                      book,
                                                                    ),
                                                              ),
                                                            );
                                                          }).toList(),
                                                        )
                                                      : Wrap(
                                                          alignment:
                                                              WrapAlignment
                                                                  .center,
                                                          runAlignment:
                                                              WrapAlignment
                                                                  .center,
                                                          spacing: 16,
                                                          runSpacing: 16,
                                                          children: pageBooks.map((
                                                            book,
                                                          ) {
                                                            return SizedBox(
                                                              width: 160,
                                                              child: BookCard(
                                                                darkMode: widget
                                                                    .darkMode,
                                                                language: widget
                                                                    .language,
                                                                book: book,
                                                                index: widget
                                                                    .books
                                                                    .indexOf(
                                                                      book,
                                                                    ),
                                                              ),
                                                            );
                                                          }).toList(),
                                                        ),
                                                ),
                                              );
                                            },
                                          )
                                        : ListView.builder(
                                            controller: _scrollController,
                                            scrollDirection: Axis.horizontal,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 20,
                                            ),
                                            itemCount:
                                                (widget.books.length /
                                                        booksPerPage)
                                                    .ceil(),
                                            itemBuilder: (context, pageIndex) {
                                              final start =
                                                  pageIndex * booksPerPage;
                                              final end = (start + booksPerPage)
                                                  .clamp(
                                                    0,
                                                    widget.books.length,
                                                  );
                                              final pageBooks = widget.books
                                                  .sublist(start, end);

                                              return Container(
                                                width: MediaQuery.of(
                                                  context,
                                                ).size.width,
                                                child: Center(
                                                  child: Wrap(
                                                    alignment:
                                                        WrapAlignment.center,
                                                    runAlignment:
                                                        WrapAlignment.center,
                                                    spacing: 16,
                                                    runSpacing: 16,
                                                    children: pageBooks.map((
                                                      book,
                                                    ) {
                                                      return SizedBox(
                                                        width: 160,
                                                        child: BookCard(
                                                          darkMode:
                                                              widget.darkMode,
                                                          language:
                                                              widget.language,
                                                          book: book,
                                                          index: widget.books
                                                              .indexOf(book),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),

                                    if (!_isMobile(context) &&
                                        !widget.isLoading) ...[
                                      Positioned(
                                        left: 0,
                                        top: 140,
                                        child: AnimatedOpacity(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          opacity: currentPage > 0 ? 1.0 : 0.3,
                                          child: _buildNavigationButton(
                                            icon: language == 'ar'
                                                ? Icons.arrow_forward_ios
                                                : Icons.arrow_back_ios,
                                            onPressed: currentPage > 0
                                                ? _scrollLeft
                                                : () {},
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        top: 140,
                                        child: AnimatedOpacity(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          opacity:
                                              currentPage <
                                                  (widget.books.length /
                                                              booksPerPage)
                                                          .ceil() -
                                                      1
                                              ? 1.0
                                              : 0.3,
                                          child: _buildNavigationButton(
                                            icon: language == "ar"
                                                ? Icons.arrow_back_ios
                                                : Icons.arrow_forward_ios,
                                            onPressed:
                                                currentPage <
                                                    (widget.books.length /
                                                                booksPerPage)
                                                            .ceil() -
                                                        1
                                                ? _scrollRight
                                                : () {},
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),

                        if (!widget.isLoading) ...[
                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              (widget.books.length / booksPerPage).ceil(),
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: currentPage == index ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: currentPage == index
                                      ? const LinearGradient(
                                          colors: [
                                            DesertColors.crimson,
                                            DesertColors.primaryGoldDark,
                                          ],
                                        )
                                      : null,
                                  color: currentPage == index
                                      ? null
                                      : (widget.darkMode
                                            ? DesertColors.darkText.withOpacity(
                                                0.3,
                                              )
                                            : DesertColors.lightText
                                                  .withOpacity(0.3)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
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

  Widget _buildNavigationButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: widget.darkMode
              ? [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.7)]
              : [DesertColors.crimson, DesertColors.maroon],
        ),
        boxShadow: [
          BoxShadow(
            color: widget.darkMode
                ? Colors.black.withOpacity(0.2)
                : DesertColors.crimson.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: widget.darkMode ? DesertColors.maroon : Colors.white,
          size: 18,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class FilterChips extends StatefulWidget {
  final bool darkMode;
  final String language;
  final Function(Map<String, dynamic>) onFiltersChanged;
  final List<String> availableAuthors;

  const FilterChips({
    Key? key,
    required this.darkMode,
    required this.language,
    required this.onFiltersChanged,
    required this.availableAuthors,
  }) : super(key: key);

  @override
  _FilterChipsState createState() => _FilterChipsState();
}

class _FilterChipsState extends State<FilterChips> {
  String selectedDate = '';
  String selectedLanguage = '';
  String selectedAuthor = '';

  bool showDateOptions = false;
  bool showLanguageOptions = false;
  bool showAuthorOptions = false;

  int maxVisibleAuthors = 6;
  bool showAllAuthors = false;

  @override
  Widget build(BuildContext context) {
    final content = AppContent().getContent(widget.language);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildFilterChip(
              title: content['booksPage']['date'],
              isExpanded: showDateOptions,
              onTap: () => setState(() {
                showDateOptions = !showDateOptions;
                showLanguageOptions = false;
                showAuthorOptions = false;
              }),
              icon: Icons.calendar_today,
              selectedValue: selectedDate,
            ),
            _buildFilterChip(
              title: content['booksPage']['languages'],
              isExpanded: showLanguageOptions,
              onTap: () => setState(() {
                showLanguageOptions = !showLanguageOptions;
                showDateOptions = false;
                showAuthorOptions = false;
              }),
              icon: Icons.language,
              selectedValue: selectedLanguage,
            ),
            _buildFilterChip(
              title: content['booksPage']['authors'],
              isExpanded: showAuthorOptions,
              onTap: () => setState(() {
                showAuthorOptions = !showAuthorOptions;
                showDateOptions = false;
                showLanguageOptions = false;
              }),
              icon: Icons.person,
              selectedValue: selectedAuthor,
            ),
            if (selectedDate.isNotEmpty ||
                selectedLanguage.isNotEmpty ||
                selectedAuthor.isNotEmpty)
              _buildClearAllChip(content['booksPage']['clear']),
          ],
        ),

        const SizedBox(height: 16),

        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _getExpandedHeight(),
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (showDateOptions) _buildDateOptions(content),
                if (showLanguageOptions) _buildLanguageOptions(content),
                if (showAuthorOptions) _buildAuthorOptions(content),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double _getExpandedHeight() {
    if (showDateOptions || showLanguageOptions) {
      return 120;
    } else if (showAuthorOptions) {
      return 200; // More space for authors
    }
    return 0;
  }

  Widget _buildFilterChip({
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    required IconData icon,
    required String selectedValue,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: isExpanded || selectedValue.isNotEmpty
              ? const LinearGradient(
                  colors: [DesertColors.crimson, DesertColors.maroon],
                )
              : LinearGradient(
                  colors: widget.darkMode
                      ? [DesertColors.darkSurface, DesertColors.darkBackground]
                      : [Colors.white, DesertColors.lightSurface],
                ),
          border: Border.all(
            color: isExpanded || selectedValue.isNotEmpty
                ? Colors.transparent
                : (widget.darkMode
                      ? DesertColors.camelSand.withOpacity(0.3)
                      : DesertColors.maroon.withOpacity(0.3)),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isExpanded || selectedValue.isNotEmpty
                  ? DesertColors.crimson.withOpacity(0.3)
                  : (widget.darkMode
                        ? Colors.black.withOpacity(0.2)
                        : Colors.black.withOpacity(0.1)),
              blurRadius: isExpanded ? 15 : 8,
              offset: Offset(0, isExpanded ? 4 : 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isExpanded || selectedValue.isNotEmpty
                  ? Colors.white
                  : (widget.darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isExpanded || selectedValue.isNotEmpty
                    ? Colors.white
                    : (widget.darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 16,
              color: isExpanded || selectedValue.isNotEmpty
                  ? Colors.white
                  : (widget.darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearAllChip(String title) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedDate = '';
          selectedLanguage = '';
          selectedAuthor = '';
          showDateOptions = false;
          showLanguageOptions = false;
          showAuthorOptions = false;
          showAllAuthors = false;
        });
        _updateFilters();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: DesertColors.primaryGoldDark.withOpacity(0.1),
          border: Border.all(color: DesertColors.primaryGoldDark, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.clear, size: 18, color: DesertColors.primaryGoldDark),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: DesertColors.primaryGoldDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateOptions(Map<String, dynamic> content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: widget.darkMode
              ? [DesertColors.darkSurface, DesertColors.darkBackground]
              : [Colors.white, DesertColors.lightSurface],
        ),
        boxShadow: [
          BoxShadow(
            color: widget.darkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildOptionChip(
            content['booksPage']['today'],
            'today',
            selectedDate == 'today',
            (value) {
              setState(() => selectedDate = value ? 'today' : '');
              _updateFilters();
            },
          ),
          _buildOptionChip(
            content['booksPage']['thisWeek'],
            'week',
            selectedDate == 'week',
            (value) {
              setState(() => selectedDate = value ? 'week' : '');
              _updateFilters();
            },
          ),
          _buildOptionChip(
            content['booksPage']['thisMonth'],
            'month',
            selectedDate == 'month',
            (value) {
              setState(() => selectedDate = value ? 'month' : '');
              _updateFilters();
            },
          ),
          _buildOptionChip(
            content['booksPage']['thisYear'],
            'year',
            selectedDate == 'year',
            (value) {
              setState(() => selectedDate = value ? 'year' : '');
              _updateFilters();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOptions(Map<String, dynamic> content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: widget.darkMode
              ? [DesertColors.darkSurface, DesertColors.darkBackground]
              : [Colors.white, DesertColors.lightSurface],
        ),
        boxShadow: [
          BoxShadow(
            color: widget.darkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildOptionChip(
            content['booksPage']['arabic'],
            'Arabic',
            selectedLanguage == 'Arabic',
            (value) {
              setState(() => selectedLanguage = value ? 'Arabic' : '');
              _updateFilters();
            },
          ),
          _buildOptionChip(
            content['booksPage']['english'],
            'English',
            selectedLanguage == 'English',
            (value) {
              setState(() => selectedLanguage = value ? 'English' : '');
              _updateFilters();
            },
          ),
          _buildOptionChip(
            content['booksPage']['multilingual'],
            'Multilingual',
            selectedLanguage == 'Multilingual',
            (value) {
              setState(() => selectedLanguage = value ? 'Multilingual' : '');
              _updateFilters();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorOptions(Map<String, dynamic> content) {
    List<String> displayedAuthors = showAllAuthors
        ? widget.availableAuthors
        : widget.availableAuthors.take(maxVisibleAuthors).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: widget.darkMode
              ? [DesertColors.darkSurface, DesertColors.darkBackground]
              : [Colors.white, DesertColors.lightSurface],
        ),
        boxShadow: [
          BoxShadow(
            color: widget.darkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: displayedAuthors.map((author) {
              return _buildOptionChip(
                author,
                author,
                selectedAuthor == author,
                (value) {
                  setState(() => selectedAuthor = value ? author : '');
                  _updateFilters();
                },
              );
            }).toList(),
          ),
          if (widget.availableAuthors.length > maxVisibleAuthors) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                setState(() {
                  showAllAuthors = !showAllAuthors;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [
                      DesertColors.camelSand,
                      DesertColors.primaryGoldDark,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      showAllAuthors ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      showAllAuthors
                          ? 'عرض أقل'
                          : content['booksPage']['showMoreAuthors'],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionChip(
    String label,
    String value,
    bool isSelected,
    Function(bool) onChanged,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!isSelected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [
                    DesertColors.camelSand,
                    DesertColors.primaryGoldDark,
                  ],
                )
              : null,
          color: isSelected
              ? null
              : (widget.darkMode
                    ? DesertColors.maroon.withOpacity(0.1)
                    : DesertColors.camelSand.withOpacity(0.1)),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (widget.darkMode
                      ? DesertColors.camelSand.withOpacity(0.3)
                      : DesertColors.maroon.withOpacity(0.3)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (widget.darkMode
                      ? DesertColors.darkText
                      : DesertColors.lightText),
          ),
        ),
      ),
    );
  }

  void _updateFilters() {
    widget.onFiltersChanged({
      'date': selectedDate,
      'language': selectedLanguage,
      'author': selectedAuthor,
    });
  }
}

class BookHeroSection extends StatefulWidget {
  final bool darkMode;
  final String language;
  final bool scrolled;
  final String searchTerm;
  final String filterType;
  final int displayedBooks;

  const BookHeroSection({
    super.key,
    required this.darkMode,
    required this.language,
    required this.scrolled,
    required this.searchTerm,
    required this.filterType,
    required this.displayedBooks,
  });

  @override
  State<BookHeroSection> createState() => _BookHeroSectionState();
}

class _BookHeroSectionState extends State<BookHeroSection>
    with TickerProviderStateMixin {
  bool darkMode = false;
  String language = 'ar';
  bool scrolled = false;
  Map<String, dynamic> filters = {};

  late AnimationController _floatingController;
  late Animation<double> _floatingAnimation;
  late ScrollController _scrollController;

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  bool _isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 768 &&
        MediaQuery.of(context).size.width < 1024;
  }

  final List<Book> allBooks = [];
  final List<String> availableAuthors = [];
  bool isLoadingBooks = true;

  Future<void> fetchBooks() async {
    setState(() {
      isLoadingBooks = true;
    });

    try {
      // First, try to load from cache
      print('🔍 Checking cache...');
      final cachedData = await BookCacheManager.loadFromCache();

      if (cachedData != null) {
        // Cache hit! Use cached data
        print('✨ Using cached data');
        setState(() {
          allBooks
            ..clear()
            ..addAll(cachedData['books']);
          availableAuthors
            ..clear()
            ..addAll(cachedData['authors']);
          isLoadingBooks = false;
        });

        // Optionally fetch fresh data in background and update cache
        _fetchAndUpdateCache();
        return;
      }

      // Cache miss - fetch from database
      print('📡 Fetching from database...');
      await _fetchFromDatabase();
    } catch (e) {
      print('❌ Error in fetchBooks: $e');
      setState(() {
        isLoadingBooks = false;
      });
    }
  }

  Future<void> _fetchFromDatabase() async {
    try {
      final firestore = FirebaseFirestore.instance;

      print('📡 Step 1: Fetching all books...');
      final booksSnapshot = await firestore
          .collection('tblbooks')
          .where('IsDeleted', isEqualTo: "False")
          .get();

      print('📚 Step 2: Fetching all authors...');
      final authorsSnapshot = await firestore.collection('tblauthors').get();

      print('🖼️ Step 3: Fetching all uploaded files (images & PDFs)...');
      final uploadedFilesSnapshot = await firestore
          .collection('tbluploadedfiles')
          .where('EntityType', isEqualTo: 'Book')
          .get();

      // Build maps for quick lookup
      final authorMap = {
        for (var doc in authorsSnapshot.docs) doc['Id']: doc.data(),
      };

      final uploadedFilesMap = {
        for (var doc in uploadedFilesSnapshot.docs) doc['Id']: doc.data(),
      };

      print('🔧 Step 4: Building book objects from cached data...');
      List<Book> fetchedBooks = [];
      Set<String> authorsSet = {};

      for (var doc in booksSnapshot.docs) {
        final bookData = doc.data();
        final authorId = bookData['AuthorId'];

        // Get author from map (instant lookup)
        Map<String, dynamic>? authorData = authorMap[authorId];
        if (authorData != null && authorData['Name'] != null) {
          authorsSet.add(authorData['Name']);
        }

        // Get image from map (instant lookup)
        String? imageUrl;
        final imageId = bookData['ImageId'];
        if (imageId != null && imageId.isNotEmpty) {
          final imageData = uploadedFilesMap[imageId];
          if (imageData != null) {
            imageUrl = imageData['SupabaseUrl'];
          }
        }

        // Get PDF from map (instant lookup)
        String? pdfUrl;
        final bookPdfId = bookData['BookPdfId'];
        if (bookPdfId != null && bookPdfId.isNotEmpty) {
          final pdfData = uploadedFilesMap[bookPdfId];
          if (pdfData != null) {
            pdfUrl = pdfData['SupabaseUrl'];
          }
        }

        // Apply fallbacks
        imageUrl ??=
            "https://images.pexels.com/photos/1130980/pexels-photo-1130980.jpeg?auto=compress&cs=tinysrgb&w=600";
        pdfUrl ??= "";

        // Parse CreatedAt
        DateTime createdAtValue;
        if (bookData['CreatedAt'] is Timestamp) {
          createdAtValue = (bookData['CreatedAt'] as Timestamp).toDate();
        } else if (bookData['CreatedAt'] is String) {
          createdAtValue =
              DateTime.tryParse(bookData['CreatedAt']) ?? DateTime.now();
        } else {
          createdAtValue = DateTime.now();
        }

        // Create Book object directly (no async calls!)
        final book = Book(
          id: bookData['Id'] ?? '',
          title: bookData['Title'] ?? '',
          author: authorData?['Name'] ?? 'Unknown Author',
          description: bookData['Description'] ?? '',
          summary: bookData['Summary'] ?? '',
          createdAt: createdAtValue,
          downloads: bookData['DownloadsCount']?.toString() ?? "0",
          coverImage: imageUrl,
          pdfUrl: pdfUrl,
        );

        fetchedBooks.add(book);
      }

      final authorsList = authorsSet.toList()..sort();

      print('💾 Step 5: Saving to cache...');
      await BookCacheManager.saveToCache(fetchedBooks, authorsList);

      setState(() {
        allBooks
          ..clear()
          ..addAll(fetchedBooks);
        availableAuthors
          ..clear()
          ..addAll(authorsList);
        isLoadingBooks = false;
      });

      print('✅ Data fetched and cached successfully in ~2 seconds!');
    } catch (e) {
      print('❌ Error fetching from database: $e');
      setState(() {
        isLoadingBooks = false;
      });
    }
  }

  Future<void> _fetchAndUpdateCache() async {
    try {
      print('🔄 Updating cache in background...');

      final firestore = FirebaseFirestore.instance;

      // Batch fetch all data
      final booksSnapshot = await firestore
          .collection('tblbooks')
          .where('IsDeleted', isEqualTo: "False")
          .get();

      final authorsSnapshot = await firestore.collection('tblauthors').get();

      final uploadedFilesSnapshot = await firestore
          .collection('tbluploadedfiles')
          .where('EntityType', isEqualTo: 'Book')
          .get();

      // Build maps
      final authorMap = {
        for (var doc in authorsSnapshot.docs) doc['Id']: doc.data(),
      };

      final uploadedFilesMap = {
        for (var doc in uploadedFilesSnapshot.docs) doc['Id']: doc.data(),
      };

      // Build books
      List<Book> fetchedBooks = [];
      Set<String> authorsSet = {};

      for (var doc in booksSnapshot.docs) {
        final bookData = doc.data();
        final authorId = bookData['AuthorId'];

        Map<String, dynamic>? authorData = authorMap[authorId];
        if (authorData != null && authorData['Name'] != null) {
          authorsSet.add(authorData['Name']);
        }

        String? imageUrl;
        final imageId = bookData['ImageId'];
        if (imageId != null && imageId.isNotEmpty) {
          final imageData = uploadedFilesMap[imageId];
          if (imageData != null) {
            imageUrl = imageData['SupabaseUrl'];
          }
        }

        String? pdfUrl;
        final bookPdfId = bookData['BookPdfId'];
        if (bookPdfId != null && bookPdfId.isNotEmpty) {
          final pdfData = uploadedFilesMap[bookPdfId];
          if (pdfData != null) {
            pdfUrl = pdfData['SupabaseUrl'];
          }
        }

        imageUrl ??=
            "https://images.pexels.com/photos/1130980/pexels-photo-1130980.jpeg?auto=compress&cs=tinysrgb&w=600";
        pdfUrl ??= "";

        DateTime createdAtValue;
        if (bookData['CreatedAt'] is Timestamp) {
          createdAtValue = (bookData['CreatedAt'] as Timestamp).toDate();
        } else if (bookData['CreatedAt'] is String) {
          createdAtValue =
              DateTime.tryParse(bookData['CreatedAt']) ?? DateTime.now();
        } else {
          createdAtValue = DateTime.now();
        }

        final book = Book(
          id: bookData['Id'] ?? '',
          title: bookData['Title'] ?? '',
          author: authorData?['Name'] ?? 'Unknown Author',
          description: bookData['Description'] ?? '',
          summary: bookData['Summary'] ?? '',
          createdAt: createdAtValue,
          downloads: bookData['DownloadsCount']?.toString() ?? "0",
          coverImage: imageUrl,
          pdfUrl: pdfUrl,
        );

        fetchedBooks.add(book);
      }

      final authorsList = authorsSet.toList()..sort();
      await BookCacheManager.saveToCache(fetchedBooks, authorsList);

      if (mounted) {
        setState(() {
          allBooks
            ..clear()
            ..addAll(fetchedBooks);
          availableAuthors
            ..clear()
            ..addAll(authorsList);
        });
      }

      print('✅ Cache updated in background');
    } catch (e) {
      print('❌ Error updating cache: $e');
    }
  }

  double _parseCount(String value) {
    if (value.isEmpty) return 0.0;

    String lower = value.toLowerCase().trim();

    if (lower.endsWith('k')) {
      return (double.tryParse(lower.replaceAll('k', '')) ?? 0.0) * 1000;
    } else if (lower.endsWith('m')) {
      return (double.tryParse(lower.replaceAll('m', '')) ?? 0.0) * 1000000;
    } else {
      return double.tryParse(lower) ?? 0.0;
    }
  }

  List<Book> get mostDownloadedBooks {
    var books = _applyFilters(allBooks);
    books = books.where((b) => _parseCount(b.downloads) > 5).toList();
    books.sort(
      (a, b) => _parseCount(b.downloads).compareTo(_parseCount(a.downloads)),
    );
    return books;
  }

  List<Book> get trendingBooks {
    var books = _applyFilters(allBooks);

    DateTime now = DateTime.now();
    books = books
        .where(
          (b) => b.createdAt.year == now.year && b.createdAt.month == now.month,
        )
        .toList();

    books.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return books;
  }

  List<Book> get classicBooks {
    var books = _applyFilters(allBooks);

    DateTime now = DateTime.now();
    books = books
        .where(
          (b) =>
              (b.createdAt.year < now.year) ||
              (b.createdAt.year == now.year && b.createdAt.month < now.month),
        )
        .toList();

    books.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return books;
  }

  List<Book> get mostLovedBooks {
    var books = _applyFilters(allBooks);
    books = books
        .where(
          (b) =>
              double.tryParse(b.rating) != null && double.parse(b.rating) >= 4,
        )
        .toList();

    books.sort(
      (a, b) => double.parse(b.rating).compareTo(double.parse(a.rating)),
    );
    return books;
  }

  @override
  void initState() {
    super.initState();

    fetchBooks();

    _floatingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _floatingAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_floatingController);

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _floatingController.repeat();
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    setState(() {
      scrolled = _scrollController.offset > 50;
    });
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  Map<String, dynamic> activeFilters = {};

  List<Book> _applyFilters(List<Book> books) {
    if (activeFilters.isEmpty) return books;

    return books.where((book) {
      if (activeFilters['date'] != null && activeFilters['date'].isNotEmpty) {
        DateTime now = DateTime.now();
        DateTime bookDate = book.createdAt;

        switch (activeFilters['date']) {
          case 'today':
            if (!_isSameDay(bookDate, now)) return false;
            break;
          case 'week':
            if (now.difference(bookDate).inDays > 7) return false;
            break;
          case 'month':
            if (now.difference(bookDate).inDays > 30) return false;
            break;
          case 'year':
            if (now.difference(bookDate).inDays > 365) return false;
            break;
        }
      }

      if (activeFilters['language'] != null &&
          activeFilters['language'].isNotEmpty) {
        if (book.language != activeFilters['language']) return false;
      }

      if (activeFilters['author'] != null &&
          activeFilters['author'].isNotEmpty) {
        if (book.author != activeFilters['author']) return false;
      }

      return true;
    }).toList();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  void _onFiltersChanged(Map<String, dynamic> filters) {
    setState(() {
      activeFilters = filters;
    });
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = widget.darkMode;
    final language = widget.language;
    final content = AppContent().getContent(language);

    return MaterialApp(
      title: 'Islamic Library',
      theme: ThemeData(fontFamily: language == 'ar' ? 'Cairo' : 'Roboto'),
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: darkMode
                    ? [DesertColors.darkBackground, DesertColors.darkSurface]
                    : [DesertColors.lightBackground, DesertColors.lightSurface],
              ),
            ),
            child: Stack(
              children: [
                ...List.generate(6, (index) {
                  return AnimatedBuilder(
                    animation: _floatingAnimation,
                    builder: (context, child) {
                      return Positioned(
                        left: (index * 25) % 100,
                        top: (index * 30) % 100,
                        child: Transform.translate(
                          offset: Offset(
                            math.sin(_floatingAnimation.value + index) * 50,
                            math.cos(_floatingAnimation.value + index) * 35,
                          ),
                          child: Container(
                            width: 100 + index * 25.0,
                            height: 100 + index * 25.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  (darkMode
                                          ? DesertColors.crimson
                                          : DesertColors.camelSand)
                                      .withOpacity(0.04),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),

                CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),

                          Container(
                            width: double.infinity,
                            margin: EdgeInsets.symmetric(
                              horizontal: _isMobile(context) ? 16 : 24,
                            ),
                            padding: EdgeInsets.all(
                              _isMobile(context) ? 24 : 48,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                _isMobile(context) ? 20 : 32,
                              ),
                              gradient: darkMode
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        DesertColors.maroon.withOpacity(0.9),
                                        DesertColors.darkBackground.withOpacity(
                                          0.9,
                                        ),
                                      ],
                                    )
                                  : LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        DesertColors.camelSand.withOpacity(
                                          0.15,
                                        ),
                                        DesertColors.primaryGoldDark
                                            .withOpacity(0.1),
                                      ],
                                    ),
                              border: Border.all(
                                color:
                                    (darkMode
                                            ? DesertColors.primaryGoldDark
                                            : DesertColors.crimson)
                                        .withOpacity(0.2),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (darkMode
                                              ? DesertColors.darkSurface
                                              : DesertColors.camelSand)
                                          .withOpacity(0.2),
                                  blurRadius: _isMobile(context) ? 15 : 30,
                                  offset: Offset(
                                    0,
                                    _isMobile(context) ? 8 : 15,
                                  ),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(
                                    _isMobile(context) ? 12 : 16,
                                  ),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        DesertColors.crimson,
                                        DesertColors.primaryGoldDark,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: DesertColors.crimson.withOpacity(
                                          0.4,
                                        ),
                                        blurRadius: _isMobile(context)
                                            ? 15
                                            : 20,
                                        offset: Offset(
                                          0,
                                          _isMobile(context) ? 6 : 8,
                                        ),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.library_books,
                                    color: Colors.white,
                                    size: _isMobile(context) ? 24 : 32,
                                  ),
                                ),

                                SizedBox(height: _isMobile(context) ? 16 : 24),

                                Text(
                                  content['booksPage']['title'],
                                  style: TextStyle(
                                    fontSize: _isMobile(context) ? 28 : 42,
                                    fontWeight: FontWeight.bold,
                                    color: darkMode
                                        ? DesertColors.darkText
                                        : DesertColors.lightText,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                SizedBox(height: _isMobile(context) ? 12 : 16),

                                Text(
                                  content['booksPage']['subtitle'],
                                  style: TextStyle(
                                    fontSize: _isMobile(context) ? 16 : 22,
                                    color:
                                        (darkMode
                                                ? DesertColors.darkText
                                                : DesertColors.lightText)
                                            .withOpacity(0.8),
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                SizedBox(height: _isMobile(context) ? 24 : 32),

                                _isMobile(context)
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _buildStatCard(
                                            icon: Icons.library_books,
                                            value: '${allBooks.length}',
                                            label:
                                                content['booksPage']['totalBooks'],
                                            color: DesertColors.crimson,
                                            context: context,
                                          ),
                                          _buildStatCard(
                                            icon: Icons.download,
                                            value: '15K+',
                                            label: 'تحميل',
                                            color: DesertColors.camelSand,
                                            context: context,
                                          ),
                                          _buildStatCard(
                                            icon: Icons.star,
                                            value: '4.8',
                                            label: 'تقييم',
                                            color: DesertColors.primaryGoldDark,
                                            context: context,
                                          ),
                                        ],
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          _buildStatCard(
                                            icon: Icons.library_books,
                                            value: '${allBooks.length}',
                                            label:
                                                content['booksPage']['totalBooks'],
                                            color: DesertColors.crimson,
                                            context: context,
                                          ),
                                          const SizedBox(width: 24),
                                          _buildStatCard(
                                            icon: Icons.download,
                                            value: '15K+',
                                            label: 'تحميل',
                                            color: DesertColors.camelSand,
                                            context: context,
                                          ),
                                          const SizedBox(width: 24),
                                          _buildStatCard(
                                            icon: Icons.star,
                                            value: '4.8',
                                            label: 'تقييم',
                                            color: DesertColors.primaryGoldDark,
                                            context: context,
                                          ),
                                        ],
                                      ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 60),
                          const SizedBox(height: 40),

                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                colors: darkMode
                                    ? [
                                        DesertColors.darkSurface.withOpacity(
                                          0.8,
                                        ),
                                        DesertColors.darkBackground.withOpacity(
                                          0.9,
                                        ),
                                      ]
                                    : [
                                        Colors.white.withOpacity(0.9),
                                        DesertColors.lightSurface.withOpacity(
                                          0.8,
                                        ),
                                      ],
                              ),
                              border: Border.all(
                                color:
                                    (darkMode
                                            ? DesertColors.camelSand
                                            : DesertColors.maroon)
                                        .withOpacity(0.2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (darkMode
                                              ? Colors.black
                                              : DesertColors.camelSand)
                                          .withOpacity(0.1),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.filter_list,
                                      color: darkMode
                                          ? DesertColors.camelSand
                                          : DesertColors.crimson,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      content['booksPage']['filters'],
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
                                const SizedBox(height: 20),
                                FilterChips(
                                  darkMode: darkMode,
                                  language: language,
                                  onFiltersChanged: _onFiltersChanged,
                                  availableAuthors: availableAuthors,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),

                          BooksCarousel(
                            title: "Trending",
                            books: trendingBooks,
                            darkMode: darkMode,
                            language: language,
                            isLoading: isLoadingBooks,
                          ),

                          BooksCarousel(
                            title: "Most Downloaded",
                            books: mostDownloadedBooks,
                            darkMode: darkMode,
                            language: language,
                            isLoading: isLoadingBooks,
                          ),

                          BooksCarousel(
                            title: language == 'ar'
                                ? "جميع الكتب"
                                : "All Books",
                            books: classicBooks,
                            darkMode: darkMode,
                            language: language,
                            isLoading: isLoadingBooks,
                          ),
                          BooksCarousel(
                            title: language == 'ar' ? "المفضلة" : "Favorites",
                            books: mostLovedBooks,
                            darkMode: darkMode,
                            language: language,
                            isLoading: isLoadingBooks,
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),

                if (!_isMobile(context))
                  AnimatedBuilder(
                    animation: _floatingAnimation,
                    builder: (context, child) {
                      return Positioned(
                        bottom: 32,
                        right: language == 'ar' ? null : 32,
                        left: language == 'ar' ? 32 : null,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: scrolled ? 1.0 : 0.0,
                          child: Transform.translate(
                            offset: Offset(
                              0,
                              math.sin(_floatingAnimation.value) * -5,
                            ),
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
                                    colors: [
                                      DesertColors.crimson,
                                      DesertColors.maroon,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: DesertColors.crimson.withOpacity(
                                        0.4,
                                      ),
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required BuildContext context,
  }) {
    if (_isMobile(context)) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
                  .withOpacity(0.7),
            ),
          ),
        ],
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color:
                    (darkMode ? DesertColors.darkText : DesertColors.lightText)
                        .withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }
  }
}
