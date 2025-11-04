import 'package:flutter/material.dart';
import 'package:alraya_app/alrayah.dart';
import 'admin_navigation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Add this RIGHT AFTER your imports and BEFORE the Publication class

class PublicationCache {
  static final PublicationCache _instance = PublicationCache._internal();
  factory PublicationCache() => _instance;
  PublicationCache._internal();

  // Cache storage
  List<Publication>? _publications;
  DateTime? _publicationsTimestamp;

  final Duration _cacheExpiry = Duration(minutes: 5);

  bool _isCacheValid(DateTime? timestamp) {
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  // Getter with cache validation
  List<Publication>? get publications =>
      _isCacheValid(_publicationsTimestamp) ? _publications : null;

  // Setter
  void setPublications(List<Publication> value) {
    _publications = value;
    _publicationsTimestamp = DateTime.now();
  }

  void clearAll() {
    _publications = null;
    _publicationsTimestamp = null;
  }
}

class Publication {
  final String id;
  final String title;
  final String authorName;
  final String description;
  final String status;
  final int chapterCount;

  Publication({
    required this.id,
    required this.title,
    required this.authorName,
    required this.description,
    required this.status,
    required this.chapterCount,
  });
}

class Chapter {
  final String id;
  final String title;
  final String publicationName;
  final String description;
  final int wordCount;

  Chapter({
    required this.id,
    required this.title,
    required this.publicationName,
    required this.description,
    required this.wordCount,
  });
}

class PublicationManagementPage extends StatefulWidget {
  @override
  State<PublicationManagementPage> createState() =>
      _PublicationManagementPageState();
}

class _PublicationManagementPageState extends State<PublicationManagementPage> {
  bool _darkMode = false;
  String _language = 'en';
  String _currentPage = 'Publications';
  String fullName = 'Admin User';
  bool _showAllPublications = false;
  bool _showAllChapters = false;
  bool _isLoading = true;

  List<Publication> publications = [];

  List<Chapter> chapters = [];

  @override
  void initState() {
    super.initState();
    _fetchPublications();
  }

  Future<void> _fetchPublications() async {
    final cache = PublicationCache();

    // ✅ Check cache first
    if (cache.publications != null) {
      setState(() {
        publications = cache.publications!;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ Fetch ALL data in parallel using Future.wait (NO LOOPS!)
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('tblposts')
            .where('IsDeleted', isEqualTo: 'False')
            .get(),
        FirebaseFirestore.instance
            .collection('tblpostchapters')
            .where('IsDeleted', isEqualTo: 'False')
            .get(),
      ]);

      final postsSnapshot = results[0];
      final chaptersSnapshot = results[1];

      // ✅ Create a map of PostId -> Chapter Count for fast lookup in memory
      Map<String, int> chapterCountMap = {};
      for (var chapterDoc in chaptersSnapshot.docs) {
        final postId = chapterDoc.data()['PostId'] as String?;
        if (postId != null) {
          chapterCountMap[postId] = (chapterCountMap[postId] ?? 0) + 1;
        }
      }

      print('Chapter count map: $chapterCountMap'); // Debug log

      // ✅ Build publications list using in-memory matching (NO DATABASE QUERIES!)
      List<Publication> fetchedPublications = [];
      for (var doc in postsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final postId = data['Id'] ?? doc.id;

        // Get chapter count from map (instant lookup, no query!)
        final chapterCount = chapterCountMap[postId] ?? 0;

        print('Publication ID: $postId, Chapters: $chapterCount'); // Debug log

        fetchedPublications.add(
          Publication(
            id: postId,
            title: data['Title'] ?? '',
            authorName: '', // No author in schema
            description: data['Description'] ?? '',
            status: 'Published',
            chapterCount: chapterCount,
          ),
        );
      }

      // ✅ Cache the results
      cache.setPublications(fetchedPublications);

      setState(() {
        publications = fetchedPublications;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching publications: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePublication(String publicationId, int index) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('tblposts')
          .where('Id', isEqualTo: publicationId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({
          'IsDeleted': 'True',
          'UpdatedAt': DateTime.now().toIso8601String(),
        });

        // ✅ Clear cache after deletion
        PublicationCache().clearAll();

        setState(() {
          publications.removeAt(index);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _language == 'ar' ? 'تم الحذف بنجاح' : 'Deleted successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error deleting publication: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_language == 'ar' ? 'فشل الحذف' : 'Delete failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Add this method to show edit dialog
  void _showEditPublicationDialog(Publication publication, int index) {
    showDialog(
      context: context,
      builder: (context) => EditChaptersDialog(
        darkMode: _darkMode,
        language: _language,
        publicationId: publication.id,
        publicationTitle: publication.title,
        onSave: () {
          _fetchPublications(); // Refresh the list after editing
        },
      ),
    );
  }

  void _showAddPublicationDialog() {
    showDialog(
      context: context,
      builder: (context) => AddPublicationDialog(
        darkMode: _darkMode,
        language: _language,
        onSave: () {
          _fetchPublications(); // Refresh the list after adding
        },
      ),
    );
  }

  void _showAddChapterDialog() {
    showDialog(
      context: context,
      builder: (context) => AddChapterDialog(
        darkMode: _darkMode,
        language: _language,
        publications: publications,
        onSave: () {
          _fetchPublications(); // Refresh to update chapter counts
        },
      ),
    );
  }

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  Widget _buildMobileLayout() {
    int publicationsToShow = _showAllPublications ? publications.length : 3;
    int chaptersToShow = _showAllChapters ? chapters.length : 3;

    return Column(
      children: [
        NavigationBarWidget(
          darkMode: _darkMode,
          language: _language,
          currentPage: _currentPage,
          onPageChange: (page) => setState(() => _currentPage = page),
          onLanguageToggle: () =>
              setState(() => _language = _language == 'en' ? 'ar' : 'en'),
          onThemeToggle: () => setState(() => _darkMode = !_darkMode),
          fullName: fullName,
          openDrawer: () {},
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.library_books_outlined,
                        size: 28,
                        color: DesertColors.primaryGoldDark,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _language == 'ar'
                              ? 'إدارة المنشورات'
                              : 'Publication Management',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),

                  // Publications Section
                  Text(
                    _language == 'ar' ? 'المنشورات' : 'Publications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                  SizedBox(height: 12),

                  _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : publications.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              _language == 'ar'
                                  ? 'لا توجد منشورات'
                                  : 'No publications found',
                              style: TextStyle(
                                color: _darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: publicationsToShow,
                          itemBuilder: (context, index) {
                            return PublicationCard(
                              publication: publications[index],
                              darkMode: _darkMode,
                              language: _language,
                              onEdit: () => _showEditPublicationDialog(
                                publications[index],
                                index,
                              ),
                              onDelete: () => _deletePublication(
                                publications[index].id,
                                index,
                              ),
                            );
                          },
                        ),
                  if (publications.length > 3)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _showAllPublications = !_showAllPublications;
                            });
                          },
                          child: Text(
                            _showAllPublications
                                ? (_language == 'ar' ? 'عرض أقل' : 'Show Less')
                                : (_language == 'ar'
                                      ? 'عرض المزيد'
                                      : 'Show More'),
                            style: TextStyle(
                              color: DesertColors.primaryGoldDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),

                  SizedBox(height: 24),

                  SizedBox(height: 100), // Space for bottom buttons
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        NavigationBarWidget(
          darkMode: _darkMode,
          language: _language,
          currentPage: _currentPage,
          onPageChange: (page) => setState(() => _currentPage = page),
          onLanguageToggle: () =>
              setState(() => _language = _language == 'en' ? 'ar' : 'en'),
          onThemeToggle: () => setState(() => _darkMode = !_darkMode),
          fullName: fullName,
          openDrawer: () {},
        ),
        Expanded(
          child: SingleChildScrollView(
            // ADD THIS
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.library_books_outlined,
                        size: 32,
                        color: DesertColors.primaryGoldDark,
                      ),
                      SizedBox(width: 12),
                      Text(
                        _language == 'ar'
                            ? 'إدارة المنشورات'
                            : 'Publication Management',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText,
                        ),
                      ),
                      Spacer(),
                      ElevatedButton.icon(
                        onPressed: _showAddPublicationDialog,
                        icon: Icon(Icons.add, color: Colors.white),
                        label: Text(
                          _language == 'ar' ? 'إضافة منشور' : 'Add Publication',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesertColors.primaryGoldDark,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _showAddChapterDialog,
                        icon: Icon(Icons.add, color: Colors.white),
                        label: Text(
                          _language == 'ar' ? 'إضافة فصول' : 'Add Chapters',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesertColors.primaryGoldDark,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 32),

                  Text(
                    _language == 'ar' ? 'المنشورات' : 'Publications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                  SizedBox(height: 16),

                  _isLoading
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : publications.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Text(
                              _language == 'ar'
                                  ? 'لا توجد منشورات'
                                  : 'No publications found',
                              style: TextStyle(
                                color: _darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true, // ADD THIS
                          physics: NeverScrollableScrollPhysics(), // ADD THIS
                          itemCount: publications.length,
                          itemBuilder: (context, index) {
                            return PublicationCard(
                              publication: publications[index],
                              darkMode: _darkMode,
                              language: _language,
                              onEdit: () => _showEditPublicationDialog(
                                publications[index],
                                index,
                              ),
                              onDelete: () => _deletePublication(
                                publications[index].id,
                                index,
                              ),
                            );
                          },
                        ),
                  SizedBox(height: 40), // Extra space at bottom
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void toggleLanguage() {
    setState(() {
      _language = _language == 'ar' ? 'en' : 'ar';
    });
  }

  void toggleDarkMode() {
    setState(() {
      _darkMode = !_darkMode;
    });
  }

  Future<String> getUserFullName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "User";

    final doc = await FirebaseFirestore.instance
        .collection("aspnetusers")
        .doc(user.uid)
        .get();

    if (doc.exists) {
      return doc.data()?["FullName"] ?? "User";
    }
    return "User";
  }

  @override
  Widget build(BuildContext context) {
    final String? currentRoute = ModalRoute.of(context)?.settings.name;
    return Scaffold(
      backgroundColor: _darkMode
          ? DesertColors.darkBackground
          : DesertColors.lightBackground,

      endDrawer: FutureBuilder<String>(
        future: getUserFullName(),
        builder: (context, snapshot) {
          final fullName = snapshot.data ?? "User";

          return Drawer(
            child: Container(
              color: _darkMode
                  ? DesertColors.darkBackground
                  : DesertColors.lightBackground,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // 🔹 Drawer Header
                  DrawerHeader(
                    decoration: BoxDecoration(
                      color: _darkMode ? Colors.black54 : Colors.grey[200],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              'assets/images/logo.png',
                              height: 60,
                              width: 60,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'الراية',
                              style: TextStyle(
                                color: _darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12), // spacing before name
                        Text(
                          fullName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 🔹 Language & Theme Toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 🌍 Language Toggle
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
                                colors: _darkMode
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
                                      (_darkMode
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
                                  color: _darkMode
                                      ? Colors.white
                                      : DesertColors.maroon,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  _language == 'ar' ? 'EN' : 'عر',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _darkMode
                                        ? Colors.white
                                        : DesertColors.maroon,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 🌙 Dark Mode Toggle
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
                                colors: _darkMode
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
                                      (_darkMode
                                              ? DesertColors.camelSand
                                              : DesertColors.maroon)
                                          .withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: AnimatedRotation(
                              turns: _darkMode ? 0.5 : 0,
                              duration: Duration(milliseconds: 400),
                              child: Icon(
                                _darkMode
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

                  // ✅ Dashboard Tile
                  ListTile(
                    selected: currentRoute == '/admin_dashboard',
                    selectedTileColor: _darkMode
                        ? DesertColors.primaryGoldDark
                        : DesertColors.maroon,
                    title: Text(
                      _language == 'ar' ? 'لوحة التحكم' : 'Dashboard',
                      style: TextStyle(
                        color: currentRoute == '/admin_dashboard'
                            ? (_darkMode
                                  ? DesertColors.lightText
                                  : Colors.white)
                            : (_darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText),
                      ),
                    ),
                    onTap: () =>
                        Navigator.pushNamed(context, '/admin_dashboard'),
                  ),

                  // ✅ Events Tile
                  ListTile(
                    selected: currentRoute == '/events',
                    selectedTileColor: _darkMode
                        ? DesertColors.primaryGoldDark
                        : DesertColors.maroon,
                    title: Text(
                      _language == 'ar' ? 'الفعاليات' : 'Events',
                      style: TextStyle(
                        color: currentRoute == '/events'
                            ? (_darkMode
                                  ? DesertColors.lightText
                                  : Colors.white)
                            : (_darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText),
                      ),
                    ),
                    onTap: () => Navigator.pushNamed(context, '/events'),
                  ),

                  // ✅ Books Tile
                  ListTile(
                    selected: currentRoute == '/admin_books',
                    selectedTileColor: _darkMode
                        ? DesertColors.primaryGoldDark
                        : DesertColors.maroon,
                    title: Text(
                      _language == 'ar' ? 'الكتب' : 'Books',
                      style: TextStyle(
                        color: currentRoute == '/admin_books'
                            ? (_darkMode
                                  ? DesertColors.lightText
                                  : Colors.white)
                            : (_darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText),
                      ),
                    ),
                    onTap: () => Navigator.pushNamed(context, '/admin_books'),
                  ),

                  // ✅ Publications Tile
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 20,
                    ), // reduce tile width
                    child: GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, '/admin_publication'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: currentRoute == '/admin_publication'
                              ? (_darkMode
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
                              _language == 'ar' ? 'المنشورات' : 'Publications',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: currentRoute == '/admin_publication'
                                    ? (_darkMode
                                          ? DesertColors.crimson
                                          : DesertColors.lightSurface)
                                    : (_darkMode
                                          ? DesertColors.darkText
                                          : DesertColors.lightText),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ✅ User Analytics Tile
                  ListTile(
                    selected: currentRoute == '/user-analytics',
                    selectedTileColor: _darkMode
                        ? DesertColors.primaryGoldDark
                        : DesertColors.maroon,
                    title: Text(
                      _language == 'ar' ? 'تحليلات المستخدم' : 'User Analytics',
                      style: TextStyle(
                        color: currentRoute == '/user-analytics'
                            ? (_darkMode
                                  ? DesertColors.lightText
                                  : Colors.white)
                            : (_darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText),
                      ),
                    ),
                    onTap: () =>
                        Navigator.pushNamed(context, '/user-analytics'),
                  ),

                  ListTile(
                    leading: Icon(
                      Icons.logout,
                      color: _darkMode ? Colors.red[300] : Colors.red[700],
                    ),
                    title: Text(
                      _language == 'ar' ? 'تسجيل الخروج' : 'Logout',
                      style: TextStyle(
                        color: _darkMode ? Colors.red[300] : Colors.red[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      PublicationCache().clearAll();
                      await FirebaseAuth.instance.signOut();
                      Navigator.pushReplacementNamed(
                        context,
                        '/login',
                      ); // redirect to login
                    },
                  ),

                  Divider(),

                  // ❌ Close Button
                  ListTile(
                    leading: Icon(
                      Icons.close,
                      color: _darkMode ? Colors.white : Colors.black,
                    ),
                    title: Text(
                      _language == 'ar' ? 'إغلاق' : 'Close',
                      style: TextStyle(
                        color: _darkMode
                            ? DesertColors.darkText
                            : DesertColors.lightText,
                      ),
                    ),
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      body: _isMobile(context) ? _buildMobileLayout() : _buildDesktopLayout(),
      bottomNavigationBar: _isMobile(context)
          ? Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _darkMode ? DesertColors.darkSurface : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showAddPublicationDialog,
                      icon: Icon(Icons.add, color: Colors.white),
                      label: Text(
                        _language == 'ar' ? 'إضافة منشور' : 'Add Publication',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesertColors.primaryGoldDark,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showAddChapterDialog,
                      icon: Icon(Icons.add, color: Colors.white),
                      label: Text(
                        _language == 'ar' ? 'إضافة فصول' : 'Add Chapters',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesertColors.primaryGoldDark,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

class PublicationCard extends StatelessWidget {
  final Publication publication;
  final bool darkMode;
  final String language;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PublicationCard({
    Key? key,
    required this.publication,
    required this.darkMode,
    required this.language,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  publication.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: publication.status == 'Published'
                      ? Colors.green.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  publication.status,
                  style: TextStyle(
                    fontSize: 12,
                    color: publication.status == 'Published'
                        ? Colors.green
                        : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '${language == 'ar' ? 'اسم المؤلف:' : 'Author Name:'} ${publication.authorName}',
            style: TextStyle(
              fontSize: 14,
              color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
                  .withOpacity(0.7),
            ),
          ),
          SizedBox(height: 8),
          Text(
            publication.description,
            style: TextStyle(
              fontSize: 14,
              color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
                  .withOpacity(0.7),
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 16,
                color: DesertColors.primaryGoldDark,
              ),
              SizedBox(width: 4),
              Text(
                '${publication.chapterCount} ${language == 'ar' ? 'فصول' : 'chapters'}',
                style: TextStyle(
                  fontSize: 14,
                  color:
                      (darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText)
                          .withOpacity(0.7),
                ),
              ),
              Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: Icon(Icons.edit, color: DesertColors.primaryGoldDark),
                style: IconButton.styleFrom(
                  backgroundColor: DesertColors.primaryGoldDark.withOpacity(
                    0.1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete, color: DesertColors.crimson),
                style: IconButton.styleFrom(
                  backgroundColor: DesertColors.crimson.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChapterCard extends StatelessWidget {
  final Chapter chapter;
  final bool darkMode;
  final String language;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ChapterCard({
    Key? key,
    required this.chapter,
    required this.darkMode,
    required this.language,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  chapter.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                ),
              ),
              Text(
                '${chapter.wordCount} ${language == 'ar' ? 'كلمة' : 'words'}',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      (darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText)
                          .withOpacity(0.5),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            chapter.publicationName,
            style: TextStyle(
              fontSize: 14,
              color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
                  .withOpacity(0.7),
            ),
          ),
          SizedBox(height: 8),
          Text(
            chapter.description,
            style: TextStyle(
              fontSize: 14,
              color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
                  .withOpacity(0.7),
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: Icon(
                  Icons.edit,
                  size: 16,
                  color: DesertColors.primaryGoldDark,
                ),
                label: Text(
                  language == 'ar' ? 'تعديل' : 'Edit',
                  style: TextStyle(color: DesertColors.primaryGoldDark),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: DesertColors.primaryGoldDark.withOpacity(
                    0.1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(width: 8),
              TextButton.icon(
                onPressed: onDelete,
                icon: Icon(Icons.delete, size: 16, color: DesertColors.crimson),
                label: Text(
                  language == 'ar' ? 'حذف' : 'Delete',
                  style: TextStyle(color: DesertColors.crimson),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: DesertColors.crimson.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AddPublicationDialog extends StatefulWidget {
  final bool darkMode;
  final String language;
  final VoidCallback onSave; // Changed from Function

  const AddPublicationDialog({
    Key? key,
    required this.darkMode,
    required this.language,
    required this.onSave,
  }) : super(key: key);

  @override
  State<AddPublicationDialog> createState() => _AddPublicationDialogState();
}

class _AddPublicationDialogState extends State<AddPublicationDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSaving = false;

  Future<void> _savePublication() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final countSnapshot = await FirebaseFirestore.instance
          .collection('tblposts')
          .get();

      final nextId = (countSnapshot.docs.length + 1).toString();
      final now = DateTime.now().toIso8601String();

      await FirebaseFirestore.instance.collection('tblposts').add({
        'Id': nextId,
        'Title': _titleController.text.trim(),
        'Description': _descriptionController.text.trim(),
        'CreatedAt': now,
        'UpdatedAt': now,
        'CreatedBy': user.uid,
        'UpdatedBy': user.uid,
        'UserId': user.uid,
        'IsDeleted': 'False',
        'ImageId': '',
      });

      // ✅ Clear cache after adding new publication
      PublicationCache().clearAll();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.language == 'ar'
                ? 'تم إضافة المنشور بنجاح'
                : 'Publication added successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );

      widget.onSave();
      Navigator.pop(context);
    } catch (e) {
      print('Error saving publication: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.language == 'ar'
                ? 'فشل إضافة المنشور'
                : 'Failed to add publication',
          ),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: widget.darkMode ? DesertColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.language == 'ar' ? 'إضافة منشور' : 'Add Publication',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: widget.darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                ),
                Spacer(),
                IconButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                  color: widget.darkMode
                      ? DesertColors.darkText
                      : DesertColors.lightText,
                ),
              ],
            ),
            SizedBox(height: 24),
            Text(
              widget.language == 'ar' ? 'عنوان المنشور' : 'Publication Title',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: widget.darkMode
                    ? DesertColors.darkText
                    : DesertColors.lightText,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _titleController,
              enabled: !_isSaving,
              decoration: InputDecoration(
                hintText: widget.language == 'ar'
                    ? 'عنوان المنشور'
                    : 'Publication Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: DesertColors.primaryGoldDark),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: DesertColors.primaryGoldDark.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: DesertColors.primaryGoldDark,
                    width: 2,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              widget.language == 'ar' ? 'الوصف' : 'Description',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: widget.darkMode
                    ? DesertColors.darkText
                    : DesertColors.lightText,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              enabled: !_isSaving,
              decoration: InputDecoration(
                hintText: widget.language == 'ar' ? 'الوصف' : 'Description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: DesertColors.primaryGoldDark),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: DesertColors.primaryGoldDark.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: DesertColors.primaryGoldDark,
                    width: 2,
                  ),
                ),
              ),
            ),
            SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: Text(
                    widget.language == 'ar' ? 'إلغاء' : 'Cancel',
                    style: TextStyle(
                      color: widget.darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSaving ? null : _savePublication,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesertColors.primaryGoldDark,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          widget.language == 'ar' ? 'حفظ' : 'Save',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AddChapterDialog extends StatefulWidget {
  final bool darkMode;
  final String language;
  final List<Publication> publications;
  final VoidCallback onSave;

  const AddChapterDialog({
    Key? key,
    required this.darkMode,
    required this.language,
    required this.publications,
    required this.onSave,
  }) : super(key: key);

  @override
  State<AddChapterDialog> createState() => _AddChapterDialogState();
}

class _AddChapterDialogState extends State<AddChapterDialog> {
  String? _selectedPublicationId; // Store the ID, not title
  String? _selectedPublicationTitle;
  int _numberOfChapters = 0;
  bool _showChapterForms = false;
  bool _isSaving = false;
  List<TextEditingController> _titleControllers = [];
  List<TextEditingController> _descriptionControllers = [];
  final _chapterCountController = TextEditingController();

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  @override
  void dispose() {
    for (var controller in _titleControllers) {
      controller.dispose();
    }
    for (var controller in _descriptionControllers) {
      controller.dispose();
    }
    _chapterCountController.dispose();
    super.dispose();
  }

  void _generateChapterForms() {
    if (_selectedPublicationId != null && _numberOfChapters > 0) {
      _titleControllers.clear();
      _descriptionControllers.clear();

      for (int i = 0; i < _numberOfChapters; i++) {
        _titleControllers.add(TextEditingController());
        _descriptionControllers.add(TextEditingController());
      }

      setState(() {
        _showChapterForms = true;
      });
    }
  }

  Future<void> _saveChapters() async {
    if (_selectedPublicationId == null || _titleControllers.isEmpty) {
      return;
    }

    // Validate all fields are filled
    for (int i = 0; i < _titleControllers.length; i++) {
      if (_titleControllers[i].text.trim().isEmpty ||
          _descriptionControllers[i].text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.language == 'ar'
                  ? 'يرجى ملء جميع الحقول'
                  : 'Please fill all fields',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final countSnapshot = await FirebaseFirestore.instance
          .collection('tblpostchapters')
          .get();

      int startId = countSnapshot.docs.length + 1;
      final now = DateTime.now().toIso8601String();

      for (int i = 0; i < _titleControllers.length; i++) {
        final chapterId = (startId + i).toString();

        await FirebaseFirestore.instance.collection('tblpostchapters').add({
          'Id': chapterId,
          'PostId': _selectedPublicationId,
          'PostChapterTitle': _titleControllers[i].text.trim(),
          'Description': _descriptionControllers[i].text.trim(),
          'CreatedAt': now,
          'UpdatedAt': now,
          'CreatedBy': user.uid,
          'UpdatedBy': user.uid,
          'IsDeleted': 'False',
        });

        print('Saved chapter $chapterId for PostId: $_selectedPublicationId');
      }

      // ✅ Clear cache after adding chapters (to update chapter counts)
      PublicationCache().clearAll();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.language == 'ar'
                ? 'تم إضافة الفصول بنجاح'
                : 'Chapters added successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );

      widget.onSave();
      Navigator.pop(context);
    } catch (e) {
      print('Error saving chapters: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.language == 'ar'
                ? 'فشل إضافة الفصول'
                : 'Failed to add chapters',
          ),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = _isMobile(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: isMobile
              ? MediaQuery.of(context).size.width -
                    32 // 16px padding on each side
              : MediaQuery.of(context).size.width * 0.8,
        ),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          decoration: BoxDecoration(
            color: widget.darkMode ? DesertColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.language == 'ar' ? 'إضافة فصول' : 'Add Chapters',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: widget.darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    icon: Icon(Icons.close),
                    color: widget.darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                ],
              ),
              SizedBox(height: 24),

              // For Mobile: Hide fields when showing chapter forms
              if (!isMobile || !_showChapterForms) ...[
                // Publication Dropdown
                Text(
                  widget.language == 'ar'
                      ? 'اختر المنشور'
                      : 'Select Publication',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: widget.darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  width:
                      double.infinity, // Force dropdown to respect parent width
                  child: DropdownButtonFormField<String>(
                    value: _selectedPublicationId,
                    isExpanded:
                        true, // CRITICAL: Makes dropdown text wrap properly
                    style: TextStyle(
                      color: widget.darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                      fontSize: isMobile ? 14 : 16, // Smaller text on mobile
                    ),
                    dropdownColor: widget.darkMode
                        ? DesertColors.darkSurface
                        : Colors.white,
                    iconEnabledColor: widget.darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                    decoration: InputDecoration(
                      hintText: widget.language == 'ar'
                          ? 'اختر المنشور'
                          : 'Select Publication',
                      hintStyle: TextStyle(
                        color:
                            (widget.darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText)
                                .withOpacity(0.6),
                        fontSize: isMobile ? 14 : 16, // Smaller hint on mobile
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 16,
                        vertical: isMobile ? 10 : 12,
                      ), // Tighter padding on mobile
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: DesertColors.primaryGoldDark,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: DesertColors.primaryGoldDark.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: DesertColors.primaryGoldDark,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: widget.darkMode
                          ? DesertColors.darkSurface
                          : Colors.white,
                    ),
                    items: widget.publications.map((publication) {
                      return DropdownMenuItem<String>(
                        value: publication.id,
                        child: Text(
                          publication.title,
                          style: TextStyle(
                            color: widget.darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText,
                            fontSize: isMobile
                                ? 14
                                : 16, // Smaller text on mobile
                          ),
                          overflow: TextOverflow
                              .ellipsis, // Prevent long titles from overflowing
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            setState(() {
                              _selectedPublicationId = value;
                              _selectedPublicationTitle = widget.publications
                                  .firstWhere((p) => p.id == value)
                                  .title;
                              _showChapterForms = false;
                            });
                          },
                  ),
                ),

                if (_selectedPublicationId != null) ...[
                  SizedBox(height: 16),

                  // Number of Chapters
                  Text(
                    widget.language == 'ar'
                        ? 'عدد الفصول'
                        : 'Number of Chapters',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                  SizedBox(height: 8),
                  Column(
                    children: [
                      TextField(
                        controller: _chapterCountController,
                        keyboardType: TextInputType.number,
                        enabled: !_isSaving,
                        decoration: InputDecoration(
                          hintText: widget.language == 'ar'
                              ? 'أدخل عدد الفصول'
                              : 'Enter number of chapters',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: DesertColors.primaryGoldDark,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: DesertColors.primaryGoldDark.withOpacity(
                                0.3,
                              ),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: DesertColors.primaryGoldDark,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          int? count = int.tryParse(value);
                          if (count != null && count > 0) {
                            setState(() {
                              _numberOfChapters = count;
                            });
                          }
                        },
                      ),
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_numberOfChapters > 0 && !_isSaving)
                              ? _generateChapterForms
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DesertColors.primaryGoldDark,
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            widget.language == 'ar'
                                ? 'إنشاء النماذج'
                                : 'Generate Forms',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],

              // Chapter Forms
              if (_showChapterForms) ...[
                if (isMobile && _showChapterForms) ...[
                  Container(
                    padding: EdgeInsets.all(12),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: DesertColors.primaryGoldDark.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: DesertColors.primaryGoldDark.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.book,
                          color: DesertColors.primaryGoldDark,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${widget.language == 'ar' ? 'المنشور المختار:' : 'Selected Publication:'} $_selectedPublicationTitle',
                            style: TextStyle(
                              color: DesertColors.primaryGoldDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (!isMobile) SizedBox(height: 24),

                Text(
                  widget.language == 'ar' ? 'تفاصيل الفصول' : 'Chapter Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: widget.darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                ),
                SizedBox(height: 16),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: List.generate(_numberOfChapters, (index) {
                        return Container(
                          margin: EdgeInsets.only(bottom: 24),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: DesertColors.primaryGoldDark.withOpacity(
                                0.2,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.language == 'ar' ? 'الفصل' : 'Chapter'} ${index + 1}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: DesertColors.primaryGoldDark,
                                ),
                              ),
                              SizedBox(height: 12),

                              Text(
                                widget.language == 'ar'
                                    ? 'عنوان الفصل'
                                    : 'Chapter Title',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: widget.darkMode
                                      ? DesertColors.darkText
                                      : DesertColors.lightText,
                                ),
                              ),
                              SizedBox(height: 8),
                              TextField(
                                controller: _titleControllers[index],
                                enabled: !_isSaving,
                                decoration: InputDecoration(
                                  hintText:
                                      '${widget.language == 'ar' ? 'عنوان الفصل' : 'Chapter Title'} ${index + 1}',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: DesertColors.primaryGoldDark,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: DesertColors.primaryGoldDark
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: DesertColors.primaryGoldDark,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 12),

                              Text(
                                widget.language == 'ar'
                                    ? 'وصف الفصل'
                                    : 'Chapter Description',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: widget.darkMode
                                      ? DesertColors.darkText
                                      : DesertColors.lightText,
                                ),
                              ),
                              SizedBox(height: 8),
                              TextField(
                                controller: _descriptionControllers[index],
                                maxLines: 6,
                                enabled: !_isSaving,
                                decoration: InputDecoration(
                                  hintText:
                                      '${widget.language == 'ar' ? 'وصف الفصل' : 'Chapter Description'} ${index + 1}',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: DesertColors.primaryGoldDark,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: DesertColors.primaryGoldDark
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: DesertColors.primaryGoldDark,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],

              SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isMobile) Spacer(),
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: Text(
                      widget.language == 'ar' ? 'إلغاء' : 'Cancel',
                      style: TextStyle(
                        color: widget.darkMode
                            ? DesertColors.darkText
                            : DesertColors.lightText,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  if (_showChapterForms)
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveChapters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesertColors.primaryGoldDark,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSaving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              widget.language == 'ar'
                                  ? 'حفظ الفصول'
                                  : 'Save Chapters',
                              style: TextStyle(color: Colors.white),
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
}

class EditChaptersDialog extends StatefulWidget {
  final bool darkMode;
  final String language;
  final String publicationId;
  final String publicationTitle;
  final VoidCallback onSave;

  const EditChaptersDialog({
    Key? key,
    required this.darkMode,
    required this.language,
    required this.publicationId,
    required this.publicationTitle,
    required this.onSave,
  }) : super(key: key);

  @override
  State<EditChaptersDialog> createState() => _EditChaptersDialogState();
}

class _EditChaptersDialogState extends State<EditChaptersDialog> {
  List<Map<String, dynamic>> _chapters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchChapters();
  }

  Future<void> _fetchChapters() async {
    try {
      print(
        'Fetching chapters for PostId: ${widget.publicationId}',
      ); // Debug log

      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('tblpostchapters')
          .where(
            'PostId',
            isEqualTo: widget.publicationId,
          ) // This should match the custom Id
          .where('IsDeleted', isEqualTo: 'False')
          .get();

      print('Found ${snapshot.docs.length} chapters'); // Debug log

      List<Map<String, dynamic>> chapters = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('Chapter: ${data['PostChapterTitle']}'); // Debug log

        chapters.add({
          'id': doc.id, // Use Firebase document ID for updates
          'titleController': TextEditingController(
            text: data['PostChapterTitle'] ?? '',
          ),
          'descriptionController': TextEditingController(
            text: data['Description'] ?? '',
          ),
        });
      }

      setState(() {
        _chapters = chapters;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching chapters: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChapters() async {
    try {
      for (var chapter in _chapters) {
        await FirebaseFirestore.instance
            .collection('tblpostchapters')
            .doc(chapter['id'])
            .update({
              'PostChapterTitle': chapter['titleController'].text,
              'Description': chapter['descriptionController'].text,
              'UpdatedAt': DateTime.now().toIso8601String(),
              'UpdatedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
            });
      }

      // ✅ Clear cache after editing chapters
      PublicationCache().clearAll();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.language == 'ar' ? 'تم الحفظ بنجاح' : 'Saved successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );

      widget.onSave();
      Navigator.pop(context);
    } catch (e) {
      print('Error saving chapters: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.language == 'ar' ? 'فشل الحفظ' : 'Save failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  @override
  void dispose() {
    for (var chapter in _chapters) {
      chapter['titleController'].dispose();
      chapter['descriptionController'].dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = _isMobile(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 800,
        ),
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: widget.darkMode ? DesertColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.edit_note,
                    color: DesertColors.primaryGoldDark,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.language == 'ar'
                              ? 'تعديل الفصول'
                              : 'Edit Chapters',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: widget.darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.publicationTitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: DesertColors.primaryGoldDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close),
                    color: widget.darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                ],
              ),
              SizedBox(height: 24),

              if (_isLoading)
                Center(child: CircularProgressIndicator())
              else if (_chapters.isEmpty)
                Center(
                  child: Text(
                    widget.language == 'ar'
                        ? 'لا توجد فصول'
                        : 'No chapters found',
                    style: TextStyle(
                      color: widget.darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: List.generate(_chapters.length, (index) {
                        final chapter = _chapters[index];
                        return Container(
                          margin: EdgeInsets.only(bottom: isMobile ? 16 : 24),
                          padding: EdgeInsets.all(isMobile ? 12 : 16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: DesertColors.primaryGoldDark.withOpacity(
                                0.2,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.language == 'ar' ? 'الفصل' : 'Chapter'} ${index + 1}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: DesertColors.primaryGoldDark,
                                ),
                              ),
                              SizedBox(height: 12),

                              Text(
                                widget.language == 'ar'
                                    ? 'عنوان الفصل'
                                    : 'Chapter Title',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: widget.darkMode
                                      ? DesertColors.darkText
                                      : DesertColors.lightText,
                                ),
                              ),
                              SizedBox(height: 8),
                              TextField(
                                controller: chapter['titleController'],
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: DesertColors.primaryGoldDark
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: DesertColors.primaryGoldDark,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 12),

                              Text(
                                widget.language == 'ar'
                                    ? 'وصف الفصل'
                                    : 'Chapter Description',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: widget.darkMode
                                      ? DesertColors.darkText
                                      : DesertColors.lightText,
                                ),
                              ),
                              SizedBox(height: 8),
                              TextField(
                                controller: chapter['descriptionController'],
                                maxLines: 6,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: DesertColors.primaryGoldDark
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: DesertColors.primaryGoldDark,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),

              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      widget.language == 'ar' ? 'إلغاء' : 'Cancel',
                      style: TextStyle(
                        color: widget.darkMode
                            ? DesertColors.darkText
                            : DesertColors.lightText,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _chapters.isEmpty ? null : _saveChapters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesertColors.primaryGoldDark,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      widget.language == 'ar'
                          ? 'حفظ التغييرات'
                          : 'Save Changes',
                      style: TextStyle(color: Colors.white),
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
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Publication Management',
      theme: ThemeData(primarySwatch: Colors.orange, fontFamily: 'Roboto'),
      home: PublicationManagementPage(),
    );
  }
}
