import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'publications_hero_section.dart'; // Import your widget
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' as ui;
import '../../alrayah.dart';
import '../../componenets/navigation.dart';

// Publication Model
class Publication {
  final String id;
  final String title;
  final String description;
  final String createdAt;
  final String createdBy;
  final String updatedAt;
  final String updatedBy;
  final String imageId;
  final String userId;
  final String authorFullName; // From aspnetusers
  final String category;
  final String views;
  final String shares;
  final String coverImage;
  final List<PublicationPart> parts; // Chapters

  Publication({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    required this.updatedBy,
    required this.imageId,
    required this.userId,
    required this.authorFullName,
    required this.category,
    required this.views,
    required this.shares,
    required this.coverImage,
    required this.parts,
  });

  factory Publication.fromFirestore(
    Map<String, dynamic> data,
    String authorFullName,
    List<PublicationPart> parts,
  ) {
    return Publication(
      id: data['Id'] ?? '',
      title: data['Title'] ?? '',
      description: data['Description'] ?? '',
      createdAt: data['CreatedAt'] ?? '',
      createdBy: data['CreatedBy'] ?? '',
      updatedAt: data['UpdatedAt'] ?? '',
      updatedBy: data['UpdatedBy'] ?? '',
      imageId: data['ImageId'] ?? '',
      userId: data['UserId'] ?? '',
      authorFullName: authorFullName,
      category: 'دراسات',
      views: '15.8K',
      shares: '2.5K',
      coverImage:
          'https://images.pexels.com/photos/1130980/pexels-photo-1130980.jpeg?auto=compress&cs=tinysrgb&w=600',
      parts: parts,
    );
  }
  String getTitle(String language) => title;
  String getAuthor(String language) => authorFullName;
  String getDescription(String language) => description;
  String getCategory(String language) => category;
}

class PublicationPart {
  final String id;
  final String postId;
  final String postChapterTitle;
  final String description;
  final String createdAt;

  PublicationPart({
    required this.id,
    required this.postId,
    required this.postChapterTitle,
    required this.description,
    required this.createdAt,
  });

  factory PublicationPart.fromFirestore(Map<String, dynamic> data) {
    return PublicationPart(
      id: data['Id'] ?? '',
      postId: data['PostId'] ?? '',
      postChapterTitle: data['PostChapterTitle'] ?? '',
      description: data['Description'] ?? '',
      createdAt: data['CreatedAt'] ?? '',
    );
  }
  String getTitle(String language) => postChapterTitle;
  String getContent(String language) => description;
}

// Content Model for Translations
class AppContent {
  final Map<String, dynamic> ar = {
    'publications': {
      'title': 'منشورات الراية',
      'subtitle': 'اكتشف أحدث المنشورات والدراسات الإسلامية',
      'details': 'التفاصيل',
      'sharing': 'مشاركة',
      'publishedOn': 'نُشر في',
      'postTitle': 'عنوان المنشور',
      'postOwner': 'صاحب المنشور',
      'postDetails': 'تفاصيل المنشور',
      'writtenOn': 'كُتب في',
      'corresponding': 'الموافق لـ',
      'partsOfPost': 'أجزاء المنشور',
      'close': 'إغلاق',
      'views': 'مشاهدة',
      'shares': 'مشاركة',
    },
  };

  final Map<String, dynamic> en = {
    'publications': {
      'title': 'Alrayah Publications',
      'subtitle': 'Discover the latest publications and Islamic studies',
      'details': 'Details',
      'sharing': 'Sharing',
      'publishedOn': 'Published on',
      'postTitle': 'Post title',
      'postOwner': 'Post owner',
      'postDetails': 'Post details',
      'writtenOn': 'Written on',
      'corresponding': 'corresponding to',
      'partsOfPost': 'Parts of a post',
      'close': 'Close',
      'views': 'Views',
      'shares': 'Shares',
    },
  };

  Map<String, dynamic> getContent(String language) {
    return language == 'ar' ? ar : en;
  }
}

// Rotating Circle Widget
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

const hijriMonthNamesAr = {
  1: 'محرم',
  2: 'صفر',
  3: 'ربيع الأول',
  4: 'ربيع الآخر',
  5: 'جمادى الأولى',
  6: 'جمادى الآخرة',
  7: 'رجب',
  8: 'شعبان',
  9: 'رمضان',
  10: 'شوال',
  11: 'ذو القعدة',
  12: 'ذو الحجة',
};

String convertToArabicNumbers(String input) {
  const arabicDigits = {
    '0': '٠',
    '1': '١',
    '2': '٢',
    '3': '٣',
    '4': '٤',
    '5': '٥',
    '6': '٦',
    '7': '٧',
    '8': '٨',
    '9': '٩',
  };

  return input.split('').map((char) => arabicDigits[char] ?? char).join();
}

String formatToHijriAndGregorian(dynamic firestoreDateTime) {
  try {
    if (firestoreDateTime == null) return 'غير معروف';

    DateTime dateTime;
    if (firestoreDateTime is Timestamp) {
      dateTime = firestoreDateTime.toDate();
    } else if (firestoreDateTime is String) {
      dateTime = DateTime.parse(firestoreDateTime.split('.').first);
    } else if (firestoreDateTime is DateTime) {
      dateTime = firestoreDateTime;
    } else {
      return 'تنسيق غير مدعوم';
    }

    // Hijri
    final hijri = HijriCalendar.fromDate(dateTime);
    final hDay = hijri.hDay.toString().padLeft(2, '0');
    final hMonth = hijriMonthNamesAr[hijri.hMonth] ?? '';
    final hYear = hijri.hYear.toString();

    // Gregorian
    final gFormatted = DateFormat('EEEE، d MMMM، y', 'ar').format(dateTime);
    final time = DateFormat('h:mm a', 'ar').format(dateTime);

    final fullDate = '$hDay $hMonth ${hYear} هـ، الموافق $gFormatted، $time';

    return convertToArabicNumbers(fullDate);
  } catch (e) {
    print('Date formatting error: $e');
    return 'تاريخ غير متوفر';
  }
}

// Publication Card Widget
class PublicationCard extends StatefulWidget {
  final bool darkMode;
  final String language;
  final Publication publication;
  final int index;
  final VoidCallback onDetailsPressed;

  const PublicationCard({
    Key? key,
    required this.darkMode,
    required this.language,
    required this.publication,
    required this.index,
    required this.onDetailsPressed,
  }) : super(key: key);

  @override
  _PublicationCardState createState() => _PublicationCardState();
}

class _PublicationCardState extends State<PublicationCard>
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
      duration: Duration(milliseconds: 800 + widget.index * 100),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 50), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  transform: Matrix4.identity()..scale(isHovered ? 1.05 : 1.0),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.darkMode
                              ? (isHovered
                                    ? DesertColors.darkSurface
                                    : DesertColors.darkBackground)
                              : (isHovered
                                    ? DesertColors.lightSurface
                                    : Colors.white),
                          widget.darkMode
                              ? const Color(0xFF3D2419)
                              : DesertColors.lightSurface,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isHovered
                              ? DesertColors.crimson.withOpacity(0.3)
                              : (widget.darkMode
                                    ? Colors.black.withOpacity(0.5)
                                    : Colors.black.withOpacity(0.15)),
                          blurRadius: isHovered ? 50 : 30,
                          offset: Offset(0, isHovered ? 25 : 15),
                        ),
                      ],
                      border: Border.all(
                        color: isHovered
                            ? DesertColors.crimson.withOpacity(0.3)
                            : DesertColors.camelSand.withOpacity(0.3),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cover Image
                          Stack(
                            children: [
                              Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: NetworkImage(
                                      widget.publication.coverImage,
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 500),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: isHovered
                                          ? [
                                              DesertColors.crimson.withOpacity(
                                                0.6,
                                              ),
                                              DesertColors.maroon.withOpacity(
                                                0.6,
                                              ),
                                            ]
                                          : [
                                              Colors.transparent,
                                              DesertColors.maroon.withOpacity(
                                                0.2,
                                              ),
                                            ],
                                    ),
                                  ),
                                ),
                              ),

                              // Category Badge
                              Positioned(
                                top: 16,
                                left: 16,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      colors: isHovered
                                          ? [
                                              DesertColors.camelSand,
                                              DesertColors.primaryGoldDark,
                                            ]
                                          : [
                                              DesertColors.crimson,
                                              DesertColors.crimson.withOpacity(
                                                0.8,
                                              ),
                                            ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (isHovered
                                                    ? DesertColors.camelSand
                                                    : DesertColors.crimson)
                                                .withOpacity(0.3),
                                        blurRadius: 15,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    widget.publication.getCategory(
                                      widget.language,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              // Publication Date
                              Positioned(
                                top: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        formatToHijriAndGregorian(
                                          widget.publication.createdAt,
                                        ),
                                        style: TextStyle(
                                          color: (widget.darkMode
                                              ? DesertColors.darkText
                                              : DesertColors.lightText),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Publication Info
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: widget.language == 'ar'
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                // Title
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 300),
                                  style: isHovered
                                      ? TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          foreground: Paint()
                                            ..shader =
                                                const LinearGradient(
                                                  colors: [
                                                    DesertColors.crimson,
                                                    DesertColors
                                                        .primaryGoldDark,
                                                  ],
                                                ).createShader(
                                                  const Rect.fromLTWH(
                                                    0,
                                                    0,
                                                    200,
                                                    70,
                                                  ),
                                                ),
                                        )
                                      : TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: widget.darkMode
                                              ? DesertColors.darkText
                                              : DesertColors.lightText,
                                        ),
                                  child: Text(
                                    widget.publication.getTitle(
                                      widget.language,
                                    ),
                                    textAlign: widget.language == 'ar'
                                        ? TextAlign.right
                                        : TextAlign.left,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Published info
                                Row(
                                  mainAxisAlignment: widget.language == 'ar'
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${content['publications']['publishedOn']} ',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color:
                                            (widget.darkMode
                                                    ? DesertColors.darkText
                                                    : DesertColors.lightText)
                                                .withOpacity(0.6),
                                      ),
                                    ),
                                    Text(
                                      formatToHijriAndGregorian(
                                        widget.publication.createdAt,
                                      ),

                                      style: TextStyle(
                                        fontSize: 12,
                                        color: (widget.darkMode
                                            ? DesertColors.darkText
                                            : DesertColors.lightText),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Description
                                Text(
                                  widget.publication.getDescription(
                                    widget.language,
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        (widget.darkMode
                                                ? DesertColors.darkText
                                                : DesertColors.lightText)
                                            .withOpacity(0.9),
                                    height: 1.5,
                                  ),
                                  textAlign: widget.language == 'ar'
                                      ? TextAlign.right
                                      : TextAlign.left,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                const SizedBox(height: 16),

                                // Stats
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildStatItem(
                                      icon: Icons.visibility,
                                      value: widget.publication.views,
                                      color: DesertColors.camelSand,
                                      label: content['publications']['views'],
                                    ),
                                    _buildStatItem(
                                      icon: Icons.share,
                                      value: widget.publication.shares,
                                      color: DesertColors.crimson,
                                      label: content['publications']['shares'],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                // Action Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        child: ElevatedButton(
                                          onPressed: widget.onDetailsPressed,

                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              gradient: LinearGradient(
                                                colors: isHovered
                                                    ? [
                                                        DesertColors.crimson,
                                                        const Color(0xFFD51721),
                                                      ]
                                                    : [
                                                        DesertColors.camelSand,
                                                        const Color(0xFFFFE55C),
                                                      ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color:
                                                      (isHovered
                                                              ? DesertColors
                                                                    .crimson
                                                              : DesertColors
                                                                    .camelSand)
                                                          .withOpacity(0.4),
                                                  blurRadius: isHovered
                                                      ? 25
                                                      : 8,
                                                  offset: Offset(
                                                    0,
                                                    isHovered ? 12 : 8,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            child: Center(
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.info_outline,
                                                    size: 16,
                                                    color: isHovered
                                                        ? Colors.white
                                                        : DesertColors.maroon,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    content['publications']['details'],
                                                    style: TextStyle(
                                                      color: isHovered
                                                          ? Colors.white
                                                          : DesertColors.maroon,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      child: IconButton(
                                        onPressed: () {},
                                        icon: const Icon(Icons.share),
                                        style: IconButton.styleFrom(
                                          backgroundColor: isHovered
                                              ? DesertColors.primaryGoldDark
                                              : Colors.transparent,
                                          side: BorderSide(
                                            color: isHovered
                                                ? Colors.transparent
                                                : (widget.darkMode
                                                      ? DesertColors.camelSand
                                                      : DesertColors.maroon),
                                            width: 2,
                                          ),
                                          padding: const EdgeInsets.all(12),
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
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required Color color,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Publication Details Modal
class PublicationDetailsModal extends StatefulWidget {
  final bool darkMode;
  final String language;
  final Publication publication;
  final VoidCallback onClose;

  const PublicationDetailsModal({
    Key? key,
    required this.darkMode,
    required this.language,
    required this.publication,
    required this.onClose,
  }) : super(key: key);

  @override
  _PublicationDetailsModalState createState() =>
      _PublicationDetailsModalState();
}

class _PublicationDetailsModalState extends State<PublicationDetailsModal>
    with TickerProviderStateMixin {
  late AnimationController _modalController;
  late AnimationController _contentController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  int selectedPartIndex = -1;
  bool showMainContent = true;

  @override
  void initState() {
    super.initState();

    _modalController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _modalController, curve: Curves.easeOut));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _modalController, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _modalController, curve: Curves.easeOut));

    _modalController.forward();
    _contentController.forward();
  }

  @override
  void dispose() {
    _modalController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _showPartDetails(int index) {
    _contentController.reverse().then((_) {
      setState(() {
        selectedPartIndex = index;
        showMainContent = false;
      });
      _contentController.forward();
    });
  }

  void _showMainContent() {
    _contentController.reverse().then((_) {
      setState(() {
        selectedPartIndex = -1;
        showMainContent = true;
      });
      _contentController.forward();
    });
  }

  void _closeModal() {
    _modalController.reverse().then((_) {
      widget.onClose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = AppContent().getContent(widget.language);

    return AnimatedBuilder(
      animation: _modalController,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.black.withOpacity(0.5 * _fadeAnimation.value),
          body: Center(
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.translate(
                offset: _slideAnimation.value,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: MediaQuery.of(context).size.height * 0.8,
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.darkMode
                          ? [
                              DesertColors.darkBackground,
                              DesertColors.darkSurface,
                            ]
                          : [
                              DesertColors.lightBackground,
                              DesertColors.lightSurface,
                            ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 50,
                        offset: const Offset(0, 25),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                DesertColors.crimson.withOpacity(0.1),
                                DesertColors.camelSand.withOpacity(0.1),
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              if (!showMainContent)
                                IconButton(
                                  onPressed: _showMainContent,
                                  icon: const Icon(Icons.arrow_back),
                                  style: IconButton.styleFrom(
                                    backgroundColor: DesertColors.camelSand
                                        .withOpacity(0.2),
                                  ),
                                ),
                              if (!showMainContent) const SizedBox(width: 12),

                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: NetworkImage(
                                      widget.publication.coverImage,
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 16),

                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 20),
                                  child: Column(
                                    crossAxisAlignment: widget.language == 'ar'
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        showMainContent
                                            ? widget.publication.getTitle(
                                                widget.language,
                                              )
                                            : widget
                                                  .publication
                                                  .parts[selectedPartIndex]
                                                  .getTitle(widget.language),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: widget.darkMode
                                              ? DesertColors.darkText
                                              : DesertColors.lightText,
                                        ),
                                        textAlign: widget.language == 'ar'
                                            ? TextAlign.right
                                            : TextAlign.left,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${content['publications']['postOwner']}: ${widget.publication.getAuthor(widget.language)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color:
                                              (widget.darkMode
                                                      ? DesertColors.darkText
                                                      : DesertColors.lightText)
                                                  .withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              IconButton(
                                onPressed: _closeModal,
                                icon: const Icon(Icons.close),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(
                                    255,
                                    250,
                                    2,
                                    23,
                                  ).withOpacity(0.2),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Content
                        Expanded(
                          child: AnimatedBuilder(
                            animation: _contentController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _contentController.value,
                                child: Transform.translate(
                                  offset: Offset(
                                    0,
                                    20 * (1 - _contentController.value),
                                  ),
                                  child: showMainContent
                                      ? _buildMainContent(content)
                                      : _buildPartContent(content),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainContent(Map<String, dynamic> content) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: widget.language == 'ar'
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Post Title Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: widget.darkMode
                    ? [
                        DesertColors.darkSurface,
                        DesertColors.maroon.withOpacity(0.1),
                      ]
                    : [Colors.white, DesertColors.lightSurface],
              ),
              border: Border.all(
                color: DesertColors.camelSand.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: widget.language == 'ar'
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            DesertColors.camelSand,
                            DesertColors.primaryGoldDark,
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      content['publications']['postTitle'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: widget.darkMode
                            ? DesertColors.camelSand
                            : DesertColors.crimson,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.publication.getTitle(widget.language),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: widget.darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                  textAlign: widget.language == 'ar'
                      ? TextAlign.right
                      : TextAlign.left,
                ),
                const SizedBox(height: 8),
                Text(
                  '${content['publications']['writtenOn']} ${formatToHijriAndGregorian(widget.publication.createdAt)}',
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        (widget.darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText)
                            .withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Description
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: widget.darkMode
                    ? [
                        DesertColors.darkSurface,
                        DesertColors.maroon.withOpacity(0.1),
                      ]
                    : [Colors.white, DesertColors.lightSurface],
              ),
              border: Border.all(
                color: DesertColors.camelSand.withOpacity(0.3),
              ),
            ),
            child: Text(
              widget.publication.getDescription(widget.language),
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: widget.darkMode
                    ? DesertColors.darkText
                    : DesertColors.lightText,
              ),
              textAlign: widget.language == 'ar'
                  ? TextAlign.right
                  : TextAlign.left,
            ),
          ),

          const SizedBox(height: 24),

          // Parts Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  DesertColors.crimson.withOpacity(0.1),
                  DesertColors.camelSand.withOpacity(0.1),
                ],
              ),
              border: Border.all(color: DesertColors.crimson.withOpacity(0.3)),
            ),

            child: Column(
              crossAxisAlignment: widget.language == 'ar'
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [DesertColors.crimson, DesertColors.maroon],
                        ),
                      ),
                      child: const Icon(
                        Icons.list,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      content['publications']['partsOfPost'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.darkMode
                            ? DesertColors.darkText
                            : DesertColors.lightText,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                ...widget.publication.parts.asMap().entries.map((entry) {
                  int index = entry.key;
                  PublicationPart part = entry.value;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => _showPartDetails(index),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: widget.darkMode
                                ? [
                                    DesertColors.darkSurface,
                                    DesertColors.maroon.withOpacity(0.1),
                                  ]
                                : [Colors.white, DesertColors.lightSurface],
                          ),
                          border: Border.all(
                            color: DesertColors.camelSand.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 50),
                                child: Column(
                                  crossAxisAlignment: widget.language == 'ar'
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      part.getTitle(widget.language),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: widget.darkMode
                                            ? DesertColors.darkText
                                            : DesertColors.lightText,
                                      ),
                                      textAlign: widget.language == 'ar'
                                          ? TextAlign.right
                                          : TextAlign.left,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formatToHijriAndGregorian(part.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            (widget.darkMode
                                                    ? DesertColors.darkText
                                                    : DesertColors.lightText)
                                                .withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: const LinearGradient(
                                  colors: [
                                    DesertColors.camelSand,
                                    DesertColors.primaryGoldDark,
                                  ],
                                ),
                              ),
                              child: Text(
                                content['publications']['details'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartContent(Map<String, dynamic> content) {
    final part = widget.publication.parts[selectedPartIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: widget.language == 'ar'
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,

        children: [
          // Part Title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  DesertColors.crimson.withOpacity(0.1),
                  DesertColors.camelSand.withOpacity(0.1),
                ],
              ),
              border: Border.all(color: DesertColors.crimson.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: widget.language == 'ar'
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  part.getTitle(widget.language),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: widget.darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                  textAlign: widget.language == 'ar'
                      ? TextAlign.right
                      : TextAlign.left,
                ),
                const SizedBox(height: 8),
                Text(
                  formatToHijriAndGregorian(part.createdAt),
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        (widget.darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText)
                            .withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Part Content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: widget.darkMode
                    ? [
                        DesertColors.darkSurface,
                        DesertColors.maroon.withOpacity(0.1),
                      ]
                    : [Colors.white, DesertColors.lightSurface],
              ),
              border: Border.all(
                color: DesertColors.camelSand.withOpacity(0.3),
              ),
            ),
            child: Text(
              part.getContent(widget.language),
              style: TextStyle(
                fontSize: 16,
                height: 1.8,
                color: widget.darkMode
                    ? DesertColors.darkText
                    : DesertColors.lightText,
              ),
              textAlign: widget.language == 'ar'
                  ? TextAlign.right
                  : TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}

class PublicationsSectionPage extends StatefulWidget {
  const PublicationsSectionPage({super.key});

  @override
  _PublicationsSectionPageState createState() =>
      _PublicationsSectionPageState();
}

class _PublicationsSectionPageState extends State<PublicationsSectionPage>
    with TickerProviderStateMixin {
  bool darkMode = false;
  String language = 'ar';

  late AnimationController _rotationController;
  late AnimationController _floatingController;
  late AnimationController _pulseController;
  late AnimationController _scrollController;
  late AnimationController _themeController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();


  ScrollController _pageScrollController = ScrollController();
  bool _scrolled = false;

  String searchTerm = '';
  String filterType = 'all';
  int displayedBooks = 9;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadPreferences();
    _setupScrollListener();
  }

  void _initializeControllers() {
    _rotationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 20),
    )..repeat();
    _floatingController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
    _scrollController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
    _themeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
  }

  void _setupScrollListener() {
    _pageScrollController.addListener(() {
      setState(() {
        _scrolled = _pageScrollController.offset > 50;
      });
    });
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
    _scaffoldKey.currentState?.openEndDrawer();
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
    return Directionality(
      textDirection: language == 'ar'
          ? ui.TextDirection.rtl
          : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Color.lerp(
          DesertColors.lightBackground,
          DesertColors.darkBackground,
          darkMode ? 1.0 : 0.0,
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
                ListTile(
                  title: Text(
                    language == 'ar'
                        ? 'إصدارات المجلس'
                        : 'Council Publications',
                    style: TextStyle(
                      color: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                  onTap: () => Navigator.pushNamed(context, '/majalis'),
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
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 20,
                  ), // reduce tile width
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/publications'),
                    child: Container(
                      decoration: BoxDecoration(
                        color: currentRoute == '/publications'
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
                                ? 'منشورات الراية'
                                : 'Al-Rayah Publications',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: currentRoute == '/publications'
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

        body: Column(
          children: [
            NavigationBarWidget(
              darkMode: darkMode,
              language: language,
              scrolled: _scrolled,
              toggleDarkMode: toggleDarkMode,
              toggleLanguage: toggleLanguage,
              openDrawer: openDrawer,
            ),
            Expanded(
              child: PublicationsHeroSection(
                darkMode: darkMode,
                language: language,
                scrolled: _scrolled,
                searchTerm: searchTerm,
                filterType: filterType,
                displayedBooks: displayedBooks,
              ),
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
