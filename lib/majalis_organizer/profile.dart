import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:alraya_app/alrayah.dart';
import 'majalis_navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  final bool darkMode;
  final String language;
  final Function(bool) onThemeToggle;
  final Function() onLanguageToggle;

  ProfilePage({
    required this.darkMode,
    required this.language,
    required this.onThemeToggle,
    required this.onLanguageToggle,
  });

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isEditing = false;
  bool darkMode = false;
  File? selectedImage;
  final ImagePicker _picker = ImagePicker();
  String currentPage = "Profile";
  String language = 'ar';

  // Controllers for text fields
  late TextEditingController fullNameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController organizationController;
  late TextEditingController locationController;
  late TextEditingController bioController;

  Map<String, Map<String, String>> translations = {
    'profile': {'ar': 'الملف الشخصي', 'en': 'Profile'},
    'manage_info': {
      'ar': 'إدارة معلوماتك الشخصية وتفاصيل الوزارة',
      'en': 'Manage your personal information and ministry details',
    },
    'edit_profile': {'ar': 'تعديل الملف الشخصي', 'en': 'Edit Profile'},
    'save_changes': {'ar': 'حفظ التغييرات', 'en': 'Save Changes'},
    'cancel': {'ar': 'إلغاء', 'en': 'Cancel'},
    'profile_picture': {'ar': 'صورة الملف الشخصي', 'en': 'Profile Picture'},
    'upload_manage': {
      'ar': 'رفع وإدارة صورة ملفك الشخصي',
      'en': 'Upload and manage your profile image',
    },
    'personal_info': {'ar': 'المعلومات الشخصية', 'en': 'Personal Information'},
    'basic_contact': {
      'ar': 'معلومات الاتصال الأساسية والوزارة',
      'en': 'Your basic contact and ministry information',
    },
    'full_name': {'ar': 'الاسم الكامل', 'en': 'Full Name'},
    'email_address': {'ar': 'عنوان البريد الإلكتروني', 'en': 'Email Address'},
    'phone_number': {'ar': 'رقم الهاتف', 'en': 'Phone Number'},
    'organization': {'ar': 'المنظمة', 'en': 'Organization'},
    'location': {'ar': 'الموقع', 'en': 'Location'},
    'bio': {'ar': 'السيرة الذاتية', 'en': 'Bio'},
    'rev_jonathan': {'ar': 'القس جوناثان ميلر', 'en': 'Rev. Jonathan Miller'},
    'grace_church': {
      'ar': 'كنيسة النعمة المجتمعية',
      'en': 'Grace Community Church',
    },
    'phone_sample': {'ar': '+1 (555) 123-4567', 'en': '+1 (555) 123-4567'},
    'email_sample': {
      'ar': 'jonathan.miller@email.com',
      'en': 'jonathan.miller@email.com',
    },
    'location_sample': {'ar': 'أوستن، تكساس', 'en': 'Austin, Texas'},
    'bio_sample': {
      'ar':
          'شغوف بنشر كلمة الله وبناء المجتمع من خلال الإيمان. أخدم في كنيسة النعمة المجتمعية لأكثر من 10 سنوات.',
      'en':
          'Passionate about spreading God\'s word and building community through faith. Serving at Grace Community Church for over 10 years.',
    },
  };

  String getText(String key) {
    return translations[key]?[language] ?? key;
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
  void initState() {
    super.initState();

    fullNameController = TextEditingController();
    emailController = TextEditingController();
    phoneController = TextEditingController();
    organizationController = TextEditingController();
    locationController = TextEditingController();
    bioController = TextEditingController();

    // 🔹 load Firestore data immediately
    _loadUserData();
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    organizationController.dispose();
    locationController.dispose();
    bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        selectedImage = File(image.path);
      });
    }
  }

  void _toggleEdit() async {
    if (isEditing) {
      // Cancel → reload Firestore data
      await _loadUserData();
    }
    setState(() {
      isEditing = !isEditing;
      selectedImage = null;
    });
  }

  Future<void> _saveChanges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final phoneNumber = phoneController.text.trim();
    final bio = bioController.text.trim();

    await FirebaseFirestore.instance
        .collection("aspnetusers")
        .doc(user.uid)
        .update({
          "FullName": fullNameController.text.trim(),
          "Email": emailController.text.trim(),
          "PhoneNumber": phoneNumber.isEmpty ? null : phoneNumber,
          "PhoneNumberConfirmed": phoneNumber.isNotEmpty,
          "Bio": bio.isEmpty ? null : bio,
        });

    setState(() {
      isEditing = false;
    });

    HapticFeedback.lightImpact();
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

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection("aspnetusers")
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;

      setState(() {
        fullNameController.text = data["FullName"] ?? "Name Not Added";
        emailController.text = data["Email"] ?? "Email Not Added";
        phoneController.text = data["PhoneNumber"] ?? "Phone Number Not Added";
        bioController.text = data["Bio"] ?? "Bio Not Added";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? currentRoute = ModalRoute.of(context)?.settings.name;
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: darkMode
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
                    selected: currentRoute == '/dashboard',
                    selectedTileColor: darkMode
                        ? DesertColors.primaryGoldDark
                        : DesertColors.maroon,
                    title: Text(
                      language == 'ar' ? 'لوحة التحكم' : 'Dashboard',
                      style: TextStyle(
                        color: currentRoute == '/dashboard'
                            ? (darkMode ? DesertColors.lightText : Colors.white)
                            : (darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText),
                      ),
                    ),
                    onTap: () => Navigator.pushNamed(context, '/dashboard'),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 20,
                    ), // reduce tile width
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/profile'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: currentRoute == '/profile'
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
                              language == 'ar' ? 'الملف الشخصي' : 'Profile',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: currentRoute == '/profile'
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

                  // ✅ Reports Tile
                  ListTile(
                    selected: currentRoute == '/reports',
                    selectedTileColor: darkMode
                        ? DesertColors.primaryGoldDark
                        : DesertColors.maroon,
                    title: Text(
                      language == 'ar' ? 'التقارير' : 'Reports',
                      style: TextStyle(
                        color: currentRoute == '/reports'
                            ? (darkMode ? DesertColors.lightText : Colors.white)
                            : (darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText),
                      ),
                    ),
                    onTap: () => Navigator.pushNamed(context, '/reports'),
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

      body: Column(
        children: [
          // ✅ Fixed Navigation Bar at top
          Directionality(
            textDirection: language == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: FutureBuilder<String>(
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
                  onLanguageToggle: toggleLanguage,
                  onThemeToggle: toggleDarkMode,
                  fullName: fullName,
                  openDrawer: () => Scaffold.of(context).openEndDrawer(),
                );
              },
            ),
          ),
          // ✅ Scrollable content below navbar
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildMobileBottomNav(context) : null,
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  getText('profile'),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  getText('manage_info'),
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        (darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText)
                            .withOpacity(0.7),
                  ),
                ),
              ],
            ),
            _buildActionButtons(),
          ],
        ),
        SizedBox(height: 32),

        // Content
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 1, child: _buildProfilePictureSection()),
            SizedBox(width: 24),
            Expanded(flex: 2, child: _buildPersonalInfoSection()),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Profile Picture Section
        _buildMobileProfileSection(),
        SizedBox(height: 24),

        // Personal Information Section
        _buildMobilePersonalInfoSection(),
        SizedBox(height: 24),

        // Edit Profile Button
        _buildMobileActionButton(),
      ],
    );
  }

  Widget _buildMobileProfileSection() {
    return Column(
      children: [
        // Profile Image
        Stack(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    DesertColors.primaryGoldDark,
                    DesertColors.camelSand,
                  ],
                ),
              ),
              child: selectedImage != null
                  ? ClipOval(
                      child: Image.file(
                        selectedImage!,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(Icons.person, size: 50, color: Colors.white),
            ),
            if (isEditing)
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: DesertColors.primaryGoldDark,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 16),

        // Name
        Text(
          fullNameController.text.isEmpty
              ? "Name Not Added"
              : fullNameController.text,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: darkMode ? DesertColors.darkText : DesertColors.lightText,
          ),
        ),
        SizedBox(height: 4),

        // Subtitle
        Text(
          "Manage your profile details",
          style: TextStyle(
            fontSize: 14,
            color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
                .withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildMobilePersonalInfoSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : DesertColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: darkMode
              ? DesertColors.camelSand.withOpacity(0.2)
              : DesertColors.maroon.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            getText('personal_info'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "Your basic contact information.",
            style: TextStyle(
              fontSize: 14,
              color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
                  .withOpacity(0.6),
            ),
          ),
          SizedBox(height: 24),

          // Form Fields
          _buildFormField(getText('full_name'), fullNameController),
          SizedBox(height: 16),
          _buildFormField(getText('email_address'), emailController),
          SizedBox(height: 16),
          _buildFormField(getText('phone_number'), phoneController),
          SizedBox(height: 16),
          _buildFormField(getText('bio'), bioController, isMultiline: true),
        ],
      ),
    );
  }

  Widget _buildMobileActionButton() {
    if (isEditing) {
      return Column(
        children: [
          // Save Changes Button
          GestureDetector(
            onTap: _saveChanges,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    DesertColors.primaryGoldDark,
                    DesertColors.camelSand,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: DesertColors.primaryGoldDark.withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    getText('save_changes'),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12),
          // Cancel Button
          GestureDetector(
            onTap: _toggleEdit,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: darkMode
                      ? DesertColors.darkText.withOpacity(0.3)
                      : DesertColors.lightText.withOpacity(0.3),
                ),
              ),
              child: Text(
                getText('cancel'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: darkMode
                      ? DesertColors.darkText
                      : DesertColors.lightText,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return GestureDetector(
        onTap: _toggleEdit,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [DesertColors.primaryGoldDark, DesertColors.camelSand],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: DesertColors.primaryGoldDark.withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            getText('edit_profile'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildActionButtons() {
    if (isEditing) {
      return Row(
        children: [
          // Cancel Button
          GestureDetector(
            onTap: _toggleEdit,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: darkMode
                      ? DesertColors.darkText.withOpacity(0.3)
                      : DesertColors.lightText.withOpacity(0.3),
                ),
              ),
              child: Text(
                getText('cancel'),
                style: TextStyle(
                  color: darkMode
                      ? DesertColors.darkText
                      : DesertColors.lightText,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          // Save Changes Button
          GestureDetector(
            onTap: _saveChanges,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    DesertColors.primaryGoldDark,
                    DesertColors.camelSand,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: DesertColors.primaryGoldDark.withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.save, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    getText('save_changes'),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      return GestureDetector(
        onTap: _toggleEdit,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [DesertColors.primaryGoldDark, DesertColors.camelSand],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: DesertColors.primaryGoldDark.withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            getText('edit_profile'),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildProfilePictureSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : DesertColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: darkMode
              ? DesertColors.camelSand.withOpacity(0.2)
              : DesertColors.maroon.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Text(
            getText('profile_picture'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
          ),
          SizedBox(height: 8),
          Text(
            getText('upload_manage'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
                  .withOpacity(0.7),
            ),
          ),
          SizedBox(height: 32),

          // Profile Image
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      DesertColors.primaryGoldDark,
                      DesertColors.camelSand,
                    ],
                  ),
                ),
                child: selectedImage != null
                    ? ClipOval(
                        child: Image.file(
                          selectedImage!,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(Icons.person, size: 60, color: Colors.white),
              ),
              if (isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: DesertColors.primaryGoldDark,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(height: 24),

          Text(
            fullNameController.text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
          ),
          SizedBox(height: 4),
          Text(
            organizationController.text,
            style: TextStyle(
              fontSize: 14,
              color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
                  .withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : DesertColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: darkMode
              ? DesertColors.camelSand.withOpacity(0.2)
              : DesertColors.maroon.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            getText('personal_info'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
          ),
          SizedBox(height: 8),
          Text(
            getText('basic_contact'),
            style: TextStyle(
              fontSize: 14,
              color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
                  .withOpacity(0.7),
            ),
          ),
          SizedBox(height: 32),

          // Form Fields
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  getText('full_name'),
                  fullNameController,
                ),
              ),
              SizedBox(width: 24),
              Expanded(
                child: _buildFormField(
                  getText('email_address'),
                  emailController,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  getText('phone_number'),
                  phoneController,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),

          _buildFormField(getText('bio'), bioController, isMultiline: true),
        ],
      ),
    );
  }

  Widget _buildFormField(
    String label,
    TextEditingController controller, {
    bool isMultiline = false,
    String placeholder = "",
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: darkMode ? DesertColors.darkText : DesertColors.lightText,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: darkMode
                ? DesertColors.darkBackground.withOpacity(0.5)
                : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: darkMode
                  ? DesertColors.camelSand.withOpacity(0.2)
                  : DesertColors.maroon.withOpacity(0.1),
            ),
          ),
          child: TextField(
            controller: controller,
            enabled: isEditing,
            maxLines: isMultiline ? 4 : 1,
            style: TextStyle(
              fontSize: 14,
              color: isEditing
                  ? (darkMode ? DesertColors.darkText : DesertColors.lightText)
                  : (darkMode ? DesertColors.darkText : DesertColors.lightText)
                        .withOpacity(0.6),
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
              hintText: placeholder,
              hintStyle: TextStyle(
                color:
                    (darkMode ? DesertColors.darkText : DesertColors.lightText)
                        .withOpacity(0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBottomNav(BuildContext context) {
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
                icon: Icons.dashboard_outlined,
                label: language == "ar" ? "لوحة القيادة" : "Dashboard",
                route: '/dashboard',
                currentRoute: currentRoute,
              ),
              _buildNavItem(
                context,
                icon: Icons.person_outline,
                label: language == "ar" ? "الملف الشخصي" : "Profile",
                route: '/profile',
                currentRoute: currentRoute,
              ),
              _buildNavItem(
                context,
                icon: Icons.analytics_outlined,
                label: language == "ar" ? "التقارير" : "Reports",
                route: '/reports',
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
}
