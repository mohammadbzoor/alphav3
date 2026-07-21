import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/models/leader_board.dart';
import 'package:alpha_app/providers/leaderbord_provider.dart';

import 'package:alpha_app/providers/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class LeaderboardScreen
    extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
  });

  @override
  State<LeaderboardScreen>
      createState() =>
          _LeaderboardScreenState();
}

class _LeaderboardScreenState
    extends State<LeaderboardScreen> {
  bool _didLoadData = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didLoadData) return;

    _didLoadData = true;

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) return;

        context
            .read<LeaderboardProvider>()
            .loadLeaderboard();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider =
        context.watch<Themeprovider>();

    final leaderboardProvider =
        context.watch<
            LeaderboardProvider>();

    final bool isDark =
        themeProvider.isDark;

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
        actions: [
          Padding(
            padding:
                const EdgeInsets.only(
              right: 16,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  color:
                      Color(0xFFF4C95D),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  "Hidden",
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkSubText
                        : AppColors
                            .lightSubText,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _buildBody(
          context: context,
          provider:
              leaderboardProvider,
          isDark: isDark,
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required LeaderboardProvider provider,
    required bool isDark,
  }) {
    if (provider.isLoading &&
        provider.leaderboard == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF34D399),
        ),
      );
    }

    final leaderboard =
        provider.leaderboard;

    if (leaderboard == null) {
      return _EmptyLeaderboardView(
        isDark: isDark,
        onRetry: () {
          provider.loadLeaderboard();
        },
      );
    }

    final users =
        [...leaderboard.users]
          ..sort(
            (a, b) =>
                a.rank.compareTo(b.rank),
          );

    final winner =
        users.isNotEmpty
            ? users.first
            : null;

    final remainingUsers =
        users.length > 1
            ? users.sublist(1)
            : <LeaderboardUserModel>[];

    return RefreshIndicator(
      color: const Color(0xFF34D399),
      onRefresh: () async {
        await context
            .read<LeaderboardProvider>()
            .loadLeaderboard();
      },
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          22,
          8,
          22,
          35,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              leaderboard.title,
              style: GoogleFonts
                  .ibmPlexSansArabic(
                color: isDark
                    ? AppColors.darkText
                    : AppColors.lightText,
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              leaderboard.subtitle,
              style: GoogleFonts
                  .ibmPlexSansArabic(
                color: isDark
                    ? AppColors.darkSubText
                    : AppColors.lightSubText,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 22),

            if (winner != null)
              _WinnerCard(
                winner: winner,
                isDark: isDark,
              ),

            const SizedBox(height: 12),

            ListView.separated(
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              itemCount:
                  remainingUsers.length,
              separatorBuilder: (
                context,
                index,
              ) {
                return const SizedBox(
                  height: 8,
                );
              },
              itemBuilder: (
                context,
                index,
              ) {
                return _LeaderboardUserCard(
                  user:
                      remainingUsers[index],
                  isDark: isDark,
                );
              },
            ),

            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  _showInviteDialog(
                    context,
                    isDark,
                  );
                },
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(
                          0xFF1C332D,
                        )
                      : Colors.white,
                  foregroundColor: isDark
                      ? AppColors.darkText
                      : AppColors.lightText,
                  elevation: 0,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white
                            .withOpacity(0.05)
                        : Colors.black
                            .withOpacity(0.05),
                  ),
                ),
                child: Text(
                  "Invite a friend",
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteDialog(
    BuildContext context,
    bool isDark,
  ) {
    final controller =
        TextEditingController();

    showDialog(
      context: context,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          backgroundColor: isDark
              ? const Color(0xFF172824)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(22),
          ),
          title: Text(
            "Invite a friend",
            style: GoogleFonts
                .ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            style: TextStyle(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
            ),
            decoration: InputDecoration(
              hintText:
                  "Email or phone number",
              hintStyle: TextStyle(
                color: isDark
                    ? AppColors.darkSubText
                    : AppColors
                        .lightSubText,
              ),
              filled: true,
              fillColor: isDark
                  ? const Color(
                      0xFF20332E,
                    )
                  : const Color(
                      0xFFF2F6F4,
                    ),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
                borderSide:
                    BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                "Cancel",
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final value =
                    controller.text.trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                );

                ScaffoldMessenger.of(
                  context,
                )
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Invitation sent successfully",
                      ),
                    ),
                  );
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xFF34D399,
                ),
                foregroundColor:
                    const Color(
                  0xFF09231E,
                ),
              ),
              child: const Text(
                "Invite",
              ),
            ),
          ],
        );
      },
    );
  }
}

// =====================================================
// WINNER
// =====================================================

class _WinnerCard extends StatelessWidget {
  final LeaderboardUserModel winner;
  final bool isDark;

  const _WinnerCard({
    required this.winner,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 24,
      ),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF28331F),
                  Color(0xFF123129),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF8DA),
                  Color(0xFFEAF8F2),
                ],
              ),
        borderRadius:
            BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF4C95D)
              .withOpacity(0.12),
        ),
      ),
      child: Column(
        children: [
          Text(
            winner.medal.isEmpty
                ? "🥇"
                : winner.medal,
            style: const TextStyle(
              fontSize: 42,
            ),
          ),

          const SizedBox(height: 9),

          Text(
            winner.name,
            style: GoogleFonts
                .ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          _LevelBadge(
            level: winner.level,
            isDark: isDark,
          ),

          const SizedBox(height: 15),

          Text(
            "${winner.progressPercentage}%",
            style: GoogleFonts
                .ibmPlexSansArabic(
              color:
                  const Color(0xFFF4C95D),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// USER CARD
// =====================================================

class _LeaderboardUserCard
    extends StatelessWidget {
  final LeaderboardUserModel user;
  final bool isDark;

  const _LeaderboardUserCard({
    required this.user,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrentUser =
        user.isCurrentUser;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? isDark
                ? const Color(
                    0xFF1E271B,
                  )
                : const Color(
                    0xFFFFFBEA,
                  )
            : Colors.transparent,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: isCurrentUser
              ? const Color(
                  0xFFF4C95D,
                ).withOpacity(0.45)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Center(
              child: user.medal.isNotEmpty
                  ? Text(
                      user.medal,
                      style:
                          const TextStyle(
                        fontSize: 22,
                      ),
                    )
                  : Text(
                      "${user.rank}",
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color: isDark
                            ? AppColors
                                .darkText
                            : AppColors
                                .lightText,
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  user.isCurrentUser
                      ? "You"
                      : user.name,
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                _LevelBadge(
                  level: user.level,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          Text(
            "${user.progressPercentage}%",
            style:
                GoogleFonts.ibmPlexSansArabic(
              color: isCurrentUser
                  ? const Color(
                      0xFF34D399,
                    )
                  : user.rank <= 3
                      ? const Color(
                          0xFF34D399,
                        )
                      : isDark
                          ? AppColors
                              .darkSubText
                          : AppColors
                              .lightSubText,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final int level;
  final bool isDark;

  const _LevelBadge({
    required this.level,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF20332E)
            : const Color(0xFFE6F0EC),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star_rounded,
            color: Color(0xFFF4C95D),
            size: 13,
          ),

          const SizedBox(width: 4),

          Text(
            "Level $level",
            style:
                GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontSize: 9,
              fontWeight: FontWeight.w600,
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

class _EmptyLeaderboardView
    extends StatelessWidget {
  final bool isDark;
  final VoidCallback onRetry;

  const _EmptyLeaderboardView({
    required this.isDark,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Text(
              "🏆",
              style: TextStyle(
                fontSize: 55,
              ),
            ),

            const SizedBox(height: 15),

            Text(
              "Leaderboard unavailable",
              style: GoogleFonts
                  .ibmPlexSansArabic(
                color: isDark
                    ? AppColors.darkText
                    : AppColors.lightText,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "Join a challenge with friends to see the ranking.",
              textAlign: TextAlign.center,
              style: GoogleFonts
                  .ibmPlexSansArabic(
                color: isDark
                    ? AppColors.darkSubText
                    : AppColors.lightSubText,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 18),

            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xFF34D399,
                ),
                foregroundColor:
                    const Color(
                  0xFF09231E,
                ),
              ),
              child: const Text(
                "Try Again",
              ),
            ),
          ],
        ),
      ),
    );
  }
}