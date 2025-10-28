import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alraya_app/alrayah.dart';
import 'read.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookDetailPage extends StatefulWidget {
  final bool darkMode;
  final String language;
  final String id;
  final String title;
  final String author;
  final DateTime createdDate;
  final String bookLanguage;
  final String description;
  final String summary;
  final String category;
  final String downloads;
  final String views;
  final String rating;
  final String coverImage;
  final String status;
  final String pdfUrl;

  const BookDetailPage({
    Key? key,
    required this.darkMode,
    required this.language,
    required this.id,
    required this.title,
    required this.author,
    required this.createdDate,
    required this.bookLanguage,
    required this.description,
    required this.summary,
    required this.category,
    required this.downloads,
    required this.views,
    required this.rating,
    required this.coverImage,
    required this.status,
    required this.pdfUrl,
  }) : super(key: key);

  @override
  _BookDetailPageState createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  bool isScrolled = false;
  late double userRating;
  int totalVotes = 324;
  double selectedRating = 0;
  TextEditingController commentController = TextEditingController();
  ScrollController _scrollController = ScrollController();

  late final Stream<QuerySnapshot> _commentsStream;

  String formatDateTime(DateTime dt) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final day = twoDigits(dt.day);
    final month = twoDigits(dt.month);
    final year = dt.year;
    final hour = twoDigits(dt.hour);
    final minute = twoDigits(dt.minute);

    return "$day-$month-$year $hour:$minute";
  }

  Map<String, Map<String, String>> get translations => {
    'ar': {
      'share': 'مشاركة',
      'bookTitle': widget.title,
      'author': 'بقلم ${widget.author}',
      'reviews': 'مراجعة',
      'rateNow': 'قيم الآن',
      'Islamic': widget.category,
      'pages':
          '${widget.downloads} تحميلات • ${widget.category} • ${formatDateTime(widget.createdDate)}',
      'download': 'تحميل',
      'readNow': 'اقرأ الآن',
      'aboutBook': 'عن الكتاب',
      'description': widget.description,
      'summary': widget.summary,
      'bookSummary': 'ملخص الكتاب',
      'quickSummary': 'ملخص سريع',
      'noSummaryAvailable': 'لا يوجد ملخص متاح لهذا الكتاب.',
      'readerReviews': 'مراجعات القراء',
      'viewAll': 'عرض الكل',
      'verifiedReader': 'قارئ معتمد',
      'rateThisBook': 'قيم هذا الكتاب',
      'chooseRating': 'اختر تقييمك',
      'writeComment': 'اكتب تعليقك هنا...',
      'cancel': 'إلغاء',
      'submit': 'إرسال',
      'ratingSubmitted': 'تم إرسال تقييمك بنجاح!',
      'bookCover': widget.coverImage,
      'daysAgo': 'منذ يومين',
      'weekAgo': 'منذ أسبوع',
      'addToFavorites': 'إضافة للمفضلة',
      'signUpRequired': 'يجب التسجيل',
      'signUpToAddFavorites':
          'لإضافة الكتب إلى المفضلة، يجب عليك التسجيل كزائر في التطبيق.',
      'signUpToComment': 'لوضع تعليق، يجب عليك التسجيل كزائر في التطبيق.',
      'ok': 'حسناً',
    },
    'en': {
      'share': 'Share',
      'bookTitle': widget.title,
      'author': 'by ${widget.author}',
      'reviews': 'Reviews',
      'rateNow': 'Rate now',
      'Islamic': widget.category,
      'pages':
          '${widget.downloads} downloads • ${widget.category} • ${formatDateTime(widget.createdDate)}',
      'download': 'Download',
      'readNow': 'Read Now',
      'aboutBook': 'About the book',
      'description': widget.description,
      'summary': widget.summary,
      'bookSummary': 'Book Summary',
      'quickSummary': 'Quick Summary',
      'noSummaryAvailable': 'No summary available for this book.',
      'readerReviews': 'Reader Reviews',
      'viewAll': 'View All',
      'verifiedReader': 'Verified Reader',
      'rateThisBook': 'Rate this book',
      'chooseRating': 'Choose your rating',
      'writeComment': 'Write your comment here...',
      'cancel': 'Cancel',
      'submit': 'Submit',
      'ratingSubmitted': 'Your rating has been submitted successfully!',
      'bookCover': 'Book Cover',
      'daysAgo': '2 days ago',
      'weekAgo': '1 week ago',
      'addToFavorites': 'Add to Favorites',
      'signUpRequired': 'Sign Up Required',
      'signUpToAddFavorites':
          'In order to add books to favorites, you must sign up as a visitor in the app.',
      'signUpToComment':
          'In order to place a comment, you must sign up as a visitor in the app.',
      'ok': 'OK',
    },
  };

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? currentUser;
  String? claimValue;

  @override
  void initState() {
    super.initState();
    userRating = double.tryParse(widget.rating) ?? 0.0;

    _scrollController.addListener(() {
      setState(() {
        isScrolled = _scrollController.offset > 50;
      });
    });
    _getUserInfo();

    // 🔥 Cache the stream ONCE so it doesn’t rebuild every time
    _commentsStream = FirebaseFirestore.instance
        .collection('bookcomments')
        .where('bookId', isEqualTo: widget.id)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _getUserInfo() async {
    try {
      currentUser = _auth.currentUser;
      print("DEBUG: currentUser = ${currentUser?.uid}");
      if (currentUser != null) {
        final userClaims = await _firestore
            .collection('aspnetuserclaims')
            .where('UserId', isEqualTo: currentUser!.uid)
            .limit(1)
            .get();

        if (userClaims.docs.isNotEmpty) {
          claimValue = userClaims.docs.first['ClaimValue'];
          print("DEBUG: claimValue = $claimValue");
        }
      }
    } catch (e, st) {
      print("ERROR in _getUserInfo: $e\n$st");
    }
  }

  Future<void> _addToFavorites() async {
    try {
      final bookId = widget.id; // make sure you pass bookId to this page
      final bookQuery = await _firestore
          .collection('tblbooks')
          .where('Id', isEqualTo: bookId)
          .limit(1)
          .get();

      if (bookQuery.docs.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Book not found.')));
        return;
      }

      final bookDoc = bookQuery.docs.first;

      // ✅ Handle missing fields gracefully
      final bookTitle = bookDoc.data().containsKey('Title')
          ? bookDoc['Title']
          : 'Untitled Book';

      final bookDescription = bookDoc.data().containsKey('Description')
          ? bookDoc['Description']
          : ''; // empty string if not present

      final favoriteData = {
        'userId': currentUser!.uid,
        'bookId': bookId,
        'bookTitle': bookTitle,
        'bookDescription': bookDescription,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await _firestore.collection('favoritebooks').add(favoriteData);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Book added to favorites!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding to favorites: $e')));
    }
  }

  Future<void> _saveCommentToFirestore() async {
    try {
      if (currentUser == null) {
        _showSignUpDialog(t('signUpToComment'));
        return;
      }
      final commentText = commentController.text.trim();
      if (commentText.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Comment is empty.')));
        return;
      }

      // get user fullName safely
      String fullName = 'Unknown';
      final userDoc = await _firestore
          .collection('aspnetusers')
          .doc(currentUser!.uid)
          .get();
      if (userDoc.exists && userDoc.data()!.containsKey('FullName')) {
        fullName = userDoc['FullName'] ?? 'Unknown';
      }

      final data = {
        'userId': currentUser!.uid,
        'bookId': widget.id,
        'comment': commentText,
        'rating': selectedRating,
        'userName': fullName,
        // use serverTimestamp so ordering works reliably
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
      };

      print("DEBUG: Adding comment doc: $data");
      await _firestore.collection('bookcomments').add(data);

      commentController.clear();
      setState(() {
        selectedRating = 0;
      });

      // Optionally scroll to top to show the new comment (depending on UI)
      // _scrollController.animateTo(0, duration: Duration(milliseconds: 300), curve: Curves.easeOut);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Comment added.')));
    } catch (e, st) {
      print("ERROR in _saveCommentToFirestore: $e\n$st");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving comment: $e')));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    commentController.dispose();
    super.dispose();
  }

  String t(String key) {
    return translations[widget.language]?[key] ?? key;
  }

  bool get isRTL => widget.language == 'ar';

  void _showSignUpDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: widget.darkMode
                ? DesertColors.darkSurface
                : DesertColors.lightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              t('signUpRequired'),
              style: TextStyle(
                color: widget.darkMode
                    ? DesertColors.darkText
                    : DesertColors.lightText,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              message,
              style: TextStyle(
                color:
                    (widget.darkMode
                            ? DesertColors.darkText
                            : DesertColors.lightText)
                        .withOpacity(0.8),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  t('ok'),
                  style: TextStyle(color: DesertColors.primaryGoldDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = widget.darkMode;
    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Theme(
        data: darkMode ? _darkTheme : _lightTheme,
        child: Scaffold(
          backgroundColor: darkMode
              ? DesertColors.darkBackground
              : DesertColors.lightBackground,
          body: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBookHeader(),
                          _buildBookInfo(),
                          _buildActionButtons(),
                          _buildDescription(),
                          _buildSummary(),
                          _buildCommentsSection(),
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
    );
  }

  ThemeData get _lightTheme => ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.orange,
    scaffoldBackgroundColor: DesertColors.lightBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: DesertColors.lightText),
      titleTextStyle: TextStyle(
        color: DesertColors.lightText,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  ThemeData get _darkTheme => ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.orange,
    scaffoldBackgroundColor: DesertColors.darkBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: DesertColors.darkText),
      titleTextStyle: TextStyle(
        color: DesertColors.darkText,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _buildBookHeader() {
    final darkMode = widget.darkMode;
    return Container(
      padding: EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 768) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 200,
                  height: 280,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.coverImage,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      t('bookTitle'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: darkMode
                            ? DesertColors.darkText
                            : DesertColors.lightText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      t('author'),
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            (darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText)
                                .withOpacity(0.8),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    _buildRatingSection(),
                    SizedBox(height: 16),
                    _buildGenreChips(),
                  ],
                ),
              ],
            );
          } else {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.coverImage,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('bookTitle'),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        t('author'),
                        style: TextStyle(
                          fontSize: 18,
                          color:
                              (darkMode
                                      ? DesertColors.darkText
                                      : DesertColors.lightText)
                                  .withOpacity(0.8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildRatingSection(),
                      SizedBox(height: 16),
                      _buildGenreChips(),
                    ],
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildRatingSection() {
    final darkMode = widget.darkMode;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth < 768 ? double.infinity : 700,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: darkMode
                ? DesertColors.darkSurface
                : DesertColors.lightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DesertColors.camelSand.withOpacity(0.3)),
          ),
          child: constraints.maxWidth < 768
              ? Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.star,
                          color: DesertColors.primaryGoldDark,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '$userRating/5'.toString(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '($totalVotes ${t('reviews')})',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                (darkMode
                                        ? DesertColors.darkText
                                        : DesertColors.lightText)
                                    .withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _showRatingDialog(),
                        child: Text(t('rateNow')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesertColors.camelSand,
                          foregroundColor: DesertColors.maroon,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: DesertColors.primaryGoldDark,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '$userRating/5'.toString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkMode
                            ? DesertColors.darkText
                            : DesertColors.lightText,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '($totalVotes ${t('reviews')})',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            (darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText)
                                .withOpacity(0.6),
                      ),
                    ),
                    Spacer(),
                    ElevatedButton(
                      onPressed: () => _showRatingDialog(),
                      child: Text(t('rateNow')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesertColors.camelSand,
                        foregroundColor: DesertColors.maroon,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  void _showRatingDialog() {
    final darkMode = widget.darkMode;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Directionality(
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              child: AlertDialog(
                backgroundColor: darkMode
                    ? DesertColors.darkSurface
                    : DesertColors.lightSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  t('rateThisBook'),
                  style: TextStyle(
                    color: darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Container(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t('chooseRating'),
                        style: TextStyle(
                          color:
                              (darkMode
                                      ? DesertColors.darkText
                                      : DesertColors.lightText)
                                  .withOpacity(0.8),
                        ),
                      ),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedRating = index + 1.0;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.star,
                                size: 40,
                                color: index < selectedRating
                                    ? DesertColors.primaryGoldDark
                                    : Colors.grey.withOpacity(0.3),
                              ),
                            ),
                          );
                        }),
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: commentController,
                        maxLines: 4,
                        textDirection: isRTL
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        decoration: InputDecoration(
                          hintText: t('writeComment'),
                          hintStyle: TextStyle(
                            color:
                                (darkMode
                                        ? DesertColors.darkText
                                        : DesertColors.lightText)
                                    .withOpacity(0.5),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: DesertColors.camelSand.withOpacity(0.5),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: DesertColors.primaryGoldDark,
                            ),
                          ),
                          filled: true,
                          fillColor: darkMode
                              ? DesertColors.darkBackground
                              : DesertColors.lightBackground,
                        ),
                        style: TextStyle(
                          color: darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText,
                        ),
                        onTap: () {
                          if (currentUser == null) {
                            Navigator.of(context).pop();
                            _showSignUpDialog(t('signUpToComment'));
                          }
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      selectedRating = 0;
                      commentController.clear();
                    },
                    child: Text(
                      t('cancel'),
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: selectedRating > 0
                        ? () async {
                            if (currentUser == null) {
                              Navigator.of(context).pop();
                              _showSignUpDialog(t('signUpToComment'));
                              return;
                            }

                            if (claimValue != 'Visitor') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Only visitors can comment.'),
                                ),
                              );
                              return;
                            }

                            await _saveCommentToFirestore();
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(t('ratingSubmitted'))),
                            );
                            selectedRating = 0;
                            commentController.clear();
                          }
                        : null,
                    child: Text(t('submit')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesertColors.primaryGoldDark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
  }

  Widget _buildGenreChips() {
    final darkMode = widget.darkMode;
    List<String> genres = [t('Islamic')];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Wrap(
          spacing: 8,
          children: genres
              .map(
                (genre) => Chip(
                  label: Text(genre),
                  backgroundColor: DesertColors.camelSand.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                    fontSize: 12,
                  ),
                ),
              )
              .toList(),
        ),
        SizedBox(width: 8),
        InkWell(
          onTap: () async {
            if (currentUser == null) {
              _showSignUpDialog(t('signUpToAddFavorites'));
              return;
            }

            if (claimValue != 'Visitor') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Only visitors can add favorites.')),
              );
              return;
            }

            await _addToFavorites();
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: DesertColors.primaryGoldDark.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: DesertColors.primaryGoldDark.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_border,
                  size: 16,
                  color: DesertColors.primaryGoldDark,
                ),
                SizedBox(width: 4),
                Text(
                  t('addToFavorites'),
                  style: TextStyle(
                    fontSize: 12,
                    color: DesertColors.primaryGoldDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookInfo() {
    final darkMode = widget.darkMode;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Text(
        t('pages'),
        style: TextStyle(
          fontSize: 14,
          color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
              .withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 768) {
            return Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final pdfUrl = widget.pdfUrl;
                      final bookId = widget.id;

                      if (pdfUrl.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("PDF not available for this book."),
                          ),
                        );
                        return;
                      }

                      try {
                        // 1️⃣ Increment download count in Firestore
                        final firestore = FirebaseFirestore.instance;

                        final bookDocQuery = await firestore
                            .collection('tblbooks')
                            .where('Id', isEqualTo: bookId)
                            .limit(1)
                            .get();

                        if (bookDocQuery.docs.isNotEmpty) {
                          final docRef = bookDocQuery.docs.first.reference;
                          final currentDownloads =
                              int.tryParse(
                                bookDocQuery.docs.first
                                        .data()['DownloadsCount'] ??
                                    '0',
                              ) ??
                              0;

                          await docRef.update({
                            'DownloadsCount': (currentDownloads + 1).toString(),
                          });
                          print(
                            "✅ DownloadsCount incremented for Book ID: $bookId",
                          );
                        }

                        // 2️⃣ Launch the PDF externally
                        final Uri pdfUri = Uri.parse(pdfUrl);
                        if (await canLaunchUrl(pdfUri)) {
                          await launchUrl(
                            pdfUri,
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          throw Exception('Could not open PDF');
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error downloading PDF: $e")),
                        );
                      }
                    },
                    icon: Icon(Icons.download),
                    label: Text(t('download')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesertColors.crimson,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PDFFlipBookScreen(
                            darkMode: widget.darkMode,
                            language: widget.language,
                            titleAr: widget.title,
                            titleEn: widget.title,
                            authorAr: widget.author,
                            authorEn: widget.author,
                            pdfUrl: widget.pdfUrl,
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.menu_book),
                    label: Text(t('readNow')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DesertColors.primaryGoldDark,
                      side: BorderSide(color: DesertColors.primaryGoldDark),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final pdfUrl = widget.pdfUrl;
                      final bookId = widget
                          .id; // ✅ Make sure you pass bookId into this widget

                      if (pdfUrl.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("PDF not available for this book."),
                          ),
                        );
                        return;
                      }

                      try {
                        // 1️⃣ Increment download count in Firestore
                        final firestore = FirebaseFirestore.instance;

                        final bookDocQuery = await firestore
                            .collection('tblbooks')
                            .where('Id', isEqualTo: bookId)
                            .limit(1)
                            .get();

                        if (bookDocQuery.docs.isNotEmpty) {
                          final docRef = bookDocQuery.docs.first.reference;
                          final currentDownloads =
                              int.tryParse(
                                bookDocQuery.docs.first
                                        .data()['DownloadsCount'] ??
                                    '0',
                              ) ??
                              0;

                          await docRef.update({
                            'DownloadsCount': (currentDownloads + 1).toString(),
                          });
                          print(
                            "✅ DownloadsCount incremented for Book ID: $bookId",
                          );
                        }

                        // 2️⃣ Launch the PDF externally
                        final Uri pdfUri = Uri.parse(pdfUrl);
                        if (await canLaunchUrl(pdfUri)) {
                          await launchUrl(
                            pdfUri,
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          throw Exception('Could not open PDF');
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error downloading PDF: $e")),
                        );
                      }
                    },
                    icon: Icon(Icons.download),
                    label: Text(t('download')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesertColors.crimson,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PDFFlipBookScreen(
                            darkMode: widget.darkMode,
                            language: widget.language,
                            titleAr: widget.title,
                            titleEn: widget.title,
                            authorAr: widget.author,
                            authorEn: widget.author,
                            pdfUrl: widget.pdfUrl,
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.menu_book),
                    label: Text(t('readNow')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DesertColors.primaryGoldDark,
                      side: BorderSide(color: DesertColors.primaryGoldDark),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildDescription() {
    final darkMode = widget.darkMode;
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('aboutBook'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
          ),
          SizedBox(height: 12),
          Text(
            t('description'),
            textAlign: TextAlign.justify,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
                  .withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final darkMode = widget.darkMode;
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.summarize_outlined,
                color: DesertColors.primaryGoldDark,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                widget.language == 'ar' ? 'ملخص الكتاب' : 'Book Summary',
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
          SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: darkMode
                    ? [
                        DesertColors.darkSurface,
                        DesertColors.darkSurface.withOpacity(0.8),
                      ]
                    : [
                        DesertColors.lightSurface,
                        DesertColors.camelSand.withOpacity(0.1),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: DesertColors.primaryGoldDark.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: DesertColors.primaryGoldDark.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: DesertColors.primaryGoldDark.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: DesertColors.primaryGoldDark.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_stories,
                            size: 14,
                            color: DesertColors.primaryGoldDark,
                          ),
                          SizedBox(width: 6),
                          Text(
                            widget.language == 'ar'
                                ? 'ملخص سريع'
                                : 'Quick Summary',
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
                SizedBox(height: 16),
                Text(
                  widget.summary.isNotEmpty
                      ? widget.summary
                      : (widget.language == 'ar'
                            ? 'لا يوجد ملخص متاح لهذا الكتاب.'
                            : 'No summary available for this book.'),
                  textAlign: TextAlign.justify,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color:
                        (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText)
                            .withOpacity(0.85),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _commentsStream,
      builder: (context, snapshot) {
        // Debug logs
        print(
          "DEBUG: Comments StreamBuilder snapshot: "
          "hasData=${snapshot.hasData}, hasError=${snapshot.hasError}, "
          "connectionState=${snapshot.connectionState}",
        );

        if (snapshot.hasError) {
          print("ERROR: comments stream error: ${snapshot.error}");
          // If Firestore requires an index, Firestore console will provide a link in the error
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Error loading comments: ${snapshot.error}',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          // show loading indicator while first load occurs
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'No comments yet. Be the first one to comment!',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          );
        }

        final comments = snapshot.data!.docs;

        // Build list using the doc id so we can update likes reliably
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final doc = comments[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final username = data['userName'] ?? 'Unknown';
            final commentText = data['comment'] ?? '';
            final rating = (data['rating'] is num)
                ? (data['rating'] as num).toDouble()
                : double.tryParse(data['rating']?.toString() ?? '') ?? 0.0;
            final likes = (data['likes'] is int)
                ? data['likes']
                : (data['likes'] is num ? (data['likes'] as num).toInt() : 0);

            // Handle createdAt which might be Timestamp or string (old docs)
            DateTime createdAtDt;
            final createdAtField = data['createdAt'];
            if (createdAtField is Timestamp) {
              createdAtDt = createdAtField.toDate();
            } else if (createdAtField is String) {
              // fallback for older iso strings
              try {
                createdAtDt = DateTime.parse(createdAtField);
              } catch (_) {
                createdAtDt = DateTime.now();
              }
            } else {
              createdAtDt = DateTime.now();
            }

            final profileInitial = username.isNotEmpty
                ? username[0].toUpperCase()
                : '?';

            return Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 6.0,
                horizontal: 8.0,
              ),
              child: _buildCommentCard(
                docId: doc.id,
                username: username,
                rating: rating,
                comment: commentText,
                timeAgo: formatDateTime(createdAtDt),
                likes: likes,
                profileInitial: profileInitial,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCommentCard({
    required String docId,
    required String username,
    required double rating,
    required String comment,
    required String timeAgo,
    required int likes,
    required String profileInitial,
  }) {
    final darkMode = widget.darkMode;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : DesertColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesertColors.camelSand.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: DesertColors.primaryGoldDark,
                child: Text(
                  profileInitial,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                  Text(
                    t('verifiedReader'),
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          (darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText)
                              .withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.star,
                    color: DesertColors.primaryGoldDark,
                    size: 16,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '${rating.toInt()}/5',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            comment,
            textAlign: TextAlign.justify,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
                  .withOpacity(0.8),
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: () async {
                  try {
                    // Update likes by doc id (atomic increment)
                    final docRef = _firestore
                        .collection('bookcomments')
                        .doc(docId);
                    print(
                      "DEBUG: Incrementing likes for $docId (current likes: $likes)",
                    );
                    await docRef.update({'likes': FieldValue.increment(1)});
                  } catch (e, st) {
                    print("ERROR incrementing likes for $docId: $e\n$st");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating likes: $e')),
                    );
                  }
                },
                icon: Icon(Icons.thumb_up_outlined),
                color: DesertColors.primaryGoldDark,
                iconSize: 18,
              ),
              Text(
                '$likes',
                style: TextStyle(
                  color:
                      (darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText)
                          .withOpacity(0.6),
                ),
              ),
              SizedBox(width: 16),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.thumb_down_outlined),
                color:
                    (darkMode ? DesertColors.darkText : DesertColors.lightText)
                        .withOpacity(0.6),
                iconSize: 18,
              ),
              Spacer(),
              Text(
                timeAgo,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      (darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText)
                          .withOpacity(0.5),
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.share),
                color:
                    (darkMode ? DesertColors.darkText : DesertColors.lightText)
                        .withOpacity(0.6),
                iconSize: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
