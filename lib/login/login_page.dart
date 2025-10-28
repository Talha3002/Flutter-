import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../alrayah.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'forgot_password.dart';
import 'package:alraya_app/notification_service.dart';

class SignupPage extends StatefulWidget {
  final bool darkMode;
  final String language;
  final bool scrolled;
  final String searchTerm;
  final String filterType;
  final int displayedBooks;

  const SignupPage({
    super.key,
    required this.darkMode,
    required this.language,
    required this.scrolled,
    required this.searchTerm,
    required this.filterType,
    required this.displayedBooks,
  });

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> with TickerProviderStateMixin {
  bool isArabic = true;
  bool agreeToTerms = false;
  bool _scrolled = false;
  bool showLoginForm = false;
  bool isLogin = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool get isRTL => Directionality.of(context) == TextDirection.rtl;
  String language = 'ar';

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool hasMinLength = false;
  bool hasUppercase = false;
  bool hasLowercase = false;
  bool hasSpecialChar = false;

  String? selectedAccountType; // Add this at class level

  bool get isMobile => MediaQuery.of(context).size.width < 768;
  bool showSignupTab = true; // For mobile tab switching

  late AnimationController _panelController;
  late Animation<Offset> _logoOffset;
  late Animation<Offset> _formOffset;
  late Animation<double> _logoScale;
  late Animation<double> _formScale;

  @override
  void initState() {
    super.initState();
    passwordController.addListener(_validatePassword);

    _panelController = AnimationController(
      duration: Duration(milliseconds: 700),
      vsync: this,
    );

    _logoOffset = Tween<Offset>(begin: Offset(0, 0), end: Offset(0, 0)).animate(
      CurvedAnimation(parent: _panelController, curve: Curves.easeInOutCubic),
    );

    _formOffset = Tween<Offset>(begin: Offset(0, 0), end: Offset(1.0, 0))
        .animate(
          CurvedAnimation(
            parent: _panelController,
            curve: Curves.easeInOutCubic,
          ),
        );

    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _panelController, curve: Curves.easeInOutCubic),
    );

    _formScale = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _panelController, curve: Curves.easeInOutCubic),
    );
  }

  void _validatePassword() {
    final password = passwordController.text;
    setState(() {
      hasMinLength = password.length >= 8;
      hasUppercase = password.contains(RegExp(r'[A-Z]'));
      hasLowercase = password.contains(RegExp(r'[a-z]'));
      hasSpecialChar = password.contains(RegExp(r'[!@#\\$%^&*(),.?":{}|<>]'));
    });
  }

  Future<void> _handleSignup() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final fullName = nameController.text.trim();
    final accountType = selectedAccountType; // e.g. "Event Organizer"

    if (email.isEmpty || password.isEmpty || fullName.isEmpty) {
      // WITH:
      _showCustomPopup(
        widget.language == 'ar' ? 'خطأ' : 'Error',
        widget.language == 'ar'
            ? 'يرجى ملء جميع الحقول المطلوبة'
            : 'Please fill all required fields',
      );
      return;
    }

    try {
      // 1️⃣ Create user in FirebaseAuth
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      final uid = userCredential.user!.uid;

      // 2️⃣ Save in "users" collection (AspNetUsers equivalent)
      final userDoc = {
        "Id": uid,
        "Email": email,
        "FullName": fullName,
        "UserType": accountType,
        "IsActive": "True", // keep as string, same as migrated data
        "IsDeleted": "False", // keep as string
        "CreatedAt": DateTime.now().toIso8601String(),
        "ImagePath": "/assets/media/svg/files/blank-image.svg",
      };

      await FirebaseFirestore.instance
          .collection("aspnetusers")
          .doc(uid)
          .set(userDoc)
          .then((_) => print("✅ User saved"))
          .catchError((e) => print("❌ Firestore error: $e"));

      // 3️⃣ Save claims separately in "userClaims" collection (AspNetUserClaims equivalent)
      final claimDocId = FirebaseFirestore.instance
          .collection("aspnetuserclaims")
          .doc()
          .id;

      String claimValue;
      if (accountType == "Event Organizer") {
        claimValue = "Orator";
      } else if (accountType == "Visitor") {
        claimValue = "Visitor";
      } else {
        claimValue = "SuperAdmin"; // default
      }

      final claimDoc = {
        "Id": claimDocId, // PK
        "UserId": uid, // FK to users.Id
        "ClaimType": "Permission",
        "ClaimValue": claimValue,
      };

      await FirebaseFirestore.instance
          .collection("aspnetuserclaims")
          .doc(claimDocId)
          .set(claimDoc);

      // ✅ Notify Admin about new user
      await NotificationService.notifyAdminNewUser(
        fullName,
        email,
        accountType ?? "Unknown",
        uid,
      );

      // 4️⃣ Send verification email
      await userCredential.user?.sendEmailVerification();

      // 5️⃣ Sign out (until verification complete)
      await _auth.signOut();

      _showCustomPopup(
        widget.language == 'ar'
            ? 'تم إرسال رسالة التحقق'
            : 'Verification Email Sent',
        widget.language == 'ar'
            ? 'تم إرسال رسالة التحقق إلى بريدك الإلكتروني. يرجى التحقق من صندوق الوارد الخاص بك.'
            : 'Verification email sent. Go to your inbox and verify your email.',
      );

      emailController.clear();
      passwordController.clear();
      nameController.clear();
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? "An error occurred")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Unexpected error: $e")));
    }
  }

  Future<void> _handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showCustomPopup(
        widget.language == 'ar' ? 'خطأ' : 'Error',
        widget.language == 'ar'
            ? 'يرجى إدخال البريد الإلكتروني وكلمة المرور'
            : 'Please enter email and password',
      );
      return;
    }

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!userCredential.user!.emailVerified) {
        await _auth.signOut();
        _showCustomPopup(
          widget.language == 'ar'
              ? 'تحقق من بريدك الإلكتروني'
              : 'Verify Your Email',
          widget.language == 'ar'
              ? 'يرجى التحقق من بريدك الإلكتروني قبل تسجيل الدخول.'
              : 'Please verify your email before logging in.',
        );
        return;
      }

      final uid = userCredential.user!.uid;

      // 1️⃣ fetch the user's document
      final userSnapshot = await FirebaseFirestore.instance
          .collection("aspnetusers")
          .doc(uid)
          .get();

      final fullName = userSnapshot.data()?["FullName"] ?? "";

      // 2️⃣ fetch the user's claims
      final claimSnapshot = await FirebaseFirestore.instance
          .collection("aspnetuserclaims")
          .where("UserId", isEqualTo: uid)
          .limit(1)
          .get();

      String role = "Orator"; // default
      if (claimSnapshot.docs.isNotEmpty) {
        role = claimSnapshot.docs.first.data()["ClaimValue"] ?? "Orator";
      }

      // 3️⃣ Redirect based on role
      if (role == "SuperAdmin") {
        Navigator.pushReplacementNamed(
          context,
          "/admin_dashboard",
          arguments: {"fullName": fullName},
        );
      }
      else if (role == "Visitor") {
        Navigator.pushReplacementNamed(
          context,
          "/",
        );
      } else {
        Navigator.pushReplacementNamed(
          context,
          "/dashboard",
          arguments: {"fullName": fullName},
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? "Login failed")));
    } catch (e) {
      print("General login error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("An unexpected error occurred")));
    }
  }

  void toggleDarkMode() {}

  void toggleLanguage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      didChangeDependencies();
    });
  }

  Color get backgroundColor => widget.darkMode
      ? DesertColors.darkBackground
      : DesertColors.lightBackground;
  Color get cardColor =>
      widget.darkMode ? DesertColors.darkSurface : Colors.white;
  Color get textColor =>
      widget.darkMode ? DesertColors.darkText : DesertColors.lightText;
  Color get subtitleColor =>
      widget.darkMode ? Colors.grey.shade400 : Colors.grey.shade700;
  Color get inputBorderColor =>
      widget.darkMode ? Colors.grey.shade600 : Colors.grey.shade300;
  Color get inputFillColor =>
      widget.darkMode ? Colors.grey.shade800 : Colors.grey.shade100;

  @override
  Widget build(BuildContext context) {
    final darkMode = widget.darkMode;
    final language = widget.language;
    final String? currentRoute = ModalRoute.of(context)?.settings.name;
    return Directionality(
      textDirection: language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: backgroundColor,
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
                                  : [DesertColors.maroon, DesertColors.crimson],
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
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 20,
                  ), // reduce tile width
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/'),
                    child: Container(
                      decoration: BoxDecoration(
                        color: currentRoute == '/'
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
                            language == 'ar' ? 'الرئيسية' : 'Home',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: currentRoute == '/'
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
                  selected: currentRoute == '/majalis',
                  selectedTileColor: darkMode
                      ? DesertColors.primaryGoldDark
                      : DesertColors.maroon,

                  title: Text(
                    language == 'ar'
                        ? 'إصدارات المجلس'
                        : 'Council Publications',
                    style: TextStyle(
                      color: currentRoute == '/majalis'
                          ? (darkMode ? DesertColors.lightText : Colors.white)
                          : (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText),
                    ),
                  ),
                  onTap: () => Navigator.pushNamed(context, '/majalis'),
                ),
                ListTile(
                  selected: currentRoute == '/books',
                  selectedTileColor: darkMode
                      ? DesertColors.primaryGoldDark
                      : DesertColors.maroon,

                  title: Text(
                    language == 'ar' ? 'مكتبة الرؤية' : 'Vision Library',
                    style: TextStyle(
                      color: currentRoute == '/books'
                          ? (darkMode ? DesertColors.lightText : Colors.white)
                          : (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText),
                    ),
                  ),
                  onTap: () => Navigator.pushNamed(context, '/books'),
                ),
                ListTile(
                  selected: currentRoute == '/about',
                  selectedTileColor: darkMode
                      ? DesertColors.primaryGoldDark
                      : DesertColors.maroon,

                  title: Text(
                    language == 'ar' ? 'من نحن' : 'About Us',
                    style: TextStyle(
                      color: currentRoute == '/about'
                          ? (darkMode ? DesertColors.lightText : Colors.white)
                          : (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText),
                    ),
                  ),
                  onTap: () => Navigator.pushNamed(context, '/about'),
                ),
                ListTile(
                  selected: currentRoute == '/publications',
                  selectedTileColor: darkMode
                      ? DesertColors.primaryGoldDark
                      : DesertColors.maroon,

                  title: Text(
                    language == 'ar'
                        ? 'منشورات الراية'
                        : 'Al-Rayah Publications',
                    style: TextStyle(
                      color: currentRoute == '/publications'
                          ? (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText)
                          : (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText),
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
        body: NotificationListener<ScrollNotification>(
          onNotification: (scroll) {
            if (scroll.metrics.pixels > 0 && !_scrolled) {
              setState(() => _scrolled = true);
            } else if (scroll.metrics.pixels <= 0 && _scrolled) {
              setState(() => _scrolled = false);
            }
            return false;
          },
          child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
        ),
        bottomNavigationBar: isMobile ? _buildMobileBottomNav(context) : null,
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [Expanded(child: Center(child: _buildCardWrapper()))],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    final darkMode = widget.darkMode;
    final language = widget.language;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              SizedBox(height: 40),

              // Logo Section
              Container(
                padding: EdgeInsets.all(20),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                ),
              ),

              SizedBox(height: 16),

              // Title
              Text(
                language == 'ar' ? 'الراية' : 'AL-Rayah',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: 2,
                ),
              ),

              SizedBox(height: 8),

              // Subtitle
              Text(
                language == 'ar'
                    ? 'منصة للمعرفة الإسلامية والنشر'
                    : 'A Platform for Islamic Knowledge & Publications',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: subtitleColor,
                  fontWeight: FontWeight.w400,
                ),
              ),

              SizedBox(height: 32),

              // Tab Buttons
              Container(
                decoration: BoxDecoration(
                  color: inputFillColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: inputBorderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => showSignupTab = true),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: showSignupTab
                                ? Color(0xFFE63946)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            language == 'ar' ? 'إنشاء حساب' : 'Sign Up',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: showSignupTab ? Colors.white : textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => showSignupTab = false),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !showSignupTab
                                ? Color(0xFFE63946)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            language == 'ar' ? 'تسجيل الدخول' : 'Login',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: !showSignupTab ? Colors.white : textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32),

              // Form Content
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Color(0xFFFF8F00).withOpacity(darkMode ? 0.2 : 0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: darkMode
                          ? Colors.black.withOpacity(0.2)
                          : Color(0xFFFF8F00).withOpacity(0.05),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: showSignupTab
                    ? _buildMobileSignupForm()
                    : _buildMobileLoginForm(),
              ),

              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileSignupForm() {
    final language = widget.language;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          language == 'ar' ? 'إنشاء حساب جديد' : 'Create New Account',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 6),
        Text(
          language == 'ar'
              ? 'أنشئ إلينا وابدأ رحلتك المعرفية'
              : 'Join us and start your knowledge journey',
          style: TextStyle(
            fontSize: 14,
            color: subtitleColor,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 24),

        _buildTextField(
          controller: nameController,
          label: language == 'ar' ? 'الإسم الكامل' : 'Full Name',
        ),
        SizedBox(height: 16),

        _buildTextField(
          controller: emailController,
          label: language == 'ar' ? 'البريد الإلكتروني' : 'Email Address',
        ),

        SizedBox(height: 16),

        _buildDropdownField(
          label: language == 'ar' ? 'نوع الحساب' : 'Account Type',
          options: language == 'ar'
              ? ['مشرف عام', 'منظم حدث', 'زائر'] // Arabic
              : ['Super Admin', 'Event Organizer', 'Visitor'], // English

          value: selectedAccountType,
          onChanged: (val) {
            setState(() => selectedAccountType = val);
          },
        ),

        SizedBox(height: 16),

        _buildTextField(
          controller: passwordController,
          label: language == 'ar' ? 'كلمة المرور' : 'Password',
          isPassword: true,
        ),

        if (passwordController.text.isNotEmpty) ...[
          SizedBox(height: 12),
          _buildPasswordRequirements(),
        ],

        SizedBox(height: 24),

        Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              colors: [Color(0xFFE63946), Color(0xFFE63946).withOpacity(0.8)],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFE63946).withOpacity(0.3),
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _handleSignup,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              language == 'ar' ? 'إنشاء حساب' : 'Create Account',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        SizedBox(height: 16),

        Text(
          language == 'ar'
              ? 'هل لديك حساب بالفعل؟ تسجيل الدخول'
              : 'Already have an account? Login',
          style: TextStyle(
            color: Color(0xFFE63946),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMobileLoginForm() {
    final language = widget.language;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          language == 'ar' ? 'تسجيل الدخول' : 'Login',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 6),
        Text(
          language == 'ar' ? 'سجل دخولك إلى حسابك' : 'Sign in to your account',
          style: TextStyle(
            fontSize: 14,
            color: subtitleColor,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 24),

        _buildTextField(
          controller: emailController,
          label: language == 'ar' ? 'البريد الإلكتروني' : 'Email Address',
        ),
        SizedBox(height: 16),

        _buildTextField(
          controller: passwordController,
          label: language == 'ar' ? 'كلمة المرور' : 'Password',
          isPassword: true,
        ),
        SizedBox(height: 24),

        Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              colors: [Color(0xFFE63946), Color(0xFFE63946).withOpacity(0.8)],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFE63946).withOpacity(0.3),
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              language == 'ar' ? 'تسجيل الدخول' : 'Login',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        SizedBox(height: 16),

        Text(
          language == 'ar' ? 'إنشاء حساب جديد' : 'Create a new account',
          style: TextStyle(
            color: Color(0xFFE63946),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCardWrapper() {
    final darkMode = widget.darkMode;
    return Container(
      key: ValueKey<bool>(showLoginForm),
      width: 1000,
      height: 650,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: darkMode
                ? Colors.black.withOpacity(0.4)
                : Colors.black.withOpacity(0.15),
            blurRadius: 40,
            offset: Offset(0, 20),
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _panelController,
              builder: (context, child) {
                return Positioned(
                  left:
                      _logoOffset.value.dx * MediaQuery.of(context).size.width,
                  top: 0,
                  bottom: 0,
                  width: 500,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: _buildLogoPanel(),
                  ),
                );
              },
            ),

            AnimatedBuilder(
              animation: _panelController,
              builder: (context, child) {
                return Positioned(
                  right:
                      _formOffset.value.dx * MediaQuery.of(context).size.width,
                  top: 0,
                  bottom: 0,
                  width: 500,
                  child: Transform.scale(
                    scale: _formScale.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: darkMode
                              ? [
                                  Color(0xFFFF8F00).withOpacity(0.08),
                                  Color(0xFFFF8F00).withOpacity(0.12),
                                  Color(0xFFFF8F00).withOpacity(0.06),
                                ]
                              : [
                                  Color(0xFFFF8F00).withOpacity(0.03),
                                  Color(0xFFFF8F00).withOpacity(0.08),
                                  Color(0xFFFF8F00).withOpacity(0.05),
                                ],
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 40,
                        ),
                        child: Center(
                          child: showLoginForm
                              ? _buildLoginCard()
                              : _buildSignupCard(),
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

  Widget _buildSignupCard() {
    final darkMode = widget.darkMode;
    final language = widget.language;
    return Container(
      width: 420,
      padding: EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFFFF8F00).withOpacity(darkMode ? 0.2 : 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: darkMode
                ? Colors.black.withOpacity(0.4)
                : Color(0xFFFF8F00).withOpacity(0.1),
            blurRadius: 30,
            offset: Offset(0, 15),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            language == 'ar' ? 'إنشاء حساب' : 'Sign Up',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6),
          Text(
            language == 'ar' ? 'إنشاء حسابك الجديد' : 'Create Your Account',
            style: TextStyle(
              fontSize: 14,
              color: subtitleColor,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 30),

          _buildTextField(
            controller: nameController,
            label: language == 'ar' ? 'الاسم الكامل' : 'Full Name',
          ),
          SizedBox(height: 18),

          _buildTextField(
            controller: emailController,
            label: language == 'ar' ? 'البريد الإلكتروني' : 'Email Address',
          ),
          SizedBox(height: 18),

          // 🔽 Account Type Dropdown
          _buildDropdownField(
            label: language == 'ar' ? 'نوع الحساب' : 'Account Type',
            options: language == 'ar'
                ? ['مشرف عام', 'منظم حدث', 'زائر'] // Arabic
                : ['Super Admin', 'Event Organizer', 'Visitor'], // English

            value: selectedAccountType,
            onChanged: (val) {
              setState(() => selectedAccountType = val);
            },
          ),
          SizedBox(height: 18),

          _buildTextField(
            controller: passwordController,
            label: language == 'ar' ? 'كلمة المرور' : 'Password',
            isPassword: true,
          ),

          if (passwordController.text.isNotEmpty) ...[
            SizedBox(height: 15),
            _buildPasswordRequirements(),
          ],

          SizedBox(height: 20),

          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: [Color(0xFFE63946), Color(0xFFE63946).withOpacity(0.8)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFE63946).withOpacity(0.3),
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _handleSignup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                language == 'ar' ? 'إنشاء الحساب' : 'Create Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            textDirection: language == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr,
            children: [
              Text(
                language == 'ar'
                    ? 'لديك حساب بالفعل؟ '
                    : 'Already have an account? ',
                style: TextStyle(color: subtitleColor, fontSize: 13),
              ),
              GestureDetector(
                onTap: () async {
                  await _panelController.forward();
                  setState(() => showLoginForm = true);
                  await _panelController.reverse();
                },
                child: Text(
                  language == 'ar' ? 'تسجيل الدخول' : 'Login',
                  style: TextStyle(
                    color: Color(0xFFE63946),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required List<String> options,
    required String? value,
    required void Function(String?) onChanged,
  }) {
    final darkMode = widget.darkMode;
    final language = widget.language;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            textAlign: language == 'ar' ? TextAlign.right : TextAlign.left,
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: inputFillColor,
            border: Border.all(color: inputBorderColor, width: 1),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFFF8F00).withOpacity(darkMode ? 0.1 : 0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: subtitleColor),
              dropdownColor: cardColor,
              style: TextStyle(color: textColor, fontSize: 14),
              onChanged: onChanged,
              items: options.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option, style: TextStyle(color: textColor)),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isPassword = false,
  }) {
    final darkMode = widget.darkMode;
    final language = widget.language;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            textAlign: language == 'ar' ? TextAlign.right : TextAlign.left,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: inputFillColor,
            border: Border.all(
              color:
                  controller == passwordController && controller.text.isNotEmpty
                  ? Color(0xFFFF8F00).withOpacity(0.3)
                  : inputBorderColor,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFFF8F00).withOpacity(darkMode ? 0.1 : 0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            style: TextStyle(color: textColor, fontSize: 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              hintStyle: TextStyle(color: subtitleColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordRequirements() {
    final darkMode = widget.darkMode;
    final language = widget.language;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          language == 'ar' ? 'متطلبات كلمة المرور:' : 'Password Requirements:',
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),

        Container(
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: darkMode ? Color(0xFF6B4F47) : Color(0xFFE8E0D6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(2),
                      bottomLeft: Radius.circular(2),
                    ),
                    color: hasMinLength
                        ? Color(0xFFE63946)
                        : Colors.transparent,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: hasUppercase ? Color(0xFFFF8F00) : Colors.transparent,
                ),
              ),
              Expanded(
                child: Container(
                  color: hasLowercase ? Color(0xFFFF8F00) : Colors.transparent,
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(2),
                      bottomRight: Radius.circular(2),
                    ),
                    color: hasSpecialChar ? Colors.green : Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRequirement(
                    language == 'ar'
                        ? 'حرف كبير واحد على الأقل'
                        : 'At least one uppercase letter',
                    hasUppercase,
                  ),
                  SizedBox(height: 4),
                  _buildRequirement(
                    language == 'ar'
                        ? 'رمز خاص واحد على الأقل'
                        : 'At least one special character',
                    hasSpecialChar,
                  ),
                ],
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRequirement(
                    language == 'ar'
                        ? 'رقم واحد على الأقل'
                        : 'At least one number',
                    hasLowercase,
                  ),
                  SizedBox(height: 4),
                  _buildRequirement(
                    language == 'ar'
                        ? '8 أحرف كحد أدنى'
                        : 'Minimum 8 characters',
                    hasMinLength,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLogoPanel() {
    final darkMode = widget.darkMode;
    final language = widget.language;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: darkMode
              ? [
                  DesertColors.darkSurface,
                  DesertColors.maroon.withOpacity(0.9),
                  DesertColors.darkBackground,
                ]
              : [
                  DesertColors.camelSand,
                  DesertColors.camelSand.withOpacity(0.8),
                  DesertColors.primaryGoldDark.withOpacity(0.7),
                ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(25),
              child: Image.asset(
                'assets/images/logo.png',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 30),
            Text(
              language == 'ar' ? 'الراية' : 'AL-Rayah',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 4,
                fontFamily: language == 'ar'
                    ? 'YourArabicFont'
                    : null, // optional
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(darkMode ? 0.5 : 0.3),
                    offset: Offset(0, 4),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            Text(
              language == 'ar'
                  ? 'منصة للمعرفة الإسلامية والنشر'
                  : 'A Platform for Islamic Knowledge & Publications',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirement(String text, bool isValid) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(top: 1),
          child: Icon(
            isValid ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 12,
            color: isValid ? Colors.green : Color(0xFFE63946),
          ),
        ),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  void _showCustomPopup(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final darkMode = widget.darkMode;
        final language = widget.language;

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: darkMode
                  ? DesertColors.darkSurface
                  : DesertColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: DesertColors.primaryGoldDark.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: darkMode
                      ? Colors.black.withOpacity(0.4)
                      : DesertColors.primaryGoldDark.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.email_outlined,
                  size: 48,
                  color: DesertColors.primaryGoldDark,
                ),
                SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText)
                            .withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: [
                        DesertColors.primaryGoldDark,
                        DesertColors.primaryGoldDark.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      language == 'ar' ? 'حسناً' : 'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoginCard() {
    final darkMode = widget.darkMode;
    final language = widget.language;
    return Container(
      width: 420,
      padding: EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFFFF8F00).withOpacity(darkMode ? 0.2 : 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: darkMode
                ? Colors.black.withOpacity(0.4)
                : Color(0xFFFF8F00).withOpacity(0.1),
            blurRadius: 30,
            offset: Offset(0, 15),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            language == 'ar' ? 'تسجيل الدخول' : 'Login',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6),
          Text(
            language == 'ar'
                ? 'سجل دخولك إلى حسابك'
                : 'Sign in to your account',
            style: TextStyle(
              fontSize: 14,
              color: subtitleColor,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 35),
          _buildTextField(
            controller: emailController,
            label: language == 'ar' ? 'البريد الإلكتروني' : 'Email Address',
          ),
          SizedBox(height: 20),
          _buildTextField(
            controller: passwordController,
            label: language == 'ar' ? 'كلمة المرور' : 'Password',
            isPassword: true,
          ),
          SizedBox(height: 8),
          // Forgot password text link
          Align(
            alignment: language == 'ar'
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PasswordResetScreen(),
                  ),
                );
              },
              child: Text(
                language == 'ar' ? 'نسيت كلمة المرور؟' : 'Forgot Password?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: darkMode
                      ? DesertColors.darkText
                      : DesertColors.lightText,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          SizedBox(height: 30),
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: [Color(0xFFE63946), Color(0xFFE63946).withOpacity(0.8)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFE63946).withOpacity(0.3),
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                language == 'ar' ? 'تسجيل الدخول' : 'Login',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          GestureDetector(
            onTap: () async {
              await _panelController.forward();
              setState(() => showLoginForm = false);
              await _panelController.reverse();
            },
            child: Text(
              language == 'ar' ? 'إنشاء حساب جديد' : 'Create a new account',
              style: TextStyle(
                color: Color(0xFFE63946),
                fontWeight: FontWeight.w600,
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBottomNav(BuildContext context) {
    final darkMode = widget.darkMode;
    final language = widget.language;
    final String? currentRoute = ModalRoute.of(context)?.settings.name;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: darkMode
              ? [
                  DesertColors.darkSurface.withOpacity(0.95),
                  DesertColors.darkBackground,
                ]
              : [
                  DesertColors.lightSurface.withOpacity(0.95),
                  DesertColors.lightBackground,
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: darkMode
                ? DesertColors.maroon.withOpacity(0.3)
                : DesertColors.camelSand.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context,
                icon: Icons.home_rounded,
                label: language == 'ar' ? 'الرئيسية' : 'Home',
                route: '/',
                currentRoute: currentRoute,
              ),
              _buildNavItem(
                context,
                icon: Icons.menu_book_rounded,
                label: language == 'ar' ? 'كتب' : 'Books',
                route: '/books',
                currentRoute: currentRoute,
              ),
              _buildNavItem(
                context,
                icon: Icons.event_rounded,
                label: language == 'ar' ? 'فعاليات' : 'Events',
                route: '/majalis',
                currentRoute: currentRoute,
              ),
              _buildNavItem(
                context,
                icon: Icons.menu_book_rounded, // <-- Book style icon
                label: language == 'ar' ? 'منشورات' : 'Publications',
                route: '/publications',
                currentRoute: currentRoute,
              ),
              _buildNavItem(
                context,
                icon: Icons.contact_mail_rounded,
                label: language == 'ar' ? 'اتصل بنا' : 'Contact',
                route: '/contact',
                currentRoute: currentRoute,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    required String? currentRoute,
  }) {
    final bool isSelected = currentRoute == route;
    final darkMode = widget.darkMode;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pushNamed(context, route);
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: Duration(milliseconds: 300),
              child: Icon(
                icon,
                size: 24,
                color: isSelected
                    ? (darkMode ? DesertColors.camelSand : DesertColors.crimson)
                    : darkMode
                    ? DesertColors.darkText.withOpacity(0.7)
                    : DesertColors.lightText.withOpacity(0.7),
              ),
            ),
            SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: isSelected ? 12 : 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? (darkMode ? DesertColors.camelSand : DesertColors.crimson)
                    : darkMode
                    ? DesertColors.darkText.withOpacity(0.8)
                    : DesertColors.lightText.withOpacity(0.8),
                letterSpacing: 0.3,
              ),
              child: Text(label, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    _panelController.dispose();
    super.dispose();
  }
}
