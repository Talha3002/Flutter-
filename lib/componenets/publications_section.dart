import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../alrayah.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../majalis/majalis_section.dart'; // Import the Event class
import '../majalis/majalis_details.dart'; // Import MajalisDetails page

// Add after imports, before PublicationSection class
class PublicationCache {
  static List<Event>? _cachedEvents;
  static DateTime? _lastFetch;

  static bool get isCacheValid {
    if (_lastFetch == null || _cachedEvents == null) return false;
    return DateTime.now().difference(_lastFetch!) < Duration(minutes: 5);
  }

  static void clearCache() {
    _cachedEvents = null;
    _lastFetch = null;
  }

  static void updateCache(List<Event> events) {
    _cachedEvents = events;
    _lastFetch = DateTime.now();
  }

  static List<Event>? get cachedEvents => _cachedEvents;
}

class PublicationSection extends StatefulWidget {
  final bool darkMode;
  final String language;

  const PublicationSection({
    super.key,
    required this.darkMode,
    required this.language,
  });

  @override
  State<PublicationSection> createState() => _PublicationSectionState();
}

class _PublicationSectionState extends State<PublicationSection> {
  List<Event> recentEvents = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRecentEvents();
  }

  // Replace the entire _fetchRecentEvents method starting at line ~30
  Future<void> _fetchRecentEvents() async {
    // 🚀 Return cached data if valid
    if (PublicationCache.isCacheValid) {
      setState(() {
        recentEvents = PublicationCache.cachedEvents ?? [];
        isLoading = false;
      });
      debugPrint("DEBUG: Using cached events (${recentEvents.length} events)");
      return;
    }

    setState(() => isLoading = true);
    debugPrint("DEBUG: Fetching events from Firestore...");

    try {
      // 🚀 Fetch ALL collections in parallel using Future.wait
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('aspnetuserclaims')
            .where('ClaimValue', isEqualTo: 'Orator')
            .get(),
        FirebaseFirestore.instance.collection('aspnetusers').get(),
        FirebaseFirestore.instance
            .collection('tblboardads')
            .where('IsDeleted', isEqualTo: 'False')
            .get(),
        FirebaseFirestore.instance
            .collection('tblboards')
            .where('IsDeleted', isEqualTo: 'False')
            .get(),
        FirebaseFirestore.instance
            .collection('tbluploadedfiles')
            .get(), // 🚀 Fetch ALL at once
      ]);

      final oratorClaims = results[0];
      final usersSnapshot = results[1];
      final adsSnapshot = results[2];
      final boardsSnapshot = results[3];
      final uploadedFilesSnapshot = results[4];

      debugPrint(
        "DEBUG: Fetched ${oratorClaims.docs.length} orators, ${usersSnapshot.docs.length} users, ${adsSnapshot.docs.length} ads, ${boardsSnapshot.docs.length} boards, ${uploadedFilesSnapshot.docs.length} files",
      );

      // 🚀 Create Maps for O(1) lookup instead of sequential queries
      final oratorIds = oratorClaims.docs.map((doc) => doc['UserId']).toSet();

      // Map users by ID
      Map<String, Map<String, dynamic>> usersMap = {};
      for (var doc in usersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['Id'];
        if (userId != null && oratorIds.contains(userId)) {
          usersMap[userId] = data;
        }
      }

      // Map ads by ID
      Map<String, Map<String, dynamic>> adsMap = {};
      for (var doc in adsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final adId = data['Id'];
        if (adId != null) {
          adsMap[adId] = data;
        }
      }

      // 🚀 Map uploaded files by ID (BoardAds specific)
      Map<String, Map<String, dynamic>> uploadedFilesMap = {};
      for (var doc in uploadedFilesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['EntityType'] == 'BoardAds') {
          final fileId = data['Id'];
          if (fileId != null) {
            uploadedFilesMap[fileId] = data;
          }
        }
      }

      debugPrint(
        "DEBUG: Mapped ${usersMap.length} orators, ${adsMap.length} ads, ${uploadedFilesMap.length} files",
      );

      // 🚀 Process boards in memory
      List<Event> pastEvents = [];
      List<Event> futureEvents = [];
      DateTime now = DateTime.now();

      for (var doc in boardsSnapshot.docs) {
        final board = doc.data() as Map<String, dynamic>;
        final boardAdsId = board['BoardAdsId'];
        final oratorId = board['OratorId'];

        final ad = adsMap[boardAdsId];
        final user = usersMap[oratorId];

        if (ad != null && user != null) {
          // 🚀 Get uploaded file from map (no query!)
          final boardAdsImageId = ad['BoardAdsImageId'];
          final uploadedData = uploadedFilesMap[boardAdsImageId];

          final event = Event.fromFirestore(
            ad,
            board,
            user,
            uploadedFilesData: uploadedData,
          );

          // Separate past and future events
          if (event.startTime.isBefore(now)) {
            pastEvents.add(event);
          } else {
            futureEvents.add(event);
          }
        }
      }

      debugPrint(
        "DEBUG: Processed ${pastEvents.length} past events, ${futureEvents.length} future events",
      );

      // Sort past events: most recent first
      pastEvents.sort((a, b) => b.startTime.compareTo(a.startTime));

      // Sort future events: nearest first
      futureEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

      // Smart selection logic
      List<Event> selectedEvents = [];

      // Take up to 3 future events first
      int futureCount = futureEvents.length > 3 ? 3 : futureEvents.length;
      selectedEvents.addAll(futureEvents.take(futureCount));

      // Fill remaining slots with past events
      int remainingSlots = 3 - futureCount;
      if (remainingSlots > 0) {
        selectedEvents.addAll(pastEvents.take(remainingSlots));
      }

      debugPrint("DEBUG: Selected ${selectedEvents.length} events to display");

      // Update cache
      PublicationCache.updateCache(selectedEvents);

      setState(() {
        recentEvents = selectedEvents;
        isLoading = false;
      });

      debugPrint("DEBUG: Events loaded and cached successfully");
    } catch (e) {
      debugPrint("ERROR: Failed to fetch recent events: $e");
      setState(() => isLoading = false);
    }
  }

  bool _isUpcomingEvent(Event event) {
    return event.startTime.isAfter(DateTime.now());
  }

  bool _isEventLive(Event event) {
    // Check if the event has a live link (online event)
    if (event.liveLink == null || event.liveLink.isEmpty) {
      return false;
    }

    final now = DateTime.now();
    final eventEnd = event.startTime.add(Duration(hours: 1)); // Live for 1 hour

    // Check if current time is between event start and end (start + 1 hour)
    return now.isAfter(event.startTime) && now.isBefore(eventEnd);
  }

  // Add after _fetchRecentEvents method
  void _refreshEvents() {
    PublicationCache.clearCache();
    _fetchRecentEvents();
  }

  @override
  Widget build(BuildContext context) {
    final content = {
      'ar': {
        'title': 'إصدارات المجلس',
        'subtitle': 'مكتبة شاملة من الإصدارات الإسلامية والبحوث الدينية',
        'viewAll': 'عرض جميع الإصدارات',
        'viewMajalis': 'عرض المجالس',
      },
      'en': {
        'title': 'Recent Events',
        'subtitle':
            'Comprehensive library of Islamic publications and religious research',
        'viewAll': 'View All Publications',
        'viewMajalis': 'View Majalis',
      },
    };

    final currentContent = content[widget.language]!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return AnimatedContainer(
      duration: Duration(milliseconds: 600),
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 40 : 80,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.darkMode
              ? [DesertColors.darkSurface, DesertColors.darkBackground]
              : [DesertColors.lightSurface, DesertColors.lightBackground],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: RefreshIndicator(
        onRefresh: () async {
          _refreshEvents();
          await Future.delayed(Duration(seconds: 1));
        },
        color: widget.darkMode ? DesertColors.camelSand : DesertColors.crimson,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),

          child: Column(
            children: [
              _buildSectionHeader(currentContent, isMobile),
              SizedBox(height: isMobile ? 32 : 64),
              isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: widget.darkMode
                            ? DesertColors.camelSand
                            : DesertColors.crimson,
                      ),
                    )
                  : recentEvents.isEmpty
                  ? Center(
                      child: Text(
                        widget.language == 'ar'
                            ? 'لا توجد فعاليات حديثة'
                            : 'No recent events',
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          color: widget.darkMode
                              ? DesertColors.darkText.withOpacity(0.7)
                              : DesertColors.lightText.withOpacity(0.7),
                        ),
                      ),
                    )
                  : _buildPublicationsContainer(
                      currentContent,
                      context,
                      isMobile,
                    ),
              SizedBox(height: isMobile ? 24 : 48),
              _buildViewAllButton(currentContent, isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(Map currentContent, bool isMobile) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 1000),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 20,
                    vertical: isMobile ? 8 : 10,
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
                      fontSize: isMobile ? 24 : 40,
                      fontWeight: FontWeight.bold,
                      color: widget.darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  currentContent['subtitle'] as String,
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 18,
                    color: widget.darkMode
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
    );
  }

  Widget _buildPublicationsContainer(
    Map currentContent,
    BuildContext context,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.darkMode
              ? [DesertColors.darkSurface, DesertColors.maroon.withOpacity(0.2)]
              : [
                  DesertColors.camelSand.withOpacity(0.3),
                  DesertColors.lightSurface,
                ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(isMobile ? 20 : 32),
        border: Border.all(
          color: widget.darkMode
              ? DesertColors.camelSand.withOpacity(0.3)
              : DesertColors.crimson.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (widget.darkMode
                ? DesertColors.crimson.withOpacity(0.2)
                : DesertColors.primaryGoldDark.withOpacity(0.2)),
            blurRadius: isMobile ? 15 : 30,
            offset: Offset(0, isMobile ? 8 : 15),
            spreadRadius: isMobile ? 2 : 5,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildViewMajalisButton(currentContent, isMobile),
          SizedBox(height: isMobile ? 16 : 32),
          isMobile
              ? _buildMobileEventsList(currentContent)
              : _buildDesktopEventsGrid(currentContent, context),
        ],
      ),
    );
  }

  Widget _buildMobileEventsList(Map currentContent) {
    return Column(
      children: recentEvents.asMap().entries.map((entry) {
        int index = entry.key;
        Event event = entry.value;

        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 600 + (index * 200)),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double value, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.darkMode
                          ? [
                              DesertColors.darkSurface,
                              DesertColors.darkBackground,
                            ]
                          : [Colors.white, DesertColors.lightSurface],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.darkMode
                          ? DesertColors.camelSand.withOpacity(0.2)
                          : DesertColors.crimson.withOpacity(0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (widget.darkMode ? Colors.black : Colors.grey)
                            .withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Right side - Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Location tag (only show if event is on-site)
                                if (event.location.isNotEmpty &&
                                    (event.liveLink == null ||
                                        event.liveLink.isEmpty))
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getCategoryColors(
                                        index,
                                      )[0].withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      event.location,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: _getCategoryColors(index)[0],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                // Live tag (for online events during their scheduled time)
                                if (_isEventLive(event)) ...[
                                  SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: () {
                                      // Open the live link
                                      if (event.liveLink != null &&
                                          event.liveLink.isNotEmpty) {
                                        // You'll need to add url_launcher package
                                        // For now, just show the link
                                        HapticFeedback.lightImpact();
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text(
                                              widget.language == 'ar'
                                                  ? 'رابط البث المباشر'
                                                  : 'Live Broadcast Link',
                                            ),
                                            content: Text(event.liveLink),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: Text(
                                                  widget.language == 'ar'
                                                      ? 'إغلاق'
                                                      : 'Close',
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.red,
                                            Colors.red[700]!,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.withOpacity(0.5),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.circle,
                                            size: 8,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            widget.language == 'ar'
                                                ? 'مباشر'
                                                : 'LIVE',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ]
                                // Upcoming tag (for future events)
                                else if (_isUpcomingEvent(event)) ...[
                                  SizedBox(height: 6),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
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
                                          color: DesertColors.primaryGoldDark
                                              .withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.upcoming,
                                          size: 10,
                                          color: widget.darkMode
                                              ? DesertColors.darkText
                                              : DesertColors.maroon,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          widget.language == 'ar'
                                              ? 'قادم'
                                              : 'Upcoming',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: widget.darkMode
                                                ? DesertColors.darkText
                                                : DesertColors.maroon,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: 8),
                            // Title
                            Text(
                              event.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: widget.darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            // Description
                            Text(
                              event.description != 'Not Added'
                                  ? event.description
                                  : (widget.language == 'ar'
                                        ? 'لا يوجد وصف'
                                        : 'No description available'),
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.darkMode
                                    ? DesertColors.darkText.withOpacity(0.7)
                                    : DesertColors.lightText.withOpacity(0.7),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 8),
                            // View Majalis Button
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MajalisDetails(
                                      darkMode: widget.darkMode,
                                      language: widget.language,
                                      event: {
                                        'Title': event.title,
                                        'Date': event.startTime,
                                        'Location': event.location,
                                        'PreacherName': event.preacherName,
                                        'Description': event.description,
                                        'LiveBroadcastLink': event.liveLink,
                                      },
                                    ),
                                    settings: const RouteSettings(
                                      name: '/majalis-details',
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
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
                                      color: DesertColors.crimson.withOpacity(
                                        0.3,
                                      ),
                                      blurRadius: 6,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  currentContent['viewMajalis'] as String,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
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
    );
  }

  List<Color> _getCategoryColors(int index) {
    final colorSets = [
      [DesertColors.crimson, DesertColors.maroon],
      [DesertColors.crimson, DesertColors.maroon],
      [DesertColors.crimson, DesertColors.maroon],
    ];
    return colorSets[index % colorSets.length];
  }

  Widget _buildDesktopEventsGrid(Map currentContent, BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 3 : 2,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 1.00,
      ),
      itemCount: recentEvents.length,
      itemBuilder: (context, index) {
        final event = recentEvents[index];
        return HoverablePublicationCard(
          darkMode: widget.darkMode,
          language: widget.language,
          event: event,
          index: index,
        );
      },
    );
  }

  Widget _buildViewMajalisButton(Map currentContent, bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.pushNamed(context, '/majalis');
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 20,
              vertical: isMobile ? 8 : 10,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  DesertColors.crimson,
                  DesertColors.crimson.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: DesertColors.crimson.withOpacity(0.4),
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              currentContent['viewMajalis'] as String,
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewAllButton(Map currentContent, bool isMobile) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 800),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: GestureDetector(
              onTap: () => HapticFeedback.mediumImpact(),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 24 : 32,
                  vertical: isMobile ? 12 : 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      DesertColors.camelSand.withOpacity(0.1),
                    ],
                  ),
                  border: Border.all(
                    color: widget.darkMode
                        ? DesertColors.camelSand
                        : DesertColors.crimson,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  currentContent['viewAll'] as String,
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: widget.darkMode
                        ? DesertColors.camelSand
                        : DesertColors.crimson,
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

class HoverablePublicationCard extends StatefulWidget {
  final bool darkMode;
  final String language;
  final Event event;
  final int index;

  const HoverablePublicationCard({
    Key? key,
    required this.darkMode,
    required this.language,
    required this.event,
    required this.index,
  }) : super(key: key);

  @override
  HoverablePublicationCardState createState() =>
      HoverablePublicationCardState();
}

class HoverablePublicationCardState extends State<HoverablePublicationCard>
    with TickerProviderStateMixin {
  bool _hovering = false;
  late AnimationController _animController;
  late AnimationController _hoverController;
  late Animation<double> _opacityAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _elevationAnim;
  bool _visibleOnce = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _hoverController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _opacityAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _slideAnim = Tween<Offset>(
      begin: Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _scaleAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );

    _elevationAnim = Tween<double>(begin: 1.0, end: 2.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _hoverController.dispose();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!_visibleOnce && info.visibleFraction > 0.1) {
      _visibleOnce = true;
      _animController.forward();
    }
  }

  bool _isEventLive() {
    if (widget.event.liveLink == null || widget.event.liveLink.isEmpty) {
      return false;
    }

    final now = DateTime.now();
    final eventEnd = widget.event.startTime.add(Duration(hours: 1));

    return now.isAfter(widget.event.startTime) && now.isBefore(eventEnd);
  }

  @override
  Widget build(BuildContext context) {
    final shadowColor = _hovering
        ? DesertColors.crimson.withOpacity(0.4)
        : (widget.darkMode ? Colors.black38 : Colors.black12);

    return VisibilityDetector(
      key: Key(widget.event.title),
      onVisibilityChanged: _onVisibilityChanged,
      child: FadeTransition(
        opacity: _opacityAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: MouseRegion(
            onEnter: (_) {
              setState(() => _hovering = true);
              _hoverController.forward();
            },
            onExit: (_) {
              setState(() => _hovering = false);
              _hoverController.reverse();
            },
            child: AnimatedBuilder(
              animation: _hoverController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _hovering ? -12 : 0),
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      padding: EdgeInsets.all(14),
                      margin: EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: widget.darkMode
                              ? [Color(0xFF3D2419), Color(0xFF2D1810)]
                              : [Colors.white, Color(0xFFFFFBF0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            blurRadius: _hovering ? 40 : 20,
                            offset: Offset(0, _hovering ? 25 : 10),
                            spreadRadius: _hovering ? 6 : 2,
                          ),
                          if (_hovering)
                            BoxShadow(
                              color: DesertColors.primaryGoldDark.withOpacity(
                                0.3,
                              ),
                              blurRadius: 25,
                              offset: Offset(0, 15),
                              spreadRadius: 3,
                            ),
                        ],
                        border: Border.all(
                          color: _hovering
                              ? DesertColors.crimson.withOpacity(0.5)
                              : (widget.darkMode
                                    ? DesertColors.maroon.withOpacity(0.3)
                                    : DesertColors.camelSand.withOpacity(0.4)),
                          width: _hovering ? 2.5 : 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top section with image and location (Full image background)
                          Container(
                            height: 170,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Full background image
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: ColorFiltered(
                                      colorFilter: ColorFilter.mode(
                                        Colors.black.withOpacity(
                                          0.2,
                                        ), // Slight darkening for text visibility
                                        BlendMode.darken,
                                      ),
                                      child: widget.event.image,
                                    ),
                                  ),
                                ),
                                // Gradient overlay for better text readability
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.3),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                ),
                                // Location tag and Upcoming tag
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // Location tag (only for on-site events)
                                      if (widget.event.location.isNotEmpty &&
                                          (widget.event.liveLink == null ||
                                              widget.event.liveLink.isEmpty))
                                        AnimatedContainer(
                                          duration: Duration(milliseconds: 300),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _hovering
                                                ? DesertColors.crimson
                                                : Colors.white.withOpacity(0.9),
                                            borderRadius: BorderRadius.circular(
                                              15,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.2,
                                                ),
                                                blurRadius: 6,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            widget.event.location,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: _hovering
                                                  ? Colors.white
                                                  : DesertColors.maroon,
                                            ),
                                          ),
                                        ),

                                      // Live tag (for online events during their time)
                                      if (_isEventLive()) ...[
                                        SizedBox(height: 6),
                                        GestureDetector(
                                          onTap: () {
                                            if (widget.event.liveLink != null &&
                                                widget
                                                    .event
                                                    .liveLink
                                                    .isNotEmpty) {
                                              HapticFeedback.lightImpact();
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: Text(
                                                    widget.language == 'ar'
                                                        ? 'رابط البث المباشر'
                                                        : 'Live Broadcast Link',
                                                  ),
                                                  content: Text(
                                                    widget.event.liveLink,
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            context,
                                                          ),
                                                      child: Text(
                                                        widget.language == 'ar'
                                                            ? 'إغلاق'
                                                            : 'Close',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.red,
                                                  Colors.red[700]!,
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.red.withOpacity(
                                                    0.5,
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
                                                  Icons.circle,
                                                  size: 8,
                                                  color: Colors.white,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  widget.language == 'ar'
                                                      ? 'مباشر'
                                                      : 'LIVE',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ]
                                      // Upcoming tag
                                      else if (widget.event.startTime.isAfter(
                                        DateTime.now(),
                                      )) ...[
                                        SizedBox(height: 6),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                DesertColors.primaryGoldDark,
                                                DesertColors.camelSand,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              15,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: DesertColors
                                                    .primaryGoldDark
                                                    .withOpacity(0.3),
                                                blurRadius: 6,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.upcoming,
                                                size: 11,
                                                color: widget.darkMode
                                                    ? DesertColors.darkText
                                                    : DesertColors.maroon,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                widget.language == 'ar'
                                                    ? 'قادم'
                                                    : 'Upcoming',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: widget.darkMode
                                                      ? DesertColors.darkText
                                                      : DesertColors.maroon,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),

                          // Title
                          Text(
                            widget.event.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: widget.darkMode
                                  ? DesertColors.darkText
                                  : DesertColors.lightText,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8),

                          // Preacher name
                          Text(
                            widget.event.preacherName,
                            style: TextStyle(
                              fontSize: 13,
                              color: widget.darkMode
                                  ? DesertColors.darkText.withOpacity(0.7)
                                  : DesertColors.lightText.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),

                          // Date
                          Text(
                            DateFormat(
                              'MMMM d, y - h:mm a',
                            ).format(widget.event.startTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.darkMode
                                  ? DesertColors.darkText.withOpacity(0.6)
                                  : DesertColors.lightText.withOpacity(0.6),
                            ),
                          ),
                          SizedBox(height: 12),

                          // Description
                          Expanded(
                            child: Text(
                              widget.event.description != 'Not Added'
                                  ? widget.event.description
                                  : (widget.language == 'ar'
                                        ? 'لا يوجد وصف متاح'
                                        : 'No description available'),
                              style: TextStyle(
                                fontSize: 13,
                                color: widget.darkMode
                                    ? DesertColors.darkText.withOpacity(0.8)
                                    : DesertColors.lightText.withOpacity(0.8),
                                height: 1.4,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(height: 6),

                          // Visit button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MajalisDetails(
                                        darkMode: widget.darkMode,
                                        language: widget.language,
                                        event: {
                                          'Title': widget.event.title,
                                          'Date': widget.event.startTime,
                                          'Location': widget.event.location,
                                          'PreacherName':
                                              widget.event.preacherName,
                                          'Description':
                                              widget.event.description,
                                          'LiveBroadcastLink':
                                              widget.event.liveLink,
                                        },
                                      ),
                                      settings: const RouteSettings(
                                        name: '/majalis-details',
                                      ),
                                    ),
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: Duration(milliseconds: 300),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _hovering
                                          ? [
                                              DesertColors.crimson,
                                              DesertColors.crimson.withOpacity(
                                                0.8,
                                              ),
                                            ]
                                          : [
                                              DesertColors.camelSand,
                                              DesertColors.camelSand
                                                  .withOpacity(0.8),
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (_hovering
                                                    ? DesertColors.crimson
                                                    : DesertColors.camelSand)
                                                .withOpacity(0.3),
                                        blurRadius: _hovering ? 8 : 4,
                                        offset: Offset(0, _hovering ? 4 : 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    widget.language == 'ar'
                                        ? 'زيارة المجلس'
                                        : 'Visit Majlis',
                                    style: TextStyle(
                                      color: _hovering
                                          ? Colors.white
                                          : DesertColors.maroon,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
