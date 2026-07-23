import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/providers/notification_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/widgets/empty_screen.dart';
import 'package:intl/intl.dart';
import 'package:alpha_app/screens/challenges/chanllenges_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  void _handleDeepLink(Map<String, dynamic>? actionData) {
    if (actionData == null) return;
    final screen = actionData['screen'];
    // Very basic deep linking implementation. Expand as needed.
    if (screen == 'dashboard') {
      Navigator.popUntil(context, (route) => route.isFirst);
    } else if (screen == 'challenges') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ChallengesScreen()),
      );
    } else if (screen == 'goal_details' || screen == 'goal_history') {
      // Future navigation logic
    }
  }

  Color _getTypeColor(String type, bool isDark) {
    switch (type) {
      case 'critical':
        return Colors.red.shade400;
      case 'warning':
        return Colors.orange.shade400;
      case 'success':
        return Colors.green.shade400;
      case 'info':
      default:
        return Colors.blue.shade400;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'critical':
        return Icons.error_outline;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'success':
        return Icons.check_circle_outline;
      case 'info':
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<Themeprovider>();
    final notificationProvider = context.watch<NotificationProvider>();
    final screenW = Device.width(context);
    final screenH = Device.height(context);
    final isDark = themeProvider.isDark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "الإشعارات",
          style: GoogleFonts.ibmPlexSansArabic(
            color: isDark ? AppColors.darkText : AppColors.lightText,
            fontSize: screenW * 0.05,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (notificationProvider.notifications.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.done_all,
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              ),
              onPressed: () {
                notificationProvider.markAllAsRead();
              },
            ),
        ],
      ),
      body: notificationProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : notificationProvider.notifications.isEmpty
              ? EmptyStateView(
                  isDark: isDark,
                  screenW: screenW,
                  title: "لا توجد إشعارات",
                  description: "أنت على اطلاع بكل شيء جديد.",
                  buttonText: "العودة للرئيسية",
                  icon: Icons.notifications_none,
                  color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  onPressed: () => Navigator.pop(context),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: notificationProvider.notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notificationProvider.notifications[index];
                    final color = _getTypeColor(notification.type, isDark);
                    
                    return GestureDetector(
                      onTap: () {
                        if (!notification.isRead) {
                          notificationProvider.markAsRead(notification.id);
                        }
                        _handleDeepLink(notification.actionData);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? (notification.isRead ? AppColors.darkCard : AppColors.darkCard.withOpacity(0.8))
                              : (notification.isRead ? Colors.white : Colors.blue.shade50),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: notification.isRead 
                                ? Colors.transparent
                                : color.withOpacity(0.5),
                            width: 1.5,
                          ),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getTypeIcon(notification.type),
                                color: color,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notification.title,
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            color: isDark ? AppColors.darkText : AppColors.lightText,
                                            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        DateFormat('dd MMM hh:mm a').format(notification.createdAt),
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    notification.message,
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
