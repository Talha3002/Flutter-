import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:alraya_app/alrayah.dart';
import 'package:alraya_app/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  bool isRead;
  final String type;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    required this.type,
  });

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      title: title,
      message: message,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      type: type,
    );
  }
}

class NavigationBarWidget extends StatefulWidget {
  final bool darkMode;
  final String language;
  final String currentPage;
  final Function(String) onPageChange;
  final VoidCallback onLanguageToggle;
  final VoidCallback onThemeToggle;
  final String fullName;
  final VoidCallback openDrawer;

  const NavigationBarWidget({
    Key? key,
    required this.darkMode,
    required this.language,
    required this.currentPage,
    required this.onPageChange,
    required this.onLanguageToggle,
    required this.onThemeToggle,
    required this.fullName,
    required this.openDrawer,
  }) : super(key: key);

  @override
  State<NavigationBarWidget> createState() => _NavigationBarWidgetState();
}

class _NavigationBarWidgetState extends State<NavigationBarWidget>
    with TickerProviderStateMixin {
  bool showProfileMenu = false;
  bool _hoveringProfile = false;
  bool _showNotifications = false;
  OverlayEntry? _notificationOverlay;
  late AnimationController _bellAnimationController;
  late Animation<double> _bellAnimation;

  final Map<String, String> _pageRoutes = {
    "Dashboard": "/admin_dashboard",
    "Events": "/events",
    "Books": "/admin_books",
    "Publications": "/admin_publication",
    "User Analytics": "/user-analytics",
  };

  List<NotificationModel> notifications = [];

  @override
  void initState() {
    super.initState();

    // Init FCM
    NotificationService.init();

    // 🔔 Initialize bell animation
    _bellAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _bellAnimation = Tween<double>(begin: -0.2, end: 0.2)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_bellAnimationController);

    // Firestore listener
    FirebaseFirestore.instance
        .collection("admin_notifications")
        .orderBy("timestamp", descending: true)
        .snapshots()
        .listen((snapshot) {
          setState(() {
            notifications = snapshot.docs
                .map((doc) {
                  final data = doc.data();
                  return NotificationModel(
                    id: data["id"],
                    title: data["title"],
                    message: data["message"],
                    timestamp: DateTime.parse(data["timestamp"]),
                    isRead: data["read"] ?? false,
                    type: data["type"],
                  );
                })
                // ✅ Filter out read notifications
                .where((n) => !n.isRead)
                .toList();
          });
        });
  }

  void _scheduleAutoDelete(String notifId) {
    Future.delayed(const Duration(minutes: 2), () async {
      try {
        await FirebaseFirestore.instance
            .collection("admin_notifications")
            .doc(notifId)
            .delete();
        print("🗑️ Notification $notifId auto-deleted after 2 min");
      } catch (e) {
        print("❌ Auto-delete error: $e");
      }
    });
  }

  @override
  void dispose() {
    _bellAnimationController.dispose();
    _removeNotificationOverlay();
    super.dispose();
  }

  int get unreadNotificationCount =>
      notifications.where((n) => !n.isRead).length;

  String _getInitials(String name) {
    final parts = name.trim().split(" ");
    if (parts.length > 1) {
      return parts[0][0] + parts[1][0];
    }
    return parts[0][0];
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return widget.language == 'ar'
          ? '${difference.inMinutes} دقيقة مضت'
          : '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return widget.language == 'ar'
          ? '${difference.inHours} ساعة مضت'
          : '${difference.inHours} hour ago';
    } else {
      return widget.language == 'ar'
          ? '${difference.inDays} يوم مضى'
          : '${difference.inDays} day ago';
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'event':
        return Icons.event;
      case 'book':
        return Icons.menu_book;
      case 'publication':
        return Icons.library_books;
      case 'analytics':
        return Icons.analytics;
      default:
        return Icons.notifications;
    }
  }

  void _showNotificationOverlay(BuildContext context) {
    if (_notificationOverlay != null) {
      _removeNotificationOverlay();
      return;
    }

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _notificationOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: offset.dy + size.height + 8,
        right: MediaQuery.of(context).size.width - offset.dx - size.width,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent,
          child: Container(
            width: 380,
            constraints: const BoxConstraints(maxHeight: 500),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.darkMode
                    ? [
                        DesertColors.darkSurface.withOpacity(0.95),
                        DesertColors.maroon.withOpacity(0.9),
                      ]
                    : [
                        Colors.white.withOpacity(0.95),
                        DesertColors.lightSurface.withOpacity(0.9),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.darkMode
                      ? Colors.black.withOpacity(0.3)
                      : DesertColors.maroon.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    gradient: LinearGradient(
                      colors: widget.darkMode
                          ? [DesertColors.primaryGoldDark, DesertColors.maroon]
                          : [DesertColors.crimson, DesertColors.maroon],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.language == 'ar' ? 'الإشعارات' : 'Notifications',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          for (var notification in notifications) {
                            notification.isRead = true;
                            await FirebaseFirestore.instance
                                .collection("admin_notifications")
                                .doc(notification.id)
                                .update({"read": true});
                            // ✅ Schedule auto-delete
                            _scheduleAutoDelete(notification.id);
                          }
                          setState(() {});
                        },

                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.language == 'ar'
                                ? 'قراءة الكل'
                                : 'Mark all read',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: notifications.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 48,
                                color: widget.darkMode
                                    ? DesertColors.darkText.withOpacity(0.5)
                                    : DesertColors.lightText.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                widget.language == 'ar'
                                    ? 'لا توجد إشعارات'
                                    : 'No notifications',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: widget.darkMode
                                      ? DesertColors.darkText.withOpacity(0.7)
                                      : DesertColors.lightText.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(8),
                          itemCount: notifications.length,
                          separatorBuilder: (context, index) => Divider(
                            color: widget.darkMode
                                ? DesertColors.darkText.withOpacity(0.1)
                                : DesertColors.lightText.withOpacity(0.1),
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            return _buildNotificationItem(notification);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_notificationOverlay!);
    setState(() => _showNotifications = true);
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: notification.isRead
            ? Colors.transparent
            : (widget.darkMode
                  ? DesertColors.primaryGoldDark.withOpacity(0.1)
                  : DesertColors.crimson.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              colors: widget.darkMode
                  ? [DesertColors.primaryGoldDark, DesertColors.camelSand]
                  : [DesertColors.crimson, DesertColors.maroon],
            ),
          ),
          child: Icon(
            _getNotificationIcon(notification.type),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w600,
            color: widget.darkMode
                ? DesertColors.darkText
                : DesertColors.lightText,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.message,
              style: TextStyle(
                fontSize: 12,
                color: widget.darkMode
                    ? DesertColors.darkText.withOpacity(0.7)
                    : DesertColors.lightText.withOpacity(0.7),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _getTimeAgo(notification.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: widget.darkMode
                    ? DesertColors.darkText.withOpacity(0.5)
                    : DesertColors.lightText.withOpacity(0.5),
              ),
            ),
          ],
        ),
        trailing: !notification.isRead
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.darkMode
                      ? DesertColors.primaryGoldDark
                      : DesertColors.crimson,
                ),
              )
            : null,

        onTap: () async {
          setState(() {
            notification.isRead = true;
          });
          await FirebaseFirestore.instance
              .collection("admin_notifications")
              .doc(notification.id)
              .update({"read": true});

          // ✅ Schedule removal after 2 min
          _scheduleAutoDelete(notification.id);
        },
      ),
    );
  }

  void _removeNotificationOverlay() {
    _notificationOverlay?.remove();
    _notificationOverlay = null;
    setState(() => _showNotifications = false);
  }

  Widget _buildNotificationButton() {
    return GestureDetector(
      onTap: () {
        _bellAnimationController.forward().then((_) {
          _bellAnimationController.reverse();
        });
        _showNotificationOverlay(context);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.darkMode
                ? [DesertColors.maroon, DesertColors.maroon.withOpacity(0.8)]
                : [
                    DesertColors.camelSand,
                    DesertColors.camelSand.withOpacity(0.8),
                  ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: widget.darkMode
                  ? DesertColors.maroon.withOpacity(0.3)
                  : DesertColors.camelSand.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _bellAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _bellAnimation.value,
                  child: const Icon(
                    Icons.notifications_outlined,
                    size: 18,
                    color: Colors.white,
                  ),
                );
              },
            ),
            if (unreadNotificationCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.darkMode
                          ? [
                              DesertColors.primaryGoldDark,
                              DesertColors.camelSand,
                            ]
                          : [DesertColors.crimson, DesertColors.maroon],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    unreadNotificationCount > 99
                        ? '99+'
                        : unreadNotificationCount.toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.darkMode
                  ? [
                      DesertColors.darkSurface.withOpacity(0.95),
                      DesertColors.maroon.withOpacity(0.9),
                    ]
                  : [
                      DesertColors.lightSurface.withOpacity(0.95),
                      Colors.white.withOpacity(0.9),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: DesertColors.maroon.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: isMobile
                  ? _buildMobileNav(context)
                  : Row(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              widget.language == 'ar'
                                  ? ' الرايــة '
                                  : 'Al-Rayah',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: widget.darkMode
                                    ? DesertColors.darkText
                                    : DesertColors.lightText,
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildNavItem(
                                  "Dashboard",
                                  widget.language == "ar"
                                      ? "لوحة القيادة"
                                      : "Dashboard",
                                  Icons.dashboard_outlined,
                                ),
                                const SizedBox(width: 24),
                                _buildNavItem(
                                  "Events",
                                  widget.language == "ar"
                                      ? "الأحداث"
                                      : "Events",
                                  Icons.event,
                                ),
                                const SizedBox(width: 24),
                                _buildNavItem(
                                  "Books",
                                  widget.language == "ar" ? "الكتب" : "Books",
                                  Icons.menu_book_outlined,
                                ),
                                const SizedBox(width: 24),
                                _buildNavItem(
                                  "Publications",
                                  widget.language == "ar"
                                      ? "منشورات"
                                      : "Publications",
                                  Icons.library_books_outlined,
                                ),
                                const SizedBox(width: 24),
                                _buildNavItem(
                                  "User Analytics",
                                  widget.language == "ar"
                                      ? "تحليلات المستخدم"
                                      : "User Analytics",
                                  Icons.analytics_outlined,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            _buildLanguageToggle(),
                            const SizedBox(width: 8),
                            _buildThemeToggle(),
                            const SizedBox(width: 8),
                            _buildNotificationButton(),
                            const SizedBox(width: 12),
                            _buildProfileMenu(),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(String pageKey, String label, IconData icon) {
    final isActive = widget.currentPage.toLowerCase() == pageKey.toLowerCase();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, _pageRoutes[pageKey]!);
          widget.onPageChange(pageKey);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isActive
                ? (widget.darkMode
                      ? DesertColors.primaryGoldDark
                      : DesertColors.crimson)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive
                    ? Colors.white
                    : (widget.darkMode
                          ? DesertColors.darkText
                          : DesertColors.lightText),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? Colors.white
                      : (widget.darkMode
                            ? DesertColors.darkText
                            : DesertColors.lightText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageToggle() {
    return GestureDetector(
      onTap: widget.onLanguageToggle,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.darkMode
                ? [DesertColors.maroon, DesertColors.maroon.withOpacity(0.8)]
                : [
                    DesertColors.camelSand,
                    DesertColors.camelSand.withOpacity(0.8),
                  ],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.language, size: 16, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              widget.language == 'ar' ? 'EN' : 'عر',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: widget.darkMode ? Colors.white : DesertColors.maroon,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    return GestureDetector(
      onTap: widget.onThemeToggle,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.darkMode
                ? [DesertColors.camelSand, DesertColors.primaryGoldDark]
                : [DesertColors.maroon, DesertColors.crimson],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          widget.darkMode ? Icons.wb_sunny : Icons.nightlight_round,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildProfileMenu() {
    return PopupMenuButton<int>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: widget.darkMode ? DesertColors.darkSurface : Colors.white,
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: DesertColors.primaryGoldDark,
            child: Text(
              _getInitials(widget.fullName),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.fullName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: widget.darkMode
                  ? DesertColors.darkText
                  : DesertColors.lightText,
            ),
          ),
          const Icon(Icons.expand_more, size: 18),
        ],
      ),
      onSelected: (value) async {
        if (value == 1) {
          Navigator.pushNamed(context, "/admin_profile");
        } else if (value == 2) {
          Navigator.pushNamed(context, "/settings");
        } else if (value == 3) {
          try {
            await FirebaseAuth.instance.signOut();
            print("✅ User signed out successfully.");
            Navigator.pushNamedAndRemoveUntil(
              context,
              "/login",
              (route) => false,
            );
          } catch (e) {
            print("❌ Logout error: $e");
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 1,
          child: Row(
            children: const [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 8),
              Text("Edit Profile"),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 3,
          child: Row(
            children: [
              Icon(
                Icons.logout_outlined,
                size: 18,
                color: DesertColors.crimson,
              ),
              const SizedBox(width: 8),
              Text("Logout", style: TextStyle(color: DesertColors.crimson)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileNav(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SizedBox(width: 8),
            Text(
              widget.language == 'ar' ? 'الرايــة' : 'Al-Rayah',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.darkMode
                    ? DesertColors.darkText
                    : DesertColors.lightText,
              ),
            ),
          ],
        ),
        Row(
          children: [
            _buildNotificationButton(),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.menu,
                color: widget.darkMode ? Colors.white : Colors.black,
              ),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ],
        ),
      ],
    );
  }
}
