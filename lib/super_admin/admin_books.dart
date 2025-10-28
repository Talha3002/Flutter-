import 'package:flutter/material.dart';
import 'package:alraya_app/alrayah.dart';
import 'admin_navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // ← ADD THIS LINE
import 'dart:typed_data'; // ← ADD THIS if not present
import 'dart:convert';
import 'package:http/http.dart' as http;

// Add after imports, before Author class
class BookManagementCache {
  static List<Author>? _cachedAuthors;
  static List<Book>? _cachedBooks;
  static DateTime? _lastFetch;

  static bool get isCacheValid {
    if (_lastFetch == null || _cachedAuthors == null || _cachedBooks == null) {
      return false;
    }
    return DateTime.now().difference(_lastFetch!) < Duration(minutes: 5);
  }

  static void clearCache() {
    _cachedAuthors = null;
    _cachedBooks = null;
    _lastFetch = null;
  }

  static void updateCache({List<Author>? authors, List<Book>? books}) {
    _cachedAuthors = authors ?? _cachedAuthors;
    _cachedBooks = books ?? _cachedBooks;
    _lastFetch = DateTime.now();
  }

  static List<Author>? get cachedAuthors => _cachedAuthors;
  static List<Book>? get cachedBooks => _cachedBooks;
}

class Author {
  final String id;
  final String name;
  final String email;
  final int bookCount;
  final DateTime createdAt;

  Author({
    required this.id,
    required this.name,
    required this.email,
    required this.bookCount,
    required this.createdAt,
  });
}

class Book {
  final String id;
  final String title;
  final String authorName;
  final String description;
  final String summary;
  final String status;
  final String date;
  final DateTime createdAt;

  Book({
    required this.id,
    required this.title,
    required this.authorName,
    required this.description,
    required this.summary,
    required this.status,
    required this.date,
    required this.createdAt,
  });
}

enum FilterPeriod { all, thisWeek, thisMonth }

class BookManagementPage extends StatefulWidget {
  final bool darkMode;
  final String language;
  final VoidCallback onThemeToggle;
  final VoidCallback onLanguageToggle;

  const BookManagementPage({
    Key? key,
    required this.darkMode,
    required this.language,
    required this.onThemeToggle,
    required this.onLanguageToggle,
  }) : super(key: key);

  @override
  State<BookManagementPage> createState() => _BookManagementPageState();
}

class _BookManagementPageState extends State<BookManagementPage> {
  bool darkMode = false;
  String language = 'en';
  String currentPage = 'Books';
  String fullName = 'Admin User';

  bool _isLoading = false;
  FilterPeriod _authorFilter = FilterPeriod.all;
  FilterPeriod _bookFilter = FilterPeriod.all;

  List<Author> _allAuthors = [];
  List<Book> _allBooks = [];
  List<Author> _filteredAuthors = [];
  List<Book> _filteredBooks = [];

  // File pickers
  dynamic _coverImage; // Can be File or Uint8List
  String? _coverImageName;

  dynamic _bookFile; // Can be File or Uint8List
  String? _bookFileName;

  // Mobile pagination
  int _authorsToShow = 3;
  int _booksToShow = 3;

  // Replace the entire fetchAuthors method
  Future<List<Author>> fetchAuthors() async {
    // 🚀 Return cached data if valid
    if (BookManagementCache.isCacheValid &&
        BookManagementCache.cachedAuthors != null) {
      debugPrint(
        "DEBUG: Using cached authors (${BookManagementCache.cachedAuthors!.length} authors)",
      );
      return BookManagementCache.cachedAuthors!;
    }

    debugPrint("DEBUG: Fetching authors from Firestore...");

    // 🚀 Fetch both collections in parallel
    final results = await Future.wait([
      FirebaseFirestore.instance
          .collection('tblauthors')
          .where('IsDeleted', isEqualTo: "False")
          .get(),
      FirebaseFirestore.instance
          .collection('tblbooks')
          .where('IsDeleted', isEqualTo: "False")
          .get(),
    ]);

    final authorsSnapshot = results[0];
    final booksSnapshot = results[1];

    debugPrint(
      "DEBUG: Fetched ${authorsSnapshot.docs.length} authors, ${booksSnapshot.docs.length} books",
    );

    // 🚀 Process book counts in memory - NO loops with queries
    final Map<String, int> bookCountMap = {};
    for (var doc in booksSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final authorId = data['AuthorId'] ?? '';
      if (authorId.isNotEmpty) {
        bookCountMap[authorId] = (bookCountMap[authorId] ?? 0) + 1;
      }
    }

    // Build authors list
    final authors = authorsSnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      DateTime createdAt;
      try {
        createdAt = DateTime.parse(
          data['CreatedAt'] ?? DateTime.now().toIso8601String(),
        );
      } catch (e) {
        createdAt = DateTime.now();
      }

      return Author(
        id: data['Id'] ?? '',
        name: data['Name'] ?? '',
        email: data['Email'] ?? '',
        bookCount: bookCountMap[data['Id']] ?? 0,
        createdAt: createdAt,
      );
    }).toList();

    // Update cache
    BookManagementCache.updateCache(authors: authors);

    debugPrint("DEBUG: Authors cached successfully");
    return authors;
  }

  // Replace the entire fetchBooks method
  Future<List<Book>> fetchBooks() async {
    // 🚀 Return cached data if valid
    if (BookManagementCache.isCacheValid &&
        BookManagementCache.cachedBooks != null) {
      debugPrint(
        "DEBUG: Using cached books (${BookManagementCache.cachedBooks!.length} books)",
      );
      return BookManagementCache.cachedBooks!;
    }

    debugPrint("DEBUG: Fetching books from Firestore...");

    // 🚀 Fetch both collections in parallel
    final results = await Future.wait([
      FirebaseFirestore.instance
          .collection('tblbooks')
          .where('IsDeleted', isEqualTo: "False")
          .get(),
      FirebaseFirestore.instance
          .collection('tblauthors')
          .where('IsDeleted', isEqualTo: "False")
          .get(),
    ]);

    final booksSnapshot = results[0];
    final authorsSnapshot = results[1];

    debugPrint(
      "DEBUG: Fetched ${booksSnapshot.docs.length} books, ${authorsSnapshot.docs.length} authors",
    );

    // 🚀 Create author name map for O(1) lookup
    final Map<String, String> authorNameMap = {};
    for (var doc in authorsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      authorNameMap[data['Id']] = data['Name'];
    }

    // Build books list
    final books = booksSnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      DateTime createdAt;
      try {
        createdAt = DateTime.parse(
          data['CreatedAt'] ?? DateTime.now().toIso8601String(),
        );
      } catch (e) {
        createdAt = DateTime.now();
      }

      return Book(
        id: data['Id'] ?? '',
        title: data['Title'] ?? '',
        authorName: authorNameMap[data['AuthorId']] ?? 'Unknown Author',
        description: data['Description'] ?? '',
        summary: data['Summary'] ?? '',
        status: "Published",
        date: data['CreatedAt']?.toString().split(' ')[0] ?? '',
        createdAt: createdAt,
      );
    }).toList();

    // Update cache
    BookManagementCache.updateCache(books: books);

    debugPrint("DEBUG: Books cached successfully");
    return books;
  }

  // Replace the entire deleteAuthorFromFirestore method
  Future<void> deleteAuthorFromFirestore(String authorId) async {
    print('🗑️ HARD DELETING author: $authorId');

    await FirebaseFirestore.instance
        .collection('tblauthors')
        .doc(authorId)
        .delete();

    print('✅ Author document DELETED from Firestore');

    // 🚀 Clear cache after deleting
    BookManagementCache.clearCache();
    debugPrint("DEBUG: Cache cleared after deleting author");
  }

  // HARD DELETE book with files from Supabase
  Future<void> deleteBookWithFiles(String bookId) async {
    try {
      print('🗑️ Starting HARD DELETE for book: $bookId');

      // 1️⃣ Get the book document to find file references
      final bookDoc = await FirebaseFirestore.instance
          .collection('tblbooks')
          .doc(bookId)
          .get();

      if (!bookDoc.exists) {
        throw Exception('Book not found');
      }

      final bookData = bookDoc.data();
      final imageId = bookData?['ImageId'] ?? '';
      final pdfId = bookData?['BookPdfId'] ?? '';

      print('📄 Book ImageId: $imageId');
      print('📄 Book PdfId: $pdfId');

      final supabase = Supabase.instance.client;

      // 2️⃣ Delete image file from Supabase AND Firestore
      if (imageId.isNotEmpty) {
        try {
          print('🖼️ Processing image deletion...');

          final imageDoc = await FirebaseFirestore.instance
              .collection('tbluploadedfiles')
              .doc(imageId)
              .get();

          if (imageDoc.exists) {
            final imageData = imageDoc.data();
            final imagePath = imageData?['Path'] ?? '';

            print('📍 Image path from DB: $imagePath');

            if (imagePath.isNotEmpty) {
              // Extract Supabase path
              String supabasePath = imagePath.replaceAll('\\', '/');
              if (supabasePath.contains('newfile/')) {
                supabasePath = supabasePath.substring(
                  supabasePath.indexOf('newfile/'),
                );

                print(
                  '🗑️ Attempting to delete image from Supabase: $supabasePath',
                );

                // Delete from Supabase storage - with explicit error handling
                try {
                  final deleteResult = await supabase.storage
                      .from('library-assets')
                      .remove([supabasePath]);

                  print('✅ Supabase image delete response: $deleteResult');
                  print('✅ Image deleted from Supabase');
                } catch (supabaseError) {
                  print('❌ Supabase image delete FAILED: $supabaseError');
                  print(
                    '❌ This might be a permissions issue in Supabase Storage policies',
                  );
                  // Don't rethrow - continue with deletion
                }
              }
            }

            // HARD DELETE the file record from Firestore
            await FirebaseFirestore.instance
                .collection('tbluploadedfiles')
                .doc(imageId)
                .delete();

            print('✅ Image record DELETED from Firestore');
          }
        } catch (e) {
          print('⚠️ Error processing image deletion: $e');
          // Continue with deletion
        }
      }

      // 3️⃣ Delete PDF file from Supabase AND Firestore
      if (pdfId.isNotEmpty) {
        try {
          print('📕 Processing PDF deletion...');

          final pdfDoc = await FirebaseFirestore.instance
              .collection('tbluploadedfiles')
              .doc(pdfId)
              .get();

          if (pdfDoc.exists) {
            final pdfData = pdfDoc.data();
            final pdfPath = pdfData?['Path'] ?? '';

            print('📍 PDF path from DB: $pdfPath');

            if (pdfPath.isNotEmpty) {
              // Extract Supabase path
              String supabasePath = pdfPath.replaceAll('\\', '/');
              if (supabasePath.contains('newfile/')) {
                supabasePath = supabasePath.substring(
                  supabasePath.indexOf('newfile/'),
                );

                print(
                  '🗑️ Attempting to delete PDF from Supabase: $supabasePath',
                );

                // Delete from Supabase storage - with explicit error handling
                try {
                  final deleteResult = await supabase.storage
                      .from('library-assets')
                      .remove([supabasePath]);

                  print('✅ Supabase PDF delete response: $deleteResult');
                  print('✅ PDF deleted from Supabase');
                } catch (supabaseError) {
                  print('❌ Supabase PDF delete FAILED: $supabaseError');
                  print(
                    '❌ This might be a permissions issue in Supabase Storage policies',
                  );
                  // Don't rethrow - continue with deletion
                }
              }
            }

            // HARD DELETE the file record from Firestore
            await FirebaseFirestore.instance
                .collection('tbluploadedfiles')
                .doc(pdfId)
                .delete();

            print('✅ PDF record DELETED from Firestore');
          }
        } catch (e) {
          print('⚠️ Error processing PDF deletion: $e');
          // Continue with deletion
        }
      }

      // 4️⃣ HARD DELETE the book document from Firestore
      print('🗑️ Deleting book document from Firestore...');

      await FirebaseFirestore.instance
          .collection('tblbooks')
          .doc(bookId)
          .delete();

      print('✅ Book document DELETED from Firestore');
      print('🎉 HARD DELETE completed successfully');

      BookManagementCache.clearCache();
      debugPrint("DEBUG: Cache cleared after deleting book");
    } catch (e, stackTrace) {
      print('❌ Error in deleteBookWithFiles: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  void _applyFilters() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);

    // Filter authors
    switch (_authorFilter) {
      case FilterPeriod.all:
        _filteredAuthors = List.from(_allAuthors);
        break;
      case FilterPeriod.thisWeek:
        _filteredAuthors = _allAuthors
            .where((author) => author.createdAt.isAfter(weekStart))
            .toList();
        break;
      case FilterPeriod.thisMonth:
        _filteredAuthors = _allAuthors
            .where((author) => author.createdAt.isAfter(monthStart))
            .toList();
        break;
    }

    // Filter books
    switch (_bookFilter) {
      case FilterPeriod.all:
        _filteredBooks = List.from(_allBooks);
        break;
      case FilterPeriod.thisWeek:
        _filteredBooks = _allBooks
            .where((book) => book.createdAt.isAfter(weekStart))
            .toList();
        break;
      case FilterPeriod.thisMonth:
        _filteredBooks = _allBooks
            .where((book) => book.createdAt.isAfter(monthStart))
            .toList();
        break;
    }
  }

  void _showAddAuthorDialog() {
    showDialog(
      context: context,
      builder: (context) => AddAuthorDialog(
        darkMode: widget.darkMode,
        language: widget.language,
        onSave: (name, email) async {
          await addAuthorToFirestore(name, email);
          await loadData();
        },
      ),
    );
  }

  void _showAddBookDialog() {
    showDialog(
      context: context,
      builder: (context) => AddBookDialog(
        darkMode: widget.darkMode,
        language: widget.language,
        authors: _filteredAuthors,
        onSave:
            (
              title,
              description,
              summary,
              authorId,
              coverImage,
              coverImageName,
              bookFile,
              bookFileName,
            ) async {
              // Set the files in the parent state
              setState(() {
                _coverImage = coverImage;
                _coverImageName = coverImageName;
                _bookFile = bookFile;
                _bookFileName = bookFileName;
              });

              await uploadAndSaveBook(title, description, summary, authorId);
              await loadData();

              // Clear the files after upload
              setState(() {
                _coverImage = null;
                _coverImageName = null;
                _bookFile = null;
                _bookFileName = null;
              });
            },
      ),
    );
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
  void initState() {
    super.initState();
    loadData();
  }

  // Replace the entire loadData method
  Future<void> loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 🚀 Parallel execution of both fetch operations
      final results = await Future.wait([fetchAuthors(), fetchBooks()]);

      final fetchedAuthors = results[0] as List<Author>;
      final fetchedBooks = results[1] as List<Book>;

      setState(() {
        _allAuthors = fetchedAuthors;
        _allBooks = fetchedBooks;
        _isLoading = false;
      });

      _applyFilters();

      debugPrint(
        "DEBUG: Data loaded - ${_allAuthors.length} authors, ${_allBooks.length} books",
      );
    } catch (e) {
      debugPrint("ERROR: Failed to load data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Replace the entire addAuthorToFirestore method
  Future<void> addAuthorToFirestore(String name, String email) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now().toIso8601String();

    await FirebaseFirestore.instance.collection('tblauthors').doc(id).set({
      'Id': id,
      'Name': name,
      'Email': email,
      'CreatedAt': now,
      'UpdatedAt': now,
      'IsDeleted': "False",
    });

    // 🚀 Clear cache after adding
    BookManagementCache.clearCache();
    debugPrint("DEBUG: Cache cleared after adding author");
  }

  // Replace the entire addBookToFirestore method
  Future<void> addBookToFirestore(
    String title,
    String description,
    String summary,
    String authorId,
  ) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now().toIso8601String();

    await FirebaseFirestore.instance.collection('tblbooks').doc(id).set({
      'Id': id,
      'Title': title,
      'AuthorId': authorId,
      'Description': description,
      'Summary': summary,
      'DownloadsCount': "0",
      'CreatedAt': now,
      'UpdatedAt': now,
      'IsDeleted': "False",
    });

    // 🚀 Clear cache after adding
    BookManagementCache.clearCache();
    debugPrint("DEBUG: Cache cleared after adding book");
  }

  // Replace the entire updateAuthorInFirestore method
  Future<void> updateAuthorInFirestore(
    String id,
    String name,
    String email,
  ) async {
    final now = DateTime.now().toIso8601String();
    await FirebaseFirestore.instance.collection('tblauthors').doc(id).update({
      'Name': name,
      'Email': email,
      'UpdatedAt': now,
    });

    // 🚀 Clear cache after updating
    BookManagementCache.clearCache();
    debugPrint("DEBUG: Cache cleared after updating author");
  }

  // Replace the entire updateBookInFirestore method
  Future<void> updateBookInFirestore(
    String id,
    String title,
    String description,
    String summary,
    String authorId,
  ) async {
    final now = DateTime.now().toIso8601String();
    await FirebaseFirestore.instance.collection('tblbooks').doc(id).update({
      'Title': title,
      'Description': description,
      'Summary': summary,
      'AuthorId': authorId,
      'UpdatedAt': now,
    });

    // 🚀 Clear cache after updating
    BookManagementCache.clearCache();
    debugPrint("DEBUG: Cache cleared after updating book");
  }

  Future<void> uploadAndSaveBook(
    String title,
    String description,
    String summary,
    String authorId,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final now = DateTime.now().toIso8601String();

      String? imageId;
      String? pdfId;

      print('Starting book upload process...'); // Debug
      print('Cover image is null: ${_coverImage == null}'); // Debug
      print('Book file is null: ${_bookFile == null}'); // Debug

      // 1️⃣ Upload image if available
      if (_coverImage != null && _coverImageName != null) {
        print('Uploading cover image...'); // Debug

        final imagePath =
            'newfile/Books/Images/${DateTime.now().millisecondsSinceEpoch}_$_coverImageName';

        late Uint8List imageBytes;

        if (kIsWeb) {
          imageBytes = _coverImage as Uint8List;
        } else {
          imageBytes = await (_coverImage as File).readAsBytes();
        }

        print('Image bytes length: ${imageBytes.length}'); // Debug

        // Upload to Supabase
        await supabase.storage
            .from('library-assets')
            .uploadBinary(imagePath, imageBytes);

        print('Image uploaded to Supabase'); // Debug

        // Get public URL
        final imagePublicUrl = supabase.storage
            .from('library-assets')
            .getPublicUrl(imagePath);

        print('Image public URL: $imagePublicUrl'); // Debug

        // Create file record in Firestore
        final imageFileId = DateTime.now().microsecondsSinceEpoch.toString();

        await FirebaseFirestore.instance
            .collection('tbluploadedfiles')
            .doc(imageFileId)
            .set({
              'Id': imageFileId,
              'EntityId': id,
              'EntityType': 'Book',
              'ContentType': '.jpeg',
              'FileName': _coverImageName,
              'Path': '\\Files\\Books\\Images\\$imagePath',
              'SupabaseUrl': imagePublicUrl,
              'CreatedAt': now,
              'CreatedBy': FirebaseAuth.instance.currentUser?.uid ?? 'system',
              'IsDeleted': 'False',
              'UpdatedAt': now,
            });

        imageId = imageFileId;
        print('Image file record created with ID: $imageId'); // Debug
      } else {
        print('No cover image to upload'); // Debug
      }

      // 2️⃣ Upload PDF if available
      if (_bookFile != null && _bookFileName != null) {
        print('Uploading book file...'); // Debug

        final pdfPath =
            'newfile/Books/PDFs/${DateTime.now().millisecondsSinceEpoch}_$_bookFileName';

        late Uint8List pdfBytes;

        if (kIsWeb) {
          pdfBytes = _bookFile as Uint8List;
        } else {
          pdfBytes = await (_bookFile as File).readAsBytes();
        }

        print('PDF bytes length: ${pdfBytes.length}'); // Debug

        // Upload to Supabase
        await supabase.storage
            .from('library-assets')
            .uploadBinary(pdfPath, pdfBytes);

        print('PDF uploaded to Supabase'); // Debug

        // Get public URL
        final pdfPublicUrl = supabase.storage
            .from('library-assets')
            .getPublicUrl(pdfPath);

        print('PDF public URL: $pdfPublicUrl'); // Debug

        // Create file record in Firestore
        final pdfFileId = DateTime.now().microsecondsSinceEpoch.toString();

        await FirebaseFirestore.instance
            .collection('tbluploadedfiles')
            .doc(pdfFileId)
            .set({
              'Id': pdfFileId,
              'EntityId': id,
              'EntityType': 'Book',
              'ContentType': '.pdf',
              'FileName': _bookFileName,
              'Path': '\\Files\\Books\\PDFs\\$pdfPath',
              'SupabaseUrl': pdfPublicUrl,
              'CreatedAt': now,
              'CreatedBy': FirebaseAuth.instance.currentUser?.uid ?? 'system',
              'IsDeleted': 'False',
              'UpdatedAt': now,
            });

        pdfId = pdfFileId;
        print('PDF file record created with ID: $pdfId'); // Debug
      } else {
        print('No book file to upload'); // Debug
      }

      // 3️⃣ Save book record with file references
      print('Creating book record...'); // Debug

      await FirebaseFirestore.instance.collection('tblbooks').doc(id).set({
        'Id': id,
        'Title': title,
        'AuthorId': authorId,
        'Description': description,
        'Summary': summary,
        'DownloadsCount': "0",
        'ImageId': imageId ?? '',
        'BookPdfId': pdfId ?? '',
        'CreatedAt': now,
        'UpdatedAt': now,
        'IsDeleted': "False",
      });

      print(
        'Book saved successfully with ImageId: $imageId and BookPdfId: $pdfId',
      ); // Debug
    } catch (e, stackTrace) {
      print('Error in uploadAndSaveBook: $e'); // Debug
      print('Stack trace: $stackTrace'); // Debug
      rethrow;
    }
  }

  Widget _buildFilterChips(
    FilterPeriod currentFilter,
    Function(FilterPeriod) onChanged,
    String type,
  ) {
    return Row(
      children: [
        _buildFilterChip(
          label: widget.language == 'ar' ? 'الكل' : 'All',
          isSelected: currentFilter == FilterPeriod.all,
          onTap: () {
            onChanged(FilterPeriod.all);
            setState(() {
              _applyFilters();
            });
          },
        ),
        SizedBox(width: 8),
        _buildFilterChip(
          label: widget.language == 'ar' ? 'هذا الأسبوع' : 'This Week',
          isSelected: currentFilter == FilterPeriod.thisWeek,
          onTap: () {
            onChanged(FilterPeriod.thisWeek);
            setState(() {
              _applyFilters();
            });
          },
        ),
        SizedBox(width: 8),
        _buildFilterChip(
          label: widget.language == 'ar' ? 'هذا الشهر' : 'This Month',
          isSelected: currentFilter == FilterPeriod.thisMonth,
          onTap: () {
            onChanged(FilterPeriod.thisMonth);
            setState(() {
              _applyFilters();
            });
          },
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? DesertColors.primaryGoldDark
              : (widget.darkMode
                    ? DesertColors.darkSurface
                    : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? DesertColors.primaryGoldDark
                : (widget.darkMode
                      ? DesertColors.darkText.withOpacity(0.2)
                      : Colors.grey.shade400),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (widget.darkMode
                      ? DesertColors.darkText
                      : DesertColors.lightText),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBottomNavigation() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.darkMode ? DesertColors.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showAddAuthorDialog,
              icon: Icon(Icons.person_add, color: Colors.white),
              label: Text(
                widget.language == 'ar' ? 'إضافة مؤلف' : 'Add Author',
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
          SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showAddBookDialog,
              icon: Icon(Icons.menu_book, color: Colors.white),
              label: Text(
                widget.language == 'ar' ? 'إضافة كتاب' : 'Add Book',
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
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        FutureBuilder<String>(
          future: getUserFullName(),
          builder: (context, snapshot) {
            final fullName = snapshot.data ?? "Loading...";
            return NavigationBarWidget(
              darkMode: darkMode,
              language: language,
              currentPage: currentPage,
              onPageChange: (page) {
                setState(() {
                  currentPage = page;
                });
              },
              onLanguageToggle: () =>
                  setState(() => language = language == 'en' ? 'ar' : 'en'),
              onThemeToggle: () => setState(() => darkMode = !darkMode),
              fullName: fullName,
              openDrawer: () => Scaffold.of(context).openEndDrawer(),
            );
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 28,
                      color: DesertColors.primaryGoldDark,
                    ),
                    SizedBox(width: 12),
                    Text(
                      widget.language == 'ar'
                          ? 'إدارة الكتب'
                          : 'Book Management',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: widget.darkMode
                            ? DesertColors.darkText
                            : DesertColors.lightText,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),

                if (_isLoading)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            DesertColors.primaryGoldDark,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          widget.language == 'ar'
                              ? 'جاري التحميل...'
                              : 'Loading...',
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
                else ...[
                  // Authors Section
                  Row(
                    children: [
                      Text(
                        widget.language == 'ar' ? 'المؤلفون' : 'Authors',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: widget.darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText,
                        ),
                      ),
                      SizedBox(width: 12),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: DesertColors.primaryGoldDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_filteredAuthors.length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildFilterChips(
                    _authorFilter,
                    (filter) => _authorFilter = filter,
                    'authors',
                  ),
                  SizedBox(height: 16),

                  // Authors List
                  _filteredAuthors.isEmpty
                      ? Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 48,
                                color:
                                    (widget.darkMode
                                            ? DesertColors.darkText
                                            : DesertColors.lightText)
                                        .withOpacity(0.3),
                              ),
                              SizedBox(height: 16),
                              Text(
                                widget.language == 'ar'
                                    ? 'لا توجد مؤلفون'
                                    : 'No authors found',
                                style: TextStyle(
                                  color:
                                      (widget.darkMode
                                              ? DesertColors.darkText
                                              : DesertColors.lightText)
                                          .withOpacity(0.6),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            ...(_filteredAuthors
                                .take(_authorsToShow)
                                .map(
                                  (author) => AuthorCard(
                                    author: author,
                                    darkMode: widget.darkMode,
                                    language: widget.language,
                                    onEdit: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AddAuthorDialog(
                                          darkMode: widget.darkMode,
                                          language: widget.language,
                                          initialName: author.name,
                                          initialEmail: author.email,
                                          onSave: (name, email) async {
                                            await updateAuthorInFirestore(
                                              author.id,
                                              name,
                                              email,
                                            );
                                            await loadData();
                                          },
                                        ),
                                      );
                                    },
                                    onDelete: () async {
                                      // Show confirmation dialog
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: widget.darkMode
                                              ? DesertColors.darkSurface
                                              : Colors.white,
                                          title: Text(
                                            widget.language == 'ar'
                                                ? 'تأكيد الحذف'
                                                : 'Confirm Delete',
                                            style: TextStyle(
                                              color: widget.darkMode
                                                  ? DesertColors.darkText
                                                  : DesertColors.lightText,
                                            ),
                                          ),
                                          content: Text(
                                            widget.language == 'ar'
                                                ? 'هل أنت متأكد من حذف هذا المؤلف؟'
                                                : 'Are you sure you want to delete this author?',
                                            style: TextStyle(
                                              color: widget.darkMode
                                                  ? DesertColors.darkText
                                                  : DesertColors.lightText,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: Text(
                                                widget.language == 'ar'
                                                    ? 'إلغاء'
                                                    : 'Cancel',
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    DesertColors.crimson,
                                              ),
                                              child: Text(
                                                widget.language == 'ar'
                                                    ? 'حذف'
                                                    : 'Delete',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirmed == true) {
                                        try {
                                          await deleteAuthorFromFirestore(
                                            author.id,
                                          );
                                          await loadData(); // Reload data from Firestore

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                widget.language == 'ar'
                                                    ? 'تم حذف المؤلف بنجاح'
                                                    : 'Author deleted successfully',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                widget.language == 'ar'
                                                    ? 'فشل في حذف المؤلف'
                                                    : 'Failed to delete author',
                                              ),
                                              backgroundColor:
                                                  DesertColors.crimson,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                )),
                            if (_filteredAuthors.length > _authorsToShow)
                              Container(
                                margin: EdgeInsets.symmetric(vertical: 16),
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _authorsToShow += 3;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: DesertColors
                                        .primaryGoldDark
                                        .withOpacity(0.1),
                                    foregroundColor:
                                        DesertColors.primaryGoldDark,
                                    elevation: 0,
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
                                        ? 'عرض المزيد من المؤلفين'
                                        : 'Show more authors',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                  SizedBox(height: 32),

                  // Books Section
                  Row(
                    children: [
                      Text(
                        widget.language == 'ar' ? 'الكتب' : 'Books',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: widget.darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText,
                        ),
                      ),
                      SizedBox(width: 12),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: DesertColors.primaryGoldDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_filteredBooks.length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildFilterChips(
                    _bookFilter,
                    (filter) => _bookFilter = filter,
                    'books',
                  ),
                  SizedBox(height: 16),

                  // Books List
                  _filteredBooks.isEmpty
                      ? Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.menu_book_outlined,
                                size: 48,
                                color:
                                    (widget.darkMode
                                            ? DesertColors.darkText
                                            : DesertColors.lightText)
                                        .withOpacity(0.3),
                              ),
                              SizedBox(height: 16),
                              Text(
                                widget.language == 'ar'
                                    ? 'لا توجد كتب'
                                    : 'No books found',
                                style: TextStyle(
                                  color:
                                      (widget.darkMode
                                              ? DesertColors.darkText
                                              : DesertColors.lightText)
                                          .withOpacity(0.6),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            ...(_filteredBooks
                                .take(_booksToShow)
                                .map(
                                  (book) => BookCard(
                                    book: book,
                                    darkMode: widget.darkMode,
                                    language: widget.language,
                                    onEdit: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AddBookDialog(
                                          darkMode: widget.darkMode,
                                          language: widget.language,
                                          authors: _filteredAuthors,
                                          initialTitle: book.title,
                                          initialDescription: book.description,
                                          initialSummary: book.summary,
                                          initialAuthorId: _filteredAuthors
                                              .firstWhere(
                                                (a) =>
                                                    a.name == book.authorName,
                                                orElse: () =>
                                                    _filteredAuthors.first,
                                              )
                                              .id,
                                          onSave:
                                              (
                                                title,
                                                description,
                                                summary,
                                                authorId,
                                                coverImage,
                                                coverImageName,
                                                bookFile,
                                                bookFileName,
                                              ) async {
                                                await updateBookInFirestore(
                                                  book.id,
                                                  title,
                                                  description,
                                                  summary,
                                                  authorId,
                                                );
                                                await loadData();
                                              },
                                        ),
                                      );
                                    },
                                    onDelete: () async {
                                      // Show confirmation dialog
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: widget.darkMode
                                              ? DesertColors.darkSurface
                                              : Colors.white,
                                          title: Text(
                                            widget.language == 'ar'
                                                ? 'تأكيد الحذف'
                                                : 'Confirm Delete',
                                            style: TextStyle(
                                              color: widget.darkMode
                                                  ? DesertColors.darkText
                                                  : DesertColors.lightText,
                                            ),
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                widget.language == 'ar'
                                                    ? 'هل أنت متأكد من حذف هذا الكتاب؟'
                                                    : 'Are you sure you want to delete this book?',
                                                style: TextStyle(
                                                  color: widget.darkMode
                                                      ? DesertColors.darkText
                                                      : DesertColors.lightText,
                                                ),
                                              ),
                                              SizedBox(height: 12),
                                              Container(
                                                padding: EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .warning_amber_rounded,
                                                      color: Colors.orange,
                                                      size: 20,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        widget.language == 'ar'
                                                            ? 'سيتم حذف ملفات الكتاب من التخزين'
                                                            : 'Book files will be deleted from storage',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: widget.darkMode
                                                              ? DesertColors
                                                                    .darkText
                                                              : DesertColors
                                                                    .lightText,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: Text(
                                                widget.language == 'ar'
                                                    ? 'إلغاء'
                                                    : 'Cancel',
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    DesertColors.crimson,
                                              ),
                                              child: Text(
                                                widget.language == 'ar'
                                                    ? 'حذف'
                                                    : 'Delete',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirmed == true) {
                                        // Show loading indicator
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (dialogContext) => Center(
                                            child: CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    DesertColors
                                                        .primaryGoldDark,
                                                  ),
                                            ),
                                          ),
                                        );

                                        try {
                                          await deleteBookWithFiles(book.id);

                                          // ✅ Check if widget is still mounted before using context
                                          if (!mounted) return;

                                          Navigator.pop(
                                            context,
                                          ); // Close loading dialog
                                          await loadData(); // Reload data from Firestore

                                          if (!mounted) return;

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                widget.language == 'ar'
                                                    ? 'تم حذف الكتاب وملفاته بنجاح'
                                                    : 'Book and files deleted successfully',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        } catch (e) {
                                          if (!mounted) return;

                                          Navigator.pop(
                                            context,
                                          ); // Close loading dialog

                                          if (!mounted) return;

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                widget.language == 'ar'
                                                    ? 'فشل في حذف الكتاب: ${e.toString()}'
                                                    : 'Failed to delete book: ${e.toString()}',
                                              ),
                                              backgroundColor:
                                                  DesertColors.crimson,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                )),
                            if (_filteredBooks.length > _booksToShow)
                              Container(
                                margin: EdgeInsets.symmetric(vertical: 16),
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _booksToShow += 3;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: DesertColors
                                        .primaryGoldDark
                                        .withOpacity(0.1),
                                    foregroundColor:
                                        DesertColors.primaryGoldDark,
                                    elevation: 0,
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
                                        ? 'عرض المزيد من الكتب'
                                        : 'Show more books',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                  SizedBox(height: 80), // Space for bottom navigation
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        FutureBuilder<String>(
          future: getUserFullName(),
          builder: (context, snapshot) {
            final fullName = snapshot.data ?? "Loading...";
            return NavigationBarWidget(
              darkMode: darkMode,
              language: language,
              currentPage: currentPage,
              onPageChange: (page) {
                setState(() {
                  currentPage = page;
                });
              },
              onLanguageToggle: () =>
                  setState(() => language = language == 'en' ? 'ar' : 'en'),
              onThemeToggle: () => setState(() => darkMode = !darkMode),
              fullName: fullName,
              openDrawer: () => Scaffold.of(context).openEndDrawer(),
            );
          },
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 32,
                      color: DesertColors.primaryGoldDark,
                    ),
                    SizedBox(width: 12),
                    Text(
                      widget.language == 'ar'
                          ? 'إدارة الكتب'
                          : 'Book Management',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: widget.darkMode
                            ? DesertColors.darkText
                            : DesertColors.lightText,
                      ),
                    ),
                    Spacer(),
                    ElevatedButton.icon(
                      onPressed: _showAddAuthorDialog,
                      icon: Icon(Icons.add, color: Colors.white),
                      label: Text(
                        widget.language == 'ar' ? 'إضافة مؤلف' : 'Add Author',
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
                      onPressed: _showAddBookDialog,
                      icon: Icon(Icons.add, color: Colors.white),
                      label: Text(
                        widget.language == 'ar' ? 'إضافة كتاب' : 'Add Book',
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
                if (_isLoading)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              DesertColors.primaryGoldDark,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            widget.language == 'ar'
                                ? 'جاري التحميل...'
                                : 'Loading...',
                            style: TextStyle(
                              color: widget.darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    widget.language == 'ar'
                                        ? 'المؤلفون'
                                        : 'Authors',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: widget.darkMode
                                          ? DesertColors.darkText
                                          : DesertColors.lightText,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: DesertColors.primaryGoldDark
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_filteredAuthors.length}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: DesertColors.primaryGoldDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              _buildFilterChips(
                                _authorFilter,
                                (filter) => _authorFilter = filter,
                                'authors',
                              ),
                              SizedBox(height: 16),
                              Expanded(
                                child: _filteredAuthors.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.person_outline,
                                              size: 48,
                                              color:
                                                  (widget.darkMode
                                                          ? DesertColors
                                                                .darkText
                                                          : DesertColors
                                                                .lightText)
                                                      .withOpacity(0.3),
                                            ),
                                            SizedBox(height: 16),
                                            Text(
                                              widget.language == 'ar'
                                                  ? 'لا توجد مؤلفون'
                                                  : 'No authors found',
                                              style: TextStyle(
                                                color:
                                                    (widget.darkMode
                                                            ? DesertColors
                                                                  .darkText
                                                            : DesertColors
                                                                  .lightText)
                                                        .withOpacity(0.6),
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: _filteredAuthors.length,
                                        itemBuilder: (context, index) {
                                          return AuthorCard(
                                            author: _filteredAuthors[index],
                                            darkMode: widget.darkMode,
                                            language: widget.language,
                                            onEdit: () {
                                              final currentAuthor =
                                                  _filteredAuthors[index];
                                              showDialog(
                                                context: context,
                                                builder: (context) => AddAuthorDialog(
                                                  darkMode: widget.darkMode,
                                                  language: widget.language,
                                                  initialName:
                                                      currentAuthor.name,
                                                  initialEmail:
                                                      currentAuthor.email,
                                                  onSave: (name, email) async {
                                                    await updateAuthorInFirestore(
                                                      currentAuthor.id,
                                                      name,
                                                      email,
                                                    );
                                                    await loadData();
                                                  },
                                                ),
                                              );
                                            },
                                            onDelete: () {
                                              setState(() {
                                                _filteredAuthors.removeAt(
                                                  index,
                                                );
                                              });
                                            },
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 32),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    widget.language == 'ar' ? 'الكتب' : 'Books',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: widget.darkMode
                                          ? DesertColors.darkText
                                          : DesertColors.lightText,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: DesertColors.primaryGoldDark
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_filteredBooks.length}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: DesertColors.primaryGoldDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              _buildFilterChips(
                                _bookFilter,
                                (filter) => _bookFilter = filter,
                                'books',
                              ),
                              SizedBox(height: 16),
                              Expanded(
                                child: _filteredBooks.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.menu_book_outlined,
                                              size: 48,
                                              color:
                                                  (widget.darkMode
                                                          ? DesertColors
                                                                .darkText
                                                          : DesertColors
                                                                .lightText)
                                                      .withOpacity(0.3),
                                            ),
                                            SizedBox(height: 16),
                                            Text(
                                              widget.language == 'ar'
                                                  ? 'لا توجد كتب'
                                                  : 'No books found',
                                              style: TextStyle(
                                                color:
                                                    (widget.darkMode
                                                            ? DesertColors
                                                                  .darkText
                                                            : DesertColors
                                                                  .lightText)
                                                        .withOpacity(0.6),
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: _filteredBooks.length,
                                        itemBuilder: (context, index) {
                                          return BookCard(
                                            book: _filteredBooks[index],
                                            darkMode: widget.darkMode,
                                            language: widget.language,
                                            onEdit: () {
                                              final currentBook =
                                                  _filteredBooks[index];
                                              showDialog(
                                                context: context,
                                                builder: (context) => AddBookDialog(
                                                  darkMode: widget.darkMode,
                                                  language: widget.language,
                                                  authors: _filteredAuthors,
                                                  initialTitle:
                                                      currentBook.title,
                                                  initialDescription:
                                                      currentBook.description,
                                                  initialSummary:
                                                      currentBook.summary,
                                                  initialAuthorId:
                                                      _filteredAuthors
                                                          .firstWhere(
                                                            (a) =>
                                                                a.name ==
                                                                currentBook
                                                                    .authorName,
                                                            orElse: () =>
                                                                _filteredAuthors
                                                                    .first,
                                                          )
                                                          .id,
                                                  onSave:
                                                      (
                                                        title,
                                                        description,
                                                        summary,
                                                        authorId,
                                                        coverImage,
                                                        coverImageName,
                                                        bookFile,
                                                        bookFileName,
                                                      ) async {
                                                        await updateBookInFirestore(
                                                          currentBook.id,
                                                          title,
                                                          description,
                                                          summary,
                                                          authorId,
                                                        );
                                                        await loadData();
                                                      },
                                                ),
                                              );
                                            },
                                            onDelete: () async {
                                              // Show confirmation dialog
                                              final confirmed = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  backgroundColor:
                                                      widget.darkMode
                                                      ? DesertColors.darkSurface
                                                      : Colors.white,
                                                  title: Text(
                                                    widget.language == 'ar'
                                                        ? 'تأكيد الحذف'
                                                        : 'Confirm Delete',
                                                    style: TextStyle(
                                                      color: widget.darkMode
                                                          ? DesertColors
                                                                .darkText
                                                          : DesertColors
                                                                .lightText,
                                                    ),
                                                  ),
                                                  content: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        widget.language == 'ar'
                                                            ? 'هل أنت متأكد من حذف هذا الكتاب؟'
                                                            : 'Are you sure you want to delete this book?',
                                                        style: TextStyle(
                                                          color: widget.darkMode
                                                              ? DesertColors
                                                                    .darkText
                                                              : DesertColors
                                                                    .lightText,
                                                        ),
                                                      ),
                                                      SizedBox(height: 12),
                                                      Container(
                                                        padding: EdgeInsets.all(
                                                          8,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.orange
                                                              .withOpacity(0.1),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .warning_amber_rounded,
                                                              color:
                                                                  Colors.orange,
                                                              size: 20,
                                                            ),
                                                            SizedBox(width: 8),
                                                            Expanded(
                                                              child: Text(
                                                                widget.language ==
                                                                        'ar'
                                                                    ? 'سيتم حذف ملفات الكتاب من التخزين'
                                                                    : 'Book files will be deleted from storage',
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color:
                                                                      widget
                                                                          .darkMode
                                                                      ? DesertColors
                                                                            .darkText
                                                                      : DesertColors
                                                                            .lightText,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            context,
                                                            false,
                                                          ),
                                                      child: Text(
                                                        widget.language == 'ar'
                                                            ? 'إلغاء'
                                                            : 'Cancel',
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            context,
                                                            true,
                                                          ),
                                                      style:
                                                          ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                DesertColors
                                                                    .crimson,
                                                          ),
                                                      child: Text(
                                                        widget.language == 'ar'
                                                            ? 'حذف'
                                                            : 'Delete',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (confirmed == true) {
                                                // Show loading indicator
                                                showDialog(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (context) => Center(
                                                    child: CircularProgressIndicator(
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(
                                                            DesertColors
                                                                .primaryGoldDark,
                                                          ),
                                                    ),
                                                  ),
                                                );

                                                try {
                                                  await deleteBookWithFiles(
                                                    _filteredBooks[index].id,
                                                  );
                                                  Navigator.pop(
                                                    context,
                                                  ); // Close loading dialog
                                                  await loadData(); // Reload data from Firestore

                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        widget.language == 'ar'
                                                            ? 'تم حذف الكتاب وملفاته بنجاح'
                                                            : 'Book and files deleted successfully',
                                                      ),
                                                      backgroundColor:
                                                          Colors.green,
                                                    ),
                                                  );
                                                } catch (e) {
                                                  Navigator.pop(
                                                    context,
                                                  ); // Close loading dialog
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        widget.language == 'ar'
                                                            ? 'فشل في حذف الكتاب: ${e.toString()}'
                                                            : 'Failed to delete book: ${e.toString()}',
                                                      ),
                                                      backgroundColor:
                                                          DesertColors.crimson,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                          );
                                        },
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
      ],
    );
  }

  void toggleLanguage() {
    setState(() {
      language = language == 'ar' ? 'en' : 'ar';
    });
  }

  void toggleDarkMode() {
    setState(() {
      darkMode = !darkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 768;
    final String? currentRoute = ModalRoute.of(context)?.settings.name;
    return Scaffold(
      backgroundColor: widget.darkMode
          ? DesertColors.darkBackground
          : DesertColors.lightBackground,
      endDrawer: FutureBuilder<String>(
        future: getUserFullName(),
        builder: (context, snapshot) {
          final fullName = snapshot.data ?? "User";

          return Drawer(
            child: Container(
              color: darkMode
                  ? DesertColors.darkBackground
                  : DesertColors.lightBackground,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // 🔹 Drawer Header
                  DrawerHeader(
                    decoration: BoxDecoration(
                      color: darkMode ? Colors.black54 : Colors.grey[200],
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
                                color: darkMode
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
                            color: darkMode
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

                  // ✅ Dashboard Tile
                  ListTile(
                    selected: currentRoute == '/admin_dashboard',
                    selectedTileColor: darkMode
                        ? DesertColors.primaryGoldDark
                        : DesertColors.maroon,
                    title: Text(
                      language == 'ar' ? 'لوحة التحكم' : 'Dashboard',
                      style: TextStyle(
                        color: currentRoute == '/admin_dashboard'
                            ? (darkMode ? DesertColors.lightText : Colors.white)
                            : (darkMode
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
                    selectedTileColor: darkMode
                        ? DesertColors.primaryGoldDark
                        : DesertColors.maroon,
                    title: Text(
                      language == 'ar' ? 'الفعاليات' : 'Events',
                      style: TextStyle(
                        color: currentRoute == '/events'
                            ? (darkMode ? DesertColors.lightText : Colors.white)
                            : (darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText),
                      ),
                    ),
                    onTap: () => Navigator.pushNamed(context, '/events'),
                  ),

                  // ✅ Books Tile
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 20,
                    ), // reduce tile width
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/admin_books'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: currentRoute == '/admin_books'
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
                              language == 'ar' ? 'الكتب' : 'Books',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: currentRoute == '/admin_books'
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

                  // ✅ Publications Tile
                  ListTile(
                    selected: currentRoute == '/admin_publication',
                    selectedTileColor: darkMode
                        ? DesertColors.primaryGoldDark
                        : DesertColors.maroon,
                    title: Text(
                      language == 'ar' ? 'المنشورات' : 'Publications',
                      style: TextStyle(
                        color: currentRoute == '/admin_publication'
                            ? (darkMode ? DesertColors.lightText : Colors.white)
                            : (darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText),
                      ),
                    ),
                    onTap: () =>
                        Navigator.pushNamed(context, '/admin_publication'),
                  ),

                  // ✅ User Analytics Tile
                  ListTile(
                    selected: currentRoute == '/user-analytics',
                    selectedTileColor: darkMode
                        ? DesertColors.primaryGoldDark
                        : DesertColors.maroon,
                    title: Text(
                      language == 'ar' ? 'تحليلات المستخدم' : 'User Analytics',
                      style: TextStyle(
                        color: currentRoute == '/user-analytics'
                            ? (darkMode ? DesertColors.lightText : Colors.white)
                            : (darkMode
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
                      color: darkMode ? Colors.red[300] : Colors.red[700],
                    ),
                    title: Text(
                      language == 'ar' ? 'تسجيل الخروج' : 'Logout',
                      style: TextStyle(
                        color: darkMode ? Colors.red[300] : Colors.red[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      BookManagementCache.clearCache();
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
          );
        },
      ),
      body: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
      bottomNavigationBar: isMobile ? _buildMobileBottomNavigation() : null,
    );
  }
}

class AuthorCard extends StatelessWidget {
  final Author author;
  final bool darkMode;
  final String language;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AuthorCard({
    Key? key,
    required this.author,
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: DesertColors.camelSand,
            child: Text(
              _getInitials(author.name),
              style: TextStyle(
                color: DesertColors.maroon,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  author.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  author.email,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText)
                            .withOpacity(0.7),
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${author.bookCount} ${language == 'ar' ? 'كتب' : 'books'}',
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
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: DesertColors.primaryGoldDark.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatDate(author.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: DesertColors.primaryGoldDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
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

  String _getInitials(String name) {
    final parts = name.trim().split(" ");
    if (parts.length > 1) {
      return parts[0][0].toUpperCase() + parts[1][0].toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '${difference}d ago';
    } else if (difference < 30) {
      return '${(difference / 7).floor()}w ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class BookCard extends StatelessWidget {
  final Book book;
  final bool darkMode;
  final String language;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const BookCard({
    Key? key,
    required this.book,
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
      // --- REPLACE the original "child: Row(" ... ")": ---
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: DesertColors.camelSand.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.menu_book_outlined,
              color: DesertColors.primaryGoldDark,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          // make the main content flexible so it can shrink on narrow screens
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  '${language == 'ar' ? 'اسم المؤلف:' : 'Author Name:'} ${book.authorName}',
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText)
                            .withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Text(
                  book.description,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText)
                            .withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Text(
                  '${language == 'ar' ? 'الملخص:' : 'Summary:'} ${book.summary}',
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText)
                            .withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12),
                // <-- FLEXIBLE status + date row: prevents overflow and lets date shrink
                Row(
                  children: [
                    // status wraps naturally and can take only required space
                    Flexible(
                      flex: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: book.status == 'Published'
                              ? Colors.green.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          book.status,
                          style: TextStyle(
                            fontSize: 12,
                            color: book.status == 'Published'
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    // date will shrink to fit using FittedBox inside a Flexible
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: DesertColors.primaryGoldDark.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        // FittedBox will scale the Text down when there's not enough width
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _formatDate(book.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: DesertColors.primaryGoldDark,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          // keep action buttons compact so they don't push layout off-screen
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  padding: EdgeInsets.all(8),
                  minimumSize: Size(40, 40),
                ),
              ),
              SizedBox(height: 8),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete, color: DesertColors.crimson),
                style: IconButton.styleFrom(
                  backgroundColor: DesertColors.crimson.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.all(8),
                  minimumSize: Size(40, 40),
                ),
              ),
            ],
          ),
        ],
      ),

      // --- END replacement ---
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '${difference}d ago';
    } else if (difference < 30) {
      return '${(difference / 7).floor()}w ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class AddAuthorDialog extends StatefulWidget {
  final bool darkMode;
  final String language;
  final Function(String name, String email) onSave;
  final String? initialName;
  final String? initialEmail;

  const AddAuthorDialog({
    Key? key,
    required this.darkMode,
    required this.language,
    required this.onSave,
    this.initialName,
    this.initialEmail,
  }) : super(key: key);

  @override
  State<AddAuthorDialog> createState() => _AddAuthorDialogState();
}

class _AddAuthorDialogState extends State<AddAuthorDialog> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
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
                  widget.language == 'ar' ? 'إضافة مؤلف' : 'Add Author',
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
              widget.language == 'ar' ? 'اسم المؤلف' : 'Author Name',
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
              controller: _nameController,
              enabled: !_isSaving,
              decoration: InputDecoration(
                hintText: widget.language == 'ar'
                    ? 'اسم المؤلف'
                    : 'Author Name',
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
              widget.language == 'ar'
                  ? 'بريد المؤلف الإلكتروني'
                  : 'Author Email',
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
              controller: _emailController,
              enabled: !_isSaving,
              decoration: InputDecoration(
                hintText: widget.language == 'ar'
                    ? 'بريد المؤلف الإلكتروني'
                    : 'Author Email',
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
                  onPressed: _isSaving
                      ? null
                      : () async {
                          if (_nameController.text.isNotEmpty &&
                              _emailController.text.isNotEmpty) {
                            setState(() {
                              _isSaving = true;
                            });

                            try {
                              await widget.onSave(
                                _nameController.text,
                                _emailController.text,
                              );
                              Navigator.pop(context);
                            } catch (e) {
                              setState(() {
                                _isSaving = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error saving author'),
                                  backgroundColor: DesertColors.crimson,
                                ),
                              );
                            }
                          }
                        },
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

class AddBookDialog extends StatefulWidget {
  final bool darkMode;
  final String language;
  final List<Author> authors;
  final Function(
    String title,
    String description,
    String summary,
    String authorId,
    dynamic coverImage,
    String? coverImageName,
    dynamic bookFile,
    String? bookFileName,
  )
  onSave;
  final String? initialTitle;
  final String? initialDescription;
  final String? initialSummary;
  final String? initialAuthorId;

  const AddBookDialog({
    Key? key,
    required this.darkMode,
    required this.language,
    required this.authors,
    required this.onSave,
    this.initialTitle,
    this.initialDescription,
    this.initialSummary,
    this.initialAuthorId,
  }) : super(key: key);

  @override
  State<AddBookDialog> createState() => _AddBookDialogState();
}

class _AddBookDialogState extends State<AddBookDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _summaryController;

  bool _isGeneratingSummary = false;
  bool _summaryGenerated = false;
  bool _isSaving = false;
  Author? _selectedAuthor;

  dynamic _coverImage; // Can be File or Uint8List
  dynamic _bookFile; // Can be File or Uint8List
  String? _coverImageName;
  String? _bookFileName;

  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _generateAISummary() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.language == 'ar'
                ? 'يرجى إدخال العنوان والوصف أولاً'
                : 'Please enter title and description first',
          ),
          backgroundColor: DesertColors.crimson,
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingSummary = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Generate a temporary book ID (or use existing if editing)
      final bookId = DateTime.now().millisecondsSinceEpoch.toString();

      // Prepare PDF base64 if available
      String? pdfBase64;
      if (_bookFile != null) {
        Uint8List bytes;
        if (kIsWeb) {
          bytes = _bookFile as Uint8List;
        } else {
          bytes = await (_bookFile as File).readAsBytes();
        }

        // Limit PDF size to 2MB for API (optional)
        if (bytes.length > 2 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.language == 'ar'
                    ? 'ملف PDF كبير جدًا. سيتم استخدام العنوان والوصف فقط.'
                    : 'PDF too large. Using title and description only.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          pdfBase64 = base64Encode(bytes);
        }
      }

      // Make API request
      final response = await http
          .post(
            Uri.parse('http://localhost:3000/generate-book-summary'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': user.uid,
              'bookId': bookId,
              'title': _titleController.text,
              'description': _descriptionController.text,
              'pdfBase64': pdfBase64, // Can be null
            }),
          )
          .timeout(
            Duration(seconds: 45),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          );

      // Parse response
      Map<String, dynamic> result = {};
      try {
        result = jsonDecode(response.body);
      } catch (_) {
        result = {'error': 'Invalid server response'};
      }

      print("📩 Summary response (${response.statusCode}): ${response.body}");

      // Handle rate limit (429)
      if (response.statusCode == 429) {
        setState(() {
          _isGeneratingSummary = false;
        });

        String errorMessage = result['error'] ?? 'Rate limit exceeded';
        String limitType = result['type'] ?? '';

        _showSummaryLimitDialog(errorMessage, limitType);
        return;
      }

      // Handle other errors
      if (response.statusCode != 200) {
        throw Exception(result['error'] ?? 'Failed to generate summary');
      }

      // Success - set the summary
      String aiSummary = result['summary'] ?? '';

      setState(() {
        _summaryController.text = aiSummary;
        _summaryGenerated = true;
        _isGeneratingSummary = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.language == 'ar'
                ? '✅ تم توليد الملخص بنجاح!'
                : '✅ Summary generated successfully!',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        _isGeneratingSummary = false;
      });

      print("❌ Summary generation failed: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.language == 'ar'
                ? 'فشل في توليد الملخص: ${e.toString()}'
                : 'Failed to generate summary: ${e.toString()}',
          ),
          backgroundColor: DesertColors.crimson,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSummaryLimitDialog(String errorMessage, String limitType) {
    String title;
    String message;
    IconData icon;
    Color iconColor;

    if (limitType == 'global') {
      title = widget.language == 'ar'
          ? 'تم الوصول إلى الحد اليومي'
          : 'Daily Limit Reached';
      message = widget.language == 'ar'
          ? 'تم استخدام جميع ملخصات الكتب لهذا اليوم (3 ملخصات). يرجى المحاولة غدًا.'
          : 'All book summaries for today have been used (3 summaries). Please try again tomorrow.';
      icon = Icons.block;
      iconColor = Colors.red;
    } else if (limitType == 'per_book') {
      title = widget.language == 'ar'
          ? 'تم توليد الملخص بالفعل'
          : 'Summary Already Generated';
      message = widget.language == 'ar'
          ? 'تم توليد ملخص لهذا الكتاب اليوم بالفعل. يمكنك توليد ملخص جديد غدًا.'
          : 'A summary for this book has already been generated today. You can generate a new one tomorrow.';
      icon = Icons.info_outline;
      iconColor = Colors.orange;
    } else {
      title = widget.language == 'ar' ? 'خطأ' : 'Error';
      message = errorMessage;
      icon = Icons.warning_amber_rounded;
      iconColor = Colors.orange;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: widget.darkMode
              ? DesertColors.darkSurface
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: widget.darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(
                  color:
                      (widget.darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText)
                          .withOpacity(0.8),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DesertColors.primaryGoldDark.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: DesertColors.primaryGoldDark.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: DesertColors.primaryGoldDark,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.language == 'ar'
                            ? 'يمكنك كتابة الملخص يدويًا'
                            : 'You can write the summary manually',
                        style: TextStyle(
                          color:
                              (widget.darkMode
                                      ? DesertColors.darkText
                                      : DesertColors.lightText)
                                  .withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: DesertColors.primaryGoldDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: Text(
                widget.language == 'ar' ? 'حسنًا' : 'Got it',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _descriptionController = TextEditingController(
      text: widget.initialDescription ?? '',
    );
    _summaryController = TextEditingController(
      text: widget.initialSummary ?? '',
    );

    if (widget.initialAuthorId != null) {
      _selectedAuthor = widget.authors.firstWhere(
        (author) => author.id == widget.initialAuthorId,
        orElse: () => widget.authors.first,
      );
    }
  }

  Future<void> _pickCoverImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _coverImage = File(pickedFile.path);
          _coverImageName = pickedFile.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.language == 'ar'
                ? 'فشل في اختيار الصورة'
                : 'Failed to pick image',
          ),
          backgroundColor: DesertColors.crimson,
        ),
      );
    }
  }

  Future<void> _pickCoverImageDesktop() async {
    try {
      // Use image picker for all platforms
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          if (kIsWeb) {
            // On web, read as bytes
            pickedFile.readAsBytes().then((bytes) {
              setState(() {
                _coverImage = bytes;
                _coverImageName = pickedFile.name;
              });
            });
          } else {
            // On desktop/mobile, use file
            _coverImage = File(pickedFile.path);
            _coverImageName = pickedFile.name;
          }
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.language == 'ar'
                ? 'فشل في اختيار الصورة: ${e.toString()}'
                : 'Failed to pick image: ${e.toString()}',
          ),
          backgroundColor: DesertColors.crimson,
        ),
      );
    }
  }

  Future<void> _pickBookFile() async {
    try {
      // Use file_selector for PDFs on all platforms
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'documents',
        extensions: ['pdf', 'epub', 'mobi'],
      );

      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file != null) {
        // Read file as bytes
        final bytes = await file.readAsBytes();

        setState(() {
          if (kIsWeb) {
            _bookFile = bytes;
          } else {
            _bookFile = File(file.path);
          }
          _bookFileName = file.name;
        });

        print('📁 Book file selected: ${file.name}');
        print('📏 File size: ${bytes.length} bytes');
      }
    } catch (e) {
      print('❌ Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.language == 'ar'
                ? 'فشل في اختيار الملف: ${e.toString()}'
                : 'Failed to pick file: ${e.toString()}',
          ),
          backgroundColor: DesertColors.crimson,
        ),
      );
    }
  }

  void _showImageSourceDialog() {
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      // Mobile: show the dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: widget.darkMode
              ? DesertColors.darkSurface
              : Colors.white,
          title: Text(
            widget.language == 'ar' ? 'اختر المصدر' : 'Choose Source',
            style: TextStyle(
              color: widget.darkMode
                  ? DesertColors.darkText
                  : DesertColors.lightText,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.camera_alt,
                  color: DesertColors.primaryGoldDark,
                ),
                title: Text(
                  widget.language == 'ar' ? 'الكاميرا' : 'Camera',
                  style: TextStyle(
                    color: widget.darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickCoverImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: DesertColors.primaryGoldDark,
                ),
                title: Text(
                  widget.language == 'ar' ? 'المعرض' : 'Gallery',
                  style: TextStyle(
                    color: widget.darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickCoverImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      );
    } else {
      // Desktop: directly open file picker
      _pickCoverImageDesktop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: widget.darkMode ? DesertColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.language == 'ar' ? 'إضافة كتاب' : 'Add Book',
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
                widget.language == 'ar' ? 'عنوان الكتاب' : 'Book Title',
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
                      ? 'عنوان الكتاب'
                      : 'Book Title',
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
                enabled: !_isSaving,
                maxLines: 3,
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
              SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    widget.language == 'ar' ? 'الملخص' : 'Summary',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                  Spacer(),
                  ElevatedButton.icon(
                    onPressed: (_isGeneratingSummary || _isSaving)
                        ? null
                        : _generateAISummary,
                    icon: _isGeneratingSummary
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Icon(Icons.auto_awesome, size: 16),
                    label: Text(
                      widget.language == 'ar'
                          ? (_isGeneratingSummary
                                ? 'جاري التوليد...'
                                : 'توليد بالذكاء الاصطناعي')
                          : (_isGeneratingSummary
                                ? 'Generating...'
                                : 'Generate with AI'),
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesertColors.primaryGoldDark,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              TextField(
                controller: _summaryController,
                enabled: !_isSaving,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: widget.language == 'ar'
                      ? 'اكتب ملخص الكتاب أو استخدم الذكاء الاصطناعي لتوليده'
                      : 'Write book summary or use AI to generate it',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: DesertColors.primaryGoldDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: _summaryGenerated
                          ? Colors.green.withOpacity(0.5)
                          : DesertColors.primaryGoldDark.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: DesertColors.primaryGoldDark,
                      width: 2,
                    ),
                  ),
                  suffixIcon: _summaryGenerated
                      ? Icon(Icons.check_circle, color: Colors.green)
                      : null,
                ),
              ),
              SizedBox(height: 16),
              Text(
                widget.language == 'ar' ? 'المؤلف' : 'Author',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: widget.darkMode
                      ? DesertColors.darkText
                      : DesertColors.lightText,
                ),
              ),
              SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  return DropdownButtonFormField<Author>(
                    value: _selectedAuthor,
                    isExpanded: true, // 👈 prevents overflow on small devices
                    items: widget.authors.map((author) {
                      return DropdownMenuItem(
                        value: author,
                        child: Text(
                          author.name,
                          overflow:
                              TextOverflow.ellipsis, // 👈 truncate long names
                          maxLines: 1,
                          style: TextStyle(
                            color: widget.darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: _isSaving
                        ? null
                        : (author) {
                            setState(() {
                              _selectedAuthor = author;
                            });
                          },
                    style: TextStyle(
                      color: widget.darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                    dropdownColor: widget.darkMode
                        ? DesertColors.darkSurface
                        : Colors.white,
                    iconEnabledColor: widget.darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                    decoration: InputDecoration(
                      hintText: widget.language == 'ar'
                          ? 'اختر المؤلف'
                          : 'Select Author',
                      hintStyle: TextStyle(
                        color:
                            (widget.darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText)
                                .withOpacity(0.6),
                      ),
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
                  );
                },
              ),

              SizedBox(height: 32),

              // Cover Image Upload Section
              Text(
                widget.language == 'ar' ? 'غلاف الكتاب' : 'Book Cover',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: widget.darkMode
                      ? DesertColors.darkText
                      : DesertColors.lightText,
                ),
              ),
              SizedBox(height: 8),
              GestureDetector(
                onTap: _isSaving ? null : _showImageSourceDialog,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: widget.darkMode
                        ? DesertColors.darkSurface
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: DesertColors.primaryGoldDark.withOpacity(0.3),
                    ),
                  ),
                  child: _coverImage != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: kIsWeb
                                  ? Image.memory(
                                      _coverImage as Uint8List, // ← For web
                                      width: double.infinity,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      _coverImage as File, // ← For mobile
                                      width: double.infinity,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.red,
                                radius: 16,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _coverImage = null;
                                      _coverImageName = null;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 40,
                              color: DesertColors.primaryGoldDark,
                            ),
                            SizedBox(height: 8),
                            Text(
                              widget.language == 'ar'
                                  ? 'اختر صورة الغلاف'
                                  : 'Choose Cover Image',
                              style: TextStyle(
                                color: widget.darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              SizedBox(height: 16),

              // Book File Upload Section
              Text(
                widget.language == 'ar' ? 'ملف الكتاب' : 'Book File',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: widget.darkMode
                      ? DesertColors.darkText
                      : DesertColors.lightText,
                ),
              ),
              SizedBox(height: 8),
              GestureDetector(
                onTap: _isSaving ? null : _pickBookFile,
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.darkMode
                        ? DesertColors.darkSurface
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: DesertColors.primaryGoldDark.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _bookFile != null
                            ? Icons.check_circle
                            : Icons.upload_file,
                        color: _bookFile != null
                            ? Colors.green
                            : DesertColors.primaryGoldDark,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _bookFileName ??
                              (widget.language == 'ar'
                                  ? 'اختر ملف الكتاب (PDF, EPUB, MOBI)'
                                  : 'Choose Book File (PDF, EPUB, MOBI)'),
                          style: TextStyle(
                            color: widget.darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_bookFile != null)
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _bookFile = null;
                              _bookFileName = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
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
                    onPressed: _isSaving
                        ? null
                        : () async {
                            if (_titleController.text.isNotEmpty &&
                                _descriptionController.text.isNotEmpty &&
                                _summaryController.text.isNotEmpty) {
                              if (_selectedAuthor == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      widget.language == 'ar'
                                          ? 'يرجى اختيار المؤلف'
                                          : 'Please select an author',
                                    ),
                                    backgroundColor: DesertColors.crimson,
                                  ),
                                );
                                return;
                              }

                              setState(() {
                                _isSaving = true;
                              });

                              try {
                                // Pass the files to the parent
                                await widget.onSave(
                                  _titleController.text,
                                  _descriptionController.text,
                                  _summaryController.text,
                                  _selectedAuthor!.id,
                                  _coverImage, // ← Pass cover image
                                  _coverImageName, // ← Pass cover image name
                                  _bookFile, // ← Pass book file
                                  _bookFileName, // ← Pass book file name
                                );
                                Navigator.pop(context);
                              } catch (e) {
                                print('Error saving book: $e'); // Debug print
                                setState(() {
                                  _isSaving = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error saving book: ${e.toString()}',
                                    ),
                                    backgroundColor: DesertColors.crimson,
                                  ),
                                );
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    widget.language == 'ar'
                                        ? 'يرجى ملء جميع الحقول المطلوبة'
                                        : 'Please fill all required fields',
                                  ),
                                  backgroundColor: DesertColors.crimson,
                                ),
                              );
                            }
                          },
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
                            widget.language == 'ar' ? 'حفظ' : 'Save',
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
