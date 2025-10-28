import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../alrayah.dart';
import 'majalis_section.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'majalis_details.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MajalisHeroSection extends StatefulWidget {
  final bool darkMode;
  final String language;
  final bool scrolled;
  final String searchTerm;
  final String filterType;
  final int displayedBooks;

  const MajalisHeroSection({
    super.key,
    required this.darkMode,
    required this.language,
    required this.scrolled,
    required this.searchTerm,
    required this.filterType,
    required this.displayedBooks,
  });
  @override
  _MajalisHeroSectionState createState() => _MajalisHeroSectionState();
}

class _MajalisHeroSectionState extends State<MajalisHeroSection>
    with SingleTickerProviderStateMixin {
  bool darkMode = false;
  String language = 'ar'; // Default to Arabic
  bool scrolled = false;
  late ScrollController _scrollController;
  late AnimationController _animationController;
  bool _loading = false;

  int visiblePreachers = 5;
  int visibleLocations = 5;

  bool get isMobile => MediaQuery.of(context).size.width < 768;

  // Filter states
  String? selectedEventType;
  String? selectedDate;
  String? selectedLocation;
  String? selectedPreacher;

  Timer? _timer;

  final Map<String, List<String>> eventTypes = {
    'en': [
      'All Events',
      'Upcoming Events',
      'Religious Lectures',
      'Quran Recitation',
      'Islamic Workshops',
      'Community Gatherings',
    ],
    'ar': [
      'جميع الفعاليات',
      'الفعاليات القادمة',
      'المحاضرات الدينية',
      'تلاوة القرآن',
      'ورش العمل الإسلامية',
      'التجمعات المجتمعية',
    ],
  };

  final Map<String, List<String>> dates = {
    'en': ['Any Date', 'This Week', 'This Month', 'Next Month', 'Custom Date'],
    'ar': [
      'أي تاريخ',
      'هذا الأسبوع',
      'هذا الشهر',
      'الشهر القادم',
      'تاريخ مخصص',
    ],
  };

  final Map<String, List<String>> locations = {};

  final Map<String, List<String>> preachers = {};

  List<Event> allEvents = [];
  List<Event> filteredEvents = [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _scrollController.addListener(() {
      if (_scrollController.offset > 50 && !scrolled) {
        setState(() => scrolled = true);
      } else if (_scrollController.offset <= 50 && scrolled) {
        setState(() => scrolled = false);
      }
    });

    _fetchEvents(); // <-- Firestore fetch
    _animationController.forward();

    _timer = Timer.periodic(Duration(seconds: 30), (_) {
      setState(() {}); // This will rebuild UI every 30 sec and re-check times
    });

    initializeDateFormatting();
  }

  void _applyFilters() {
    setState(() {
      filteredEvents = allEvents.where((event) {
        // --- Type filter ---
        bool typeMatch =
            selectedEventType == null ||
            selectedEventType == eventTypes[widget.language]![0];

        // --- Date filter ---
        bool dateMatch = true;
        if (selectedDate != null &&
            selectedDate != dates[widget.language]![0]) {
          DateTime now = DateTime.now();
          DateTime start;
          DateTime end;

          if (selectedDate ==
              (widget.language == 'ar' ? 'هذا الأسبوع' : 'This Week')) {
            int currentWeekday = now.weekday;
            start = DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(Duration(days: currentWeekday - 1));
            end = start.add(Duration(days: 6));
          } else if (selectedDate ==
              (widget.language == 'ar' ? 'هذا الشهر' : 'This Month')) {
            start = DateTime(now.year, now.month, 1);
            end = DateTime(now.year, now.month + 1, 0);
          } else if (selectedDate ==
              (widget.language == 'ar' ? 'الشهر القادم' : 'Next Month')) {
            start = DateTime(now.year, now.month + 1, 1);
            end = DateTime(now.year, now.month + 2, 0);
          } else {
            start = DateTime(1900);
            end = DateTime(3000);
          }

          dateMatch =
              !event.startTime.isBefore(start) && !event.startTime.isAfter(end);
        }

        // --- Location filter ---
        bool locationMatch =
            selectedLocation == null ||
            selectedLocation == locations[widget.language]![0] ||
            event.location == selectedLocation;

        // --- Preacher filter ---
        bool preacherMatch =
            selectedPreacher == null ||
            selectedPreacher == preachers[widget.language]![0] ||
            event.preacherName == selectedPreacher;

        return typeMatch && dateMatch && locationMatch && preacherMatch;
      }).toList();

      // 🔥 NEW: Sort events - Live events first, then by start time
      _sortEventsByLiveStatus();
    });
  }

  void _sortEventsByLiveStatus() {
    DateTime now = DateTime.now();

    filteredEvents.sort((a, b) {
      // Check if event A is live
      bool aIsLive = _isEventLive(a, now);

      // Check if event B is live
      bool bIsLive = _isEventLive(b, now);

      // If A is live and B is not, A comes first
      if (aIsLive && !bIsLive) return -1;

      // If B is live and A is not, B comes first
      if (!aIsLive && bIsLive) return 1;

      // If both are live or both are not live, sort by start time (earlier first)
      return a.startTime.compareTo(b.startTime);
    });
  }

  bool _isEventLive(Event event, DateTime now) {
    if (event.liveLink.isEmpty ||
        event.liveLink == 'No Link' ||
        event.liveLink.toLowerCase() == 'null') {
      return false;
    }

    DateTime eventEnd = event.startTime.add(Duration(hours: 1));
    return now.isAfter(event.startTime) && now.isBefore(eventEnd);
  }

Future<void> _fetchEvents() async {
  setState(() => _loading = true);

  try {
    // 🔥 Step 1: Try to load from cache first
    final cachedEvents = await _loadFromCache();
    if (cachedEvents != null && cachedEvents.isNotEmpty) {
      print('✅ Loaded ${cachedEvents.length} events from cache');
      setState(() {
        allEvents = cachedEvents;
        filteredEvents = cachedEvents;
        _extractUniqueFilters();
        _sortEventsByLiveStatus();
        _loading = false;
      });

      // 🔥 Optionally: Fetch fresh data in background and update cache
      _fetchAndCacheInBackground();
      return;
    }

    // 🔥 Step 2: If no cache, fetch from Firestore
    print('⏳ No cache found, fetching from Firestore...');
    await _fetchFromFirestoreAndCache();
  } catch (e) {
    print("Error fetching events: $e");
    setState(() => _loading = false);
  }
}

/// Load events from SharedPreferences cache
Future<List<Event>?> _loadFromCache() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'events_cache';
    final cacheTimeKey = 'events_cache_time';

    final cachedJson = prefs.getString(cacheKey);
    final cacheTimeStr = prefs.getString(cacheTimeKey);

    if (cachedJson == null || cacheTimeStr == null) {
      return null; // No cache
    }

    // Check if cache is expired (24 hours)
    final cacheTime = DateTime.parse(cacheTimeStr);
    final now = DateTime.now();
    if (now.difference(cacheTime).inHours >= 24) {
      print('⏰ Cache expired, will fetch fresh data');
      return null;
    }

    // Decode cached events
    final List<dynamic> jsonList = json.decode(cachedJson);
    final cachedEvents = jsonList
        .map((json) => CachedEvent.fromJson(json).toEvent())
        .toList();

    return cachedEvents;
  } catch (e) {
    print('❌ Error loading cache: $e');
    return null;
  }
}

/// Fetch from Firestore and save to cache
/// Fetch from Firestore and save to cache - OPTIMIZED VERSION
Future<void> _fetchFromFirestoreAndCache() async {
  try {
    print('🚀 Starting optimized fetch...');
    
    // Step 1: Get all Orators
    final oratorClaims = await FirebaseFirestore.instance
        .collection('aspnetuserclaims')
        .where('ClaimValue', isEqualTo: 'Orator')
        .get();

    final oratorIds = oratorClaims.docs.map((doc) => doc['UserId']).toList();
    print('✅ Found ${oratorIds.length} orators');

    // Step 2: Get all Users who are Orators (batch because of 30 limit)
    Map<String, dynamic> usersMap = {};
    for (int i = 0; i < oratorIds.length; i += 30) {
      final batch = oratorIds.sublist(
        i,
        i + 30 > oratorIds.length ? oratorIds.length : i + 30,
      );

      final usersSnap = await FirebaseFirestore.instance
          .collection('aspnetusers')
          .where('Id', whereIn: batch)
          .get();

      for (var doc in usersSnap.docs) {
        usersMap[doc['Id']] = doc.data();
      }
    }
    print('✅ Loaded ${usersMap.length} users');

    // Step 3: Get Ads that are not deleted
    final adsSnap = await FirebaseFirestore.instance
        .collection('tblboardads')
        .where('IsDeleted', isEqualTo: 'False')
        .get();

    final adsMap = {for (var doc in adsSnap.docs) doc['Id']: doc.data()};
    print('✅ Loaded ${adsMap.length} ads');

    // Step 4: Get Boards linked to Ads
    final boardsSnap = await FirebaseFirestore.instance
        .collection('tblboards')
        .where('IsDeleted', isEqualTo: 'False')
        .get();
    print('✅ Loaded ${boardsSnap.docs.length} boards');

    // 🔥 Step 5: Fetch ALL uploaded files for BoardAds ONCE (not in loop!)
    final uploadedFilesSnap = await FirebaseFirestore.instance
        .collection('tbluploadedfiles')
        .where('EntityType', isEqualTo: 'BoardAds')
        .get();

    // Create a map: imageId -> uploadedFileData for fast lookup
    final Map<String, Map<String, dynamic>> uploadedFilesMap = {
      for (var doc in uploadedFilesSnap.docs)
        doc['Id'].toString(): doc.data()
    };
    print('✅ Loaded ${uploadedFilesMap.length} uploaded files');

    // Step 6: Build events by matching data in memory
    List<Event> events = [];
    List<CachedEvent> cachedEvents = [];

    for (var doc in boardsSnap.docs) {
      final board = doc.data();
      final ad = adsMap[board['BoardAdsId']];
      final user = usersMap[board['OratorId']];

      if (ad != null && user != null) {
        // 🔥 Fast lookup - no Firestore query!
        final boardAdsImageId = ad['BoardAdsImageId']?.toString();
        final uploadedData = boardAdsImageId != null 
            ? uploadedFilesMap[boardAdsImageId] 
            : null;

        // Create Event
        final event = Event.fromFirestore(
          ad,
          board,
          user,
          uploadedFilesData: uploadedData,
        );
        events.add(event);

        // Create CachedEvent with imageUrl
        String? imageUrl;
        if (uploadedData != null &&
            uploadedData['SupabaseUrl'] != null &&
            uploadedData['SupabaseUrl'].toString().isNotEmpty) {
          imageUrl = uploadedData['SupabaseUrl'].toString();
        }

        cachedEvents.add(CachedEvent(
          id: event.id,
          title: event.title,
          startTime: event.startTime.toIso8601String(),
          preacherName: event.preacherName,
          location: event.location,
          description: event.description,
          liveLink: event.liveLink,
          imageUrl: imageUrl,
        ));
      }
    }

    // 🔥 Save to cache
    await _saveToCache(cachedEvents);

    setState(() {
      allEvents = events;
      filteredEvents = events;
      _extractUniqueFilters();
      _sortEventsByLiveStatus();
      _loading = false;
    });

    print('✅ Fetched and cached ${events.length} events');
  } catch (e) {
    print("❌ Error fetching from Firestore: $e");
    setState(() => _loading = false);
  }
}

/// Save events to SharedPreferences cache
Future<void> _saveToCache(List<CachedEvent> events) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'events_cache';
    final cacheTimeKey = 'events_cache_time';

    // Serialize events to JSON
    final jsonList = events.map((e) => e.toJson()).toList();
    final jsonString = json.encode(jsonList);

    // Save to cache with timestamp
    await prefs.setString(cacheKey, jsonString);
    await prefs.setString(cacheTimeKey, DateTime.now().toIso8601String());

    print('💾 Cached ${events.length} events');
  } catch (e) {
    print('❌ Error saving cache: $e');
  }
}

/// Fetch fresh data in background and update cache (optional)
Future<void> _fetchAndCacheInBackground() async {
  // This runs silently in the background without blocking UI
  try {
    await _fetchFromFirestoreAndCache();
  } catch (e) {
    print('Background fetch error: $e');
  }
}

/// Extract unique preachers and locations from events
void _extractUniqueFilters() {
  final uniquePreachers = allEvents.map((e) => e.preacherName).toSet().toList();
  final uniqueLocations = allEvents.map((e) => e.location).toSet().toList();

  preachers['en'] = ['All Preachers', ...uniquePreachers];
  preachers['ar'] = ['جميع الخطباء', ...uniquePreachers];

  locations['en'] = ['All Locations', ...uniqueLocations];
  locations['ar'] = ['جميع المواقع', ...uniqueLocations];
}

  @override
  Widget build(BuildContext context) {
    final darkMode = widget.darkMode;
    final language = widget.language;

    return Theme(
      data: ThemeData(
        scaffoldBackgroundColor: darkMode
            ? DesertColors.darkBackground
            : DesertColors.lightBackground,
        primarySwatch: Colors.orange,
      ),
      child: Scaffold(
        body: _loading
            ? Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Directionality(
                        textDirection: language == 'ar'
                            ? ui.TextDirection.rtl
                            : ui.TextDirection.ltr,
                        child: Column(
                          children: [
                            _buildHeroSection(),
                            _buildFiltersSection(),
                            _buildBrowseEventsHeader(),
                            _buildEventsContainer(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final darkMode = widget.darkMode;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 40 : 60,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: darkMode
              ? [DesertColors.darkSurface, DesertColors.maroon.withOpacity(0.8)]
              : [Color(0xFFFFF8E1), Color(0xFFFFF3C4)],
        ),
      ),

      child: Column(
        children: [
          // Mobile: Wrap content in container, Desktop: Keep as is
          if (isMobile)
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: darkMode
                    ? DesertColors.darkSurface.withOpacity(0.8)
                    : DesertColors.lightSurface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: darkMode
                      ? DesertColors.camelSand.withOpacity(0.2)
                      : DesertColors.maroon.withOpacity(0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (darkMode ? Colors.black : Colors.grey).withOpacity(
                      0.1,
                    ),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: _buildHeroContent(),
            )
          else
            _buildHeroContent(),
        ],
      ),
    );
  }

  Widget _buildHeroContent() {
    final darkMode = widget.darkMode;
    final language = widget.language;

    return Column(
      children: [
        // ✅ Publication Icon above the heading
        Container(
          width: isMobile ? 60 : 80,
          height: isMobile ? 60 : 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [DesertColors.crimson, DesertColors.primaryGoldDark],
            ),
            borderRadius: BorderRadius.circular(isMobile ? 15 : 20),
            boxShadow: [
              BoxShadow(
                color: DesertColors.crimson.withOpacity(0.3),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Icon(
            Icons.auto_stories,
            size: isMobile ? 30 : 40,
            color: DesertColors.lightBackground,
          ),
        ),
        SizedBox(height: isMobile ? 16 : 24),

        // ✅ Heading
        FadeTransition(
          opacity: _animationController,
          child: Text(
            language == 'ar' ? 'فعاليات الراية' : 'Al Raya Events',
            style: TextStyle(
              fontSize: isMobile ? 28 : 48,
              fontWeight: FontWeight.bold,
              color: darkMode ? DesertColors.darkText : DesertColors.lightText,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 16),

        // ✅ Subtitle
        SlideTransition(
          position: Tween<Offset>(begin: Offset(0, 0.5), end: Offset(0, 0))
              .animate(
                CurvedAnimation(
                  parent: _animationController,
                  curve: Curves.easeOutCubic,
                ),
              ),
          child: Text(
            language == 'ar'
                ? 'اكتشف الفعاليات الإسلامية والروحانية المميزة'
                : 'Discover meaningful Islamic and spiritual events',
            style: TextStyle(
              fontSize: isMobile ? 14 : 18,
              color: (darkMode ? DesertColors.darkText : DesertColors.lightText)
                  .withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersSection() {
    final darkMode = widget.darkMode;
    final language = widget.language;

    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: language == 'ar'
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Filter Events header for mobile
          if (isMobile)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: darkMode ? DesertColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: darkMode
                      ? DesertColors.maroon.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 20,
                    color: DesertColors.crimson,
                  ),
                  SizedBox(width: 8),
                  Text(
                    language == 'ar' ? 'تصفية الفعاليات' : 'Filter Events',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                ],
              ),
            ),

          // Desktop: Show "Browse Events" title
          if (!isMobile) ...[
            Text(
              language == 'ar' ? 'تصفح الفعاليات' : 'Browse Events',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: darkMode
                    ? DesertColors.darkText
                    : DesertColors.lightText,
              ),
            ),
            SizedBox(height: 24),
          ],

          // Filters layout: 2x2 grid for mobile, wrap for desktop
          isMobile ? _buildMobileFilters() : _buildDesktopFilters(),
        ],
      ),
    );
  }

  Widget _buildMobileFilters() {
    final darkMode = widget.darkMode;
    final language = widget.language;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: darkMode
              ? DesertColors.maroon.withOpacity(0.2)
              : Colors.grey.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: (darkMode ? DesertColors.maroon : Colors.grey).withOpacity(
              0.1,
            ),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // First row
          Row(
            children: [
              Expanded(
                child: _buildMobileFilterDropdown(
                  icon: Icons.calendar_today,
                  label: language == 'ar' ? 'التاريخ' : 'Date',
                  items: dates[language]!,
                  selectedValue: selectedDate,
                  onChanged: (value) {
                    selectedDate = value;
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Second row
          Row(
            children: [
              Expanded(
                child: _buildMobileFilterDropdown(
                  icon: Icons.location_on,
                  label: language == 'ar' ? 'الموقع' : 'Location',
                  items: locations[language]!,
                  selectedValue: selectedLocation,
                  onChanged: (value) {
                    selectedLocation = value;
                    _applyFilters();
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildMobileFilterDropdown(
                  icon: Icons.person,
                  label: language == 'ar' ? 'الخطيب' : 'Preacher',
                  items: preachers[language]!,
                  selectedValue: selectedPreacher,
                  onChanged: (value) {
                    selectedPreacher = value;
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileFilterDropdown({
    required IconData icon,
    required String label,
    required List<String> items,
    String? selectedValue,
    required Function(String?) onChanged,
  }) {
    final darkMode = widget.darkMode;
    final language = widget.language;
    String? safeValue = items.contains(selectedValue) ? selectedValue : null;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: darkMode
            ? DesertColors.darkBackground.withOpacity(0.5)
            : DesertColors.lightBackground.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: darkMode
              ? DesertColors.camelSand.withOpacity(0.3)
              : DesertColors.maroon.withOpacity(0.2),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isExpanded: true,
          hint: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: darkMode
                    ? DesertColors.darkText
                    : DesertColors.lightText,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: darkMode
                        ? DesertColors.darkText
                        : DesertColors.lightText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                size: 14,
                color: darkMode
                    ? DesertColors.darkText
                    : DesertColors.lightText,
              ),
            ],
          ),
          items: [
            ...items
                .take(
                  label == (language == 'ar' ? 'الخطيب' : 'Preacher')
                      ? visiblePreachers
                      : visibleLocations,
                )
                .map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 12,
                        color: darkMode
                            ? DesertColors.darkText
                            : DesertColors.lightText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),

            // Add "Show More"
            if ((label == (language == 'ar' ? 'الخطيب' : 'Preacher') &&
                    visiblePreachers < items.length) ||
                (label == (language == 'ar' ? 'الموقع' : 'Location') &&
                    visibleLocations < items.length))
              DropdownMenuItem<String>(
                value: '__show_more__',
                child: Text(
                  language == 'ar' ? 'عرض المزيد' : 'Show More',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: DesertColors.crimson,
                  ),
                ),
              ),
          ],

          onChanged: (value) {
            if (value == '__show_more__') {
              setState(() {
                if (label == (language == 'ar' ? 'الخطيب' : 'Preacher')) {
                  visiblePreachers += 3;
                } else if (label ==
                    (language == 'ar' ? 'الموقع' : 'Location')) {
                  visibleLocations += 3;
                }
              });
            } else {
              onChanged(value);
            }
          },

          dropdownColor: darkMode ? DesertColors.darkSurface : Colors.white,
        ),
      ),
    );
  }

  Widget _buildDesktopFilters() {
    final language = widget.language;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildFilterChip(
          icon: Icons.filter_list,
          label: language == 'ar' ? 'فلتر' : 'Filter',
          isMainFilter: true,
        ),
        _buildFilterDropdown(
          icon: Icons.calendar_today,
          label: language == 'ar' ? 'التاريخ' : 'Date',
          items: dates[language]!,
          selectedValue: selectedDate,
          onChanged: (value) {
            selectedDate = value;
            _applyFilters();
          },
        ),
        _buildFilterDropdown(
          icon: Icons.location_on,
          label: language == 'ar' ? 'الموقع' : 'Location',
          items: locations[language]!,
          selectedValue: selectedLocation,
          onChanged: (value) {
            selectedLocation = value;
            _applyFilters();
          },
        ),
        _buildFilterDropdown(
          icon: Icons.person,
          label: language == 'ar' ? 'الخطيب' : 'Preacher',
          items: preachers[language]!,
          selectedValue: selectedPreacher,
          onChanged: (value) {
            selectedPreacher = value;
            _applyFilters();
          },
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    bool isMainFilter = false,
  }) {
    final darkMode = widget.darkMode;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMainFilter
            ? (darkMode ? DesertColors.maroon : DesertColors.crimson)
            : (darkMode ? DesertColors.darkSurface : Colors.white),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: darkMode
              ? DesertColors.maroon.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: (darkMode ? DesertColors.maroon : Colors.grey).withOpacity(
              0.1,
            ),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isMainFilter
                ? Colors.white
                : (darkMode ? DesertColors.darkText : DesertColors.lightText),
          ),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isMainFilter
                  ? Colors.white
                  : (darkMode ? DesertColors.darkText : DesertColors.lightText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required IconData icon,
    required String label,
    required List<String> items,
    String? selectedValue,
    required Function(String?) onChanged,
  }) {
    final darkMode = widget.darkMode;
    final language = widget.language;
    String? safeValue = items.contains(selectedValue) ? selectedValue : null;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: darkMode
              ? DesertColors.maroon.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: (darkMode ? DesertColors.maroon : Colors.grey).withOpacity(
              0.1,
            ),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,

          hint: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: darkMode
                    ? DesertColors.darkText
                    : DesertColors.lightText,
              ),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: darkMode
                      ? DesertColors.darkText
                      : DesertColors.lightText,
                ),
              ),
              SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: darkMode
                    ? DesertColors.darkText
                    : DesertColors.lightText,
              ),
            ],
          ),
          items: [
            ...items
                .take(
                  label == (language == 'ar' ? 'الخطيب' : 'Preacher')
                      ? visiblePreachers
                      : visibleLocations,
                )
                .map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 12,
                        color: darkMode
                            ? DesertColors.darkText
                            : DesertColors.lightText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),

            // Add "Show More"
            if ((label == (language == 'ar' ? 'الخطيب' : 'Preacher') &&
                    visiblePreachers < items.length) ||
                (label == (language == 'ar' ? 'الموقع' : 'Location') &&
                    visibleLocations < items.length))
              DropdownMenuItem<String>(
                value: '__show_more__',
                child: Text(
                  language == 'ar' ? 'عرض المزيد' : 'Show More',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: DesertColors.crimson,
                  ),
                ),
              ),
          ],

          onChanged: (value) {
            if (value == '__show_more__') {
              setState(() {
                if (label == (language == 'ar' ? 'الخطيب' : 'Preacher')) {
                  visiblePreachers += 3;
                } else if (label ==
                    (language == 'ar' ? 'الموقع' : 'Location')) {
                  visibleLocations += 3;
                }
              });
            } else {
              onChanged(value);
            }
          },

          dropdownColor: darkMode ? DesertColors.darkSurface : Colors.white,
        ),
      ),
    );
  }

  Widget _buildBrowseEventsHeader() {
    final darkMode = widget.darkMode;
    final language = widget.language;

    if (!isMobile) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Text(
        language == 'ar' ? 'تصفح الفعاليات' : 'Browse Events',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: darkMode ? DesertColors.darkText : DesertColors.lightText,
        ),
        textAlign: language == 'ar' ? TextAlign.right : TextAlign.left,
      ),
    );
  }

  Widget _buildEventsContainer() {
    final darkMode = widget.darkMode;

    if (_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (filteredEvents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Text(
            language == 'ar' ? "لا توجد فعاليات" : "No events found",
            style: TextStyle(
              color: darkMode ? Colors.white70 : Colors.black87,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.all(20),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: darkMode ? DesertColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: darkMode
              ? DesertColors.maroon.withOpacity(0.2)
              : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (darkMode ? DesertColors.maroon : Colors.grey).withOpacity(
              0.1,
            ),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount;
          double childAspectRatio;

          if (isMobile) {
            crossAxisCount = 2;
            double itemWidth = constraints.maxWidth / crossAxisCount;
            double itemHeight = itemWidth * 1.5;
            childAspectRatio = itemWidth / itemHeight;
          } else {
            crossAxisCount = 3;
            if (constraints.maxWidth < 900) crossAxisCount = 2;
            if (constraints.maxWidth < 600) crossAxisCount = 1;

            double itemWidth = constraints.maxWidth / crossAxisCount;
            double itemHeight = itemWidth * 1.2;
            childAspectRatio = itemWidth / itemHeight;
          }

          return GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: isMobile ? 12 : 16,
              mainAxisSpacing: isMobile ? 12 : 16,
            ),
            itemCount: filteredEvents.length,
            itemBuilder: (context, index) {
              return _buildEventCard(filteredEvents[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    final darkMode = widget.darkMode;
    final language = widget.language;

    bool isLive = false;
    if (event.liveLink.isNotEmpty &&
        event.liveLink != 'No Link' &&
        event.liveLink.toLowerCase() != 'null') {
      DateTime now = DateTime.now();
      DateTime eventEnd = event.startTime.add(
        Duration(hours: 1),
      ); // Assume max 4 hours duration

      isLive = now.isAfter(event.startTime) && now.isBefore(eventEnd);
    }

    return GestureDetector(
      onTap: () async {
        try {
          final collectionRef = FirebaseFirestore.instance.collection(
            'tblboardads',
          );
          DocumentReference? docRef;

          // Attempt 1: assume event.id is Firestore doc ID (new schema)
          docRef = collectionRef.doc(event.id);
          final snapshot = await docRef.get();

          if (!snapshot.exists) {
            // Old schema: query document by "Id" field (numeric string)
            final querySnap = await collectionRef
                .where(
                  'Id',
                  isEqualTo: event.id,
                ) // event.id may be "1270" string
                .limit(1)
                .get();

            if (querySnap.docs.isEmpty) {
              print("Event not found in Firestore: ${event.id}");
              docRef = null;
            } else {
              docRef = querySnap.docs.first.reference;
            }
          }

          if (docRef != null) {
            // Run transaction to increment
            await FirebaseFirestore.instance.runTransaction((
              transaction,
            ) async {
              final snapshot = await transaction.get(docRef!);
              if (!snapshot.exists) return;

              final data = snapshot.data() as Map<String, dynamic>;
              String viewedStr = (data['Viewed'] ?? "0").toString();
              int viewedCount = int.tryParse(viewedStr) ?? 0;

              // Increment
              viewedCount++;

              transaction.update(docRef, {'Viewed': viewedCount.toString()});
            });

            // --- Add log entry in eventViews ---
            await FirebaseFirestore.instance.collection("eventViews").add({
              "eventId": event.id, // works for new schema
              "viewedAt": DateTime.now().toIso8601String(),
            });
          }
        } catch (e, st) {
          print("Error updating viewed count: $e");
          print(st);
        }

        // Navigate after increment
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MajalisDetails(
              darkMode: darkMode,
              language: language,
              event: {
                'Title': event.title,
                'Date': event.startTime,
                'Location': event.location,
                'PreacherName': event.preacherName,
                'Description': event.description,
                'LiveBroadcastLink': event.liveLink,
              },
            ),
            settings: const RouteSettings(name: '/majalis'),
          ),
        );
      },

      child: Container(
        decoration: BoxDecoration(
          color: darkMode
              ? DesertColors.darkBackground
              : DesertColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: darkMode
                ? DesertColors.maroon.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (darkMode ? DesertColors.maroon : Colors.grey).withOpacity(
                0.08,
              ),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      gradient: LinearGradient(
                        colors: [
                          DesertColors.camelSand,
                          DesertColors.primaryGoldDark,
                        ],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: event.image,
                    ),
                  ),

                  // Join Live button
                  if (isLive)
                    Positioned(
                      top: 8,
                      left: language == 'ar' ? null : 8,
                      right: language == 'ar' ? 8 : null,
                      child: GestureDetector(
                        onTap: () async {
                          final url = event.liveLink;
                          if (url.isNotEmpty && url != 'No Link') {
                            try {
                              final uri = Uri.parse(url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              } else {
                                // Fallback: show dialog
                                if (context.mounted) {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(
                                        language == 'ar'
                                            ? 'رابط البث المباشر'
                                            : 'Live Stream Link',
                                      ),
                                      content: SelectableText(url),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: Text(
                                            language == 'ar'
                                                ? 'إغلاق'
                                                : 'Close',
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              print('Error opening live link: $e');
                            }
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.3),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.live_tv,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                language == 'ar' ? "انضم مباشرة" : "Join Live",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Content section
            Expanded(
              flex: isMobile ? 2 : 1,
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 8 : 12),
                child: Column(
                  crossAxisAlignment: language == 'ar'
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: language == 'ar'
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            fontWeight: FontWeight.bold,
                            color: darkMode
                                ? DesertColors.darkText
                                : DesertColors.lightText,
                          ),
                          maxLines: isMobile ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: language == 'ar'
                              ? TextAlign.right
                              : TextAlign.left,
                        ),
                        SizedBox(height: 4),
                        Text(
                          DateFormat(
                            isMobile ? 'MMM d, yyyy' : 'MMMM d, yyyy – h:mm a',
                          ).format(event.startTime),
                          style: TextStyle(
                            fontSize: isMobile ? 9 : 11,
                            color:
                                (darkMode
                                        ? DesertColors.darkText
                                        : DesertColors.lightText)
                                    .withOpacity(0.7),
                          ),
                          textAlign: language == 'ar'
                              ? TextAlign.right
                              : TextAlign.left,
                        ),
                      ],
                    ),
                    if (isMobile) ...[
                      SizedBox(height: 4),
                      Text(
                        event.preacherName,
                        style: TextStyle(
                          fontSize: 9,
                          color:
                              (darkMode
                                      ? DesertColors.darkText
                                      : DesertColors.lightText)
                                  .withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: language == 'ar'
                            ? TextAlign.right
                            : TextAlign.left,
                      ),
                      Text(
                        event.location,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: darkMode
                              ? DesertColors.camelSand
                              : DesertColors.maroon,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: language == 'ar'
                            ? TextAlign.right
                            : TextAlign.left,
                      ),
                    ] else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              event.preacherName,
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    (darkMode
                                            ? DesertColors.darkText
                                            : DesertColors.lightText)
                                        .withOpacity(0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: language == 'ar'
                                  ? TextAlign.right
                                  : TextAlign.left,
                            ),
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              event.location,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: darkMode
                                    ? DesertColors.camelSand
                                    : DesertColors.maroon,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: language == 'ar'
                                  ? TextAlign.right
                                  : TextAlign.left,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
