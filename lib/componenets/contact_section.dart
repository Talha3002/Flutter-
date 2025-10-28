import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../alrayah.dart';

class ContactSection extends StatefulWidget {
  final String language;
  final bool darkMode;

  const ContactSection({
    Key? key, // 👈 add this
    required this.language,
    required this.darkMode,
  }) : super(key: key);

  @override
  State<ContactSection> createState() => _ContactSectionState();
}

class _ContactSectionState extends State<ContactSection>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _floatingController;
  late AnimationController _scrollController;
  late AnimationController _pulseController;

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
        'title': 'رأيك يهمنا',
        'subtitle': 'تواصل معنا ونحن سعداء للإجابة على استفساراتك',
        'form': {
          'name': 'اسمك',
          'email': 'البريد الإلكتروني',
          'phone': 'رقم الهاتف',
          'message': 'رأيك',
          'submit': 'إرسال',
        },
        'contact': {
          'address': 'العنوان',
          'phone': 'الهاتف',
          'email': 'البريد الإلكتروني',
        },
      },
      'en': {
        'title': 'Your Opinion Matters',
        'subtitle': 'Contact us and we\'ll be happy to answer your questions',
        'form': {
          'name': 'Your Name',
          'email': 'Email Address',
          'phone': 'Phone Number',
          'message': 'Your Message',
          'submit': 'Send',
        },
        'contact': {'address': 'Address', 'phone': 'Phone', 'email': 'Email'},
      },
    };

    final currentContent = content[language]!;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final contactInfo = [
      {
        'icon': Icons.location_on,
        'label': (currentContent['contact'] as Map)['address']!,
        'value': language == 'ar' ? 'الكويت، الجهراء' : 'Kuwait, Al-Jahra',
      },
      {
        'icon': Icons.phone,
        'label': (currentContent['contact'] as Map)['phone']!,
        'value': '+965 2345 6789',
      },
      {
        'icon': Icons.email,
        'label': (currentContent['contact'] as Map)['email']!,
        'value': 'info@alraya.com',
      },
    ];

    return Container(
      key: widget.key,
      padding: EdgeInsets.symmetric(vertical: 80, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: darkMode
              ? [DesertColors.darkSurface, DesertColors.darkBackground]
              : [DesertColors.lightSurface, DesertColors.lightBackground],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Section Header
          TweenAnimationBuilder(
            duration: Duration(milliseconds: 800),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              DesertColors.crimson.withOpacity(0.1),
                              DesertColors.camelSand.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: DesertColors.crimson.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          currentContent['title'] as String,
                          style: TextStyle(
                            fontSize: isMobile
                                ? 28
                                : 40, // 👈 Responsive font size
                            fontWeight: FontWeight.bold,
                            color: darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        currentContent['subtitle'] as String,
                        style: TextStyle(
                          fontSize: isMobile
                              ? 14
                              : 18, // 👈 Responsive font size
                          color: darkMode
                              ? DesertColors.darkText.withOpacity(0.8)
                              : DesertColors.lightText.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 64),
          isMobile
              ? _buildMobileFormOnly(language, darkMode, currentContent)
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Contact Info
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: contactInfo.asMap().entries.map((entry) {
                          int index = entry.key;
                          Map info = entry.value;

                          return TweenAnimationBuilder(
                            duration: Duration(
                              milliseconds: 600 + (index * 200),
                            ),
                            tween: Tween<double>(begin: 0, end: 1),
                            builder: (context, double value, child) {
                              return Transform.translate(
                                offset: Offset(
                                  language == 'ar'
                                      ? 50 * (1 - value)
                                      : -50 * (1 - value),
                                  0,
                                ),
                                child: Opacity(
                                  opacity: value,
                                  child: Container(
                                    margin: EdgeInsets.only(bottom: 32),
                                    padding: EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: darkMode
                                            ? [
                                                DesertColors.darkSurface,
                                                DesertColors.maroon.withOpacity(
                                                  0.1,
                                                ),
                                              ]
                                            : [
                                                Colors.white,
                                                DesertColors.lightSurface,
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: DesertColors.crimson
                                              .withOpacity(0.1),
                                          blurRadius: 15,
                                          offset: Offset(0, 5),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: DesertColors.camelSand
                                            .withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: language == 'ar'
                                          ? [
                                              // 👉 Text first (aligned to the right)
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      info['label']!,
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: darkMode
                                                            ? DesertColors
                                                                  .darkText
                                                            : DesertColors
                                                                  .lightText,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4),
                                                    Text(
                                                      info['value']!,
                                                      style: TextStyle(
                                                        color: darkMode
                                                            ? DesertColors
                                                                  .darkText
                                                                  .withOpacity(
                                                                    0.8,
                                                                  )
                                                            : DesertColors
                                                                  .lightText
                                                                  .withOpacity(
                                                                    0.8,
                                                                  ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(width: 16),
                                              // 👉 Responsive Icon (replaces old Container)
                                              isMobile
                                                  ? Icon(
                                                      info['icon'],
                                                      color:
                                                          DesertColors.crimson,
                                                      size: 28,
                                                    )
                                                  : Container(
                                                      width: 48,
                                                      height: 48,
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
                                                              12,
                                                            ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: DesertColors
                                                                .crimson
                                                                .withOpacity(
                                                                  0.3,
                                                                ),
                                                            blurRadius: 8,
                                                            offset: Offset(
                                                              0,
                                                              4,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Icon(
                                                        info['icon'],
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                    ),
                                            ]
                                          : [
                                              // 👉 Responsive Icon (left side for English)
                                              isMobile
                                                  ? Icon(
                                                      info['icon'],
                                                      color:
                                                          DesertColors.crimson,
                                                      size: 28,
                                                    )
                                                  : Container(
                                                      width: 48,
                                                      height: 48,
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
                                                              12,
                                                            ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: DesertColors
                                                                .crimson
                                                                .withOpacity(
                                                                  0.3,
                                                                ),
                                                            blurRadius: 8,
                                                            offset: Offset(
                                                              0,
                                                              4,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Icon(
                                                        info['icon'],
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                    ),
                                              SizedBox(width: 16),
                                              // 👉 Text aligned to left for English
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      info['label']!,
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: darkMode
                                                            ? DesertColors
                                                                  .darkText
                                                            : DesertColors
                                                                  .lightText,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4),
                                                    Text(
                                                      info['value']!,
                                                      style: TextStyle(
                                                        color: darkMode
                                                            ? DesertColors
                                                                  .darkText
                                                                  .withOpacity(
                                                                    0.8,
                                                                  )
                                                            : DesertColors
                                                                  .lightText
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
                    ),

                    SizedBox(width: 48),

                    // Contact Form
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: language == 'ar' ? 0 : 80,
                          right: language == 'en' ? 40 : 0,
                        ),
                        child: _buildAnimatedForm(
                          currentContent,
                          darkMode,
                          language,
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildMobileFormOnly(
    String language,
    bool darkMode,
    Map currentContent,
  ) {
    return Center(
      // 👈 Added Center widget
      child: Container(
        constraints: BoxConstraints(maxWidth: 400), // 👈 Max width constraint
        padding: const EdgeInsets.symmetric(
          horizontal: 20.0,
        ), // 👈 Increased padding
        child: _buildAnimatedForm(currentContent, darkMode, language),
      ),
    );
  }

  Widget _buildAnimatedForm(
    Map currentContent,
    bool darkMode,
    String language,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 800),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double value, child) {
            return Transform.translate(
              offset: Offset(0, 50 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: darkMode
                          ? [
                              DesertColors.darkSurface,
                              DesertColors.maroon.withOpacity(0.1),
                            ]
                          : [Colors.white, DesertColors.lightSurface],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: DesertColors.camelSand.withOpacity(0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: DesertColors.crimson.withOpacity(0.1),
                        blurRadius: 25,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              darkMode,
                              language,
                              (currentContent['form'] as Map)['name']!,
                              Icons.person,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildFormField(
                              darkMode,
                              language,
                              (currentContent['form'] as Map)['email']!,
                              Icons.email,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      _buildFormField(
                        darkMode,
                        language,
                        (currentContent['form'] as Map)['phone']!,
                        Icons.phone,
                      ),
                      SizedBox(height: 24),
                      _buildFormField(
                        darkMode,
                        language,
                        (currentContent['form'] as Map)['message']!,
                        Icons.message,
                        isTextArea: true,
                      ),
                      SizedBox(height: 32),
                      GestureDetector(
                        onTap: () => HapticFeedback.mediumImpact(),
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
                                color: DesertColors.crimson.withOpacity(0.4),
                                blurRadius: 15,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                (currentContent['form'] as Map)['submit']!,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isMobile
                                      ? 14
                                      : 16, // 👈 Responsive font size
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
                                      Icons.send,
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
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFormField(
    bool darkMode,
    String language,
    String label,
    IconData icon, {
    bool isTextArea = false,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Column(
      crossAxisAlignment: language == 'ar'
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: darkMode
                ? DesertColors.darkText.withOpacity(0.9)
                : DesertColors.lightText.withOpacity(0.9),
          ),
        ),
        SizedBox(height: 8),
        AnimatedContainer(
          duration: Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: darkMode
                  ? [
                      DesertColors.darkSurface,
                      DesertColors.maroon.withOpacity(0.1),
                    ]
                  : [Colors.white, DesertColors.lightSurface],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DesertColors.camelSand.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: DesertColors.camelSand.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            maxLines: isTextArea ? 5 : 1,
            textAlign: language == 'ar' ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(
                color: darkMode
                    ? DesertColors.darkText.withOpacity(0.6)
                    : DesertColors.lightText.withOpacity(0.6),
              ),
              prefixIcon: language == 'ar'
                  ? null
                  : Padding(
                      padding: EdgeInsets.only(
                        top: isTextArea ? 12 : 0,
                        left: 8,
                        right: 8,
                      ),
                      child: isMobile
                          // 👇 On mobile: plain red icon
                          ? Icon(icon, color: DesertColors.crimson, size: 22)
                          // 👇 On desktop: keep gradient container
                          : Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    DesertColors.camelSand,
                                    DesertColors.primaryGoldDark,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(icon, color: Colors.white, size: 18),
                            ),
                    ),
              suffixIcon: language == 'ar'
                  ? Padding(
                      padding: EdgeInsets.only(
                        top: isTextArea ? 12 : 0,
                        left: 8,
                        right: 8,
                      ),
                      child: isMobile
                          // 👇 On mobile: plain red icon
                          ? Icon(icon, color: DesertColors.crimson, size: 22)
                          // 👇 On desktop: keep gradient container
                          : Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    DesertColors.camelSand,
                                    DesertColors.primaryGoldDark,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(icon, color: Colors.white, size: 18),
                            ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }
}
