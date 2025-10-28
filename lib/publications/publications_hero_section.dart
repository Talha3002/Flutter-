import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alraya_app/alrayah.dart';
import 'publications_detail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'publications_section.dart';
import 'dart:convert';  // Add this
import 'package:shared_preferences/shared_preferences.dart';  // Add this

// Add this AFTER imports, BEFORE PublicationsHeroSection class
class CacheService {
  static const String _cacheKey = 'publications_cache';
  static const String _timestampKey = 'publications_cache_timestamp';
  static const Duration _cacheDuration = Duration(hours: 24);

  // Save publications to cache
  static Future<void> saveToCache(List<Publication> publications) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert publications to JSON
      final List<Map<String, dynamic>> jsonList = publications.map((pub) {
        return {
          'id': pub.id,
          'title': pub.title,
          'description': pub.description,
          'createdAt': pub.createdAt,
          'createdBy': pub.createdBy,
          'updatedAt': pub.updatedAt,
          'updatedBy': pub.updatedBy,
          'imageId': pub.imageId,
          'userId': pub.userId,
          'authorFullName': pub.authorFullName,
          'category': pub.category,
          'views': pub.views,
          'shares': pub.shares,
          'coverImage': pub.coverImage,
          'parts': pub.parts.map((part) => {
            'id': part.id,
            'postId': part.postId,
            'postChapterTitle': part.postChapterTitle,
            'description': part.description,
            'createdAt': part.createdAt,
          }).toList(),
        };
      }).toList();

      await prefs.setString(_cacheKey, jsonEncode(jsonList));
      await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error saving cache: $e');
    }
  }

  // Load publications from cache
  static Future<List<Publication>?> loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if cache exists and is valid
      final timestamp = prefs.getInt(_timestampKey);
      if (timestamp == null) return null;
      
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge > _cacheDuration.inMilliseconds) {
        // Cache expired
        await clearCache();
        return null;
      }

      final String? cachedData = prefs.getString(_cacheKey);
      if (cachedData == null) return null;

      // Parse JSON
      final List<dynamic> jsonList = jsonDecode(cachedData);
      
      return jsonList.map((json) {
        final parts = (json['parts'] as List<dynamic>)
            .map((partJson) => PublicationPart(
                  id: partJson['id'] ?? '',
                  postId: partJson['postId'] ?? '',
                  postChapterTitle: partJson['postChapterTitle'] ?? '',
                  description: partJson['description'] ?? '',
                  createdAt: partJson['createdAt'] ?? '',
                ))
            .toList();

        return Publication(
          id: json['id'] ?? '',
          title: json['title'] ?? '',
          description: json['description'] ?? '',
          createdAt: json['createdAt'] ?? '',
          createdBy: json['createdBy'] ?? '',
          updatedAt: json['updatedAt'] ?? '',
          updatedBy: json['updatedBy'] ?? '',
          imageId: json['imageId'] ?? '',
          userId: json['userId'] ?? '',
          authorFullName: json['authorFullName'] ?? '',
          category: json['category'] ?? '',
          views: json['views'] ?? '',
          shares: json['shares'] ?? '',
          coverImage: json['coverImage'] ?? '',
          parts: parts,
        );
      }).toList();
    } catch (e) {
      print('Error loading cache: $e');
      return null;
    }
  }

  // Clear cache
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_timestampKey);
  }
}

class PublicationsHeroSection extends StatefulWidget {
  final bool darkMode;
  final String language;
  final bool scrolled;
  final String searchTerm;
  final String filterType;
  final int displayedBooks;

  const PublicationsHeroSection({
    super.key,
    required this.darkMode,
    required this.language,
    required this.scrolled,
    required this.searchTerm,
    required this.filterType,
    required this.displayedBooks,
  });
  @override
  _PublicationsHeroSectionState createState() =>
      _PublicationsHeroSectionState();
}

class _PublicationsHeroSectionState extends State<PublicationsHeroSection> {
  bool darkMode = false;
  String language = 'en';
  bool scrolled = false;

  List<Publication> publications = [];
  bool isLoading = true;

  ScrollController _scrollController = ScrollController();

@override
void initState() {
  super.initState();

  _scrollController.addListener(() {
    setState(() {
      scrolled = _scrollController.offset > 50;
    });
  });

  // Load data (cache first, then Firestore if needed)
  _loadPublications();
}

Future<void> _loadPublications() async {
  setState(() {
    isLoading = true;
  });

  try {
    // Try loading from cache first
    final cachedData = await CacheService.loadFromCache();
    
    if (cachedData != null && cachedData.isNotEmpty) {
      // Cache hit - instant load!
      setState(() {
        publications = cachedData;
        isLoading = false;
      });
      print('✅ Loaded ${cachedData.length} publications from cache');
    } else {
      // Cache miss - fetch from Firestore
      print('⏳ Cache miss - fetching from Firestore...');
      final fetchedPublications = await fetchPublications();
      
      setState(() {
        publications = fetchedPublications;
        isLoading = false;
      });

      // Save to cache for next time
      await CacheService.saveToCache(fetchedPublications);
      print('✅ Loaded ${fetchedPublications.length} publications from Firestore & cached');
    }
  } catch (e) {
    print('❌ Error loading publications: $e');
    setState(() {
      isLoading = false;
    });
  }
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

Future<List<Publication>> fetchPublications() async {
  try {
    // 🔥 STEP 1: Fetch ALL posts at once
    final postsSnapshot = await FirebaseFirestore.instance
        .collection('tblposts')
        .where('IsDeleted', isEqualTo: 'False')
        .get();

    if (postsSnapshot.docs.isEmpty) {
      return [];
    }

    // 🔥 STEP 2: Extract all unique UserIds
    final Set<String> userIds = postsSnapshot.docs
        .map((doc) => doc.data()['UserId'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet();

    // 🔥 STEP 3: Fetch ALL users at once (batch query)
    Map<String, String> userIdToFullName = {};
    
    if (userIds.isNotEmpty) {
      // Firestore 'in' query supports up to 10 items, so we batch if needed
      final userIdsList = userIds.toList();
      for (int i = 0; i < userIdsList.length; i += 10) {
        final batch = userIdsList.skip(i).take(10).toList();
        
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('aspnetusers')
            .where('Id', whereIn: batch)
            .get();

        for (var userDoc in usersSnapshot.docs) {
          final data = userDoc.data();
          userIdToFullName[data['Id']] = data['FullName'] ?? '';
        }
      }
    }

    // 🔥 STEP 4: Extract all PostIds
    final List<String> postIds = postsSnapshot.docs
        .map((doc) => doc.data()['Id'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toList();

    // 🔥 STEP 5: Fetch ALL chapters at once (batch query)
    Map<String, List<PublicationPart>> postIdToChapters = {};
    
    if (postIds.isNotEmpty) {
      for (int i = 0; i < postIds.length; i += 10) {
        final batch = postIds.skip(i).take(10).toList();
        
        final chaptersSnapshot = await FirebaseFirestore.instance
            .collection('tblpostchapters')
            .where('PostId', whereIn: batch)
            .get();

        for (var chapterDoc in chaptersSnapshot.docs) {
          final data = chapterDoc.data();
          final postId = data['PostId'] as String;
          
          if (!postIdToChapters.containsKey(postId)) {
            postIdToChapters[postId] = [];
          }
          
          postIdToChapters[postId]!.add(PublicationPart.fromFirestore(data));
        }
      }
    }

    // 🔥 STEP 6: Build publications in memory (no more loops!)
    List<Publication> publications = [];

    for (var postDoc in postsSnapshot.docs) {
      final postData = postDoc.data();
      final postId = postData['Id'] ?? '';
      final userId = postData['UserId'] ?? '';

      final fullName = userIdToFullName[userId] ?? '';
      final parts = postIdToChapters[postId] ?? [];

      publications.add(Publication.fromFirestore(postData, fullName, parts));
    }

    print('✅ Fetched ${publications.length} publications in optimized batch mode');
    return publications;

  } catch (e) {
    print('❌ Error fetching publications: $e');
    return [];
  }
}

  void openDrawer() {}

  @override
  Widget build(BuildContext context) {
    final darkMode = widget.darkMode;

    return Scaffold(
      backgroundColor: darkMode
          ? DesertColors.darkBackground
          : DesertColors.lightBackground,
      body: isLoading
          ? Center(child: CircularProgressIndicator()) // 🔑 loader
          : RefreshIndicator(
  onRefresh: () async {
    await CacheService.clearCache();
    await _loadPublications();
  },
  child: CustomScrollView(
    controller: _scrollController,
    slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildHeroSection(),
                      _buildPublicationsSection(),
                    ],
                  ),
                ),
              ],
            ),
    )
    );
  }

  Widget _buildHeroSection() {
    final darkMode = widget.darkMode;
    final language = widget.language;
    final publicationsCount = publications.length;

    // Check if mobile
    bool isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      height: isMobile ? 400 : 500, // Shorter height for mobile
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: darkMode
              ? [DesertColors.darkSurface, DesertColors.maroon.withOpacity(0.8)]
              : [Color(0xFFFFF8E1), Color(0xFFFFF3C4)],
        ),
      ),
      child: Stack(
        children: [
          // Mobile-specific container wrapper
          if (isMobile)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: darkMode
                    ? DesertColors.darkSurface.withOpacity(0.9)
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: _buildHeroContent(
                darkMode,
                language,
                publicationsCount,
                isMobile,
              ),
            ),

          // Desktop content (original)
          if (!isMobile)
            Center(
              child: _buildHeroContent(
                darkMode,
                language,
                publicationsCount,
                isMobile,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroContent(
    bool darkMode,
    String language,
    int publicationsCount,
    bool isMobile,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // App icon
        Container(
          width: isMobile ? 60 : 80,
          height: isMobile ? 60 : 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [DesertColors.crimson, DesertColors.primaryGoldDark],
            ),
            borderRadius: BorderRadius.circular(isMobile ? 15 : 20),
            boxShadow: [
              BoxShadow(
                color: DesertColors.crimson.withOpacity(0.3),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Icon(
            Icons.menu_book,
            size: isMobile ? 30 : 40,
            color: DesertColors.lightBackground,
          ),
        ),
        SizedBox(height: isMobile ? 16 : 24),

        // Main title
        Text(
          language == 'ar' ? 'منشورات الرؤوية' : 'Al-Rayah Publications',
          style: TextStyle(
            fontSize: isMobile ? 28 : 48,
            fontWeight: FontWeight.bold,
            color: darkMode ? DesertColors.darkText : DesertColors.lightText,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: isMobile ? 12 : 16),

        // Subtitle
        Text(
          language == 'ar'
              ? 'اكتشف مجموعة واسعة من الكتبوالدراسات الإسلامية'
              : 'Discover a wide collection of Islamic books and studies',
          style: TextStyle(
            fontSize: isMobile ? 14 : 18,
            color: darkMode
                ? DesertColors.darkText.withOpacity(0.8)
                : DesertColors.lightText.withOpacity(0.7),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: isMobile ? 24 : 40),

        // Statistics row
        isMobile
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMobileInlineStat(
                    icon: Icons.star,
                    value: '4.8',
                    label: language == 'ar' ? 'تقييم' : 'Rating',
                    color: DesertColors.camelSand,
                  ),
                  SizedBox(width: 24),
                  _buildMobileInlineStat(
                    icon: Icons.menu_book,
                    value: '$publicationsCount',
                    label: language == 'ar' ? 'كتاب متاح' : 'Books Available',
                    color: DesertColors.crimson,
                  ),
                  SizedBox(width: 24),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatCard(
                    icon: Icons.star,
                    value: '4.8',
                    label: language == 'ar' ? 'تقييم' : 'Rating',
                    color: DesertColors.camelSand,
                    darkMode: darkMode,
                  ),
                  SizedBox(width: 16),
                  _buildStatCard(
                    icon: Icons.menu_book,
                    value: '$publicationsCount',
                    label: language == 'ar' ? 'كتاب متاح' : 'Books Available',
                    color: DesertColors.crimson,
                    darkMode: darkMode,
                  ),
                  SizedBox(width: 16),
                ],
              ),
      ],
    );
  }

  Widget _buildMobileInlineStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool darkMode, // ✅ added
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        // Slightly stronger background
        color: color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),

        // Border a little darker
        border: Border.all(color: color.withOpacity(0.4), width: 1.2),

        // Soft shadow
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: darkMode
                  ? color
                  : Colors.black.withOpacity(0.8), // ✅ logic here
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: darkMode
                  ? color
                  : Colors.black.withOpacity(0.6), // ✅ lighter in light mode
            ),
          ),
        ],
      ),
    );
  }

  // Update grid delegate for smaller cards
  Widget _buildPublicationsSection() {
    final darkMode = widget.darkMode;
    final language = widget.language;
    bool isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      child: Column(
        children: [
          Text(
            language == 'ar' ? 'الإصدارات الحديثة' : 'Recent Publications',
            style: TextStyle(
              fontSize: isMobile ? 24 : 32,
              fontWeight: FontWeight.bold,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
          ),
          SizedBox(height: isMobile ? 24 : 48),

          // Mobile: Single column, Desktop: Multi-column
          isMobile
              ? _buildMobilePublicationsList()
              : _buildDesktopPublicationsGrid(),
        ],
      ),
    );
  }

  Widget _buildMobilePublicationsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: publications.length,
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: 16),
          child: _buildMobilePublicationCard(publications[index]),
        );
      },
    );
  }

  Widget _buildDesktopPublicationsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 3 : 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.1,
      ),
      itemCount: publications.length,
      itemBuilder: (context, index) {
        return _buildPublicationCard(publications[index]);
      },
    );
  }

  Widget _buildMobilePublicationCard(Publication publication) {
    final darkMode = widget.darkMode;
    final language = widget.language;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PublicationDetailPage(
              darkMode: darkMode,
              language: language,
              publication: publication,
            ),
            settings: const RouteSettings(name: '/publications'),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: darkMode
                ? [DesertColors.darkSurface, DesertColors.darkBackground]
                : [Colors.white, DesertColors.lightSurface],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: DesertColors.camelSand.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with category and language
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [DesertColors.crimson, DesertColors.maroon],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      language == 'ar' ? 'عام' : 'General',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: DesertColors.camelSand.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      language == 'ar' ? 'عربي' : 'Arabic',
                      style: TextStyle(
                        fontSize: 9,
                        color: DesertColors.primaryGoldDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: DesertColors
                      .primaryGoldDark, // 🔑 primary gold background
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/logo.png', // 🔑 your asset image
                    fit: BoxFit.cover, // fills the container nicely
                    errorBuilder: (context, error, stackTrace) {
                      // fallback if image not found
                      return Center(
                        child: Text(
                          'Desert Poetry Book Cover',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: 12),

              // Title
              Text(
                publication.getTitle(language),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: darkMode
                      ? DesertColors.darkText
                      : DesertColors.lightText,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: language == 'ar' ? TextAlign.right : TextAlign.left,
              ),
              SizedBox(height: 8),

              // Description
              Text(
                publication.getDescription(language),
                style: TextStyle(
                  fontSize: 12,
                  color: darkMode
                      ? DesertColors.darkText.withOpacity(0.7)
                      : DesertColors.lightText.withOpacity(0.7),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: language == 'ar' ? TextAlign.right : TextAlign.left,
              ),
              SizedBox(height: 12),

              // Footer with date and action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: DesertColors.crimson,
                      ),
                      SizedBox(width: 4),
                      Text(
                        publication.createdAt,
                        style: TextStyle(
                          fontSize: 10,
                          color: DesertColors.crimson,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          DesertColors.camelSand,
                          DesertColors.primaryGoldDark,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      language == 'ar' ? 'عام' : 'General',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPublicationCard(Publication publication) {
    final darkMode = widget.darkMode;
    final language = widget.language;

    // theme shortcuts
    final primaryText = darkMode
        ? DesertColors.darkText
        : const Color(0xFF2D1810);
    final secondaryText = darkMode ? Colors.white70 : const Color(0xFF666666);
    final mutedText = darkMode ? Colors.white54 : const Color(0xFF999999);
    final borderColor = darkMode ? Colors.white24 : const Color(0xFFE8E8E8);
    final tagBackground = darkMode
        ? DesertColors.darkBackground
        : const Color(0xFFF5F5F5);
    final categoryBackground = darkMode
        ? Colors.brown[700]
        : const Color(0xFFFFF3C4);

    return _HoverablePublicationCard(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PublicationDetailPage(
                darkMode: darkMode,
                language: language,
                publication: publication,
              ),
              settings: const RouteSettings(name: '/publications'),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 280,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: darkMode
                  ? [
                      DesertColors.darkSurface,
                      DesertColors.darkSurface.withOpacity(0.9),
                    ]
                  : [Colors.white, const Color(0xFFFFFDF7)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // category + bilingual
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: categoryBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getCategoryFromTitle(
                          publication.getTitle(language),
                          language,
                        ),
                        style: TextStyle(
                          fontSize: 10,
                          color: darkMode
                              ? DesertColors.darkText
                              : const Color(0xFF8B4513),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.language, size: 12, color: mutedText),
                        const SizedBox(width: 2),
                        Text(
                          language == 'ar' ? 'ثنائي اللغة' : 'Bilingual',
                          style: TextStyle(fontSize: 10, color: mutedText),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // title
                Text(
                  publication.getTitle(language),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: language == 'ar'
                      ? TextAlign.right
                      : TextAlign.left,
                ),
                const SizedBox(height: 8),

                // author
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: DesertColors.primaryGoldDark,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        publication.getAuthor(language),
                        style: TextStyle(
                          fontSize: 12,
                          color: DesertColors.primaryGoldDark,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: language == 'ar'
                            ? TextAlign.right
                            : TextAlign.left,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // description
                Text(
                  publication.getDescription(language),
                  style: TextStyle(
                    fontSize: 12,
                    color: darkMode ? DesertColors.camelSand : secondaryText,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: language == 'ar'
                      ? TextAlign.right
                      : TextAlign.left,
                ),

                // image (logo)
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 250, // adjust size as needed
                    fit: BoxFit.contain,
                  ),
                ),

                const Spacer(),

                // date + chapters
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: mutedText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      publication.createdAt,
                      style: TextStyle(
                        fontSize: 10,
                        color: DesertColors.crimson,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.book_outlined,
                      size: 12,
                      color: DesertColors.crimson,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${publication.parts.length} ${language == "ar" ? "فصول" : "chapters"}',
                      style: TextStyle(
                        fontSize: 10,
                        color: DesertColors.crimson,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: DesertColors.crimson,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // tags
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children:
                      _getTagsFromTitle(
                            publication.getTitle(language),
                            language,
                          )
                          .take(4)
                          .map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: tagBackground,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: secondaryText,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getCategoryFromTitle(String title, String language) {
    if (title.contains('Quran') || title.contains('القرآن')) {
      return language == 'ar' ? 'دراسات قرآنية' : 'Quranic Studies';
    }
    if (title.contains('Hadith') || title.contains('الحديث')) {
      return language == 'ar' ? 'الحديث' : 'Hadith';
    }
    if (title.contains('Fiqh') || title.contains('الفقه')) {
      return language == 'ar' ? 'الفقه' : 'Fiqh';
    }
    if (title.contains('Seerah') || title.contains('السيرة')) {
      return language == 'ar' ? 'السيرة' : 'Seerah';
    }
    if (title.contains('Aqeedah') || title.contains('العقيدة')) {
      return language == 'ar' ? 'العقيدة' : 'Aqeedah';
    }
    return language == 'ar' ? 'عام' : 'General';
  }

  List<String> _getTagsFromTitle(String title, String language) {
    if (title.contains('Quran') || title.contains('القرآن')) {
      return language == 'ar'
          ? ['القرآن', 'تفسير', 'تجويد', 'علوم القرآن']
          : ['quran', 'tafseer', 'tajweed', 'quranic sciences'];
    }
    if (title.contains('Hadith') || title.contains('الحديث')) {
      return language == 'ar'
          ? ['الحديث', 'السنة', 'البخاري', 'مسند']
          : ['hadith', 'sunnah', 'bukhari', 'musnad'];
    }
    if (title.contains('Fiqh') || title.contains('الفقه')) {
      return language == 'ar'
          ? ['الفقه', 'الشريعة', 'الاجتهاد', 'الفقه الإسلامي']
          : ['fiqh', 'islamic law', 'jurisprudence', 'islamic fiqh'];
    }
    if (title.contains('Seerah') || title.contains('السيرة')) {
      return language == 'ar'
          ? ['السيرة', 'حياة النبي', 'السيرة النبوية']
          : ['seerah', 'prophet life', 'sirah nabawiyyah'];
    }
    if (title.contains('Aqeedah') || title.contains('العقيدة')) {
      return language == 'ar'
          ? ['العقيدة', 'الإيمان', 'التوحيد']
          : ['aqeedah', 'beliefs', 'iman'];
    }
    return [];
  }
}

// New hoverable card widget with proper state management
class _HoverablePublicationCard extends StatefulWidget {
  final Widget child;

  const _HoverablePublicationCard({required this.child});

  @override
  _HoverablePublicationCardState createState() =>
      _HoverablePublicationCardState();
}

class _HoverablePublicationCardState extends State<_HoverablePublicationCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
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
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: DesertColors.primaryGoldDark.withOpacity(0.6),
                          blurRadius: 25,
                          offset: Offset(0, 10),
                          spreadRadius: 3,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
              ),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}
