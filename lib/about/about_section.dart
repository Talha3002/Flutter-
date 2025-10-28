import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../alrayah.dart';
import 'about_section_classes.dart';

// Demo App
class AboutSectionDemo extends StatefulWidget {
  final bool darkMode;
  final String language;
  final bool scrolled;
  final String searchTerm;
  final String filterType;
  final int displayedBooks;

  const AboutSectionDemo({
    super.key,
    required this.darkMode,
    required this.language,
    required this.scrolled,
    required this.searchTerm,
    required this.filterType,
    required this.displayedBooks,
  });
  @override
  _AboutSectionDemoState createState() => _AboutSectionDemoState();
}

class _AboutSectionDemoState extends State<AboutSectionDemo> {
  bool darkMode = false;
  String language = 'ar';

  @override
  Widget build(BuildContext context) {
    final darkMode = widget.darkMode;
    final language = widget.language;
    return MaterialApp(
      title: 'About Al-Rayah',
      theme: ThemeData(fontFamily: language == 'ar' ? 'Cairo' : 'Roboto'),
      home: Scaffold(
        body: AboutSection(darkMode: darkMode, language: language),
      ),
    );
  }
}
