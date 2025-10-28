import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../alrayah.dart';
import 'package:visibility_detector/visibility_detector.dart';

class QRCodePainter extends CustomPainter {
  final bool darkMode;

  QRCodePainter({required this.darkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = darkMode ? DesertColors.darkText : DesertColors.lightText
      ..style = PaintingStyle.fill;

    final blockSize = size.width / 21;

    // QR Code pattern (simplified)
    final pattern = [
      [1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1],
      [1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1],
      [1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1],
      [1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1],
      [1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1],
      [1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1],
      [1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1],
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      [1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1],
      [0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0],
      [1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1],
      [0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0],
      [1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1],
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      [1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1],
      [1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1],
      [1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1],
      [1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1],
      [1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1],
      [1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1],
      [1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1],
    ];

    for (int i = 0; i < pattern.length; i++) {
      for (int j = 0; j < pattern[i].length; j++) {
        if (pattern[i][j] == 1) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                j * blockSize,
                i * blockSize,
                blockSize * 0.9,
                blockSize * 0.9,
              ),
              Radius.circular(blockSize * 0.1),
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MobileAppSection extends StatefulWidget {
  final String language;
  final bool darkMode;
  final VoidCallback onShowQR;

  const MobileAppSection({
    super.key,
    required this.language,
    required this.darkMode,
    required this.onShowQR,
  });

  @override
  State<MobileAppSection> createState() => _MobileAppSectionState();
}

class _MobileAppSectionState extends State<MobileAppSection>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _floatingController;
  late AnimationController _scrollController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // init controllers here but don't start immediately
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
  }

  void _startAnimations() {
    _rotationController.repeat();
    _floatingController.repeat();
    _scrollController.repeat();
    _pulseController.repeat();
  }

  void _stopAnimations() {
    _rotationController.stop();
    _floatingController.stop();
    _scrollController.stop();
    _pulseController.stop();
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
        'title': 'تطبيق الراية',
        'subtitle': 'تجربة استثنائية على جوالك',
        'description':
            'حمل تطبيق الراية واستمتع بتجربة رقمية فريدة تجمع بين سهولة الاستخدام والمحتوى الثري',
        'downloadText': 'حمل التطبيق الآن',
        'features': [
          {'title': 'آمن ومحمي', 'description': 'حماية عالية لبياناتك الشخصية'},
          {
            'title': 'سريع وسهل',
            'description': 'واجهة بسيطة وسرعة في الاستجابة',
          },
          {'title': 'مجتمع متفاعل', 'description': 'تفاعل مع القراء والباحثين'},
        ],
        'stats': [
          {'label': 'تحميل', 'value': '100K+'},
          {'label': 'تقييم', 'value': '4.8'},
          {'label': 'مستخدم نشط', 'value': '50K+'},
        ],
      },
      'en': {
        'title': 'Alraya App',
        'subtitle': 'Exceptional experience on your mobile',
        'description':
            'Download the Alraya app and enjoy a unique digital experience that combines ease of use with rich content',
        'downloadText': 'Download App Now',
        'features': [
          {
            'title': 'Secure & Protected',
            'description': 'High-level protection for your personal data',
          },
          {
            'title': 'Fast & Easy',
            'description': 'Simple interface with quick response',
          },
          {
            'title': 'Interactive Community',
            'description': 'Engage with readers and researchers',
          },
        ],
        'stats': [
          {'label': 'Downloads', 'value': '100K+'},
          {'label': 'Rating', 'value': '4.8'},
          {'label': 'Active Users', 'value': '50K+'},
        ],
      },
    };

    final currentContent = content[language]!;

    final circleDecoration = BoxDecoration(
      gradient: RadialGradient(
        colors: [Colors.white.withOpacity(0.08), Colors.transparent],
      ),
      shape: BoxShape.circle,
    );

    return VisibilityDetector(
      key: Key('mobile-app-section'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.2) {
          _startAnimations();
        } else {
          _stopAnimations();
        }
      },

      child: MouseReactiveTilt(
        builder: (offset) {
          return Container(
            padding: EdgeInsets.symmetric(vertical: 80, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: darkMode
                    ? [
                        DesertColors.maroon,
                        DesertColors.darkBackground,
                        DesertColors.darkSurface,
                      ]
                    : [
                        DesertColors.crimson,
                        DesertColors.maroon,
                        DesertColors.primaryGoldDark,
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // Enhanced Background Elements
                ...List.generate(6, (index) {
                  return AnimatedBuilder(
                    animation: _floatingController,
                    builder: (context, child) {
                      return Positioned(
                        left:
                            (index * 140.0) % MediaQuery.of(context).size.width,
                        top: (index * 160.0) % 700,
                        child: Transform.translate(
                          offset: Offset(
                            math.sin(
                                  _floatingController.value * 2 * math.pi +
                                      index,
                                ) *
                                120,
                            math.cos(
                                  _floatingController.value * 2 * math.pi +
                                      index,
                                ) *
                                80,
                          ),
                          child: Container(
                            width: 60 + (index * 10.0),
                            height: 60 + (index * 10.0),
                            decoration:
                                circleDecoration, // reused instead of rebuilding
                          ),
                        ),
                      );
                    },
                  );
                }),

                // Main Content
                Row(
                  children: [
                    // Content Side
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: EdgeInsets.only(left: 120),
                        child: Column(
                          crossAxisAlignment: language == 'ar'
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            // Title with enhanced animation
                            TweenAnimationBuilder(
                              duration: Duration(milliseconds: 1000),
                              tween: Tween<double>(begin: 0, end: 1),
                              builder: (context, double value, child) {
                                return Transform.translate(
                                  offset: Offset(
                                    language == 'ar'
                                        ? 80 * (1 - value)
                                        : -80 * (1 - value),
                                    0,
                                  ),
                                  child: Opacity(
                                    opacity: value,
                                    child: ShaderMask(
                                      shaderCallback: (bounds) =>
                                          LinearGradient(
                                            colors: [
                                              Colors.white,
                                              DesertColors.camelSand,
                                            ],
                                          ).createShader(bounds),
                                      child: Text(
                                        currentContent['title'] as String,
                                        style: TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        textAlign: language == 'ar'
                                            ? TextAlign.right
                                            : TextAlign.left,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            SizedBox(height: 16),

                            // Subtitle with slide animation
                            TweenAnimationBuilder(
                              duration: Duration(milliseconds: 800),
                              tween: Tween<double>(begin: 0, end: 1),
                              builder: (context, double value, child) {
                                return Transform.translate(
                                  offset: Offset(
                                    language == 'ar'
                                        ? 60 * (1 - value)
                                        : -60 * (1 - value),
                                    0,
                                  ),
                                  child: Opacity(
                                    opacity: value,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.2),
                                            DesertColors.camelSand.withOpacity(
                                              0.2,
                                            ),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        currentContent['subtitle'] as String,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
                                          color: DesertColors.camelSand,
                                        ),
                                        textAlign: language == 'ar'
                                            ? TextAlign.right
                                            : TextAlign.left,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            SizedBox(height: 24),

                            // Description
                            TweenAnimationBuilder(
                              duration: Duration(milliseconds: 600),
                              tween: Tween<double>(begin: 0, end: 1),
                              builder: (context, double value, child) {
                                return Transform.translate(
                                  offset: Offset(
                                    language == 'ar'
                                        ? 40 * (1 - value)
                                        : -40 * (1 - value),
                                    0,
                                  ),
                                  child: Opacity(
                                    opacity: value,
                                    child: Text(
                                      currentContent['description'] as String,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white.withOpacity(0.9),
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

                            // Features with staggered animation
                            Column(
                              children: (currentContent['features'] as List).asMap().entries.map((
                                entry,
                              ) {
                                int index = entry.key;
                                Map feature = entry.value;

                                return TweenAnimationBuilder(
                                  duration: Duration(
                                    milliseconds: 600 + (index * 200),
                                  ),
                                  tween: Tween<double>(begin: 0, end: 1),
                                  builder: (context, double value, child) {
                                    return Transform.translate(
                                      offset: Offset(
                                        language == 'ar'
                                            ? 30 * (1 - value)
                                            : -30 * (1 - value),
                                        0,
                                      ),
                                      child: Opacity(
                                        opacity: value,
                                        child: Container(
                                          margin: EdgeInsets.only(bottom: 24),
                                          padding: EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.white.withOpacity(0.1),
                                                Colors.white.withOpacity(0.05),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.2,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: language == 'ar'
                                                ? [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .end,
                                                        children: [
                                                          Text(
                                                            feature['title']!,
                                                            style: TextStyle(
                                                              fontSize: 18,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                          SizedBox(height: 4),
                                                          Text(
                                                            feature['description']!,
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .white
                                                                  .withOpacity(
                                                                    0.8,
                                                                  ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    SizedBox(width: 16),
                                                    Container(
                                                      width: 48,
                                                      height: 48,
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [
                                                            DesertColors
                                                                .camelSand,
                                                            DesertColors
                                                                .primaryGoldDark,
                                                          ],
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: DesertColors
                                                                .camelSand
                                                                .withOpacity(
                                                                  0.4,
                                                                ),
                                                            blurRadius: 12,
                                                            offset: Offset(
                                                              0,
                                                              6,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Icon(
                                                        index == 0
                                                            ? Icons.security
                                                            : index == 1
                                                            ? Icons.flash_on
                                                            : Icons.people,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ]
                                                : [
                                                    Container(
                                                      width: 48,
                                                      height: 48,
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [
                                                            DesertColors
                                                                .camelSand,
                                                            DesertColors
                                                                .primaryGoldDark,
                                                          ],
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: DesertColors
                                                                .camelSand
                                                                .withOpacity(
                                                                  0.4,
                                                                ),
                                                            blurRadius: 12,
                                                            offset: Offset(
                                                              0,
                                                              6,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Icon(
                                                        index == 0
                                                            ? Icons.security
                                                            : index == 1
                                                            ? Icons.flash_on
                                                            : Icons.people,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                    ),
                                                    SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            feature['title']!,
                                                            style: TextStyle(
                                                              fontSize: 18,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                          SizedBox(height: 4),
                                                          Text(
                                                            feature['description']!,
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .white
                                                                  .withOpacity(
                                                                    0.8,
                                                                  ),
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
                                  },
                                );
                              }).toList(),
                            ),
                            SizedBox(height: 32),

                            // Download Button with pulse animation
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
                                        widget
                                            .onShowQR(); // 👈 tell parent to show overlay
                                      },
                                      child: AnimatedBuilder(
                                        animation: _pulseController,
                                        builder: (context, child) {
                                          return Transform.scale(
                                            scale:
                                                1.0 +
                                                (math.sin(
                                                      _pulseController.value *
                                                          2 *
                                                          math.pi,
                                                    ) *
                                                    0.05),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 32,
                                                vertical: 16,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    DesertColors.camelSand,
                                                    DesertColors
                                                        .primaryGoldDark,
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: DesertColors
                                                        .camelSand
                                                        .withOpacity(0.4),
                                                    blurRadius: 20,
                                                    offset: Offset(0, 8),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.download,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    currentContent['downloadText']
                                                        as String,
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
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
                      ),
                    ),

                    SizedBox(width: 32),

                    // Enhanced 3D Phone Mockup
                    Expanded(
                      flex: 2,
                      child: TweenAnimationBuilder(
                        duration: Duration(milliseconds: 1200),
                        tween: Tween<double>(begin: 0, end: 1),
                        builder: (context, double value, child) {
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateX(offset.dy * 0.6)
                              ..rotateY(-offset.dx * 0.6),
                            child: Transform.scale(
                              scale: 0.6 + (0.4 * value),
                              child: Opacity(
                                opacity: value,
                                child: Center(
                                  child: Container(
                                    width: 300,
                                    height: 500,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          DesertColors.maroon,
                                          DesertColors.darkSurface,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.4),
                                          blurRadius: 30,
                                          offset: Offset(0, 15),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              DesertColors.darkBackground,
                                              DesertColors.darkSurface,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            // Status Bar
                                            Padding(
                                              padding: EdgeInsets.all(16),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    '9:41',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  Text(
                                                    '●●●●',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // App Header
                                            Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 16,
                                              ),
                                              child: Row(
                                                children: [
                                                  AnimatedBuilder(
                                                    animation:
                                                        _rotationController,
                                                    builder: (context, child) {
                                                      return Transform.rotate(
                                                        angle:
                                                            _rotationController
                                                                .value *
                                                            2 *
                                                            math.pi,
                                                        child: Container(
                                                          width: 32,
                                                          height: 32,
                                                          decoration: BoxDecoration(
                                                            gradient:
                                                                LinearGradient(
                                                                  colors: [
                                                                    DesertColors
                                                                        .crimson,
                                                                    DesertColors
                                                                        .maroon,
                                                                  ],
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                          child: Center(
                                                            child: Text(
                                                              'ر',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  SizedBox(width: 12),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        language == 'ar'
                                                            ? 'الراية'
                                                            : 'Alraya',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      Text(
                                                        language == 'ar'
                                                            ? 'النشر الإسلامي'
                                                            : 'Islamic Publishing',
                                                        style: TextStyle(
                                                          color: DesertColors
                                                              .camelSand,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(height: 16),

                                            // Content Cards
                                            Expanded(
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                ),
                                                child: Column(
                                                  children: List.generate(3, (
                                                    index,
                                                  ) {
                                                    return TweenAnimationBuilder(
                                                      duration: Duration(
                                                        milliseconds:
                                                            600 + (index * 200),
                                                      ),
                                                      tween: Tween<double>(
                                                        begin: 0,
                                                        end: 1,
                                                      ),
                                                      builder: (context, double value, child) {
                                                        return Transform.translate(
                                                          offset: Offset(
                                                            60 * (1 - value),
                                                            0,
                                                          ),
                                                          child: Opacity(
                                                            opacity: value,
                                                            child: Container(
                                                              margin:
                                                                  EdgeInsets.only(
                                                                    bottom: 12,
                                                                  ),
                                                              padding:
                                                                  EdgeInsets.all(
                                                                    12,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                gradient: LinearGradient(
                                                                  colors: [
                                                                    DesertColors
                                                                        .crimson
                                                                        .withOpacity(
                                                                          0.3,
                                                                        ),
                                                                    DesertColors
                                                                        .maroon
                                                                        .withOpacity(
                                                                          0.3,
                                                                        ),
                                                                  ],
                                                                ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                                border: Border.all(
                                                                  color: DesertColors
                                                                      .camelSand
                                                                      .withOpacity(
                                                                        0.3,
                                                                      ),
                                                                ),
                                                              ),
                                                              child: Row(
                                                                children: [
                                                                  Container(
                                                                    width: 24,
                                                                    height: 24,
                                                                    decoration: BoxDecoration(
                                                                      gradient: LinearGradient(
                                                                        colors: [
                                                                          DesertColors
                                                                              .camelSand,
                                                                          DesertColors
                                                                              .primaryGoldDark,
                                                                        ],
                                                                      ),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            6,
                                                                          ),
                                                                    ),
                                                                    child: Icon(
                                                                      Icons
                                                                          .star,
                                                                      color: Colors
                                                                          .white,
                                                                      size: 12,
                                                                    ),
                                                                  ),
                                                                  SizedBox(
                                                                    width: 12,
                                                                  ),
                                                                  Expanded(
                                                                    child: Column(
                                                                      children: [
                                                                        Container(
                                                                          height:
                                                                              8,
                                                                          decoration: BoxDecoration(
                                                                            color: DesertColors.camelSand.withOpacity(
                                                                              0.6,
                                                                            ),
                                                                            borderRadius: BorderRadius.circular(
                                                                              4,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        SizedBox(
                                                                          height:
                                                                              8,
                                                                        ),
                                                                        Container(
                                                                          height:
                                                                              8,
                                                                          width:
                                                                              double.infinity *
                                                                              0.6,
                                                                          decoration: BoxDecoration(
                                                                            color: DesertColors.camelSand.withOpacity(
                                                                              0.4,
                                                                            ),
                                                                            borderRadius: BorderRadius.circular(
                                                                              4,
                                                                            ),
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
                                                      },
                                                    );
                                                  }),
                                                ),
                                              ),
                                            ),

                                            // Enhanced Bottom Navigation
                                            Container(
                                              padding: EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    DesertColors.maroon
                                                        .withOpacity(0.8),
                                                    DesertColors.darkSurface
                                                        .withOpacity(0.8),
                                                  ],
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceAround,
                                                children:
                                                    [
                                                      Icons.home,
                                                      Icons.star,
                                                      Icons.people,
                                                      Icons.download,
                                                    ].asMap().entries.map((
                                                      entry,
                                                    ) {
                                                      int index = entry.key;
                                                      IconData icon =
                                                          entry.value;

                                                      return AnimatedBuilder(
                                                        animation:
                                                            _floatingController,
                                                        builder: (context, child) {
                                                          return Transform.translate(
                                                            offset: Offset(
                                                              0,
                                                              math.sin(
                                                                    _floatingController.value *
                                                                            2 *
                                                                            math.pi +
                                                                        index,
                                                                  ) *
                                                                  3,
                                                            ),
                                                            child: Container(
                                                              padding:
                                                                  EdgeInsets.all(
                                                                    8,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color:
                                                                    index == 0
                                                                    ? DesertColors
                                                                          .crimson
                                                                          .withOpacity(
                                                                            0.3,
                                                                          )
                                                                    : Colors
                                                                          .transparent,
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      8,
                                                                    ),
                                                              ),
                                                              child: Icon(
                                                                icon,
                                                                color:
                                                                    index == 0
                                                                    ? DesertColors
                                                                          .camelSand
                                                                    : Colors
                                                                          .white
                                                                          .withOpacity(
                                                                            0.7,
                                                                          ),
                                                                size: 20,
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      );
                                                    }).toList(),
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
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
