import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/models/reward_model.dart';
import 'package:alpha_app/providers/reward_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class RewardScreen extends StatefulWidget {
  const RewardScreen({
    super.key,
  });

  @override
  State<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen> {
  bool _didLoadData = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didLoadData) return;

    _didLoadData = true;

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) return;

        context.read<RewardProvider>().loadRewards();
      },
    );
  }

  Future<void> _refreshRewards() async {
    await context.read<RewardProvider>().loadRewards();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<Themeprovider>();
    final rewardProvider = context.watch<RewardProvider>();

    final bool isDark = themeProvider.isDark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark
                ? AppColors.darkText
                : AppColors.lightText,
          ),
        ),
        title: Text(
          "Rewards",
          style: GoogleFonts.ibmPlexSansArabic(
            color: isDark
                ? AppColors.darkText
                : AppColors.lightText,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _buildBody(
          provider: rewardProvider,
          isDark: isDark,
        ),
      ),
    );
  }

  Widget _buildBody({
    required RewardProvider provider,
    required bool isDark,
  }) {
    if (provider.isLoading && provider.rewardData == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF34D399),
        ),
      );
    }

    final reward = provider.rewardData;

    if (reward == null) {
      return _EmptyRewardsView(
        isDark: isDark,
        onRetry: () {
          context.read<RewardProvider>().loadRewards();
        },
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF34D399),
      onRefresh: _refreshRewards,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          22,
          12,
          22,
          40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LevelCard(
              reward: reward,
              isDark: isDark,
            ),

            const SizedBox(height: 22),

            _SectionHeader(
              title: "Badges",
              subtitle: "${reward.badgeCount} unlocked",
              isDark: isDark,
            ),

            const SizedBox(height: 12),

            _BadgesGrid(
              badges: reward.badges,
              isDark: isDark,
            ),

            const SizedBox(height: 22),

            _SectionHeader(
              title: "Achievements",
              subtitle:
                  "${_completedAchievements(reward.achievements)} completed",
              isDark: isDark,
            ),

            const SizedBox(height: 12),

            _AchievementsCard(
              achievements: reward.achievements,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  int _completedAchievements(
    List<AchievementModel> achievements,
  ) {
    return achievements
        .where((achievement) => achievement.isCompleted)
        .length;
  }
}

// =====================================================
// LEVEL CARD
// =====================================================

class _LevelCard extends StatelessWidget {
  final RewardModel reward;
  final bool isDark;

  const _LevelCard({
    required this.reward,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = reward.levelProgress.clamp(
      0.0,
      1.0,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B2D24),
                  Color(0xFF11231D),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Color(0xFFF0F9F5),
                ],
              ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: const Color(0xFF34D399).withOpacity(0.10),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Current level",
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkSubText
                            : AppColors.lightSubText,
                        fontSize: 11,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "Level ${reward.level}",
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      reward.levelTitle,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: const Color(0xFF34D399),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                width: 66,
                height: 66,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4C95D).withOpacity(0.13),
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  "🏅",
                  style: TextStyle(
                    fontSize: 36,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: isDark
                  ? const Color(0xFF293A34)
                  : const Color(0xFFE1EBE7),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFF4C95D),
              ),
            ),
          ),

          const SizedBox(height: 9),

          Row(
            children: [
              Text(
                "${reward.currentXp} XP",
                style: GoogleFonts.ibmPlexSansArabic(
                  color: const Color(0xFFF4C95D),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const Spacer(),

              Text(
                "${reward.nextLevelXp} XP to next level",
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                  fontSize: 10,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _LevelInfoItem(
                  icon: Icons.workspace_premium_outlined,
                  title: "Badges",
                  value: "${reward.badgeCount}",
                  isDark: isDark,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _LevelInfoItem(
                  icon: Icons.local_fire_department_outlined,
                  title: "Streak",
                  value: "${reward.streak} days",
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelInfoItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool isDark;

  const _LevelInfoItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF20332E)
            : Colors.white.withOpacity(0.80),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 21,
            color: const Color(0xFF34D399),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText,
                    fontSize: 9,
                  ),
                ),

                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// SECTION HEADER
// =====================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDark;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        Text(
          subtitle,
          style: GoogleFonts.ibmPlexSansArabic(
            color: isDark
                ? AppColors.darkSubText
                : AppColors.lightSubText,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// =====================================================
// BADGES GRID
// =====================================================

class _BadgesGrid extends StatelessWidget {
  final List<BadgeModel> badges;
  final bool isDark;

  const _BadgesGrid({
    required this.badges,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return _EmptySectionCard(
        icon: Icons.workspace_premium_outlined,
        title: "No badges yet",
        description:
            "Complete challenges to unlock your first badge.",
        isDark: isDark,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        14,
        18,
        14,
        16,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF172824)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.04),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.035),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: badges.length,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 14,

          // ارتفاع ثابت يمنع الـ RenderFlex overflow.
          mainAxisExtent: 108,
        ),
        itemBuilder: (
          context,
          index,
        ) {
          return _BadgeItem(
            badge: badges[index],
            isDark: isDark,
          );
        },
      ),
    );
  }
}

class _BadgeItem extends StatelessWidget {
  final BadgeModel badge;
  final bool isDark;

  const _BadgeItem({
    required this.badge,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bool isUnlocked = badge.isUnlocked;

    return Opacity(
      opacity: isUnlocked ? 1 : 0.38,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 55,
                height: 55,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? const Color(0xFFF4C95D).withOpacity(0.12)
                      : isDark
                          ? const Color(0xFF20332E)
                          : const Color(0xFFF0F6F3),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: isUnlocked
                        ? const Color(0xFFF4C95D)
                            .withOpacity(0.15)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  badge.icon,
                  style: const TextStyle(
                    fontSize: 26,
                  ),
                ),
              ),

              if (!isUnlocked)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 21,
                    height: 21,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF10201C)
                          : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 12,
                      color: isDark
                          ? AppColors.darkSubText
                          : AppColors.lightSubText,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 7),

          Expanded(
            child: Center(
              child: Text(
                badge.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                  fontSize: 9,
                  height: 1.2,
                  fontWeight: isUnlocked
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// ACHIEVEMENTS
// =====================================================

class _AchievementsCard extends StatelessWidget {
  final List<AchievementModel> achievements;
  final bool isDark;

  const _AchievementsCard({
    required this.achievements,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return _EmptySectionCard(
        icon: Icons.emoji_events_outlined,
        title: "No achievements yet",
        description:
            "Your completed achievements will appear here.",
        isDark: isDark,
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF172824)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.04),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.035),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: achievements.length,
        separatorBuilder: (
          context,
          index,
        ) {
          return Divider(
            height: 1,
            indent: 18,
            endIndent: 18,
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.06),
          );
        },
        itemBuilder: (
          context,
          index,
        ) {
          return _AchievementItem(
            achievement: achievements[index],
            isDark: isDark,
          );
        },
      ),
    );
  }
}

class _AchievementItem extends StatelessWidget {
  final AchievementModel achievement;
  final bool isDark;

  const _AchievementItem({
    required this.achievement,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bool completed = achievement.isCompleted;

    return Opacity(
      opacity: completed ? 1 : 0.55,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: completed
                    ? const Color(0xFF34D399).withOpacity(0.12)
                    : const Color(0xFFF4C95D).withOpacity(0.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                completed
                    ? Icons.check_rounded
                    : Icons.lock_outline_rounded,
                color: completed
                    ? const Color(0xFF34D399)
                    : const Color(0xFFF4C95D),
                size: 22,
              ),
            ),

            const SizedBox(width: 13),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: isDark
                          ? AppColors.darkText
                          : AppColors.lightText,
                      fontSize: 13,
                      fontWeight: completed
                          ? FontWeight.w600
                          : FontWeight.normal,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    completed
                        ? "Achievement completed"
                        : "Continue completing challenges to unlock",
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: isDark
                          ? AppColors.darkSubText
                          : AppColors.lightSubText,
                      fontSize: 9,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Icon(
              completed
                  ? Icons.verified_rounded
                  : Icons.arrow_forward_ios_rounded,
              color: completed
                  ? const Color(0xFF34D399)
                  : isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
              size: completed ? 20 : 13,
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// EMPTY SECTION
// =====================================================

class _EmptySectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isDark;

  const _EmptySectionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 30,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF172824)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFF34D399),
            size: 39,
          ),

          const SizedBox(height: 12),

          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkSubText
                  : AppColors.lightSubText,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// EMPTY SCREEN
// =====================================================

class _EmptyRewardsView extends StatelessWidget {
  final bool isDark;
  final VoidCallback onRetry;

  const _EmptyRewardsView({
    required this.isDark,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF4C95D).withOpacity(0.13),
                shape: BoxShape.circle,
              ),
              child: const Text(
                "🏅",
                style: TextStyle(
                  fontSize: 43,
                ),
              ),
            ),

            const SizedBox(height: 17),

            Text(
              "No rewards available",
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                color: isDark
                    ? AppColors.darkText
                    : AppColors.lightText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "Complete challenges to earn XP, badges and achievements.",
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                color: isDark
                    ? AppColors.darkSubText
                    : AppColors.lightSubText,
                fontSize: 12,
                height: 1.6,
              ),
            ),

            const SizedBox(height: 19),

            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: Text(
                "Try Again",
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34D399),
                foregroundColor: const Color(0xFF09231E),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}