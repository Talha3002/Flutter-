import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:alraya_app/alrayah.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

// Enhanced PDF Flipbook Screen with zoom functionality and better UI
class PDFFlipBookScreen extends StatefulWidget {
  final bool darkMode;
  final String language;

  // NEW: receive both Arabic & English titles and authors
  final String titleAr;
  final String titleEn;
  final String authorAr;
  final String authorEn;
  final String pdfUrl;

  const PDFFlipBookScreen({
    super.key,
    required this.darkMode,
    required this.language,
    required this.titleAr,
    required this.titleEn,
    required this.authorAr,
    required this.authorEn,
    required this.pdfUrl,
  });

  @override
  State<PDFFlipBookScreen> createState() => _PDFFlipBookScreenState();
}

class _PDFFlipBookScreenState extends State<PDFFlipBookScreen>
    with TickerProviderStateMixin {
  late PdfDocument _pdfDocument;
  bool _isLoading = true;
  int _totalPages = 0;
  int _currentPage = 0;
  bool darkMode = false;
  String language = 'en';
  bool _scrolled = false;
  double _zoomLevel = 1.0;
  bool _showZoomControls = false;

  // Book metadata

  late AnimationController _flipNextController;
  late Animation<double> _flipNextAnimation;
  bool _isFlippingNext = false;

  late AnimationController _flipPrevController;
  late Animation<double> _flipPrevAnimation;
  bool _isFlippingPrev = false;

  late AnimationController _zoomController;
  late Animation<double> _zoomAnimation;

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  int _currentPageMobile = 0;
  late PageController _mobilePageController;

  Map<int, Uint8List> _pageImageCache = {};

  @override
  void initState() {
    super.initState();
    _loadPdf();

    _mobilePageController = PageController(initialPage: _currentPageMobile);

    // Zoom controller
    _zoomController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _zoomAnimation = Tween<double>(
      begin: 1.0,
      end: 1.0,
    ).animate(_zoomController);

    // Next flip controller - right page flips left
    _flipNextController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _flipNextAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _flipNextController, curve: Curves.easeInOut),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            setState(() {
              _currentPage += 2;
              _isFlippingNext = false;
            });
            _flipNextController.reset();
          }
        });

    // Previous flip controller - left page flips right
    _flipPrevController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _flipPrevAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _flipPrevController, curve: Curves.easeInOut),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            setState(() {
              _currentPage -= 2;
              if (_currentPage < 0) _currentPage = 0;
              _isFlippingPrev = false;
            });
            _flipPrevController.reset();
          }
        });
  }

  @override
  void dispose() {
    _flipNextController.dispose();
    _flipPrevController.dispose();
    _zoomController.dispose();
    _mobilePageController.dispose();

    super.dispose();
  }

  Future<void> _loadPdf() async {
    try {
      final pdfUrl = widget.pdfUrl;
      if (pdfUrl.isEmpty) throw Exception("PDF URL not available");

      setState(() => _isLoading = true);

      final fileName = pdfUrl.split('/').last;

      Uint8List pdfBytes;

      if (kIsWeb) {
        print("🌐 Loading PDF (Web via package:http)...");
        final response = await http.get(Uri.parse(pdfUrl));
        if (response.statusCode != 200) {
          throw Exception("HTTP ${response.statusCode}: Failed to fetch PDF");
        }
        pdfBytes = response.bodyBytes;
      } else {
        print("📱 Loading PDF (Mobile/Desktop)...");
        final dir = await getTemporaryDirectory();
        final cachedFile = File("${dir.path}/$fileName");

        if (await cachedFile.exists()) {
          print("📘 Loading from cache: ${cachedFile.path}");
          pdfBytes = await cachedFile.readAsBytes();
        } else {
          print("⬇️ Downloading from URL...");
          final response = await http.get(Uri.parse(pdfUrl));
          if (response.statusCode != 200) {
            throw Exception("HTTP ${response.statusCode}: Failed to fetch PDF");
          }
          await cachedFile.writeAsBytes(response.bodyBytes);
          pdfBytes = response.bodyBytes;
        }
      }

      _pdfDocument = await PdfDocument.openData(pdfBytes);
      _totalPages = _pdfDocument.pagesCount;

      // ✅ Preload pages for smoother flipping
      // ✅ Load first few pages immediately, rest later
      int initialLoadCount = _totalPages > 4 ? 4 : _totalPages;

      for (int i = 1; i <= initialLoadCount; i++) {
        final page = await _pdfDocument.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          backgroundColor: '#FFFFFF',
        );
        _pageImageCache[i] = pageImage!.bytes;
        await page.close();
      }

      // 🔄 Preload remaining pages in background
      Future.microtask(() => _preloadRemainingPages());

      setState(() {
        _isLoading = false;
        _currentPage = 0;
      });

      print("✅ PDF loaded successfully (${_totalPages} pages)");
    } catch (e) {
      print("❌ Error loading PDF: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to load PDF: $e")));
      }
    }
  }

  Future<void> _preloadRemainingPages() async {
    for (int i = _pageImageCache.length + 1; i <= _totalPages; i++) {
      if (_pageImageCache.containsKey(i)) continue;

      try {
        final page = await _pdfDocument.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          backgroundColor: '#FFFFFF',
        );
        if (pageImage != null) {
          _pageImageCache[i] = pageImage.bytes;
        }
        await page.close();
      } catch (e) {
        print("⚠️ Error preloading page $i: $e");
      }
    }

    print("✅ Background preloading completed");
  }

  void _zoomIn() {
    if (_zoomLevel < 3.0) {
      setState(() {
        _zoomLevel = (_zoomLevel + 0.5).clamp(1.0, 3.0);
      });
      _animateZoom();
    }
  }

  void _zoomOut() {
    if (_zoomLevel > 1.0) {
      setState(() {
        _zoomLevel = (_zoomLevel - 0.5).clamp(1.0, 3.0);
      });
      _animateZoom();
    }
  }

  void _resetZoom() {
    setState(() {
      _zoomLevel = 1.0;
    });
    _animateZoom();
  }

  void _animateZoom() {
    _zoomAnimation = Tween<double>(begin: _zoomAnimation.value, end: _zoomLevel)
        .animate(
          CurvedAnimation(parent: _zoomController, curve: Curves.easeInOut),
        );
    _zoomController.forward(from: 0);
  }

  void _toggleZoomControls() {
    setState(() {
      _showZoomControls = !_showZoomControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isMobile(context) ? _buildMobileView() : _buildDesktopView(),
    );
  }

  Widget _buildDesktopView() {
    final darkMode = widget.darkMode;
    final language = widget.language;

    final displayedTitle = (widget.language == 'ar')
        ? widget.titleAr
        : widget.titleEn;
    final displayedAuthor = (widget.language == 'ar')
        ? widget.authorAr
        : widget.authorEn;
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: darkMode
              ? [DesertColors.darkBackground, DesertColors.darkSurface]
              : [
                  DesertColors.lightBackground,
                  DesertColors.lightBackground.withOpacity(0.8),
                  DesertColors.camelSand.withOpacity(0.3),
                ],
        ),
      ),
      child: Column(
        children: [
          // Book Title and Author Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                // Book Title
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        DesertColors.primaryGoldDark.withOpacity(0.1),
                        DesertColors.camelSand.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: DesertColors.primaryGoldDark.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    displayedTitle,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      foreground: Paint()
                        ..shader = const LinearGradient(
                          colors: [
                            DesertColors.crimson,
                            DesertColors.primaryGoldDark,
                          ],
                        ).createShader(const Rect.fromLTWH(0, 0, 300, 40)),
                      fontFamily: 'Georgia',
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 8),

                // Author Name
                Text(
                  widget.language == 'ar'
                      ? 'بقلم $displayedAuthor'
                      : 'by $displayedAuthor',
                  style: TextStyle(
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    color: darkMode
                        ? DesertColors.darkText.withOpacity(0.8)
                        : DesertColors.lightText.withOpacity(0.8),
                    fontFamily: 'Georgia',
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: darkMode
                                ? DesertColors.darkSurface
                                : DesertColors.lightSurface,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: DesertColors.maroon.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    DesertColors.primaryGoldDark,
                                  ),
                                  strokeWidth: 5,
                                ),
                              ),
                              const SizedBox(height: 25),
                              Text(
                                language == 'ar'
                                    ? 'تحميل الصفحات ...'
                                    : 'Loading Pages...',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: darkMode
                                      ? DesertColors.darkText
                                      : DesertColors.lightText,
                                  fontFamily: 'Georgia',
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            // Book Container
                            Expanded(
                              child: Center(
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 1800,
                                    maxHeight: 1400, // Increased height
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 10, // Better aspect ratio
                                    child: AnimatedBuilder(
                                      animation: _zoomAnimation,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: _zoomAnimation.value,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: DesertColors.maroon
                                                      .withOpacity(0.4),
                                                  blurRadius: 30,
                                                  offset: const Offset(0, 12),
                                                  spreadRadius: 8,
                                                ),
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.2),
                                                  blurRadius: 50,
                                                  offset: const Offset(0, 25),
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      DesertColors.maroon,
                                                      DesertColors.maroon
                                                          .withOpacity(0.8),
                                                    ],
                                                  ),
                                                ),
                                                child: Stack(
                                                  children: [
                                                    // Book Pages
                                                    Container(
                                                      margin:
                                                          const EdgeInsets.all(
                                                            8,
                                                          ), // Reduced margin
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                  0.4,
                                                                ),
                                                            blurRadius: 15,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  8,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Stack(
                                                        children: [
                                                          // Show static book spread when not flipping
                                                          if (!_isFlippingNext &&
                                                              !_isFlippingPrev)
                                                            _buildBookSpread(
                                                              _currentPage,
                                                            ),

                                                          // Show next flip animation
                                                          if (_isFlippingNext)
                                                            _buildFlipNextAnimation(
                                                              _currentPage,
                                                            ),

                                                          // Show previous flip animation
                                                          if (_isFlippingPrev)
                                                            _buildFlipPrevAnimation(
                                                              _currentPage,
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 25),

                            // Page Counter with enhanced design
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 25,
                                vertical: 15,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: darkMode
                                      ? [
                                          DesertColors.darkSurface,
                                          DesertColors.darkSurface.withOpacity(
                                            0.8,
                                          ),
                                        ]
                                      : [
                                          DesertColors.lightSurface,
                                          DesertColors.lightSurface.withOpacity(
                                            0.9,
                                          ),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: DesertColors.primaryGoldDark,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: DesertColors.maroon.withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_stories,
                                    color: DesertColors.primaryGoldDark,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    language == 'ar'
                                        ? "صفحة ${_currentPage + 1} من $_totalPages"
                                        : "Page ${_currentPage + 1} of $_totalPages",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: darkMode
                                          ? DesertColors.darkText
                                          : DesertColors.lightText,
                                      fontFamily: 'Georgia',
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 30),

                            // Navigation Buttons with enhanced design
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Previous Button
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (_isFlippingNext || _isFlippingPrev)
                                            ? Colors.grey.withOpacity(0.3)
                                            : DesertColors.maroon.withOpacity(
                                                0.4,
                                              ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        _isFlippingNext || _isFlippingPrev
                                        ? null
                                        : _prevPage,
                                    icon: Icon(
                                      language == 'ar'
                                          ? Icons.arrow_back_ios
                                          : Icons.arrow_back_ios,
                                      color:
                                          (_isFlippingNext || _isFlippingPrev)
                                          ? Colors.grey
                                          : Colors.white,
                                      size: 22,
                                    ),
                                    label: Text(
                                      language == 'ar' ? "السابق" : "Previous",
                                      style: TextStyle(
                                        color:
                                            (_isFlippingNext || _isFlippingPrev)
                                            ? Colors.grey
                                            : Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Georgia',
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          (_isFlippingNext || _isFlippingPrev)
                                          ? Colors.grey[400]
                                          : DesertColors.maroon,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 35,
                                        vertical: 20,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 40),

                                // Next Button
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (_isFlippingNext || _isFlippingPrev)
                                            ? Colors.grey.withOpacity(0.3)
                                            : DesertColors.primaryGoldDark
                                                  .withOpacity(0.5),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        _isFlippingNext || _isFlippingPrev
                                        ? null
                                        : _nextPage,
                                    label: Text(
                                      language == 'ar' ? "التالي" : "Next",
                                      style: TextStyle(
                                        color:
                                            (_isFlippingNext || _isFlippingPrev)
                                            ? Colors.grey
                                            : Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Georgia',
                                      ),
                                    ),
                                    icon: Icon(
                                      language == 'ar'
                                          ? Icons.arrow_forward_ios
                                          : Icons.arrow_forward_ios,
                                      color:
                                          (_isFlippingNext || _isFlippingPrev)
                                          ? Colors.grey
                                          : Colors.white,
                                      size: 22,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          (_isFlippingNext || _isFlippingPrev)
                                          ? Colors.grey[400]
                                          : DesertColors.primaryGoldDark,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 35,
                                        vertical: 20,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),

                      // Zoom Controls
                      Positioned(
                        top: 20,
                        right: 20,
                        child: Column(
                          children: [
                            // Zoom Toggle Button
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    DesertColors.primaryGoldDark,
                                    DesertColors.camelSand,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: DesertColors.primaryGoldDark
                                        .withOpacity(0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: _toggleZoomControls,
                                icon: Icon(
                                  Icons.zoom_in,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                padding: const EdgeInsets.all(12),
                              ),
                            ),

                            // Zoom Control Panel
                            if (_showZoomControls) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: darkMode
                                      ? DesertColors.darkSurface.withOpacity(
                                          0.95,
                                        )
                                      : DesertColors.lightSurface.withOpacity(
                                          0.95,
                                        ),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: DesertColors.primaryGoldDark
                                        .withOpacity(0.3),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Zoom In
                                    _buildZoomButton(
                                      icon: Icons.add,
                                      onPressed: _zoomLevel < 3.0
                                          ? _zoomIn
                                          : null,
                                      tooltip: language == 'ar'
                                          ? 'تكبير'
                                          : 'Zoom In',
                                    ),
                                    const SizedBox(height: 8),

                                    // Zoom Level Indicator
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: DesertColors.primaryGoldDark
                                            .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${(_zoomLevel * 100).toInt()}%',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: darkMode
                                              ? DesertColors.darkText
                                              : DesertColors.lightText,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Reset Zoom
                                    _buildZoomButton(
                                      icon: Icons.center_focus_strong,
                                      onPressed: _zoomLevel != 1.0
                                          ? _resetZoom
                                          : null,
                                      tooltip: language == 'ar'
                                          ? 'إعادة تعيين'
                                          : 'Reset',
                                    ),
                                    const SizedBox(height: 8),

                                    // Zoom Out
                                    _buildZoomButton(
                                      icon: Icons.remove,
                                      onPressed: _zoomLevel > 1.0
                                          ? _zoomOut
                                          : null,
                                      tooltip: language == 'ar'
                                          ? 'تصغير'
                                          : 'Zoom Out',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

Widget _buildMobileView() {
  final darkMode = widget.darkMode;
  final language = widget.language;

  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: darkMode
            ? [DesertColors.darkBackground, DesertColors.darkSurface]
            : [
                DesertColors.lightBackground,
                DesertColors.lightBackground.withOpacity(0.8),
                DesertColors.camelSand.withOpacity(0.3),
              ],
      ),
    ),
    child: _isLoading
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: darkMode
                        ? DesertColors.darkSurface
                        : DesertColors.lightSurface,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: DesertColors.maroon.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            DesertColors.primaryGoldDark,
                          ),
                          strokeWidth: 5,
                        ),
                      ),
                      const SizedBox(height: 25),
                      Text(
                        language == 'ar'
                            ? 'تحميل الصفحات ...'
                            : 'Loading Pages...',
                        style: TextStyle(
                          fontSize: 20,
                          color: darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText,
                          fontFamily: 'Georgia',
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        : Column(
            children: [
              // Page indicator
              Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _currentPageMobile > 0 ? _prevPageMobile : null,
                      icon: Icon(
                        Icons.chevron_left,
                        color: _currentPageMobile > 0
                            ? DesertColors.crimson
                            : Colors.grey,
                        size: 28,
                      ),
                    ),
                    Text(
                      '${_currentPageMobile + 1} / $_totalPages',
                      style: TextStyle(
                        color: darkMode
                            ? DesertColors.darkText
                            : DesertColors.lightText,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: _currentPageMobile < _totalPages - 1
                          ? _nextPageMobile
                          : null,
                      icon: Icon(
                        Icons.chevron_right,
                        color: _currentPageMobile < _totalPages - 1
                            ? DesertColors.crimson
                            : Colors.grey,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),

              // Zoomable page view
              Expanded(
                child: PageView.builder(
                  controller: _mobilePageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPageMobile = index;
                    });
                  },
                  itemCount: _totalPages,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.all(8),
                      child: InteractiveViewer(
                        panEnabled: true,
                        scaleEnabled: true,
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: darkMode
                                ? DesertColors.darkSurface
                                : DesertColors.lightSurface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _buildMobilePage(index + 1),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
  );
}

  Widget _buildMobilePage(int pageNumber) {
    if (pageNumber < 1 || pageNumber > _totalPages) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories,
              size: 80,
              color: DesertColors.primaryGoldDark.withOpacity(0.6),
            ),
            const SizedBox(height: 20),
            Text(
              language == 'ar' ? 'نهاية الحكاية' : 'End of Tale',
              style: TextStyle(
                color:
                    (darkMode ? DesertColors.darkText : DesertColors.lightText)
                        .withOpacity(0.7),
                fontSize: 24,
                fontStyle: FontStyle.italic,
                fontFamily: 'Georgia',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final imageBytes = _pageImageCache[pageNumber];
    if (imageBytes == null) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            DesertColors.primaryGoldDark,
          ),
          strokeWidth: 4,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Image.memory(
        imageBytes,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  void _nextPageMobile() {
    if (_currentPageMobile < _totalPages - 1) {
      _mobilePageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPageMobile() {
    if (_currentPageMobile > 0) {
      _mobilePageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildZoomButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          gradient: onPressed != null
              ? LinearGradient(
                  colors: [DesertColors.crimson, DesertColors.maroon],
                )
              : null,
          color: onPressed == null ? Colors.grey[400] : null,
          borderRadius: BorderRadius.circular(10),
          boxShadow: onPressed != null
              ? [
                  BoxShadow(
                    color: DesertColors.crimson.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            icon,
            color: onPressed != null ? Colors.white : Colors.grey[600],
            size: 20,
          ),
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
      ),
    );
  }

  Widget _buildPage(int pageNumber, {required bool isLeft}) {
    if (pageNumber < 1 || pageNumber > _totalPages) {
      return Container(
        decoration: BoxDecoration(
          color: darkMode
              ? DesertColors.darkSurface
              : DesertColors.lightSurface,
          borderRadius: BorderRadius.only(
            topLeft: isLeft ? const Radius.circular(8) : Radius.zero,
            bottomLeft: isLeft ? const Radius.circular(8) : Radius.zero,
            topRight: !isLeft ? const Radius.circular(8) : Radius.zero,
            bottomRight: !isLeft ? const Radius.circular(8) : Radius.zero,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 5,
              offset: isLeft ? const Offset(-3, 3) : const Offset(3, 3),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_stories,
                size: 64,
                color: DesertColors.primaryGoldDark.withOpacity(0.6),
              ),
              const SizedBox(height: 20),
              Text(
                language == 'ar' ? 'نهاية الحكاية' : 'End of Tale',
                style: TextStyle(
                  color:
                      (darkMode
                              ? DesertColors.darkText
                              : DesertColors.lightText)
                          .withOpacity(0.7),
                  fontSize: 24,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final imageBytes = _pageImageCache[pageNumber];
    if (imageBytes == null) {
      return Container(
        decoration: BoxDecoration(
          color: darkMode
              ? DesertColors.darkSurface
              : DesertColors.lightSurface,
          borderRadius: BorderRadius.only(
            topLeft: isLeft ? const Radius.circular(8) : Radius.zero,
            bottomLeft: isLeft ? const Radius.circular(8) : Radius.zero,
            topRight: !isLeft ? const Radius.circular(8) : Radius.zero,
            bottomRight: !isLeft ? const Radius.circular(8) : Radius.zero,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 5,
              offset: isLeft ? const Offset(-3, 3) : const Offset(3, 3),
            ),
          ],
        ),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              DesertColors.primaryGoldDark,
            ),
            strokeWidth: 4,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : DesertColors.lightSurface,
        borderRadius: BorderRadius.only(
          topLeft: isLeft ? const Radius.circular(8) : Radius.zero,
          bottomLeft: isLeft ? const Radius.circular(8) : Radius.zero,
          topRight: !isLeft ? const Radius.circular(8) : Radius.zero,
          bottomRight: !isLeft ? const Radius.circular(8) : Radius.zero,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 5,
            offset: isLeft ? const Offset(-3, 3) : const Offset(3, 3),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(4), // Reduced padding for bigger pages
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: isLeft ? const Radius.circular(6) : Radius.zero,
            bottomLeft: isLeft ? const Radius.circular(6) : Radius.zero,
            topRight: !isLeft ? const Radius.circular(6) : Radius.zero,
            bottomRight: !isLeft ? const Radius.circular(6) : Radius.zero,
          ),
          child: Image.memory(imageBytes, fit: BoxFit.contain),
        ),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 2 &&
        !_isFlippingNext &&
        !_isFlippingPrev) {
      setState(() {
        _isFlippingNext = true;
      });
      _flipNextController.forward();
    }
  }

  void _prevPage() {
    if (_currentPage > 0 && !_isFlippingPrev && !_isFlippingNext) {
      setState(() {
        _isFlippingPrev = true;
      });
      _flipPrevController.forward();
    }
  }

  void _toggleDarkMode() {
    setState(() {
      darkMode = !darkMode;
    });
  }

  void _toggleLanguage() {
    setState(() {
      language = language == 'ar' ? 'en' : 'ar';
    });
  }

  void _openDrawer() {
    // Implement drawer functionality if needed
  }

  Widget _buildBookSpread(int startPage) {
    return Row(
      children: [
        // Left page
        Expanded(child: _buildPage(startPage + 1, isLeft: true)),

        // Book spine
        Container(
          width: 8, // Slightly wider spine
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                DesertColors.maroon,
                DesertColors.maroon.withOpacity(0.7),
                DesertColors.maroon,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 6,
                offset: const Offset(3, 0),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(-3, 0),
              ),
            ],
          ),
        ),

        // Right page
        Expanded(child: _buildPage(startPage + 2, isLeft: false)),
      ],
    );
  }

  Widget _buildFlipNextAnimation(int startPage) {
    return Row(
      children: [
        // Left page static
        Expanded(child: _buildPage(startPage + 1, isLeft: true)),

        // Book spine
        Container(
          width: 8,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                DesertColors.maroon,
                DesertColors.maroon.withOpacity(0.7),
                DesertColors.maroon,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 6,
                offset: const Offset(3, 0),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(-3, 0),
              ),
            ],
          ),
        ),

        // Right page flipping
        Expanded(
          child: AnimatedBuilder(
            animation: _flipNextAnimation,
            builder: (context, child) {
              double angle = _flipNextAnimation.value * 3.1416;
              bool showBack = angle > 1.5708;

              return Transform(
                alignment: Alignment.centerLeft,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0015)
                  ..rotateY(angle),
                child: showBack
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(3.1416),
                        child: _buildPage(startPage + 3, isLeft: false),
                      )
                    : _buildPage(startPage + 2, isLeft: false),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFlipPrevAnimation(int startPage) {
    return Row(
      children: [
        // Left page flipping
        Expanded(
          child: AnimatedBuilder(
            animation: _flipPrevAnimation,
            builder: (context, child) {
              double angle = _flipPrevAnimation.value * 3.1416;
              bool showBack = angle > 1.5708;

              return Transform(
                alignment: Alignment.centerRight,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0015)
                  ..rotateY(-angle),
                child: showBack
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(3.1416),
                        child: _buildPage(startPage - 1, isLeft: true),
                      )
                    : _buildPage(startPage + 1, isLeft: true),
              );
            },
          ),
        ),

        // Book spine
        Container(
          width: 8,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                DesertColors.maroon,
                DesertColors.maroon.withOpacity(0.7),
                DesertColors.maroon,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 6,
                offset: const Offset(3, 0),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(-3, 0),
              ),
            ],
          ),
        ),

        // Right page static
        Expanded(child: _buildPage(startPage + 2, isLeft: false)),
      ],
    );
  }
}
