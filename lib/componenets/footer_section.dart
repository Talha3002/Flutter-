import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'dart:math' as math;
import '../alrayah.dart';

class FooterSection extends StatefulWidget {
  final String language;
  final bool darkMode;

  const FooterSection({
    super.key,
    required this.language,
    required this.darkMode,
  });

  @override
  State<FooterSection> createState() => _FooterSectionState();
}

class _FooterSectionState extends State<FooterSection>
    with TickerProviderStateMixin {

  ScrollController _pageScrollController = ScrollController();
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    
     _setupScrollListener();

  }

  void _setupScrollListener() {
    _pageScrollController.addListener(() {
      setState(() {
        _scrolled = _pageScrollController.offset > 50;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = widget.darkMode;
    final language = widget.language;
    final content = {
      'ar': {
        'company': 'الراية',
        'description': 'منصة رقمية شاملة للنشر الإسلامي والتراث الديني',
        'quickLinks': 'روابط سريعة',
        'links': [
          {'name': 'الرئيسية', 'href': '#home'},
          {'name': 'إصدارات المجلس', 'href': '#publications'},
          {'name': 'مكتبة الرؤية', 'href': '#library'},
          {'name': 'من نحن', 'href': '#about'},
          {'name': 'تواصل معنا', 'href': '#contact'},
        ],
        'socialMedia': 'وسائل التواصل',
        'followUs': 'تابعنا على',
        'copyright': 'جميع الحقوق محفوظة',
        'madeWith': 'صُنع بـ',
        'in': 'في',
      },
      'en': {
        'company': 'Al-Rayah',
        'description':
            'Comprehensive digital platform for Islamic publishing and religious heritage',
        'quickLinks': 'Quick Links',
        'links': [
          {'name': 'Home', 'href': '#home'},
          {'name': 'Council Publications', 'href': '#publications'},
          {'name': 'Vision Library', 'href': '#library'},
          {'name': 'About Us', 'href': '#about'},
          {'name': 'Contact', 'href': '#contact'},
        ],
        'socialMedia': 'Social Media',
        'followUs': 'Follow Us',
        'copyright': 'All rights reserved',
        'madeWith': 'Made with',
        'in': 'in',
      },
    };

    final currentContent = content[language]! as Map<String, dynamic>;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final socialLinks = [
      {
        'icon': FontAwesomeIcons.whatsapp,
        'name': 'WhatsApp',
        'color': Color(0xFF25D366),
      },
      {
        'icon': FontAwesomeIcons.instagram,
        'name': 'Instagram',
        'color': Color(0xFFE4405F),
      },
      {
        'icon': FontAwesomeIcons.youtube,
        'name': 'YouTube',
        'color': Color(0xFFFF0000),
      },
      {
        'icon': FontAwesomeIcons.twitter,
        'name': 'Twitter',
        'color': Color(0xFF1DA1F2),
      },
      {
        'icon': FontAwesomeIcons.facebook,
        'name': 'Facebook',
        'color': Color(0xFF1877F2),
      },
    ];

    if (isMobile) {
      // ✅ Mobile layout
      return Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: darkMode
                ? [DesertColors.darkSurface, DesertColors.darkBackground]
                : [DesertColors.darkSurface, DesertColors.crimson],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo & Company
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', width: 40, height: 40),
                SizedBox(width: 12),
                Text(
                  currentContent['company']!,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              currentContent['description']!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 24),

            // Social media
            Text(
              currentContent['followUs']!,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              children: socialLinks.map((social) {
                return HoverIconButton(
                  icon: social['icon'] as IconData,
                  hoverColor: social['color'] as Color,
                );
              }).toList(),
            ),
            SizedBox(height: 24),

            // Quick Links
            Text(
              currentContent['quickLinks']!,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),
            Column(
              children: (currentContent['links'] as List).map((link) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: GestureDetector(
                    onTap: () {
                      if (!kIsWeb) {
                        HapticFeedback.lightImpact();
                      }
                    },
                    child: Text(
                      link['name']!,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 24),

            // Contact Info
            Text(
              language == 'ar' ? 'معلومات الاتصال' : 'Contact Info',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),
            _buildContactInfo(
              language == 'ar' ? 'العنوان:' : 'Address:',
              language == 'ar' ? 'الكويت، الجهراء' : 'Kuwait, Al-Jahra',
              language,
            ),
            SizedBox(height: 12),
            _buildContactInfo(
              language == 'ar' ? 'الهاتف:' : 'Phone:',
              '+965 2345 6789',
              language,
            ),
            SizedBox(height: 12),
            _buildContactInfo(
              language == 'ar' ? 'البريد الإلكتروني:' : 'Email:',
              'info@alrayah.com',
              language,
            ),
            SizedBox(height: 24),

            // Bottom
            Text(
              '© 2024 ${currentContent['company']}. ${currentContent['copyright']}',
              style: TextStyle(color: Colors.white60),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 64, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: darkMode
              ? [
                  DesertColors.maroon,
                  DesertColors.darkBackground,
                  DesertColors.darkSurface,
                ]
              : [
                  DesertColors.maroon,
                  DesertColors.crimson,
                  DesertColors.darkSurface,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Company Info
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.only(left: 50),
                  child: TweenAnimationBuilder(
                    duration: Duration(milliseconds: 800),
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, double value, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: Column(
                            crossAxisAlignment: language == 'ar'
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              // Logo
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,

                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        8,
                                      ), // optional: rounded image
                                      child: Image.asset(
                                        'assets/images/logo.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    currentContent['company'] as String,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),

                              Text(
                                currentContent['description'] as String,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  height: 1.6,
                                ),
                                textAlign: language == 'ar'
                                    ? TextAlign.right
                                    : TextAlign.left,
                              ),
                              SizedBox(height: 24),

                              // Social Media
                              Text(
                                currentContent['followUs'] as String,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 16),

                              Row(
                                mainAxisAlignment: language == 'ar'
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                                children: socialLinks.map((social) {
                                  return HoverIconButton(
                                    icon: social['icon'] as IconData,
                                    hoverColor: social['color'] as Color,
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              SizedBox(width: 48),

              // Quick Links
              Expanded(
                flex: 1,
                child: TweenAnimationBuilder(
                  duration: Duration(milliseconds: 800),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.translate(
                      offset: Offset(0, 30 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: Column(
                          crossAxisAlignment: language == 'ar'
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    DesertColors.camelSand.withOpacity(0.3),
                                    DesertColors.primaryGoldDark.withOpacity(
                                      0.3,
                                    ),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                currentContent['quickLinks'] as String,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(height: 16),

                            Column(
                              children: (currentContent['links'] as List)
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                    int index = entry.key;
                                    Map link = entry.value;

                                    return TweenAnimationBuilder(
                                      duration: Duration(
                                        milliseconds: 500 + (index * 100),
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
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                bottom: 12,
                                              ),
                                              child: GestureDetector(
                                                onTap: () {
                                                  if (!kIsWeb) {
                                                    HapticFeedback.lightImpact();
                                                  }
                                                },

                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withOpacity(0.2),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        link['name']!,
                                                        style: TextStyle(
                                                          color: Colors.white
                                                              .withOpacity(0.9),
                                                        ),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Icon(
                                                        Icons.arrow_outward,
                                                        size: 14,
                                                        color: DesertColors
                                                            .camelSand,
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
                                  })
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              SizedBox(width: 48),

              // Contact Info
              Expanded(
                flex: 1,
                child: TweenAnimationBuilder(
                  duration: Duration(milliseconds: 800),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.translate(
                      offset: Offset(0, 30 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: Column(
                          crossAxisAlignment: language == 'ar'
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    DesertColors.camelSand.withOpacity(0.3),
                                    DesertColors.primaryGoldDark.withOpacity(
                                      0.3,
                                    ),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                language == 'ar'
                                    ? 'معلومات الاتصال'
                                    : 'Contact Info',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(height: 16),

                            Column(
                              crossAxisAlignment: language == 'ar'
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                _buildContactInfo(
                                  language == 'ar' ? 'العنوان:' : 'Address:',
                                  language == 'ar'
                                      ? 'الكويت، الجهراء'
                                      : 'Kuwait, Al-Jahra',
                                  language,
                                ),
                                SizedBox(height: 12),
                                _buildContactInfo(
                                  language == 'ar' ? 'الهاتف:' : 'Phone:',
                                  '+965 2345 6789',
                                  language,
                                ),
                                SizedBox(height: 12),
                                _buildContactInfo(
                                  language == 'ar'
                                      ? 'البريد الإلكتروني:'
                                      : 'Email:',
                                  'info@alrayah.com',
                                  language,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 48),

          // Bottom Section
          TweenAnimationBuilder(
            duration: Duration(milliseconds: 800),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    padding: EdgeInsets.only(top: 32),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '© 2024 ${currentContent['company']}. ${currentContent['copyright']}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

Widget _buildContactInfo(String label, String value, String language) {
  return Container(
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
      ),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: RichText(
      textAlign: language == 'ar' ? TextAlign.right : TextAlign.left,
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label\n',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: value,
            style: TextStyle(color: DesertColors.camelSand),
          ),
        ],
      ),
    ),
  );
}
