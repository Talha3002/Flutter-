import 'package:alraya_app/componenets/mobile_form_section.dart';
import 'package:alraya_app/login/login_section_classes.dart';
import 'package:alraya_app/majalis_organizer/report.dart';
import 'package:alraya_app/super_admin/admin_events.dart';
import 'package:alraya_app/super_admin/admin_publication.dart';
import 'package:flutter/material.dart';
import 'package:alraya_app/alrayah.dart';
import 'about/about_section_classes.dart';
import 'books/books_section.dart';
import 'publications/publications_section.dart';
import 'majalis/majalis_section.dart';
import 'componenets/all_books.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'majalis_organizer/dashboard.dart';
import 'majalis_organizer/profile.dart';
import 'super_admin/admin_dashboard.dart';
import 'super_admin/admin_books.dart';
import 'super_admin/user_analytics.dart';
import 'super_admin/admin_profile.dart';
import 'package:alraya_app/splash.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Container(
      color: Colors.red,
      padding: EdgeInsets.all(12),
      child: Text(
        details.exception.toString(),
        style: TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  };
  VisitorService.trackVisitor();

  await Supabase.initialize(
    url: 'https://wsbtujhacpnwdzyqboud.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndzYnR1amhhY3Bud2R6eXFib3VkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAzNDkxNzEsImV4cCI6MjA3NTkyNTE3MX0.2pCcw_MEnN2cQbJzTANQ8xIv-Snq3GiBi43yNpj433c',
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final bool darkMode;
  final String language;

  const MyApp({super.key, this.darkMode = false, this.language = "en"});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alraya',
      theme: ThemeData(fontFamily: 'Roboto'),
      debugShowCheckedModeBanner: false,

      initialRoute: "/splash",
      routes: {
        "/splash": (context) => SplashScreen(),
        "/": (context) => AlrayaPage(),
        "/books": (context) => BooksSectionPage(),
        "/majalis": (context) => MajalisSectionPage(),
        "/publications": (context) => PublicationsSectionPage(),
        "/about": (context) => AboutSectionPage(),
        "/login": (context) => LoginSectionPage(),
        "/favorite-books": (context) =>
            AllFavoriteBooksPage(darkMode: darkMode, language: language),
        "/contact": (context) =>
            ContactPage(darkMode: darkMode, language: language),
        '/dashboard': (context) => DashboardPage(),
        '/profile': (context) => ProfilePage(
          darkMode: darkMode,
          language: language,
          onThemeToggle: (isDark) {
            // TODO: implement theme toggle logic
          },
          onLanguageToggle: () {
            // TODO: implement language toggle logic
          },
        ),
        '/reports': (context) => ReportsAnalyticsPage(),
        '/admin_dashboard': (context) => AdminDashboardPage(),
        '/events': (context) => EventManagementPage(),
        '/admin_books': (context) => BookManagementPage(
          darkMode: darkMode,
          language: language,
          onThemeToggle: () {
            // TODO: implement theme toggle logic
          },
          onLanguageToggle: () {
            // TODO: implement language toggle logic
          },
        ),
        '/admin_publication': (context) => PublicationManagementPage(),
        '/user-analytics': (context) => UserAnalyticsPage(),
        '/admin_profile': (context) => AdminProfilePage(
          darkMode: darkMode,
          language: language,
          onThemeToggle: (isDark) {
            // TODO: implement theme toggle logic
          },
          onLanguageToggle: () {
            // TODO: implement language toggle logic
          },
        ),
      },
    );
  }
}
