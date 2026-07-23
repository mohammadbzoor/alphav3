import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/models/home_model.dart';
import 'package:alpha_app/providers/home_provider.dart';
import 'package:alpha_app/providers/profile_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/providers/expense_provider.dart';
import 'package:alpha_app/screens/analysis/financial_analysis_center_screen.dart';
import 'package:alpha_app/screens/challenges/chanllenges_screen.dart';
import 'package:alpha_app/screens/expenses/new_expense_screen.dart';
import 'package:alpha_app/screens/goals/goal_history.dart';
import 'package:alpha_app/screens/receipts/receipt_input_screen.dart';
import 'package:alpha_app/screens/notifications/notifications_screen.dart';
import 'package:alpha_app/providers/notification_provider.dart';
import 'package:alpha_app/providers/challenge_provider.dart';
import 'package:alpha_app/widgets/Home/progress_card.dart';
import 'package:alpha_app/widgets/Home/quick_actions_grid.dart';
import 'package:alpha_app/providers/cycle_provider.dart';
import 'package:alpha_app/providers/onboarding_provider.dart';
import 'package:alpha_app/widgets/app_button.dart';
import 'package:alpha_app/widgets/complete_profile_card.dart';
import 'package:alpha_app/screens/profile/financial_profile_screen.dart';
import 'package:alpha_app/core/utils/onboarding_guard.dart';
import 'package:alpha_app/screens/planning/savings_allocation_screen.dart';
import 'package:alpha_app/core/utils/dashboard_action_result.dart';
import 'package:alpha_app/widgets/dashboard/cycle_header.dart';
import 'package:alpha_app/widgets/dashboard/income_overview.dart';
import 'package:alpha_app/widgets/dashboard/safe_daily_spending.dart';
import 'package:alpha_app/widgets/dashboard/bucket_cards.dart';
import 'package:alpha_app/widgets/dashboard/commitments_summary.dart';
import 'package:alpha_app/widgets/dashboard/goals_summary.dart';
import 'package:alpha_app/widgets/dashboard/dashboard_warnings.dart';
import 'package:alpha_app/widgets/dashboard/section_title.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _didLoadDashboard = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_didLoadDashboard && mounted) {
        _didLoadDashboard = true;
        _initializeDashboard();
      }
    });
  }

  Future<void> _initializeDashboard() async {
    if (!mounted) return;

    final onboardingProvider = context.read<OnboardingProvider>();
    final cycleProvider = context.read<CycleProvider>();
    final homeProvider = context.read<HomeProvider>();
    final profileProvider = context.read<ProfileProvider>();

    // 1. Load Onboarding status
    await onboardingProvider.checkOnboardingStatus();
    if (!mounted) return;

    if (!onboardingProvider.isOnboarded) {
      // Not onboarded -> CompleteProfileCard only, do NOT load financial data
      return;
    }

    // Load profile summary safely in background
    if (!profileProvider.hasProfile && !profileProvider.isLoading) {
      profileProvider.loadProfileSummary().catchError((_) {});
    }

    // 2. Load Current Cycle
    await cycleProvider.loadCurrentCycle();
    if (!mounted) return;

    if (!cycleProvider.hasActiveCycle) {
      // No active cycle -> StartCycleCard only, do NOT load dashboard data
      return;
    }

    // 3. Load Dashboard Data (which internally handles expenses, etc.)
    if (!homeProvider.hasData && !homeProvider.isLoading) {
      await homeProvider.loadHomeData();
    }
    
    // 4. Fetch Notifications Unread Count
    if (mounted) {
      context.read<NotificationProvider>().fetchUnreadCount();
      context.read<ChallengeProvider>().loadChallenges();
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();

    final themeProvider = context.watch<Themeprovider>();

    final isDark = themeProvider.isDark;

    final homeData = homeProvider.homeData;

    final screenW = Device.width(context);
    final screenH = Device.height(context);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: _buildBody(
            context: context,
            homeProvider: homeProvider,
            homeData: homeData,
            isDark: isDark,
            screenWidth: screenW,
            screenHeight: screenH),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required HomeProvider homeProvider,
    required HomeModel? homeData,
    required bool isDark,
    required double screenWidth,
    required double screenHeight,
  }) {
    final cycleProvider = context.watch<CycleProvider>();
    final onboardingProvider = context.watch<OnboardingProvider>();
    final profileProvider = context.watch<ProfileProvider>();

    // 1. Onboarding Loading
    if (onboardingProvider.isLoading) {
      return Center(
        child: CircularProgressIndicator(
            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
      );
    }

    // 2. Onboarding Error
    if (onboardingProvider.errorMessage != null) {
      return _HomeErrorView(
        message:
            onboardingProvider.errorMessage ?? "تعذر تحميل بيانات الملف المالي",
        isDark: isDark,
        onRetry: () => onboardingProvider.checkOnboardingStatus(),
      );
    }

    // 3. Not Onboarded
    if (!onboardingProvider.isOnboarded) {
      return _buildScrollableContent(
        context: context,
        isDark: isDark,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HomeHeader(
                userName: profileProvider.displayName,
                isDark: isDark,
                onNotificationTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
            _BirthdayGreetingCard(
              isDark: isDark,
              profileProvider: profileProvider,
            ),
            SizedBox(height: screenHeight * 0.03),
            CompleteProfileCard(isDark: isDark),
          ],
        ),
      );
    }

    // 3.5. Onboarded but Financial Profile Incomplete
    if (!onboardingProvider.financialProfileComplete) {
      return _buildScrollableContent(
        context: context,
        isDark: isDark,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HomeHeader(
                userName: profileProvider.displayName,
                isDark: isDark,
                onNotificationTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
            _BirthdayGreetingCard(
              isDark: isDark,
              profileProvider: profileProvider,
            ),
            SizedBox(height: screenHeight * 0.03),
            _FinancialProfileNeedsAttentionCard(
              isDark: isDark,
              missingFields: onboardingProvider.missingFinancialFields,
              onCompleteTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FinancialProfileScreen()));
              },
            ),
          ],
        ),
      );
    }

    // 4. Cycle Loading
    if (cycleProvider.isLoading) {
      return Center(
        child: CircularProgressIndicator(
            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
      );
    }

    // 5. Cycle Error
    if (cycleProvider.error != null) {
      return _HomeErrorView(
        message: cycleProvider.error!,
        isDark: isDark,
        onRetry: () => cycleProvider.loadCurrentCycle(),
      );
    }

    // 6. No Active Cycle
    if (!cycleProvider.hasActiveCycle) {
      return _buildScrollableContent(
        context: context,
        isDark: isDark,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HomeHeader(
                userName: profileProvider.displayName,
                isDark: isDark,
                onNotificationTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
            _BirthdayGreetingCard(
              isDark: isDark,
              profileProvider: profileProvider,
            ),
            SizedBox(height: screenHeight * 0.03),
            _StartCycleCard(
              isDark: isDark,
              isLoading: cycleProvider.isCreatingCycle,
              onStart: () async {
                final success = await context
                    .read<CycleProvider>()
                    .createCycle({}, context.read<OnboardingProvider>());
                if (success && context.mounted) {
                  final cycleId = context.read<CycleProvider>().currentCycle['id']?.toString();
                  if (cycleId != null) {
                    final approved = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SavingsAllocationScreen(cycleId: cycleId),
                      ),
                    );
                    if (approved == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("تم بدء دورتك المالية بنجاح",
                              style: GoogleFonts.ibmPlexSansArabic()),
                          backgroundColor: isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary,
                        ),
                      );
                    }
                  }
                } else if (context.mounted &&
                    context.read<CycleProvider>().error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.read<CycleProvider>().error!,
                          style: GoogleFonts.ibmPlexSansArabic()),
                      backgroundColor:
                          isDark ? AppColors.darkError : AppColors.lightError,
                    ),
                  );
                  context.read<CycleProvider>().clearError();
                }
              },
            ),
          ],
        ),
      );
    }

    // 7. Home Loading
    if (homeProvider.isLoading) {
      return Center(
        child: CircularProgressIndicator(
            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
      );
    }

    // 8. Home Error
    if (homeProvider.hasError) {
      return _HomeErrorView(
        message: homeProvider.errorMessage ?? "تعذر تحميل لوحة التحكم",
        isDark: isDark,
        onRetry: () => context.read<HomeProvider>().loadHomeData(),
      );
    }

    // 9. Dashboard data is ready
    if (homeData == null) {
      return _HomeErrorView(
        message: "حدث خطأ غير متوقع",
        isDark: isDark,
        onRetry: () => context.read<HomeProvider>().loadHomeData(),
      );
    }

    return _buildScrollableContent(
      context: context,
      isDark: isDark,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeHeader(
              userName: profileProvider.displayName,
              isDark: isDark,
              onNotificationTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
          _BirthdayGreetingCard(
            isDark: isDark,
            profileProvider: profileProvider,
          ),
          SizedBox(height: screenHeight * 0.03),
          // 1. Warnings
          DashboardWarningsWidget(warnings: homeData.warnings, isDark: isDark),
          if (homeData.warnings.isNotEmpty &&
              !homeData.warnings.every((w) => w == 'NO_ACTIVE_FINANCIAL_CYCLE'))
            SizedBox(height: screenHeight * 0.02),

          // 2. Cycle Header
          CycleHeader(cycle: homeData.cycle, isDark: isDark),
          SizedBox(height: screenHeight * 0.03),

          // 3. Income Overview
          IncomeOverview(income: homeData.income, isDark: isDark),
          SizedBox(height: screenHeight * 0.03),

          // 4. Safe Daily Spending
          SafeDailySpendingCard(
            safeDailySpending: homeData.safeDailySpending,
            isDark: isDark,
          ),
          SizedBox(height: screenHeight * 0.03),

          // 5. Buckets (Needs, Wants, Savings)
          SectionTitle(title: "Budgets & Savings", isDark: isDark),
          SizedBox(height: screenHeight * 0.015),
          BucketCardsSection(buckets: homeData.buckets, isDark: isDark),
          SizedBox(height: screenHeight * 0.03),

          // 6. Commitments Summary
          CommitmentsSummaryWidget(
            commitments: homeData.commitments,
            isDark: isDark,
            onViewCommitments: () {
              // Navigate to commitments list
            },
          ),
          if ((homeData.commitments?.totalReserved ?? 0) > 0 ||
              (homeData.commitments?.upcomingCount ?? 0) > 0 ||
              (homeData.commitments?.overdueCount ?? 0) > 0)
            SizedBox(height: screenHeight * 0.03),

          // 7. Goals Summary
          GoalsSummaryWidget(
            goals: homeData.goals,
            isDark: isDark,
            onViewGoals: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MyGoalsScreen()),
              );
            },
          ),
          if ((homeData.goals?.activeCount ?? 0) > 0 ||
              (homeData.goals?.readyCount ?? 0) > 0)
            SizedBox(height: screenHeight * 0.03),

          // 8. Quick Actions Grid
          SectionTitle(title: "Quick Actions", isDark: isDark),
          SizedBox(height: screenHeight * 0.015),
          Consumer<ChallengeProvider>(
            builder: (context, challengeProvider, child) {
              final activeChallenge = challengeProvider.firstActiveChallenge;
              if (activeChallenge == null) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProgressCard(
                    title: activeChallenge.title,
                    subtitle: activeChallenge.description,
                    progress: activeChallenge.progress,
                    color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    icon: Icons.star,
                    isDark: isDark,
                  ),
                  SizedBox(height: screenHeight * 0.03),
                ],
              );
            },
          ),
          QuickActionsGrid(
            isDark: isDark,
            onAddExpense: () async {
              if (!requireOnboarding(context)) return;
              if (!cycleProvider.hasActiveCycle) {
                _showNoCycleMessage(context, isDark);
                return;
              }
              final result = await Navigator.push<DashboardActionResult>(
                context,
                MaterialPageRoute(
                  builder: (_) => const NewExpenseScreen(),
                ),
              );
              if (result == DashboardActionResult.created && context.mounted) {
                context.read<ExpenseProvider>().loadExpenses();
                context.read<HomeProvider>().refreshHomeData();
              }
            },
            onAnalytics: () {
              if (!requireOnboarding(context)) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FinancialAnalysisCenterScreen(),
                ),
              );
            },
            onScanReceipt: () async {
              if (!requireOnboarding(context)) return;
              if (!cycleProvider.hasActiveCycle) {
                _showNoCycleMessage(context, isDark);
                return;
              }
              final result = await Navigator.push<DashboardActionResult>(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReceiptInputScreen(),
                ),
              );
              if (result == DashboardActionResult.created && context.mounted) {
                context.read<ExpenseProvider>().loadExpenses();
                context.read<HomeProvider>().refreshHomeData();
              }
            },
            onChallenges: () {
              if (!requireOnboarding(context)) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChallengesScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableContent({
    required BuildContext context,
    required bool isDark,
    required double screenWidth,
    required double screenHeight,
    required Widget child,
  }) {
    return RefreshIndicator(
      color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
      onRefresh: () async {
        await context.read<CycleProvider>().loadCurrentCycle();
        if (context.read<CycleProvider>().hasActiveCycle) {
          await context.read<HomeProvider>().refreshHomeData();
          await context.read<ExpenseProvider>().loadExpenses();
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          screenWidth * 0.055,
          20,
          screenWidth * 0.055,
          125,
        ),
        child: child,
      ),
    );
  }

  void _showNoCycleMessage(BuildContext context, bool isDark) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "ابدأ دورة مالية أولًا.",
          style: GoogleFonts.ibmPlexSansArabic(),
        ),
        backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _StartCycleCard extends StatelessWidget {
  final bool isDark;
  final bool isLoading;
  final VoidCallback onStart;

  const _StartCycleCard({
    Key? key,
    required this.isDark,
    required this.isLoading,
    required this.onStart,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkPrimary.withOpacity(0.1)
                      : AppColors.lightPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color:
                      isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "ابدأ دورتك المالية",
                      style: GoogleFonts.ibmPlexSansArabic(
                        color:
                            isDark ? AppColors.darkText : AppColors.lightText,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "الملف المالي مكتمل. ابدأ دورة جديدة لتنظيم ميزانيتك.",
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkSubText
                            : AppColors.lightSubText,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: AppButton(
              text: "بدء الدورة الآن",
              onPressed: onStart,
              isLoading: isLoading,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// HEADER
// =====================================================

class _BirthdayGreetingCard extends StatelessWidget {
  final bool isDark;
  final ProfileProvider profileProvider;

  const _BirthdayGreetingCard({
    required this.isDark,
    required this.profileProvider,
  });

  @override
  Widget build(BuildContext context) {
    if (!profileProvider.isBirthdayToday) {
      return const SizedBox.shrink();
    }

    final name = profileProvider.firstName.isEmpty
        ? 'صديقنا'
        : profileProvider.firstName;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF243424),
                  Color(0xFF493A18),
                ]
              : const [
                  Color(0xFFFFFBEB),
                  Color(0xFFEFFDF5),
                ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? AppColors.darkAccent.withOpacity(0.5)
              : AppColors.lightAccent.withOpacity(0.45),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkAccent.withOpacity(0.16)
                  : AppColors.lightAccent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.cake_rounded,
              color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'عيد ميلاد سعيد يا $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'نتمنى لك سنة جميلة ومليانة راحة ونجاحات صغيرة تكبر مع الوقت.',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color:
                        isDark ? AppColors.darkSubText : AppColors.lightSubText,
                    fontSize: 12.5,
                    height: 1.45,
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

class _HomeHeader extends StatelessWidget {
  final String userName;
  final bool isDark;
  final VoidCallback onNotificationTap;

  const _HomeHeader({
    required this.userName,
    required this.isDark,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = userName.trim().isEmpty ? "User" : userName.trim();

    final firstLetter = displayName[0].toUpperCase();

    return Row(
      children: [
        Container(
          width: 49,
          height: 49,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF34D399),
                Color(0xFF14B8A6),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            firstLetter,
            style: GoogleFonts.ibmPlexSansArabic(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        SizedBox(width: 13),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hello, $displayName 👋",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Let's improve your finances today",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexSansArabic(
                  color:
                      isDark ? AppColors.darkSubText : AppColors.lightSubText,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),

        Consumer<NotificationProvider>(
          builder: (context, notificationProvider, _) {
            final unreadCount = notificationProvider.unreadCount;
            return InkWell(
              onTap: onNotificationTap,
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF172624) : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.05),
                      ),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFFF4C95D),
                      size: 26,
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// =====================================================
// FINANCIAL SCORE
// =====================================================

// =====================================================
// ERROR VIEW
// =====================================================

class _HomeErrorView extends StatelessWidget {
  final String message;
  final bool isDark;
  final VoidCallback onRetry;

  const _HomeErrorView({
    required this.message,
    required this.isDark,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkError.withOpacity(0.12)
                    : AppColors.lightError.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                color: Color(0xFFFF6B6B),
                size: 35,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "Unable to load home data",
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                color: isDark ? AppColors.darkText : AppColors.lightText,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text("Try Again"),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinancialProfileNeedsAttentionCard extends StatelessWidget {
  final bool isDark;
  final List<String> missingFields;
  final VoidCallback onCompleteTap;

  const _FinancialProfileNeedsAttentionCard({
    Key? key,
    required this.isDark,
    required this.missingFields,
    required this.onCompleteTap,
  }) : super(key: key);

  String _formatMissingFields() {
    if (missingFields.isEmpty) return "يرجى مراجعة ملفك المالي.";
    final map = {
      'expectedMonthlyIncome': 'الدخل الشهري المتوقع',
      'paymentDay': 'يوم استلام الدخل',
      'currency': 'العملة',
      'allocation_preferences': 'تفضيلات التوزيع (Allocation)',
      'valid_allocation_bps': 'صحة التوزيع المئوي للنسب',
      'financial_profiles': 'الملف المالي الأساسي'
    };
    final names = missingFields.map((f) => map[f] ?? f).join('، ');
    return "البيانات الناقصة أو غير الصالحة: $names";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.orange.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Colors.orange,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "الملف المالي غير مكتمل",
                      style: GoogleFonts.ibmPlexSansArabic(
                        color:
                            isDark ? AppColors.darkText : AppColors.lightText,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatMissingFields(),
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkSubText
                            : AppColors.lightSubText,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: AppButton(
              text: "أكمل ملفك المالي",
              onPressed: onCompleteTap,
              isLoading: false,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}
