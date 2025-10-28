import 'package:alraya_app/about/about_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../../alrayah.dart';
import '../../componenets/navigation.dart';
import '../../componenets/footer_section.dart';
import 'dart:ui' as ui;

// About Content Model
class AboutContent {
  final Map<String, dynamic> ar = {
    'about': {
      'title': 'عن الراية',
      'subtitle': 'اكتشف قصتنا ورؤيتنا ورسالتنا',
      'faqs': [
        {
          'question': 'متى بدأت الراية؟',
          'answer':
              'كانت البداية في ذكرى خروج الإمام الحسين عليه السلام من سنة ٢٠٢٠ ميلادية',
        },
        {
          'question': 'من أين أتت مسمى "الراية"؟',
          'answer':
              'الراية من ذلك الراية التي تشرفت أن تؤدي واجبها الشريف في معركة سهلاء الطينية، أمسك بها رقم تولاها الحجة بن الحسن عجل الله فرجه الشريف',
        },
        {
          'question': 'ما هي رؤية و هدف فريق الراية؟',
          'answer':
              'الاعتماد استمرار رسالة الإمام الحسين عليه السلام و إيصالها للأجيال القادمة طالما و تمجيل فرج مولانا الحجة بن الحسن عجل الله فرجه الشريف',
        },
        {
          'question': 'كيف أستطيع المساهمة معكم؟',
          'answer': 'المساعدة في نشر موقع و تطبيق الراية لأكبر عدد ممكن',
        },
      ],
    },
  };

  final Map<String, dynamic> en = {
    'about': {
      'title': 'About Al-Rayah',
      'subtitle': 'Discover our story, vision and mission',
      'faqs': [
        {
          'question': 'When did Al-Rayah start?',
          'answer':
              'It began in commemoration of Imam Hussein\'s departure, peace be upon him, from the year 2020 AD',
        },
        {
          'question': 'Where did the name "Al-Rayah" come from?',
          'answer':
              'Al-Rayah is from that banner which was honored to perform its noble duty in the battle of Sahla al-Tiniya, held by the one who took charge of it, al-Hujjah ibn al-Hassan, may Allah hasten his noble reappearance',
        },
        {
          'question': 'What is the vision and mission of Al-Rayah team?',
          'answer':
              'To continue the mission of Imam Hussein, peace be upon him, and convey it to future generations, and to accelerate the reappearance of our master al-Hujjah ibn al-Hassan, may Allah hasten his noble reappearance',
        },
        {
          'question': 'How can I contribute with you?',
          'answer':
              'Help in spreading the Al-Rayah website and application to the largest possible number',
        },
      ],
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
                    : [DesertColors.crimson, DesertColors.primaryGoldDark],
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (widget.darkMode
                              ? DesertColors.crimson
                              : DesertColors.crimson)
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

// FAQ Item Widget
class FAQItem extends StatefulWidget {
  final bool darkMode;
  final String language;
  final String question;
  final String answer;
  final int index;
  final bool isExpanded;
  final VoidCallback onTap;

  const FAQItem({
    Key? key,
    required this.darkMode,
    required this.language,
    required this.question,
    required this.answer,
    required this.index,
    required this.isExpanded,
    required this.onTap,
  }) : super(key: key);

  @override
  _FAQItemState createState() => _FAQItemState();
}

class _FAQItemState extends State<FAQItem> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotationAnimation;
  bool isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600 + widget.index * 100),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 30), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _rotationAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Initial animation
    Future.delayed(Duration(milliseconds: widget.index * 150), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void didUpdateWidget(FAQItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: _slideAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: MouseRegion(
              onEnter: (_) => setState(() => isHovered = true),
              onExit: (_) => setState(() => isHovered = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
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
                          ? DesertColors.darkSurface.withOpacity(0.8)
                          : DesertColors.lightSurface.withOpacity(0.6),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isHovered
                          ? DesertColors.crimson.withOpacity(0.3)
                          : (widget.darkMode
                                ? Colors.black.withOpacity(0.3)
                                : Colors.black.withOpacity(0.1)),
                      blurRadius: isHovered ? 30 : 15,
                      offset: Offset(0, isHovered ? 15 : 8),
                    ),
                  ],
                  border: Border.all(
                    color: widget.isExpanded
                        ? DesertColors.crimson.withOpacity(0.5)
                        : DesertColors.crimson.withOpacity(0.3),
                    width: widget.isExpanded ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      // Question Header
                      InkWell(
                        onTap: widget.onTap,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            children: [
                              // Question Number
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: widget.isExpanded
                                        ? [
                                            DesertColors.crimson,
                                            DesertColors.maroon,
                                          ]
                                        : [
                                            DesertColors.crimson,
                                            DesertColors.primaryGoldDark,
                                          ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (widget.isExpanded
                                                  ? DesertColors.crimson
                                                  : DesertColors.crimson)
                                              .withOpacity(0.4),
                                      blurRadius: 15,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    '${widget.index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 16),

                              // Question Text
                              Expanded(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 300),
                                  style: widget.isExpanded
                                      ? TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          foreground: Paint()
                                            ..shader =
                                                const LinearGradient(
                                                  colors: [
                                                    DesertColors.crimson,
                                                    DesertColors.primaryGoldDark,
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
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: widget.darkMode
                                              ? DesertColors.darkText
                                              : DesertColors.lightText,
                                        ),
                                  child: Text(
                                    widget.question,
                                    textAlign: widget.language == 'ar'
                                        ? TextAlign.right
                                        : TextAlign.left,
                                  ),
                                ),
                              ),

                              // Expand Icon
                              AnimatedBuilder(
                                animation: _rotationAnimation,
                                builder: (context, child) {
                                  return Transform.rotate(
                                    angle: widget.isExpanded ? math.pi : 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: widget.isExpanded
                                            ? DesertColors.crimson
                                                  .withOpacity(0.2)
                                            : DesertColors.crimson
                                                  .withOpacity(0.2),
                                      ),
                                      child: Icon(
                                        Icons.keyboard_arrow_down,
                                        color: widget.isExpanded
                                            ? DesertColors.crimson
                                            : DesertColors.maroon,
                                        size: 20,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Answer Section
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        height: widget.isExpanded ? null : 0,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: widget.isExpanded ? 1.0 : 0.0,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [
                                    DesertColors.crimson.withOpacity(0.05),
                                    DesertColors.crimson.withOpacity(0.05),
                                  ],
                                ),
                                border: Border.all(
                                  color: DesertColors.crimson.withOpacity(
                                    0.2,
                                  ),
                                ),
                              ),
                              child: Text(
                                widget.answer,
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
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// About Hero Section
class AboutHeroSection extends StatefulWidget {
  final bool darkMode;
  final String language;

  const AboutHeroSection({
    Key? key,
    required this.darkMode,
    required this.language,
  }) : super(key: key);

  @override
  _AboutHeroSectionState createState() => _AboutHeroSectionState();
}

class _AboutHeroSectionState extends State<AboutHeroSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _heroController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _heroController, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 50),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _heroController, curve: Curves.easeOut));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _heroController, curve: Curves.easeOut));

    _heroController.forward();
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = AboutContent().getContent(widget.language);

    return AnimatedBuilder(
      animation: _heroController,
      builder: (context, child) {
        return Transform.translate(
          offset: _slideAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      DesertColors.crimson.withOpacity(0.1),
                      DesertColors.crimson.withOpacity(0.1),
                      DesertColors.primaryGoldDark.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(
                    color: DesertColors.crimson.withOpacity(0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (widget.darkMode
                                  ? DesertColors.crimson
                                  : DesertColors.crimson)
                              .withOpacity(0.2),
                      blurRadius: 40,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Logo and Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 130,
                          height: 130,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: widget.language == 'ar'
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              content['about']['title'],
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: widget.darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              content['about']['subtitle'],
                              style: TextStyle(
                                fontSize: 18,
                                color:
                                    (widget.darkMode
                                            ? DesertColors.darkText
                                            : DesertColors.lightText)
                                        .withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Main About Section Widget
class AboutSection extends StatefulWidget {
  final bool darkMode;
  final String language;

  const AboutSection({Key? key, required this.darkMode, required this.language})
    : super(key: key);

  @override
  _AboutSectionState createState() => _AboutSectionState();
}

class _AboutSectionState extends State<AboutSection>
    with TickerProviderStateMixin {
  int expandedIndex = -1;
  late AnimationController _floatingController;
  late Animation<double> _floatingAnimation;
  late ScrollController _scrollController;
  bool scrolled = false;

  @override
  void initState() {
    super.initState();

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

  void _toggleExpansion(int index) {
    setState(() {
      expandedIndex = expandedIndex == index ? -1 : index;
    });
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = AboutContent().getContent(widget.language);
    final faqs = content['about']['faqs'] as List<Map<String, String>>;

    return Directionality(
      textDirection: widget.language == 'ar'
          ? ui.TextDirection.rtl
          : ui.TextDirection.ltr,
      child: Scaffold(
        body: Stack(
          children: [
            // Background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.darkMode
                      ? [DesertColors.darkBackground, DesertColors.darkSurface]
                      : [
                          DesertColors.lightBackground,
                          DesertColors.lightSurface,
                        ],
                ),
              ),
              child: Stack(
                children: [
                  // Floating Background Elements
                  ...List.generate(8, (index) {
                    return AnimatedBuilder(
                      animation: _floatingAnimation,
                      builder: (context, child) {
                        return Positioned(
                          left:
                              (index * 30) % MediaQuery.of(context).size.width,
                          top:
                              (index * 35) % MediaQuery.of(context).size.height,
                          child: Transform.translate(
                            offset: Offset(
                              math.sin(_floatingAnimation.value + index) * 80,
                              math.cos(_floatingAnimation.value + index) * 60,
                            ),
                            child: Container(
                              width: 120 + index * 30.0,
                              height: 120 + index * 30.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    (widget.darkMode
                                            ? DesertColors.crimson
                                            : DesertColors.crimson)
                                        .withOpacity(0.03),
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

                  // Main Content
                  CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // Content
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const SizedBox(height: 40),

                              // Hero Section
                              AboutHeroSection(
                                darkMode: widget.darkMode,
                                language: widget.language,
                              ),

                              const SizedBox(height: 50),

                              // FAQ Section
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: LinearGradient(
                                    colors: widget.darkMode
                                        ? [
                                            DesertColors.darkSurface
                                                .withOpacity(0.5),
                                            DesertColors.maroon
                                                .withOpacity(0.1),
                                          ]
                                        : [
                                            Colors.white.withOpacity(0.8),
                                            DesertColors.lightSurface,
                                          ],
                                  ),
                                  border: Border.all(
                                    color: DesertColors.crimson.withOpacity(
                                      0.3,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (widget.darkMode
                                                  ? Colors.black
                                                  : Colors.grey)
                                              .withOpacity(0.1),
                                      blurRadius: 30,
                                      offset: const Offset(0, 15),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // FAQ Header
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: LinearGradient(
                                          colors: [
                                            DesertColors.crimson.withOpacity(
                                              0.15,
                                            ),
                                            DesertColors.primaryGoldDark.withOpacity(
                                              0.1,
                                            ),
                                          ],
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: const LinearGradient(
                                                colors: [
                                                  DesertColors.crimson,
                                                  DesertColors.primaryGoldDark,
                                                ],
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.help_outline,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Text(
                                            widget.language == 'ar'
                                                ? 'الأسئلة الشائعة'
                                                : 'Frequently Asked Questions',
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
                                    ),

                                    const SizedBox(height: 32),

                                    // FAQ Items
                                    ...faqs.asMap().entries.map((entry) {
                                      int index = entry.key;
                                      Map<String, String> faq = entry.value;

                                      return FAQItem(
                                        darkMode: widget.darkMode,
                                        language: widget.language,
                                        question: faq['question']!,
                                        answer: faq['answer']!,
                                        index: index,
                                        isExpanded: expandedIndex == index,
                                        onTap: () => _toggleExpansion(index),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 50),

                              // Contact Section
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scroll to Top Button
            AnimatedBuilder(
              animation: _floatingAnimation,
              builder: (context, child) {
                return Positioned(
                  bottom: 32,
                  right: widget.language == 'ar' ? null : 32,
                  left: widget.language == 'ar' ? 32 : null,
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
                                color: DesertColors.crimson.withOpacity(0.4),
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
    );
  }
}

class AboutSectionPage extends StatefulWidget {
  const AboutSectionPage({super.key});

  @override
  _AboutSectionPageState createState() => _AboutSectionPageState();
}

class _AboutSectionPageState extends State<AboutSectionPage>
    with TickerProviderStateMixin {
  bool darkMode = false;
  String language = 'ar';
  double _mouseX = 0.0;
  double _mouseY = 0.0;

  late AnimationController _rotationController;
  late AnimationController _floatingController;
  late AnimationController _pulseController;
  late AnimationController _scrollController;
  late AnimationController _themeController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Offset _mousePosition = Offset.zero;
  Offset _targetOffset = Offset.zero;

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
                                      DesertColors.maroon.withOpacity(
                                        0.8,
                                      ),
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
                Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 20,
                      ), // reduce tile width
                      child: GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/about'),
                        child: Container(
                          decoration: BoxDecoration(
                            color: currentRoute == '/about'
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
                                 language == 'ar' ? 'من نحن' : 'About Us',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: currentRoute == '/about'
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
                ListTile(
                  title: Text(
                    language == 'ar'
                        ? 'منشورات الراية'
                        : 'Al-Rayah Publications',
                    style: TextStyle(
                      color: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                  onTap: () => Navigator.pushNamed(context, '/publications'),
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
              child: AboutSectionDemo(
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
      ),
    );
  }
}
