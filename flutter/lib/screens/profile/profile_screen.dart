import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/providers/expense_provider.dart';
import 'package:alpha_app/providers/goal_provider.dart';
import 'package:alpha_app/providers/profile_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/screens/analysis/financial_analysis_screen.dart';
import 'package:alpha_app/screens/auth/login.dart';
import 'package:alpha_app/screens/profile/change_password_dialog.dart';
import 'package:alpha_app/screens/profile/components/profile_completion_card.dart';
import 'package:alpha_app/screens/profile/personal_info_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider =
        context.watch<Themeprovider>();

    final profileProvider =
        context.watch<ProfileProvider>();

    final goalProvider =
        context.watch<GoalProvider>();

    final expenseProvider =
        context.watch<ExpenseProvider>();

    final bool isDark =
        themeProvider.isDark;

    final double screenW =
        Device.width(context);

    final double screenH =
        Device.height(context);

    final profile =
        profileProvider.profile;

    final String displayName =
        profileProvider.displayName;

    final String email =
        profileProvider.email.isEmpty
            ? 'No email available'
            : profileProvider.email;

    final String? photoUrl =
        profileProvider.photoUrl;

    final int goalsCount =
        profileProvider.activeGoalsCount;

    final int expensesCount =
        profileProvider.confirmedCycleExpensesCount;

    final String memberSince =
        _formatMemberSince(
      profile?.joinedAt,
    );

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SafeArea(
        child: profileProvider.isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: isDark
                      ? AppColors.darkPrimary
                      : AppColors.lightPrimary,
                ),
              )
            : SingleChildScrollView(
                physics:
                    const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: screenW * 0.05,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: screenH * 0.025,
                    ),

                    // ================= HEADER =================

                    Text(
                      'Profile',
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                        fontSize:
                            screenW * 0.075,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    SizedBox(
                      height: screenH * 0.025,
                    ),

                    // ================= PROFILE HEADER =================

                    Center(
                      child: _ProfileHeader(
                        displayName: displayName,
                        email: email,
                        photoUrl: photoUrl,
                        isDark: isDark,
                        screenW: screenW,
                        onEdit: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PersonalInfoScreen(isEditing: true),
                            ),
                          ).then((_) {
                            profileProvider.refreshProfileSummary();
                          });
                        },
                      ),
                    ),

                    SizedBox(
                      height: screenH * 0.022,
                    ),

                    ProfileCompletionCard(
                      profileProvider: profileProvider,
                      isDark: isDark,
                    ),

                    SizedBox(
                      height: screenH * 0.022,
                    ),

                    // ================= FINANCIAL LEVEL =================

                    _FinancialLevelCard(
                      profileProvider: profileProvider,
                      isDark: isDark,
                      screenW: screenW,
                    ),

                    SizedBox(
                      height: screenH * 0.018,
                    ),

                    // ================= STATISTICS =================

                    Row(
                      children: [
                        Expanded(
                          child: _StatisticCard(
                            value:
                                goalsCount.toString(),
                            label: 'Goals',
                            icon:
                                Icons.flag_outlined,
                            isDark: isDark,
                            screenW: screenW,
                          ),
                        ),

                        SizedBox(
                          width: screenW * 0.025,
                        ),

                        Expanded(
                          child: _StatisticCard(
                            value: expensesCount
                                .toString(),
                            label: 'Expenses',
                            icon: Icons
                                .payments_outlined,
                            isDark: isDark,
                            screenW: screenW,
                          ),
                        ),

                        SizedBox(
                          width: screenW * 0.025,
                        ),

                        Expanded(
                          child: _StatisticCard(
                            value: memberSince,
                            label: 'Member Since',
                            icon: Icons
                                .calendar_month_outlined,
                            isDark: isDark,
                            screenW: screenW,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(
                      height: screenH * 0.03,
                    ),

                    // ================= SETTINGS =================

                    Text(
                      'Settings',
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                        fontSize:
                            screenW * 0.048,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    SizedBox(
                      height: screenH * 0.012,
                    ),

                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkBorder
                            : Colors.white,
                        borderRadius:
                            BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: Column(
                        children: [
                          _ProfileMenuTile(
                            icon: Icons
                                .person_outline_rounded,
                            title:
                                'Personal Information',
                            isDark: isDark,
                            screenW: screenW,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PersonalInfoScreen(isEditing: true),
                                ),
                              ).then((_) {
                                profileProvider.refreshProfileSummary();
                              });
                            },
                          ),

                          _ProfileDivider(
                            isDark: isDark,
                          ),

                          _ProfileMenuTile(
                            icon: Icons
                                .notifications_none_rounded,
                            title: 'Notifications',
                            isDark: isDark,
                            screenW: screenW,
                            onTap: () {
                              _showComingSoon(
                                context,
                                'Notifications',
                              );
                            },
                          ),

                          _ProfileDivider(
                            isDark: isDark,
                          ),

                          _ProfileMenuTile(
                            icon:
                                Icons.lock_outline_rounded,
                            title:
                                'Privacy & Security',
                            isDark: isDark,
                            screenW: screenW,
                            onTap: () {
                              showChangePasswordDialog(
                                context: context,
                                profileProvider: profileProvider,
                                isDark: isDark,
                                screenW: screenW,
                              );
                            },
                          ),

                          _ProfileDivider(
                            isDark: isDark,
                          ),

                          _ProfileSwitchTile(
                            icon: isDark
                                ? Icons
                                    .dark_mode_outlined
                                : Icons
                                    .light_mode_outlined,
                            title: 'Dark Mode',
                            value: isDark,
                            isDark: isDark,
                            screenW: screenW,
                            onChanged: (_) {
                              themeProvider
                                  .toggleDark();
                            },
                          ),

                          _ProfileDivider(
                            isDark: isDark,
                          ),

                          _ProfileMenuTile(
                            icon: Icons
                                .analytics_outlined,
                            title:
                                'Financial Analysis',
                            isDark: isDark,
                            screenW: screenW,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const FinancialAnalysisScreen(),
                                ),
                              );
                            },
                          ),

                          _ProfileDivider(
                            isDark: isDark,
                          ),

                          _ProfileMenuTile(
                            icon: Icons
                                .language_rounded,
                            title: 'Language',
                            trailingText: 'English',
                            isDark: isDark,
                            screenW: screenW,
                            onTap: () {
                              _showLanguageDialog(
                                context: context,
                                isDark: isDark,
                              );
                            },
                          ),

                          _ProfileDivider(
                            isDark: isDark,
                          ),

                          _ProfileMenuTile(
                            icon:
                                Icons.logout_rounded,
                            title: 'Log Out',
                            isDark: isDark,
                            screenW: screenW,
                            isDanger: true,
                            showArrow: false,
                            onTap: () {
                              _showLogoutDialog(
                                context: context,
                                profileProvider:
                                    profileProvider,
                                isDark: isDark,
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    SizedBox(
                      height: screenH * 0.035,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  static String _formatMemberSince(
    DateTime? date,
  ) {
    if (date == null) {
      return DateFormat('MMM yyyy').format(
        DateTime.now(),
      );
    }

    return DateFormat('MMM yyyy').format(date);
  }

  static void _showComingSoon(
    BuildContext context,
    String feature,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$feature will be available soon.',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  static Future<void>
      _showEditProfileDialog({
    required BuildContext context,
    required ProfileProvider profileProvider,
    required bool isDark,
    required double screenW,
  }) async {
    final nameController =
        TextEditingController(
      text: profileProvider.displayName == 'User'
          ? ''
          : profileProvider.displayName,
    );

    final emailController =
        TextEditingController(
      text: profileProvider.email,
    );

    final phoneController =
        TextEditingController(
      text:
          profileProvider.profile?.phone ?? '',
    );

    final bool? saved =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark
              ? AppColors.darkBorder
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
          ),
          title: Text(
            'Edit Profile',
            style:
                GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                  ),
                  decoration:
                      _dialogInputDecoration(
                    label: 'Full name',
                    icon:
                        Icons.person_outline,
                    isDark: isDark,
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: emailController,
                  keyboardType:
                      TextInputType.emailAddress,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                  ),
                  decoration:
                      _dialogInputDecoration(
                    label: 'Email',
                    icon:
                        Icons.email_outlined,
                    isDark: isDark,
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: phoneController,
                  keyboardType:
                      TextInputType.phone,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                  ),
                  decoration:
                      _dialogInputDecoration(
                    label: 'Phone',
                    icon:
                        Icons.phone_outlined,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                ),
              ),
            ),

            ElevatedButton(
              onPressed: () async {
                final name =
                    nameController.text.trim();

                final email =
                    emailController.text.trim();

                if (name.isEmpty ||
                    email.isEmpty) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please enter your name and email.',
                      ),
                    ),
                  );

                  return;
                }

                final success =
                    await profileProvider
                        .updateProfile(
                  name: name,
                  email: email,
                  phone: phoneController.text
                      .trim(),
                );

                if (!dialogContext.mounted) {
                  return;
                }

                if (success) {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                }
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? AppColors.darkPrimary
                    : AppColors.lightPrimary,
                foregroundColor:
                    AppColors.darkBorder,
              ),
              child: const Text(
                'Save',
              ),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();

    if (saved == true &&
        context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Profile updated successfully.',
            ),
            behavior:
                SnackBarBehavior.floating,
          ),
        );
    }
  }

  static InputDecoration
      _dialogInputDecoration({
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark
            ? AppColors.darkSubText
            : AppColors.lightSubText,
      ),
      prefixIcon: Icon(
        icon,
        color: isDark
            ? AppColors.darkPrimary
            : AppColors.lightPrimary,
      ),
      filled: true,
      fillColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide: BorderSide(
          color: isDark
              ? AppColors.darkSubText
                  .withOpacity(0.4)
              : AppColors.lightSubText
                  .withOpacity(0.4),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide: BorderSide(
          color: isDark
              ? AppColors.darkPrimary
              : AppColors.lightPrimary,
        ),
      ),
    );
  }

  static Future<void>
      _showLanguageDialog({
    required BuildContext context,
    required bool isDark,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark
              ? AppColors.darkBorder
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
          ),
          title: Text(
            'Language',
            style:
                GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Text('🇬🇧'),
                title: Text(
                  'English',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                  ),
                ),
                trailing: Icon(
                  Icons.check_circle_rounded,
                  color: isDark
                      ? AppColors.darkPrimary
                      : AppColors.lightPrimary,
                ),
                onTap: () {
                  Navigator.pop(
                    dialogContext,
                  );
                },
              ),

              ListTile(
                leading:
                    const Text('🇯🇴'),
                title: Text(
                  'العربية',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                  ),
                ),
                subtitle: Text(
                  'سيتم ربطها لاحقًا',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText,
                  ),
                ),
                onTap: () {
                  Navigator.pop(
                    dialogContext,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void>
      _showLogoutDialog({
    required BuildContext context,
    required ProfileProvider profileProvider,
    required bool isDark,
  }) async {
    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark
              ? AppColors.darkBorder
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
          ),
          title: Text(
            'Log Out',
            style:
                GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to log out?',
            style:
                GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkSubText
                  : AppColors.lightSubText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                ),
              ),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? AppColors.darkError
                    : AppColors.lightError,
                foregroundColor:
                    Colors.white,
              ),
              child: const Text(
                'Log Out',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !context.mounted) {
      return;
    }

    await profileProvider.logout();

    if (!context.mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const Login(),
      ),
      (route) => false,
    );
  }
}

// =====================================================
// PROFILE HEADER
// =====================================================

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String email;
  final String? photoUrl;
  final bool isDark;
  final double screenW;
  final VoidCallback onEdit;

  const _ProfileHeader({
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.isDark,
    required this.screenW,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: screenW * 0.27,
              height: screenW * 0.27,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
                border: Border.all(
                  color: isDark
                      ? AppColors.darkPrimary
                      : AppColors.lightPrimary,
                  width: 3,
                ),
              ),
              child: ClipOval(
                child:
                    _buildProfileImage(),
              ),
            ),

            Positioned(
              right: -2,
              bottom: 3,
              child: InkWell(
                onTap: onEdit,
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkPrimary
                        : AppColors.lightPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? AppColors
                              .darkBackground
                          : AppColors
                              .lightBackground,
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    color:
                        AppColors.darkBorder,
                    size: 17,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        Text(
          displayName,
          textAlign: TextAlign.center,
          style:
              GoogleFonts.ibmPlexSansArabic(
            color: isDark
                ? AppColors.darkText
                : AppColors.lightText,
            fontSize: screenW * 0.056,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          email,
          textAlign: TextAlign.center,
          style:
              GoogleFonts.ibmPlexSansArabic(
            color: isDark
                ? AppColors.darkSubText
                : AppColors.lightSubText,
            fontSize: screenW * 0.032,
          ),
        ),

        const SizedBox(height: 14),

        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(
            Icons.edit_outlined,
            size: 18,
          ),
          label: Text(
            'Edit Profile',
            style:
                GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark
                ? AppColors.darkPrimary
                : AppColors.lightPrimary,
            side: BorderSide(
              color: isDark
                  ? AppColors.darkPrimary
                  : AppColors.lightPrimary,
            ),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImage() {
    final value = photoUrl?.trim() ?? '';

    if (value.isEmpty) {
      return Icon(
        Icons.person_rounded,
        size: screenW * 0.16,
        color: isDark
            ? AppColors.darkSubText
            : AppColors.lightSubText,
      );
    }

    return Image.network(
      value,
      fit: BoxFit.cover,
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) {
        return Icon(
          Icons.person_rounded,
          size: screenW * 0.16,
          color: isDark
              ? AppColors.darkSubText
              : AppColors.lightSubText,
        );
      },
      loadingBuilder: (
        context,
        child,
        loadingProgress,
      ) {
        if (loadingProgress == null) {
          return child;
        }

        return Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: isDark
                ? AppColors.darkPrimary
                : AppColors.lightPrimary,
          ),
        );
      },
    );
  }
}

// =====================================================
// FINANCIAL LEVEL
// =====================================================

class _FinancialLevelCard
    extends StatelessWidget {
  final ProfileProvider profileProvider;
  final bool isDark;
  final double screenW;

  const _FinancialLevelCard({
    required this.profileProvider,
    required this.isDark,
    required this.screenW,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSecondary
                .withOpacity(0.13)
            : AppColors.lightSecondary
                .withOpacity(0.13),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppColors.darkSecondary
                  .withOpacity(0.25)
              : AppColors.lightSecondary
                  .withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkPrimary
                      .withOpacity(0.14)
                  : AppColors.lightPrimary
                      .withOpacity(0.14),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.workspace_premium_outlined,
              color: isDark
                  ? AppColors.darkPrimary
                  : AppColors.lightPrimary,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial Level',
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText,
                    fontSize:
                        screenW * 0.031,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  profileProvider.financialLevel,
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                    fontSize:
                        screenW * 0.044,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Icon(
            Icons.trending_up_rounded,
            color: isDark
                ? AppColors.darkPrimary
                : AppColors.lightPrimary,
          ),
        ],
      ),
    );
  }
}

// =====================================================
// STATISTIC CARD
// =====================================================

class _StatisticCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool isDark;
  final double screenW;

  const _StatisticCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.isDark,
    required this.screenW,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 105,
      padding:
          const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkBorder
            : Colors.white,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : AppColors.lightBorder,
        ),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 21,
            color: isDark
                ? AppColors.darkPrimary
                : AppColors.lightPrimary,
          ),

          const SizedBox(height: 6),

          Text(
            value,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontSize:
                  screenW * 0.038,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkSubText
                  : AppColors.lightSubText,
              fontSize:
                  screenW * 0.025,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// MENU TILE
// =====================================================

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailingText;
  final bool isDark;
  final double screenW;
  final VoidCallback onTap;
  final bool isDanger;
  final bool showArrow;

  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.isDark,
    required this.screenW,
    required this.onTap,
    this.trailingText,
    this.isDanger = false,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    final Color mainColor =
        isDanger
            ? (isDark
                ? AppColors.darkError
                : AppColors.lightError)
            : (isDark
                ? AppColors.darkText
                : AppColors.lightText);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(14),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            vertical: 13,
          ),
          child: Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: isDanger
                      ? mainColor
                          .withOpacity(0.10)
                      : (isDark
                          ? AppColors
                              .darkPrimary
                              .withOpacity(
                                0.10,
                              )
                          : AppColors
                              .lightPrimary
                              .withOpacity(
                                0.10,
                              )),
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isDanger
                      ? mainColor
                      : (isDark
                          ? AppColors
                              .darkPrimary
                          : AppColors
                              .lightPrimary),
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: mainColor,
                    fontSize:
                        screenW * 0.036,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),

              if (trailingText != null) ...[
                Text(
                  trailingText!,
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText,
                    fontSize:
                        screenW * 0.029,
                  ),
                ),

                const SizedBox(width: 7),
              ],

              if (showArrow)
                Icon(
                  Icons
                      .arrow_forward_ios_rounded,
                  size: 16,
                  color: isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// SWITCH TILE
// =====================================================

class _ProfileSwitchTile
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final bool isDark;
  final double screenW;
  final ValueChanged<bool> onChanged;

  const _ProfileSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.isDark,
    required this.screenW,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkPrimary
                      .withOpacity(0.10)
                  : AppColors.lightPrimary
                      .withOpacity(0.10),
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isDark
                  ? AppColors.darkPrimary
                  : AppColors.lightPrimary,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Text(
              title,
              style: GoogleFonts
                  .ibmPlexSansArabic(
                color: isDark
                    ? AppColors.darkText
                    : AppColors.lightText,
                fontSize:
                    screenW * 0.036,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: isDark
                ? AppColors.darkPrimary
                : AppColors.lightPrimary,
          ),
        ],
      ),
    );
  }
}

// =====================================================
// DIVIDER
// =====================================================

class _ProfileDivider
    extends StatelessWidget {
  final bool isDark;

  const _ProfileDivider({
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: isDark
          ? AppColors.darkSubText
              .withOpacity(0.12)
          : AppColors.lightSubText
              .withOpacity(0.12),
    );
  }
}