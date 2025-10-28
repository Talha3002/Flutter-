import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../alrayah.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StatsService {
  static final StatsService _instance = StatsService._internal();
  factory StatsService() => _instance;
  StatsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache variables
  Map<String, dynamic>? _cachedStats;
  DateTime? _lastFetch;
  static const Duration _cacheDuration = Duration(hours: 1);

  // Get stats with caching
  Future<Map<String, dynamic>> getStats() async {
    // Return cached data if available and not expired
    if (_cachedStats != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheDuration) {
      return _cachedStats!;
    }

    // Fetch fresh data
    try {
      final stats = await _fetchStatsFromFirestore();
      _cachedStats = stats;
      _lastFetch = DateTime.now();
      return stats;
    } catch (e) {
      print('Error fetching stats: $e');
      // Return cached data even if expired, or default values
      return _cachedStats ?? _getDefaultStats();
    }
  }

  Future<Map<String, dynamic>> _fetchStatsFromFirestore() async {
    // Fetch all three stats in parallel for better performance
    final results = await Future.wait([
      _getBookCount(),
      _getPublicationCount(),
      _getTotalVisitors(),
    ]);

    return {
      'books': results[0],
      'publications': results[1],
      'visitors': results[2],
    };
  }

  // Count books where isDeleted == false
  Future<int> _getBookCount() async {
    try {
      final snapshot = await _firestore
          .collection('tblbooks')
          .where('IsDeleted', isEqualTo: "False")
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error counting books: $e');
      return 0;
    }
  }

  // Count publications where isDeleted == false
  Future<int> _getPublicationCount() async {
    try {
      final snapshot = await _firestore
          .collection('tblposts')
          .where('IsDeleted', isEqualTo: "False")
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error counting publications: $e');
      return 0;
    }
  }

  // Sum all visitors from daily_stats collection
  Future<int> _getTotalVisitors() async {
    try {
      final snapshot = await _firestore.collection('daily_stats').get();

      int totalVisitors = 0;
      for (var doc in snapshot.docs) {
        // Assuming the visitor count is stored in a field called 'visitors'
        // Adjust the field name if different
        final visitors = doc.data()['visitors'] as int? ?? 0;
        totalVisitors += visitors;
      }

      return totalVisitors;
    } catch (e) {
      print('Error counting visitors: $e');
      return 0;
    }
  }

  Map<String, dynamic> _getDefaultStats() {
    return {'books': 0, 'publications': 0, 'visitors': 0};
  }

  // Method to force refresh stats
  void clearCache() {
    _cachedStats = null;
    _lastFetch = null;
  }
}

class AnimatedBookWidget extends StatefulWidget {
  const AnimatedBookWidget({Key? key}) : super(key: key);

  @override
  _AnimatedBookWidgetState createState() => _AnimatedBookWidgetState();
}

class _AnimatedBookWidgetState extends State<AnimatedBookWidget>
    with TickerProviderStateMixin {
  late AnimationController _stackController;
  late Animation<double> _moveAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  int currentCardIndex = 0;

  final List<Map<String, dynamic>> cardContents = [
    {
      "text": "Welcome",
      "subtitle": "Discover more about our Islamic publications.",
      "icon": Icons.auto_stories,
    },
    {
      "text": "Learn More",
      "subtitle": "Visit our library – Our Vision Library.",
      "icon": Icons.local_library,
    },
    {
      "text": "Visit Streams",
      "subtitle":
          "Join our live sessions and majalis – Visit our publications.",
      "icon": Icons.people_alt,
    },
    {
      "text": "Give Feedback",
      "subtitle": "Contact us – Give us your opinion.",
      "icon": Icons.contact_mail,
    },
  ];

  @override
  void initState() {
    super.initState();

    _stackController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _moveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _stackController, curve: Curves.easeInOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _stackController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.3).animate(
      CurvedAnimation(parent: _stackController, curve: Curves.easeInOut),
    );

    _startStackAnimation();
  }

  void _startStackAnimation() async {
    while (mounted) {
      await Future.delayed(Duration(milliseconds: 2500));

      await _stackController.forward();

      setState(() {
        currentCardIndex = (currentCardIndex + 1) % cardContents.length;
      });

      _stackController.reset();
    }
  }

  Widget _buildCard(int index, int position) {
    final content = cardContents[index];
    final isTopCard = position == 0;

    double opacity = position == 0 ? 1.0 : (position == 1 ? 0.7 : 0.4);
    double scale = position == 0 ? 1.0 : (position == 1 ? 0.95 : 0.9);
    double yOffset = position * 8.0;

    if (isTopCard) {
      opacity = 1.0 - (_moveAnimation.value * 0.3);
      scale = _scaleAnimation.value;
      yOffset = _moveAnimation.value * 200;
    }

    return Transform.translate(
      offset: Offset(0, yOffset),
      child: Transform.scale(
        scale: scale,
        child: Transform.rotate(
          angle: isTopCard ? _rotationAnimation.value : 0,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 350,
              height: 450,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [DesertColors.lightSurface, DesertColors.camelSand],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: DesertColors.maroon.withOpacity(0.2),
                    blurRadius: 15 - (position * 3),
                    offset: Offset(0, 8 + (position * 2)),
                  ),
                ],
                border: Border.all(
                  color: DesertColors.primaryGoldDark.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Top decorative line
                    Container(
                      width: 60,
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          colors: [
                            DesertColors.crimson.withOpacity(0.3),
                            DesertColors.crimson,
                            DesertColors.crimson.withOpacity(0.3),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 40),

                    // Icon with glow
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            DesertColors.crimson.withOpacity(0.15),
                            DesertColors.crimson.withOpacity(0.05),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Icon(
                        content["icon"],
                        size: 50,
                        color: DesertColors.crimson,
                      ),
                    ),

                    SizedBox(height: 40),

                    // Main text
                    Text(
                      content["text"],
                      style: TextStyle(
                        color: DesertColors.maroon,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 20),

                    // Subtitle
                    Text(
                      content["subtitle"],
                      style: TextStyle(
                        color: DesertColors.lightText,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 40),

                    // Bottom dots indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        cardContents.length,
                        (dotIndex) => Container(
                          width: dotIndex == index ? 12 : 8,
                          height: dotIndex == index ? 12 : 8,
                          margin: EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dotIndex == index
                                ? DesertColors.crimson
                                : DesertColors.crimson.withOpacity(0.3),
                          ),
                        ),
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
  }

  @override
  void dispose() {
    _stackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _stackController,
        builder: (context, child) {
          return Container(
            width: 320,
            height: 450,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background cards (stack of 3 visible)
                for (int i = 2; i >= 0; i--)
                  _buildCard((currentCardIndex + i) % cardContents.length, i),
              ],
            ),
          );
        },
      ),
    );
  }
}

class HeroSection extends StatefulWidget {
  final String language;
  final bool darkMode;

  const HeroSection({
    Key? key, // ✅ standard Flutter key
    required this.language,
    required this.darkMode,
  }) : super(key: key);

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _floatingController;
  late AnimationController _scrollController;
  late AnimationController _pulseController;

  // Add these after your animation controller declarations
  Map<String, dynamic>? _stats;
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 10),
    )..repeat();

    _floatingController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 6),
    )..repeat();

    _scrollController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // ADD THIS: Load stats immediately
    _loadStats();
  }

  // ADD THIS NEW METHOD after initState()
  void _loadStats() async {
    try {
      final stats = await StatsService().getStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _statsLoaded = true;
        });
      }
    } catch (e) {
      print('Error loading stats: $e');
      // Set default values on error
      if (mounted) {
        setState(() {
          _stats = {'books': 0, 'publications': 0, 'visitors': 0};
          _statsLoaded = true;
        });
      }
    }
  }

// ADD THIS METHOD
String _formatVisitors(int visitors) {
  if (visitors >= 1000000) {
    return '${(visitors / 1000000).toStringAsFixed(1)}M';
  } else if (visitors >= 1000) {
    return '${(visitors / 1000).toStringAsFixed(1)}K';
  }
  return visitors.toString();
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Find this section in your build() method:
    final content = {
      'ar': {
        'titles': [
          'مجالس أهل البيت عليهم السلام',
          'كُتُب وخَواطِر مَنْشُورات',
          'أَهلًا وسَهلًا بكُم في مَواقِع رائِعَة',
        ],
        'subtitle': 'منصة رقمية شاملة للنشر الإسلامي والتراث الديني',
        'description':
            'اكتشف مجموعة واسعة من الإصدارات الإسلامية والبحوث الدينية من خلال منصة متطورة تجمع بين الأصالة والحداثة',
        'cta1': 'ابدأ الاستكشاف',
        'cta2': 'تسجيل دخول',
        // REPLACE THIS 'stats' array:
        'stats': [
          {
            'label': 'منشورات متاحة',
            'value': '${_stats?['publications'] ?? 0}+',
          },
          {'label': 'كتب متاحة', 'value': '${_stats?['books'] ?? 0}+'},
          {
            'label': 'زوار',
            'value': '${_formatVisitors(_stats?['visitors'] ?? 0)}',
          },
        ],
      },
      'en': {
        'titles': [
          'Ahl al-Bayt Peace Councils',
          'Books & Reflecting Publications',
          'Welcome to Great Platforms',
        ],
        'subtitle':
            'Comprehensive Digital Platform for Islamic Publishing and Religious Heritage',
        'description':
            'Discover a vast collection of Islamic publications and religious research through an advanced platform that combines authenticity with modernity',
        'cta1': 'Start Exploring',
        'cta2': 'Sign In',
        // REPLACE THIS 'stats' array:
        'stats': [
          {
            'label': 'Available Publications',
            'value': '${_stats?['publications'] ?? 0}+',
          },
          {'label': 'Available Books', 'value': '${_stats?['books'] ?? 0}+'},
          {
            'label': 'Visitors',
            'value': '${_formatVisitors(_stats?['visitors'] ?? 0)}',
          },
        ],
      },
    };

    final currentContent = content[language]!;

    return MouseReactiveTilt(
      builder: (offset) {
        return Container(
          height: MediaQuery.of(context).size.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: darkMode
                  ? [
                      DesertColors.darkBackground,
                      DesertColors.darkSurface,
                      DesertColors.maroon.withOpacity(0.3),
                    ]
                  : [
                      DesertColors.lightBackground,
                      DesertColors.lightSurface,
                      DesertColors.camelSand.withOpacity(0.3),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.6, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Animated Background Elements
              ...List.generate(8, (index) {
                return AnimatedBuilder(
                  animation: _floatingController,
                  builder: (context, child) {
                    return Positioned(
                      left: (index * 150.0) % MediaQuery.of(context).size.width,
                      top: (index * 200.0) % MediaQuery.of(context).size.height,
                      child: Transform.translate(
                        offset: Offset(
                          math.sin(
                                _floatingController.value * 2 * math.pi + index,
                              ) *
                              80,
                          math.cos(
                                _floatingController.value * 2 * math.pi + index,
                              ) *
                              60,
                        ),
                        child: Container(
                          width: 120 + (index * 30.0),
                          height: 120 + (index * 30.0),
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                (darkMode
                                        ? DesertColors.crimson
                                        : DesertColors.camelSand)
                                    .withOpacity(0.1),
                                Colors.transparent,
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),

              // Main Content
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SizedBox(height: 80),

                      Expanded(
                        child: isMobile
                            ? SingleChildScrollView(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(height: 40),
                                    _buildContent(
                                      currentContent,
                                      darkMode,
                                      language,
                                      isMobile,
                                    ),
                                    SizedBox(height: 32),
                                    _buildMobileStats(
                                      currentContent,
                                      darkMode,
                                      language,
                                      context,
                                    ),
                                    SizedBox(height: 40),
                                  ],
                                ),
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _buildContent(
                                      currentContent,
                                      darkMode,
                                      language,
                                      isMobile,
                                    ),
                                  ),
                                  SizedBox(width: 32),
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 80),
                                      child: AnimatedBookWidget(),
                                    ),
                                  ),
                                ],
                              ),
                      ),

                      // Enhanced Scroll Indicator
                      if (!isMobile)
                        AnimatedBuilder(
                          animation: _scrollController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(
                                0,
                                math.sin(
                                      _scrollController.value * 2 * math.pi,
                                    ) *
                                    15,
                              ),
                              child: Container(
                                width: 30,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      DesertColors.camelSand.withOpacity(0.3),
                                      DesertColors.crimson.withOpacity(0.3),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: darkMode
                                        ? DesertColors.camelSand
                                        : DesertColors.crimson,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 10),
                                    AnimatedBuilder(
                                      animation: _scrollController,
                                      builder: (context, child) {
                                        return Transform.translate(
                                          offset: Offset(
                                            0,
                                            math.sin(
                                                  _scrollController.value *
                                                      2 *
                                                      math.pi,
                                                ) *
                                                15,
                                          ),
                                          child: Container(
                                            width: 6,
                                            height: 15,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  DesertColors.crimson,
                                                  DesertColors.maroon,
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(
    Map currentContent,
    bool darkMode,
    String language,
    bool isMobile,
  ) {
    return isMobile
        ? Center(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: darkMode
                      ? [
                          DesertColors.darkSurface,
                          DesertColors.maroon.withOpacity(0.8),
                        ]
                      : [
                          DesertColors.lightSurface,
                          DesertColors.camelSand.withOpacity(0.8),
                        ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: darkMode
                      ? DesertColors.camelSand.withOpacity(0.3)
                      : DesertColors.crimson.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (darkMode ? DesertColors.maroon : DesertColors.crimson)
                            .withOpacity(0.2),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMobileTitle(currentContent, language, darkMode),
                  SizedBox(height: 16),
                  _buildMobileDescription(currentContent, language, darkMode),
                  SizedBox(height: 24),
                  _buildMobileButton(currentContent, language),
                ],
              ),
            ),
          )
        : Padding(
            padding: EdgeInsets.only(left: 80, right: 0),
            child: Column(
              crossAxisAlignment: language == 'ar'
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Keep existing desktop content structure
                // Title
                TweenAnimationBuilder(
                  duration: Duration(milliseconds: 1200),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.translate(
                      offset: Offset(0, 50 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: darkMode
                                ? [
                                    DesertColors.darkText,
                                    DesertColors.camelSand,
                                  ]
                                : [
                                    DesertColors.lightText,
                                    DesertColors.crimson,
                                  ],
                          ).createShader(bounds),
                          child: AnimatedTextKit(
                            animatedTexts:
                                (currentContent['titles'] as List<String>)
                                    .map(
                                      (title) => TyperAnimatedText(
                                        title,
                                        textStyle: TextStyle(
                                          fontSize: isMobile ? 24 : 48,
                                          fontWeight: isMobile
                                              ? FontWeight.w500
                                              : FontWeight.bold,
                                          color: DesertColors.primaryGoldDark,
                                          height: 1.2,
                                        ),
                                        textAlign: language == 'ar'
                                            ? TextAlign.right
                                            : TextAlign.left,
                                        speed: Duration(milliseconds: 50),
                                      ),
                                    )
                                    .toList(),
                            pause: Duration(seconds: 2),
                            repeatForever: true,
                            isRepeatingAnimation: true,
                            displayFullTextOnTap: true,
                            stopPauseOnTap: true,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 16),
                // Subtitle with slide animation
                TweenAnimationBuilder(
                  duration: Duration(milliseconds: 1000),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.translate(
                      offset: Offset(30 * (1 - value), 0),
                      child: Opacity(
                        opacity: value,
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(top: 20),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  DesertColors.crimson.withOpacity(0.1),
                                  DesertColors.camelSand.withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: DesertColors.crimson.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              currentContent['subtitle'] as String,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: darkMode
                                    ? DesertColors.camelSand
                                    : DesertColors.crimson,
                              ),
                              textAlign: language == 'ar'
                                  ? TextAlign.right
                                  : TextAlign.left,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 24),

                // Description
                TweenAnimationBuilder(
                  duration: Duration(milliseconds: 800),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.translate(
                      offset: Offset(0, 30 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: Text(
                          currentContent['description'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            color: darkMode
                                ? DesertColors.darkText.withOpacity(0.8)
                                : DesertColors.lightText.withOpacity(0.8),
                            height: 1.6,
                          ),
                          textAlign: language == 'ar'
                              ? TextAlign.right
                              : TextAlign.left,
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 32),

                TweenAnimationBuilder(
                  duration: Duration(milliseconds: 1000),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.translate(
                      offset: Offset(0, 30 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: isMobile
                            ? Column(
                                crossAxisAlignment: language == 'ar'
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.pushNamed(context, '/login');
                                    },
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 300),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            DesertColors.crimson,
                                            DesertColors.maroon,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: DesertColors.crimson
                                                .withOpacity(0.4),
                                            blurRadius: 15,
                                            offset: Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        currentContent['cta2'] as String,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: language == 'ar'
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                                children: [
                                  // Primary Button
                                  GestureDetector(
                                    onTap: () => HapticFeedback.mediumImpact(),
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 300),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 15 : 32,
                                        vertical: isMobile ? 12 : 16,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            DesertColors.crimson,
                                            DesertColors.maroon,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: DesertColors.crimson
                                                .withOpacity(0.4),
                                            blurRadius: 15,
                                            offset: Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            currentContent['cta1'] as String,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: isMobile ? 12 : 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          AnimatedBuilder(
                                            animation: _pulseController,
                                            builder: (context, child) {
                                              return Transform.translate(
                                                offset: Offset(
                                                  math.sin(
                                                        _pulseController.value *
                                                            2 *
                                                            math.pi,
                                                      ) *
                                                      3,
                                                  0,
                                                ),
                                                child: Icon(
                                                  language == 'ar'
                                                      ? Icons.arrow_back
                                                      : Icons.arrow_forward,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16),

                                  // Secondary Button
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.pushNamed(context, '/login');
                                    },
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 300),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 15 : 32,
                                        vertical: isMobile ? 12 : 16,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            DesertColors.camelSand.withOpacity(
                                              0.1,
                                            ),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: darkMode
                                              ? DesertColors.camelSand
                                              : DesertColors.crimson,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        currentContent['cta2'] as String,
                                        style: TextStyle(
                                          color: darkMode
                                              ? DesertColors.camelSand
                                              : DesertColors.crimson,
                                          fontSize: isMobile ? 12 : 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 48),

                // Stats with staggered animation
                Flex(
                  direction: Axis.horizontal,
                  mainAxisAlignment: language == 'ar'
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: (currentContent['stats'] as List)
                      .asMap()
                      .entries
                      .map((entry) {
                        int index = entry.key;
                        Map stat = entry.value;

                        return TweenAnimationBuilder(
                          duration: Duration(milliseconds: 800 + (index * 200)),
                          tween: Tween<double>(begin: 0, end: 1),
                          builder: (context, double value, child) {
                            return Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Opacity(
                                opacity: value,
                                child: Container(
                                  width: isMobile
                                      ? double.infinity
                                      : 160, // Full width on mobile
                                  padding: EdgeInsets.all(16),
                                  margin: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 0 : 8,
                                    vertical: isMobile ? 8 : 0,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        DesertColors.camelSand.withOpacity(0.1),
                                        DesertColors.crimson.withOpacity(0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: DesertColors.camelSand.withOpacity(
                                        0.3,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: language == 'ar'
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        stat['value']!,
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: darkMode
                                              ? DesertColors.camelSand
                                              : DesertColors.crimson,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        stat['label']!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: darkMode
                                              ? DesertColors.darkText
                                                    .withOpacity(0.7)
                                              : DesertColors.lightText
                                                    .withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      })
                      .toList(),
                ),
              ],
            ),
          );
  }

  Widget _buildMobileTitle(Map currentContent, String language, bool darkMode) {
    return Center(
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: darkMode
              ? [DesertColors.darkText, DesertColors.camelSand]
              : [DesertColors.lightText, DesertColors.crimson],
        ).createShader(bounds),
        child: AnimatedTextKit(
          animatedTexts: (currentContent['titles'] as List<String>)
              .map(
                (title) => TyperAnimatedText(
                  title,
                  textStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: DesertColors.primaryGoldDark,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                  speed: Duration(milliseconds: 50),
                ),
              )
              .toList(),
          pause: Duration(seconds: 2),
          repeatForever: true,
          isRepeatingAnimation: true,
        ),
      ),
    );
  }

  Widget _buildMobileDescription(
    Map currentContent,
    String language,
    bool darkMode,
  ) {
    return Text(
      currentContent['description'] as String,
      style: TextStyle(
        fontSize: 14,
        color: darkMode
            ? DesertColors.darkText.withOpacity(0.8)
            : DesertColors.lightText.withOpacity(0.8),
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildMobileStats(
    Map currentContent,
    bool darkMode,
    String language,
    BuildContext context,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _buildStatItems(
          currentContent,
          darkMode,
          true,
        ), // always vertical
      ),
    );
  }

  List<Widget> _buildStatItems(
    Map currentContent,
    bool darkMode,
    bool isVertical,
  ) {
    final stats = currentContent['stats'] as List;

    return stats.asMap().entries.map((entry) {
      int index = entry.key;
      Map stat = entry.value;

      return Container(
        width: isVertical ? double.infinity : 100,
        margin: EdgeInsets.symmetric(
          vertical: isVertical ? 8 : 0,
          horizontal: isVertical ? 0 : 4,
        ),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: darkMode
                ? [
                    DesertColors.darkSurface,
                    DesertColors.maroon.withOpacity(0.3),
                  ]
                : [
                    DesertColors.lightSurface,
                    DesertColors.camelSand.withOpacity(0.3),
                  ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: darkMode
                ? DesertColors.camelSand.withOpacity(0.3)
                : DesertColors.crimson.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              stat['value']!,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkMode ? DesertColors.camelSand : DesertColors.crimson,
              ),
            ),
            SizedBox(height: 4),
            Text(
              stat['label']!,
              style: TextStyle(
                fontSize: 10,
                color: darkMode
                    ? DesertColors.darkText.withOpacity(0.7)
                    : DesertColors.lightText.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildMobileButton(Map currentContent, String language) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pushNamed(context, '/login');
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [DesertColors.crimson, DesertColors.maroon],
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: DesertColors.crimson.withOpacity(0.4),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          currentContent['cta2'] as String,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
