import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/models/challenge_model.dart';
import 'package:alpha_app/providers/challenge_provider.dart';
import 'package:alpha_app/providers/reward_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/screens/challenges/leaderboard_screen.dart';
import 'package:alpha_app/screens/challenges/reward_screen.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({
    super.key,
  });

  @override
  State<ChallengesScreen> createState() =>
      _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  bool _didLoadData = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didLoadData) return;

    _didLoadData = true;

    WidgetsBinding.instance.addPostFrameCallback(
      (_) async {
        if (!mounted) return;

        await context
            .read<ChallengeProvider>()
            .loadChallenges();

        if (!mounted) return;

        await context
            .read<RewardProvider>()
            .loadRewards();
      },
    );
  }

  Future<void> _refreshData() async {
    await context
        .read<ChallengeProvider>()
        .loadChallenges();

    if (!mounted) return;

    await context
        .read<RewardProvider>()
        .loadRewards();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider =
        context.watch<Themeprovider>();

    final challengeProvider =
        context.watch<ChallengeProvider>();

    final rewardProvider =
        context.watch<RewardProvider>();

    final bool isDark = themeProvider.isDark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF34D399),
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(
              22,
              22,
              22,
              125,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  isDark: isDark,
                ),

                const SizedBox(height: 22),

                _ChallengeTypeSelector(
                  selectedType:
                      challengeProvider.selectedType,
                  isDark: isDark,
                  onSelected: challengeProvider.selectType,
                ),

                const SizedBox(height: 14),

                _ChallengeStatusSelector(
                  selectedStatus:
                      challengeProvider.selectedStatus,
                  isDark: isDark,
                  onSelected:
                      challengeProvider.selectStatus,
                ),

                const SizedBox(height: 18),

                _ChallengesContent(
                  provider: challengeProvider,
                  isDark: isDark,
                  onChallengeTap: (
                    ChallengeModel challenge,
                  ) {
                    _showChallengeDetails(
                      challenge,
                      isDark,
                    );
                  },
                  onAccept: (
                    ChallengeModel challenge,
                  ) {
                    _acceptChallenge(challenge);
                  },
                ),

                const SizedBox(height: 18),

                _RewardSummarySection(
                  badgeCount: rewardProvider
                          .rewardData?.badgeCount ??
                      0,
                  streak: rewardProvider
                          .rewardData?.streak ??
                      0,
                  isDark: isDark,
                  onRewardsTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const RewardScreen(),
                      ),
                    );
                  },
                  onLeaderboardTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const LeaderboardScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _acceptChallenge(
    ChallengeModel challenge,
  ) {
    context
        .read<ChallengeProvider>()
        .acceptChallenge(challenge.id);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            "Challenge accepted successfully",
            style: GoogleFonts.ibmPlexSansArabic(),
          ),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
  }

  void _showChallengeDetails(
    ChallengeModel challenge,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ChallengeDetailsSheet(
          challenge: challenge,
          isDark: isDark,
          onAccept: () {
            Navigator.pop(sheetContext);
            _acceptChallenge(challenge);
          },
        );
      },
    );
  }
}

// =====================================================
// HEADER
// =====================================================

class _Header extends StatelessWidget {
  final bool isDark;

  const _Header({
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Challenges",
          style: GoogleFonts.ibmPlexSansArabic(
            color: isDark
                ? AppColors.darkText
                : AppColors.lightText,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          "Raise your score, earn rewards",
          style: GoogleFonts.ibmPlexSansArabic(
            color: isDark
                ? AppColors.darkSubText
                : AppColors.lightSubText,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

// =====================================================
// INDIVIDUAL / TEAM
// =====================================================

class _ChallengeTypeSelector extends StatelessWidget {
  final ChallengeType selectedType;
  final bool isDark;
  final ValueChanged<ChallengeType> onSelected;

  const _ChallengeTypeSelector({
    required this.selectedType,
    required this.isDark,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF20312E)
            : const Color(0xFFE6ECE9),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TypeButton(
              title: "Individual",
              icon: Icons.person_outline_rounded,
              isSelected:
                  selectedType == ChallengeType.individual,
              isDark: isDark,
              onTap: () {
                onSelected(
                  ChallengeType.individual,
                );
              },
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _TypeButton(
              title: "Team",
              icon: Icons.groups_2_outlined,
              isSelected:
                  selectedType == ChallengeType.team,
              isDark: isDark,
              onTap: () {
                onSelected(
                  ChallengeType.team,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _TypeButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF34D399)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? const Color(0xFF09231E)
                    : isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isSelected
                      ? const Color(0xFF09231E)
                      : isDark
                          ? AppColors.darkSubText
                          : AppColors.lightSubText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// CURRENT / COMPLETED / AVAILABLE
// =====================================================

class _ChallengeStatusSelector extends StatelessWidget {
  final ChallengeStatus selectedStatus;
  final bool isDark;
  final ValueChanged<ChallengeStatus> onSelected;

  const _ChallengeStatusSelector({
    required this.selectedStatus,
    required this.isDark,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatusButton(
            title: "Current",
            isSelected:
                selectedStatus == ChallengeStatus.current,
            isDark: isDark,
            onTap: () {
              onSelected(
                ChallengeStatus.current,
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatusButton(
            title: "Completed",
            isSelected:
                selectedStatus == ChallengeStatus.completed,
            isDark: isDark,
            onTap: () {
              onSelected(
                ChallengeStatus.completed,
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatusButton(
            title: "Available",
            isSelected:
                selectedStatus == ChallengeStatus.available,
            isDark: isDark,
            onTap: () {
              onSelected(
                ChallengeStatus.available,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _StatusButton({
    required this.title,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 43,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF063D34)
                : isDark
                    ? const Color(0xFF20312E)
                    : Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF14B8A6)
                  : Colors.transparent,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: GoogleFonts.ibmPlexSansArabic(
                color: isSelected
                    ? const Color(0xFF34D399)
                    : isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// CHALLENGES CONTENT
// =====================================================

class _ChallengesContent extends StatelessWidget {
  final ChallengeProvider provider;
  final bool isDark;

  final ValueChanged<ChallengeModel>
      onChallengeTap;

  final ValueChanged<ChallengeModel>
      onAccept;

  const _ChallengesContent({
    required this.provider,
    required this.isDark,
    required this.onChallengeTap,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading &&
        provider.challenges.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 70),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF34D399),
          ),
        ),
      );
    }

    if (provider.errorMessage != null &&
        provider.challenges.isEmpty) {
      return _ErrorView(
        message: provider.errorMessage!,
        isDark: isDark,
        onRetry: provider.loadChallenges,
      );
    }

    if (provider.selectedType ==
        ChallengeType.team) {
      return _TeamChallengeView(
        isDark: isDark,
      );
    }

    final challenges =
        provider.filteredChallenges;

    if (challenges.isEmpty) {
      return _EmptyChallengesView(
        status: provider.selectedStatus,
        isDark: isDark,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount: challenges.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final challenge =
            challenges[index];

        return _ChallengeCard(
          challenge: challenge,
          isDark: isDark,
          onTap: () {
            onChallengeTap(challenge);
          },
          onAccept: () {
            onAccept(challenge);
          },
        );
      },
    );
  }
}

// =====================================================
// CHALLENGE CARD
// =====================================================

class _ChallengeCard extends StatelessWidget {
  final ChallengeModel challenge;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onAccept;

  const _ChallengeCard({
    required this.challenge,
    required this.isDark,
    required this.onTap,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAvailable =
        challenge.status ==
            ChallengeStatus.available;

    final bool isCompleted =
        challenge.isCompleted;

    final progress =
        challenge.progress.clamp(0.0, 1.0);

    final progressColor =
        _getProgressColor();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(19),
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
                      color: Colors.black
                          .withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ChallengeStatusBadge(
                    challenge: challenge,
                  ),
                  const Spacer(),
                  if (!isCompleted)
                    Text(
                      "${challenge.daysLeft} days left",
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkSubText
                            : AppColors.lightSubText,
                        fontSize: 10,
                      ),
                    ),
                  if (isCompleted)
                    Text(
                      "+${challenge.xpReward} XP",
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color:
                            const Color(0xFFF4C95D),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: progressColor
                          .withOpacity(0.12),
                      borderRadius:
                          BorderRadius.circular(15),
                    ),
                    child: Text(
                      challenge.icon,
                      style: const TextStyle(
                        fontSize: 24,
                      ),
                    ),
                  ),

                  const SizedBox(width: 13),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          challenge.title,
                          style: GoogleFonts
                              .ibmPlexSansArabic(
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                            fontSize: 15,
                            height: 1.4,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        if (challenge.description
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            challenge.description,
                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,
                            style: GoogleFonts
                                .ibmPlexSansArabic(
                              color: isDark
                                  ? AppColors
                                      .darkSubText
                                  : AppColors
                                      .lightSubText,
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 17),

              if (isAvailable)
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF34D399),
                      foregroundColor:
                          const Color(0xFF09231E),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      "Accept Challenge",
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else ...[
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: isDark
                        ? const Color(0xFF253A35)
                        : const Color(0xFFE8EEEC),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(
                      progressColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      isCompleted
                          ? "Challenge completed"
                          : "Keep going",
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkSubText
                            : AppColors.lightSubText,
                        fontSize: 10,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      isCompleted
                          ? "Completed"
                          : "${challenge.progressPercentage}%",
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color: progressColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getProgressColor() {
    if (challenge.isCompleted) {
      return const Color(0xFF34D399);
    }

    if (challenge.progress >= 0.75) {
      return const Color(0xFFF4C95D);
    }

    return const Color(0xFF14B8A6);
  }
}

class _ChallengeStatusBadge extends StatelessWidget {
  final ChallengeModel challenge;

  const _ChallengeStatusBadge({
    required this.challenge,
  });

  @override
  Widget build(BuildContext context) {
    late String text;
    late Color color;

    if (challenge.isCompleted) {
      text = "Completed";
      color = const Color(0xFF34D399);
    } else if (challenge.status ==
        ChallengeStatus.available) {
      text = "Available";
      color = const Color(0xFF14B8A6);
    } else {
      text = "Active";
      color = challenge.progress >= 0.75
          ? const Color(0xFFF4C95D)
          : const Color(0xFF34D399);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.ibmPlexSansArabic(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// =====================================================
// REWARDS / LEADERBOARD CARDS
// =====================================================

class _RewardSummarySection extends StatelessWidget {
  final int badgeCount;
  final int streak;
  final bool isDark;

  final VoidCallback onRewardsTap;
  final VoidCallback onLeaderboardTap;

  const _RewardSummarySection({
    required this.badgeCount,
    required this.streak,
    required this.isDark,
    required this.onRewardsTap,
    required this.onLeaderboardTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                emoji: "🏅",
                title: "Rewards",
                value: "$badgeCount badges",
                isDark: isDark,
                onTap: onRewardsTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                emoji: "🔥",
                title: "Current streak",
                value: "$streak days",
                isDark: isDark,
                onTap: onRewardsTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _LeaderboardButton(
          isDark: isDark,
          onTap: onLeaderboardTap,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String value;
  final bool isDark;
  final VoidCallback onTap;

  const _SummaryCard({
    required this.emoji,
    required this.title,
    required this.value,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 118,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF172824)
                : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.04),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                emoji,
                style: const TextStyle(
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts
                    .ibmPlexSansArabic(
                  color: isDark
                      ? AppColors.darkText
                      : AppColors.lightText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                textAlign: TextAlign.center,
                style: GoogleFonts
                    .ibmPlexSansArabic(
                  color: isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _LeaderboardButton({
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 62,
          padding: const EdgeInsets.symmetric(
            horizontal: 17,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF172824)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFF4C95D)
                  .withOpacity(0.14),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 39,
                height: 39,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4C95D)
                      .withOpacity(0.13),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: const Text(
                  "🏆",
                  style: TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "View Leaderboard",
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
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
// TEAM VIEW
// =====================================================

class _TeamChallengeView extends StatelessWidget {
  final bool isDark;

  const _TeamChallengeView({
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 38,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF172824)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFF14B8A6)
                  .withOpacity(0.13),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups_2_outlined,
              color: Color(0xFF14B8A6),
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Team Challenges",
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
            "Create a team, invite friends and complete financial challenges together.",
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkSubText
                  : AppColors.lightSubText,
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 17),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF4C95D)
                  .withOpacity(0.13),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "Coming Soon",
              style: GoogleFonts.ibmPlexSansArabic(
                color: const Color(0xFFF4C95D),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// EMPTY VIEW
// =====================================================

class _EmptyChallengesView extends StatelessWidget {
  final ChallengeStatus status;
  final bool isDark;

  const _EmptyChallengesView({
    required this.status,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    late String title;
    late String description;
    late IconData icon;

    switch (status) {
      case ChallengeStatus.current:
        title = "No active challenges";
        description =
            "Accept an available challenge to start improving your financial habits.";
        icon = Icons.bolt_outlined;
        break;

      case ChallengeStatus.completed:
        title = "No completed challenges";
        description =
            "Your completed challenges will appear here.";
        icon = Icons.emoji_events_outlined;
        break;

      case ChallengeStatus.available:
        title = "No available challenges";
        description =
            "New challenges will be added soon.";
        icon = Icons.explore_outlined;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 44,
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
            size: 45,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkSubText
                  : AppColors.lightSubText,
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// ERROR VIEW
// =====================================================

class _ErrorView extends StatelessWidget {
  final String message;
  final bool isDark;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.isDark,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF172824)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: Color(0xFFFF6B6B),
            size: 45,
          ),
          const SizedBox(height: 15),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            label: const Text("Try Again"),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  const Color(0xFF34D399),
              foregroundColor:
                  const Color(0xFF09231E),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// DETAILS BOTTOM SHEET
// =====================================================

class _ChallengeDetailsSheet extends StatelessWidget {
  final ChallengeModel challenge;
  final bool isDark;
  final VoidCallback onAccept;

  const _ChallengeDetailsSheet({
    required this.challenge,
    required this.isDark,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAvailable =
        challenge.status ==
            ChallengeStatus.available;

    return Container(
      padding: EdgeInsets.fromLTRB(
        22,
        12,
        22,
        MediaQuery.paddingOf(context).bottom + 25,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF10201C)
            : AppColors.lightBackground,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 45,
              height: 5,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white24
                    : Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          const SizedBox(height: 22),

          Row(
            children: [
              Container(
                width: 57,
                height: 57,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399)
                      .withOpacity(0.12),
                  borderRadius:
                      BorderRadius.circular(17),
                ),
                child: Text(
                  challenge.icon,
                  style: const TextStyle(
                    fontSize: 27,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "+${challenge.xpReward} XP reward",
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color:
                            const Color(0xFFF4C95D),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Text(
            "About this challenge",
            style: GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            challenge.description,
            style: GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkSubText
                  : AppColors.lightSubText,
              fontSize: 12,
              height: 1.7,
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _DetailItem(
                  label: "Duration",
                  value:
                      "${challenge.totalDays} days",
                  icon:
                      Icons.calendar_today_outlined,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DetailItem(
                  label: "Progress",
                  value:
                      "${challenge.progressPercentage}%",
                  icon:
                      Icons.trending_up_rounded,
                  isDark: isDark,
                ),
              ),
            ],
          ),

          if (isAvailable) ...[
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF34D399),
                  foregroundColor:
                      const Color(0xFF09231E),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  "Accept Challenge",
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;

  const _DetailItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF172824)
            : Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF34D399),
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText,
                    fontSize: 9,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts
                      .ibmPlexSansArabic(
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