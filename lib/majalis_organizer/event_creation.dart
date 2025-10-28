import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alraya_app/alrayah.dart';
import 'majalis_navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:alraya_app/notification_service.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async'; // For timeout functionality

class CreateEventPage extends StatefulWidget {
  final bool darkMode;
  final String language;
  final String currentPage;
  final Function(String) onPageChange;
  final VoidCallback onLanguageToggle;
  final VoidCallback onThemeToggle;

  const CreateEventPage({
    Key? key,
    required this.darkMode,
    required this.language,
    required this.currentPage,
    required this.onPageChange,
    required this.onLanguageToggle,
    required this.onThemeToggle,
  }) : super(key: key);

  @override
  _CreateEventPageState createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  String attendanceType = 'In-Person Event';
  String genderRestriction = 'Men and Women';
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController timeController = TextEditingController();
  final TextEditingController venueController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController areaController = TextEditingController();
  final TextEditingController broadcastLinkController = TextEditingController();
  String duration = 'Select duration';
  String advertisementDuration = 'Select advertisement period';

  dynamic _selectedImage; // Can be File (mobile) or Uint8List (web)
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String? _uploadedImageId;
  bool _isWeb = false; // Track if running on web

  Future<void> createEvent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("User not logged in");
      return;
    }

    // ✅ STEP 1: Upload image ONLY if selected and NOT already uploaded
    if (_selectedImage != null && _uploadedImageId == null) {
      _uploadedImageId = await _uploadImageToSupabase(_selectedImage);

      if (_uploadedImageId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload image. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // ✅ STEP 2: Create BoardAds document
    final boardAdsRef = FirebaseFirestore.instance
        .collection("tblboardads")
        .doc();

    final adData = {
      "Id": boardAdsRef.id,
      "Title": titleController.text,
      "Description": descriptionController.text,
      "Location": attendanceType == "In-Person Event"
          ? "${venueController.text}, ${stateController.text}, ${cityController.text}, ${areaController.text}"
          : "",
      "LiveBroadcastLink": attendanceType == "Online Event"
          ? broadcastLinkController.text
          : "",
      "RepeatDay": mapAdvertisementDuration(advertisementDuration),
      "TypeOfAudience": genderRestriction == "Men Only" ? "1" : "2",
      "OwnerId": user.uid,
      "CreatedAt": DateTime.now().toIso8601String(),
      "UpdatedAt": DateTime.now().toIso8601String(),
      "IsDeleted": "False",
      "status": "Pending",
      "BoardAdsImageId": _uploadedImageId ?? "",
    };

    await boardAdsRef.set(adData);

    // ✅ STEP 3: Update EntityId in tbluploadedfiles
    if (_uploadedImageId != null) {
      await FirebaseFirestore.instance
          .collection("tbluploadedfiles")
          .doc(_uploadedImageId)
          .update({
            "EntityId": boardAdsRef.id,
            "UpdatedAt": DateTime.now().toIso8601String(),
          });
    }

    // ✅ STEP 4: Create Board entry
    final boardRef = FirebaseFirestore.instance.collection("tblboards").doc();
    final combinedDateTime = "${dateController.text} ${timeController.text}";

    final boardData = {
      "Id": boardRef.id,
      "BoardAdsId": boardAdsRef.id,
      "OratorId": user.uid,
      "BoardDateTime": combinedDateTime,
      "CreatedAt": DateTime.now().toIso8601String(),
      "UpdatedAt": DateTime.now().toIso8601String(),
      "IsDeleted": "False",
      "status": "Pending",
    };

    await boardRef.set(boardData);

    print("✅ Event Created Successfully");

    await NotificationService.notifyAdminNewEvent(
      titleController.text,
      boardAdsRef.id,
      user.uid,
    );
  }

  int mapAdvertisementDuration(String value) {
    switch (value) {
      case "1 week":
        return 7;
      case "2 weeks":
        return 14;
      case "1 month":
        return 30;
      case "2 months":
        return 60;
      case "3 months":
        return 90;
      default:
        return 0;
    }
  }

  Future<String?> _uploadImageToSupabase(dynamic imageFile) async {
    try {
      setState(() => _isUploading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Generate unique filename
      final uuid = Uuid();
      final fileName = '${uuid.v4()}.jpeg';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final supabaseFileName = '$timestamp-$fileName';

      // Upload to Supabase Storage
      final supabase = Supabase.instance.client;

      // Get bytes - works for both web and mobile
      Uint8List bytes;
      if (_isWeb) {
        bytes = imageFile as Uint8List; // Web: already bytes
      } else {
        bytes = await (imageFile as File)
            .readAsBytes(); // Mobile: read from file
      }

      await supabase.storage
          .from('library-assets')
          .uploadBinary(
            'newfile/Boards/Images/$supabaseFileName',
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      // Get public URL
      final supabaseUrl = supabase.storage
          .from('library-assets')
          .getPublicUrl('newfile/Boards/Images/$supabaseFileName');

      // Create document in tbluploadedfiles
      final uploadedFileRef = FirebaseFirestore.instance
          .collection("tbluploadedfiles")
          .doc();

      final uploadedFileData = {
        "Id": uploadedFileRef.id,
        "FileName": fileName,
        "Path": "\\Files\\Boards\\Images\\$supabaseFileName",
        "SupabaseUrl": supabaseUrl,
        "EntityType": "BoardAds",
        "EntityId": "",
        "CreatedBy": user.uid,
        "CreatedAt": DateTime.now().toIso8601String(),
        "UpdatedAt": DateTime.now().toIso8601String(),
        "IsDeleted": "False",
      };

      await uploadedFileRef.set(uploadedFileData);

      setState(() => _isUploading = false);

      return uploadedFileRef.id;
    } catch (e) {
      print("❌ Image upload error: $e");
      setState(() => _isUploading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload image: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  void _showImageUploadSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final backgroundColor = widget.darkMode
            ? DesertColors.darkSurface
            : DesertColors.lightSurface;
        final textColor = widget.darkMode
            ? DesertColors.darkText
            : DesertColors.lightText;

        return AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DesertColors.primaryGoldDark.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  color: DesertColors.primaryGoldDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Image Uploaded Successfully',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Would you like to extract event details from the image automatically or fill them manually?',
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DesertColors.primaryGoldDark.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: DesertColors.primaryGoldDark.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: DesertColors.primaryGoldDark,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'OCR will automatically read text from your image',
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please fill the form manually'),
                    backgroundColor: DesertColors.primaryGoldDark,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: Icon(
                Icons.edit_outlined,
                size: 18,
                color: textColor.withOpacity(0.7),
              ),
              label: Text(
                'Fill Manually',
                style: TextStyle(
                  color: textColor.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: textColor.withOpacity(0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                // Close this dialog first
                Navigator.of(context).pop();

                // Then call OCR processing
                _performOCRProcessing();
              },
              icon: Icon(Icons.auto_awesome, size: 18, color: Colors.white),
              label: Text(
                'Use OCR',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: DesertColors.primaryGoldDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performOCRProcessing() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _selectedImage == null) return;

    // ✅ Create a GlobalKey to track the loading dialog
    final loadingDialogKey = GlobalKey<NavigatorState>();
    bool isDialogDismissed = false;

    // ✅ Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingDialogContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: CircularProgressIndicator(
              color: DesertColors.primaryGoldDark,
            ),
          ),
        );
      },
    );

    try {
      // Get image bytes
      Uint8List bytes;
      if (_isWeb) {
        bytes = _selectedImage as Uint8List;
      } else {
        bytes = await (_selectedImage as File).readAsBytes();
      }

      final base64Image = base64Encode(bytes);

      // Make OCR request
      final response = await http
          .post(
            Uri.parse('http://localhost:3000/ocr-process'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': user.uid, 'imageBase64': base64Image}),
          )
          .timeout(
            Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'Request timeout - server took too long to respond',
              );
            },
          );

      // ✅ Close loading dialog SAFELY
      if (mounted && !isDialogDismissed) {
        isDialogDismissed = true;
        Navigator.of(context).pop();
      }

      // ✅ Small delay to ensure UI is stable
      await Future.delayed(Duration(milliseconds: 200));

      // ✅ Check mounted again before proceeding
      if (!mounted) return;

      print("📩 OCR response (${response.statusCode}): ${response.body}");

      // Parse response
      Map<String, dynamic> result = {};
      try {
        result = jsonDecode(response.body);
      } catch (_) {
        result = {'error': 'Invalid server response'};
      }

      // ✅ Handle 429 (Rate Limit)
      if (response.statusCode == 429) {
        String errorMessage = result['error'] ?? 'Rate limit exceeded';
        if (mounted) {
          _showRateLimitDialog(errorMessage);
        }
        return;
      }

      // ✅ Handle other errors
      if (response.statusCode != 200) {
        String errorMessage = result['error'] ?? 'OCR processing failed';
        if (mounted) {
          _showErrorDialog(errorMessage);
        }
        return;
      }

      // ✅ Success - fill form fields
      if (mounted) {
        setState(() {
          if (result['title']?.toString().isNotEmpty ?? false) {
            titleController.text = result['title'];
          }
          if (result['description']?.toString().isNotEmpty ?? false) {
            descriptionController.text = result['description'];
          }
          if (result['date']?.toString().isNotEmpty ?? false) {
            dateController.text = result['date'];
          }
          if (result['time']?.toString().isNotEmpty ?? false) {
            timeController.text = result['time'];
          }
          if (result['location']?.toString().isNotEmpty ?? false) {
            venueController.text = result['location'];
          }
          // ✅ NEW: Handle duration
          if (result['duration']?.toString().isNotEmpty ?? false) {
            String durationText = result['duration'].toString().toLowerCase();

            // Map common duration formats
            if (durationText.contains('30') || durationText.contains('half')) {
              duration = '30 minutes';
            } else if (durationText.contains('1.5') ||
                durationText.contains('90')) {
              duration = '1.5 hours';
            } else if (durationText.contains('2')) {
              duration = '2 hours';
            } else if (durationText.contains('3')) {
              duration = '3 hours';
            } else if (durationText.contains('1')) {
              duration = '1 hour';
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ OCR processed successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // ✅ Close loading dialog SAFELY on error
      if (mounted && !isDialogDismissed) {
        isDialogDismissed = true;
        try {
          Navigator.of(context).pop();
        } catch (_) {
          // Dialog already dismissed
        }
      }

      print("❌ OCR request failed: $e");

      // ✅ DON'T show error dialog for widget lifecycle errors
      String errorString = e.toString().toLowerCase();
      bool isWidgetError =
          errorString.contains('deactivated') ||
          errorString.contains('ancestor') ||
          errorString.contains('unsafe');

      if (isWidgetError) {
        // This is just a Flutter lifecycle issue, OCR already succeeded
        print(
          "ℹ️ Ignoring widget lifecycle error - OCR completed successfully",
        );
        return;
      }

      // Only show error dialog for real OCR failures
      await Future.delayed(Duration(milliseconds: 200));

      if (mounted) {
        _showErrorDialog(
          'Server not reachable or OCR failed.\n${e.toString()}',
        );
      }
    }
  }

  late bool darkMode;
  late String language;
  late String currentPage;

  @override
  void initState() {
    super.initState();
    darkMode = widget.darkMode;
    language = widget.language;
    currentPage = widget.currentPage;
    _isWeb = kIsWeb;
  }

  void _showRateLimitDialog(String errorMessage) {
    // ✅ Check if widget is still mounted
    if (!mounted) return;

    final backgroundColor = widget.darkMode
        ? DesertColors.darkSurface
        : DesertColors.lightSurface;
    final textColor = widget.darkMode
        ? DesertColors.darkText
        : DesertColors.lightText;

    // ✅ Determine if it's user or global limit
    bool isUserLimit = errorMessage.toLowerCase().contains('user');
    bool isGlobalLimit = errorMessage.toLowerCase().contains('global');

    String title;
    String message;
    IconData icon;
    Color iconColor;

    if (isUserLimit) {
      title = 'Daily Limit Reached';
      message =
          'You have used your 2 OCR requests for today. Please try again tomorrow or fill the form manually.';
      icon = Icons.person_off_outlined;
      iconColor = Colors.orange;
    } else if (isGlobalLimit) {
      title = 'Service Unavailable';
      message =
          'OCR service has reached its daily limit (15 requests). Please come back tomorrow or fill the form manually.';
      icon = Icons.block;
      iconColor = Colors.red;
    } else {
      title = 'Limit Exceeded';
      message = errorMessage;
      icon = Icons.warning_amber_rounded;
      iconColor = Colors.orange;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DesertColors.primaryGoldDark.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: DesertColors.primaryGoldDark.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: DesertColors.primaryGoldDark,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You can still create your event by filling the form manually',
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: DesertColors.primaryGoldDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Got it',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String errorMessage) {
    // ✅ Check if widget is still mounted
    if (!mounted) return;

    final backgroundColor = widget.darkMode
        ? DesertColors.darkSurface
        : DesertColors.lightSurface;
    final textColor = widget.darkMode
        ? DesertColors.darkText
        : DesertColors.lightText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.error_outline, color: Colors.red, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'OCR Failed',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            errorMessage,
            style: TextStyle(
              color: textColor.withOpacity(0.8),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: DesertColors.primaryGoldDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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

  Future<void> _pickFromGallery() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      if (_isWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImage = bytes;
        });
      } else {
        final file = File(pickedFile.path);
        setState(() {
          _selectedImage = file;
        });
      }

      // ✅ ONLY show dialog, DON'T upload yet
      _showImageUploadSuccessDialog();
    }
  }

  Future<void> _pickFromCamera() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      if (_isWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImage = bytes;
        });
      } else {
        final file = File(pickedFile.path);
        setState(() {
          _selectedImage = file;
        });
      }

      // ✅ ONLY show dialog, DON'T upload yet
      _showImageUploadSuccessDialog();
    }
  }

  void _showEventSubmissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final backgroundColor = widget.darkMode
            ? DesertColors.darkSurface
            : DesertColors.lightSurface;
        final textColor = widget.darkMode
            ? DesertColors.darkText
            : DesertColors.lightText;

        return AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DesertColors.primaryGoldDark.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  color: DesertColors.primaryGoldDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Event Submitted Successfully',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your event has been submitted for review and will be approved by the admin shortly.',
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DesertColors.primaryGoldDark.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: DesertColors.primaryGoldDark.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: DesertColors.primaryGoldDark,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You will be notified once your event is approved',
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Optionally navigate to dashboard or clear form
                // Navigator.pushReplacementNamed(context, '/dashboard');
              },
              style: TextButton.styleFrom(
                foregroundColor: textColor.withOpacity(0.7),
              ),
              child: const Text('OK'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/dashboard');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: DesertColors.primaryGoldDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Go to Dashboard'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateTimeSection(
    bool isMobile,
    Color textColor,
    Color backgroundColor,
    Color surfaceColor,
  ) {
    if (isMobile) {
      return Column(
        children: [
          // Date
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Date *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dateController,
                readOnly: true,
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );

                  if (pickedDate != null) {
                    String formattedDate =
                        "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                    dateController.text = formattedDate;
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Select date',
                  suffixIcon: Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: textColor.withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: textColor.withOpacity(0.2)),
                  ),
                ),
                style: TextStyle(color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Time and Duration Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: timeController,
                      readOnly: true,
                      onTap: () async {
                        TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );

                        if (pickedTime != null) {
                          String formattedTime =
                              "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}";
                          timeController.text = formattedTime;
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Select time',
                        suffixIcon: Icon(
                          Icons.access_time,
                          size: 18,
                          color: textColor.withOpacity(0.5),
                        ),
                        filled: true,
                        fillColor: backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: textColor.withOpacity(0.2),
                          ),
                        ),
                      ),
                      style: TextStyle(color: textColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                flex: 2, // give dropdown more breathing space
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Duration',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true, // 👈 important: let text wrap/ellipsis
                      value: duration,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: textColor.withOpacity(0.2),
                          ),
                        ),
                      ),
                      items:
                          [
                            'Select duration',
                            '30 minutes',
                            '1 hour',
                            '1.5 hours',
                            '2 hours',
                            '3 hours',
                          ].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                overflow: TextOverflow
                                    .ellipsis, // 👈 prevent overflow text
                                style: TextStyle(
                                  color: value == 'Select duration'
                                      ? textColor.withOpacity(0.5)
                                      : textColor,
                                ),
                              ),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          duration = newValue!;
                        });
                      },
                      dropdownColor: surfaceColor,
                      style: TextStyle(color: textColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // Desktop layout (existing)
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: dateController,
                  readOnly: true,
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );

                    if (pickedDate != null) {
                      String formattedDate =
                          "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                      dateController.text = formattedDate;
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'dd/mm/yyyy',
                    suffixIcon: Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: textColor.withOpacity(0.5),
                    ),
                    filled: true,
                    fillColor: backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: textColor.withOpacity(0.2)),
                    ),
                  ),
                  style: TextStyle(color: textColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: timeController,
                  readOnly: true,
                  onTap: () async {
                    TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );

                    if (pickedTime != null) {
                      String formattedTime =
                          "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}";
                      timeController.text = formattedTime;
                    }
                  },
                  decoration: InputDecoration(
                    hintText: '--:--',
                    suffixIcon: Icon(
                      Icons.access_time,
                      size: 18,
                      color: textColor.withOpacity(0.5),
                    ),
                    filled: true,
                    fillColor: backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: textColor.withOpacity(0.2)),
                    ),
                  ),
                  style: TextStyle(color: textColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Duration',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: duration,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: textColor.withOpacity(0.2)),
                    ),
                  ),
                  items:
                      [
                        'Select duration',
                        '30 minutes',
                        '1 hour',
                        '1.5 hours',
                        '2 hours',
                        '3 hours',
                      ].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: TextStyle(
                              color: value == 'Select duration'
                                  ? textColor.withOpacity(0.5)
                                  : textColor,
                            ),
                          ),
                        );
                      }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      duration = newValue!;
                    });
                  },
                  dropdownColor: surfaceColor,
                  style: TextStyle(color: textColor),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  Widget _buildLocationFields(
    bool isMobile,
    Color textColor,
    Color backgroundColor,
  ) {
    if (isMobile) {
      return Column(
        children: [
          // Venue/Location
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Venue/Location *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: venueController,
                decoration: InputDecoration(
                  hintText: 'e.g., Main Sanctuary, Fellowship Hall',
                  hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                  filled: true,
                  fillColor: backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: textColor.withOpacity(0.2)),
                  ),
                ),
                style: TextStyle(color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // State
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'State *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  hintText: 'Select state',
                  filled: true,
                  fillColor: backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: textColor.withOpacity(0.2)),
                  ),
                ),
                items: ['Select state', 'Texas', 'California', 'New York'].map((
                  String value,
                ) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: TextStyle(color: textColor)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  stateController.text = newValue ?? '';
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // City
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'City *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  hintText: 'Select city',
                  filled: true,
                  fillColor: backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: textColor.withOpacity(0.2)),
                  ),
                ),
                items: ['Select city', 'Austin', 'Houston', 'Dallas'].map((
                  String value,
                ) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: TextStyle(color: textColor)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  cityController.text = newValue ?? '';
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Area
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Area',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  hintText: 'Select area',
                  filled: true,
                  fillColor: backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: textColor.withOpacity(0.2)),
                  ),
                ),
                items: ['Select area', 'Downtown', 'Suburb', 'North'].map((
                  String value,
                ) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: TextStyle(color: textColor)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  areaController.text = newValue ?? '';
                },
              ),
            ],
          ),
        ],
      );
    } else {
      // Desktop layout (existing)
      return Column(
        children: [
          // Venue/Location
          Text(
            'Venue/Location *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: venueController,
            decoration: InputDecoration(
              hintText: 'e.g., Main Sanctuary, Fellowship Hall',
              hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
              filled: true,
              fillColor: backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: textColor.withOpacity(0.2)),
              ),
            ),
            style: TextStyle(color: textColor),
          ),
          const SizedBox(height: 16),

          // State, City, Area Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'State *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: stateController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Texas',
                        hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                        filled: true,
                        fillColor: backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: textColor.withOpacity(0.2),
                          ),
                        ),
                      ),
                      style: TextStyle(color: textColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'City *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: cityController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Austin',
                        hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                        filled: true,
                        fillColor: backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: textColor.withOpacity(0.2),
                          ),
                        ),
                      ),
                      style: TextStyle(color: textColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Area',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: areaController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Downtown',
                        hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                        filled: true,
                        fillColor: backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: textColor.withOpacity(0.2),
                          ),
                        ),
                      ),
                      style: TextStyle(color: textColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildAttendanceTypeSection(bool isMobile, Color textColor) {
    if (isMobile) {
      return Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => attendanceType = 'In-Person Event'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: attendanceType == 'In-Person Event'
                      ? DesertColors.primaryGoldDark.withOpacity(0.1)
                      : Colors.transparent,
                  border: Border.all(
                    color: attendanceType == 'In-Person Event'
                        ? DesertColors.primaryGoldDark
                        : textColor.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'In-Person',
                    style: TextStyle(
                      color: attendanceType == 'In-Person Event'
                          ? DesertColors.primaryGoldDark
                          : textColor,
                      fontWeight: attendanceType == 'In-Person Event'
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => attendanceType = 'Online Event'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: attendanceType == 'Online Event'
                      ? DesertColors.primaryGoldDark.withOpacity(0.1)
                      : Colors.transparent,
                  border: Border.all(
                    color: attendanceType == 'Online Event'
                        ? DesertColors.primaryGoldDark
                        : textColor.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Online',
                    style: TextStyle(
                      color: attendanceType == 'Online Event'
                          ? DesertColors.primaryGoldDark
                          : textColor,
                      fontWeight: attendanceType == 'Online Event'
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // Desktop layout (existing)
      return Row(
        children: [
          Radio<String>(
            value: 'In-Person Event',
            groupValue: attendanceType,
            onChanged: (String? value) {
              setState(() {
                attendanceType = value!;
              });
            },
            activeColor: DesertColors.primaryGoldDark,
          ),
          Text(
            'In-Person Event',
            style: TextStyle(fontSize: 14, color: textColor),
          ),
          const SizedBox(width: 24),
          Radio<String>(
            value: 'Online Event',
            groupValue: attendanceType,
            onChanged: (String? value) {
              setState(() {
                attendanceType = value!;
              });
            },
            activeColor: DesertColors.primaryGoldDark,
          ),
          Text(
            'Online Event',
            style: TextStyle(fontSize: 14, color: textColor),
          ),
        ],
      );
    }
  }

  Widget _buildGenderRestrictionSection(bool isMobile, Color textColor) {
    if (isMobile) {
      return Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => genderRestriction = 'Men and Women'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: genderRestriction == 'Men and Women'
                      ? DesertColors.primaryGoldDark.withOpacity(0.1)
                      : Colors.transparent,
                  border: Border.all(
                    color: genderRestriction == 'Men and Women'
                        ? DesertColors.primaryGoldDark
                        : textColor.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Men & Women',
                    style: TextStyle(
                      color: genderRestriction == 'Men and Women'
                          ? DesertColors.primaryGoldDark
                          : textColor,
                      fontWeight: genderRestriction == 'Men and Women'
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => genderRestriction = 'Men Only'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: genderRestriction == 'Men Only'
                      ? DesertColors.primaryGoldDark.withOpacity(0.1)
                      : Colors.transparent,
                  border: Border.all(
                    color: genderRestriction == 'Men Only'
                        ? DesertColors.primaryGoldDark
                        : textColor.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Men Only',
                    style: TextStyle(
                      color: genderRestriction == 'Men Only'
                          ? DesertColors.primaryGoldDark
                          : textColor,
                      fontWeight: genderRestriction == 'Men Only'
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // Desktop layout (existing)
      return Row(
        children: [
          Radio<String>(
            value: 'Men and Women',
            groupValue: genderRestriction,
            onChanged: (String? value) {
              setState(() {
                genderRestriction = value!;
              });
            },
            activeColor: DesertColors.primaryGoldDark,
          ),
          Text(
            'Men and Women',
            style: TextStyle(fontSize: 14, color: textColor),
          ),
          const SizedBox(width: 24),
          Radio<String>(
            value: 'Men Only',
            groupValue: genderRestriction,
            onChanged: (String? value) {
              setState(() {
                genderRestriction = value!;
              });
            },
            activeColor: DesertColors.primaryGoldDark,
          ),
          Text('Men Only', style: TextStyle(fontSize: 14, color: textColor)),
        ],
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.darkMode
        ? DesertColors.darkBackground
        : DesertColors.lightBackground;
    final surfaceColor = widget.darkMode
        ? DesertColors.darkSurface
        : DesertColors.lightSurface;
    final textColor = widget.darkMode
        ? DesertColors.darkText
        : DesertColors.lightText;

    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    final fullName = args?["fullName"] ?? "User";

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final String? currentRoute = ModalRoute.of(context)?.settings.name;

    return Scaffold(
      backgroundColor: backgroundColor,

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
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 20,
                    ), // reduce tile width
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/dashboard'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: currentRoute == '/dashboard'
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
                              language == 'ar' ? 'لوحة التحكم' : 'Dashboard',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: currentRoute == '/dashboard'
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
                    selected: currentRoute == '/profile',
                    selectedTileColor: darkMode
                        ? DesertColors.primaryGoldDark
                        : DesertColors.maroon,

                    title: Text(
                      language == 'ar' ? 'الملف الشخصي' : 'Profile',
                      style: TextStyle(
                        color: currentRoute == '/profile'
                            ? (darkMode ? DesertColors.lightText : Colors.white)
                            : (darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText),
                      ),
                    ),
                    onTap: () => Navigator.pushNamed(context, '/profile'),
                  ),
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
          NavigationBarWidget(
            darkMode: widget.darkMode,
            language: widget.language,
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
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create New Event',
                        style: TextStyle(
                          fontSize: isMobile ? 24 : 28,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set up your ministry event and share it with your community',
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Upload Event Flyer Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: textColor.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.file_upload_outlined,
                                  color: DesertColors.primaryGoldDark,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Upload Event Flyer',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isMobile
                                  ? 'Auto-fill details from your flyer (optional)'
                                  : 'Upload an image of your event flyer to auto-fill the form details',
                              style: TextStyle(
                                fontSize: 12,
                                color: textColor.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Upload Area with Functionality
                            GestureDetector(
                              onTap: () async {
                                if (isMobile) {
                                  // Show bottom sheet for mobile
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (context) => Container(
                                      padding: EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: Icon(Icons.photo_library),
                                            title: Text('Choose from Gallery'),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _pickFromGallery();
                                            },
                                          ),
                                          ListTile(
                                            leading: Icon(Icons.camera_alt),
                                            title: Text('Take Photo'),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _pickFromCamera();
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                } else {
                                  // Desktop: pick from gallery
                                  _pickFromGallery();
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: backgroundColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: textColor.withOpacity(0.2),
                                    width: 1,
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: _isUploading
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              color:
                                                  DesertColors.primaryGoldDark,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Uploading...',
                                              style: TextStyle(
                                                color: textColor.withOpacity(
                                                  0.7,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : _selectedImage != null
                                    ? Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: _isWeb
                                                ? Image.memory(
                                                    _selectedImage as Uint8List,
                                                    width: double.infinity,
                                                    height: 120,
                                                    fit: BoxFit.cover,
                                                  )
                                                : Image.file(
                                                    _selectedImage as File,
                                                    width: double.infinity,
                                                    height: 120,
                                                    fit: BoxFit.cover,
                                                  ),
                                          ),
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: IconButton(
                                              icon: Icon(
                                                Icons.close,
                                                color: Colors.white,
                                              ),
                                              style: IconButton.styleFrom(
                                                backgroundColor: Colors.black54,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _selectedImage = null;
                                                  _uploadedImageId = null;
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.cloud_upload_outlined,
                                            color: textColor.withOpacity(0.5),
                                            size: 32,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            isMobile
                                                ? 'Tap to upload'
                                                : 'Click to upload or drag and drop',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: textColor.withOpacity(0.7),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'PNG, JPG or JPEG (MAX: 10MB)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: textColor.withOpacity(0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            // Mobile-only buttons
                            if (isMobile) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _pickFromGallery,
                                      icon: const Icon(
                                        Icons.photo_library,
                                        size: 18,
                                      ),
                                      label: const Text('Gallery'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: textColor,
                                        side: BorderSide(
                                          color: textColor.withOpacity(0.3),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _pickFromCamera,
                                      icon: const Icon(
                                        Icons.camera_alt,
                                        size: 18,
                                      ),
                                      label: const Text('Camera'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: textColor,
                                        side: BorderSide(
                                          color: textColor.withOpacity(0.3),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: TextButton(
                                  onPressed: () {
                                    // Scroll to next section or do nothing
                                  },
                                  child: Text(
                                    'Skip & Fill Manually',
                                    style: TextStyle(
                                      color: DesertColors.primaryGoldDark,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Event Information Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: textColor.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: DesertColors.primaryGoldDark,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Event Information',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Basic details about your event',
                              style: TextStyle(
                                fontSize: 12,
                                color: textColor.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Event Title
                            Text(
                              'Event Title *',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: titleController,
                              decoration: InputDecoration(
                                hintText: 'e.g., Sunday Morning Service',
                                hintStyle: TextStyle(
                                  color: textColor.withOpacity(0.5),
                                ),
                                filled: true,
                                fillColor: backgroundColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: textColor.withOpacity(0.2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: textColor.withOpacity(0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: DesertColors.primaryGoldDark,
                                  ),
                                ),
                              ),
                              style: TextStyle(color: textColor),
                            ),

                            const SizedBox(height: 16),

                            // Description
                            Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: descriptionController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: 'Describe your event...',
                                hintStyle: TextStyle(
                                  color: textColor.withOpacity(0.5),
                                ),
                                filled: true,
                                fillColor: backgroundColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: textColor.withOpacity(0.2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: textColor.withOpacity(0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: DesertColors.primaryGoldDark,
                                  ),
                                ),
                              ),
                              style: TextStyle(color: textColor),
                            ),

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Date & Duration Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: textColor.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date & Duration',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 20),

                            _buildDateTimeSection(
                              isMobile,
                              textColor,
                              backgroundColor,
                              surfaceColor,
                            ),

                            const SizedBox(height: 16),

                            // Advertisement Duration
                            Text(
                              'Advertisement Duration',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: advertisementDuration,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: backgroundColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: textColor.withOpacity(0.2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: textColor.withOpacity(0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: DesertColors.primaryGoldDark,
                                  ),
                                ),
                              ),
                              items:
                                  [
                                    'Select advertisement period',
                                    '1 week',
                                    '2 weeks',
                                    '1 month',
                                    '2 months',
                                    '3 months',
                                  ].map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        value,
                                        style: TextStyle(
                                          color:
                                              value ==
                                                  'Select advertisement period'
                                              ? textColor.withOpacity(0.5)
                                              : textColor,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  advertisementDuration = newValue!;
                                });
                              },
                              dropdownColor: surfaceColor,
                              style: TextStyle(color: textColor),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Attendance Type Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: textColor.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Attendance Type',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'How will people attend your event?',
                              style: TextStyle(
                                fontSize: 12,
                                color: textColor.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildAttendanceTypeSection(isMobile, textColor),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Conditional Section: Location Details or Broadcast Information
                      if (attendanceType == 'In-Person Event') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: textColor.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Location Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Where will your event take place?',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textColor.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 20),

                              _buildLocationFields(
                                isMobile,
                                textColor,
                                backgroundColor,
                              ),

                              const SizedBox(height: 20),

                              // Gender Restriction
                              Text(
                                'Gender Restriction',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 12),

                              _buildGenderRestrictionSection(
                                isMobile,
                                textColor,
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: textColor.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Broadcast Information',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'How will people join your online event?',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textColor.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Broadcast Link
                              Text(
                                'Broadcast Link *',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: broadcastLinkController,
                                decoration: InputDecoration(
                                  hintText: 'e.g., https://zoom.us/j/123456789',
                                  hintStyle: TextStyle(
                                    color: textColor.withOpacity(0.5),
                                  ),
                                  filled: true,
                                  fillColor: backgroundColor,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: textColor.withOpacity(0.2),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: textColor.withOpacity(0.2),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: DesertColors.primaryGoldDark,
                                    ),
                                  ),
                                ),
                                style: TextStyle(color: textColor),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Provide the link where attendees can join your online event (Zoom, YouTube Live, etc.)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textColor.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Action Buttons
                      isMobile
                          ? Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await createEvent();
                                      _showEventSubmissionDialog();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          DesertColors.primaryGoldDark,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Create Event',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {},
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: textColor.withOpacity(0.7),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton(
                                  onPressed: () async {
                                    await createEvent();
                                    _showEventSubmissionDialog();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        DesertColors.primaryGoldDark,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Create Event',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
