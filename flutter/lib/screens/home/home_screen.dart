import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/models/home_model.dart';
import 'package:alpha_app/providers/home_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/screens/ai_assistant/chat_screen.dart';
import 'package:alpha_app/screens/analysis/financial_analysis_screen.dart';
import 'package:alpha_app/screens/challenges/chanllenges_screen.dart';
import 'package:alpha_app/screens/expenses/new_expense_screen.dart';
import 'package:alpha_app/screens/goals/goal_history.dart';
import 'package:alpha_app/screens/incomes/incomes_screen.dart';
import 'package:alpha_app/screens/receipts/receipt_input_screen.dart';
import 'package:alpha_app/widgets/Home/progress_card.dart';
import 'package:alpha_app/widgets/Home/quick_actions_grid.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  

  @override
  Widget build(BuildContext context) {
    final homeProvider =
        context.watch<HomeProvider>();

    final themeProvider =
        context.watch<Themeprovider>();

    final isDark = themeProvider.isDark;

    final homeData = homeProvider.homeData;

    final screenW = Device.width(context);
      final screenH = Device.height(context);
       

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SafeArea(
        child: _buildBody(
          context: context,
          homeProvider: homeProvider,
          homeData: homeData,
          isDark: isDark,
          screenWidth: screenW,
          screenHeight: screenH
        ),
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

    if (homeProvider.isLoading &&
        homeData == null) {
      return Center(
        child: CircularProgressIndicator(
          color: isDark
              ? AppColors.darkPrimary
              : AppColors.lightPrimary,
        ),
      );
    }

    if (homeProvider.hasError &&
        homeData == null) {
      return _HomeErrorView(
        message: homeProvider.errorMessage ??
            "Something went wrong",
        isDark: isDark,
        onRetry: () {
          context
              .read<HomeProvider>()
              .loadHomeData();
        },
      );
    }

    if (homeData == null) {
      return const SizedBox.shrink();
    }

    return RefreshIndicator(
      color: isDark
          ? AppColors.darkPrimary
          : AppColors.lightPrimary,
      onRefresh: () {
        return context
            .read<HomeProvider>()
            .refreshHomeData();
      },
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          screenWidth * 0.055,
          20,
          screenWidth * 0.055,
          125,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
           
            _HomeHeader(
              userName: homeData.userName,
              isDark: isDark,
              onNotificationTap: () {},
            ),

          SizedBox(height: screenHeight*0.03),

            _FinancialScoreCard(
              score: homeData.financialScore,
              scoreMessage: homeData.scoreMessage,
              scoreLevel: homeData.scoreLevel,
              isDark: isDark,
            ),

           SizedBox(height: screenHeight*0.03),

            _FinancialSummarySection(
              income: homeData.income,
              expenses: homeData.expenses,
              savings: homeData.savings,
              isDark: isDark,
            ),

           SizedBox(height: screenHeight*0.03),

            _SectionTitle(
              title: "Today's Insight",
              isDark: isDark,
            ),

            SizedBox(height: screenHeight*0.015),

            _TodayInsightCard(
              insight: homeData.todayInsight,
              isDark: isDark,
              onViewAdvice: () {
               Navigator.push(context, MaterialPageRoute(builder: (context) => FinancialAnalysisScreen(),));
              },
            ),

            if (homeData.goal != null) ...[
              SizedBox(height: screenHeight*0.03),

              _SectionTitle(
                title: "Goal Progress",
                isDark: isDark,
                actionText: "View All",
                onActionTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => MyGoalsScreen()),) ;
                },
              ),

            SizedBox(height: screenHeight*0.015),

             ProgressCard(
  title: homeData.goal!.name,
  subtitle: "Keep saving to reach your goal",
  progress: homeData.goal!.progress,
  color: isDark ? AppColors.darkAccent  : AppColors.lightAccent,
  icon: Icons.flag_outlined,
  isDark: isDark,
),
            ],

            if (homeData.challenge != null) ...[
            SizedBox(height: screenHeight*0.03),

              _SectionTitle(
                title: "Active Challenge",
                isDark: isDark,
                actionText: "View",
                onActionTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ChallengesScreen(),));
                },
              ),

              SizedBox(height: screenHeight*0.015),

             ProgressCard(
  title: homeData.challenge!.name,
  subtitle: "You're getting closer to completing it",
  progress: homeData.challenge!.progress,
  color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
  icon: Icons.emoji_events_outlined,
  isDark: isDark,
),
            ],

            SizedBox(height: screenHeight*0.03),

            _SectionTitle(
              title: "Quick Actions",
              isDark: isDark,
            ),

            SizedBox(height: screenHeight*0.015),
QuickActionsGrid(
  isDark: isDark,

  onAddExpense: () {
      Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const NewExpenseScreen(),
      ),
    );
  },

  onAnalytics: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const FinancialAnalysisScreen(),
      ),
    );
  },

  onScanReceipt: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const ReceiptInputScreen(),
      ),
    );
  },

  onChallenges: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const ChallengesScreen(),
      ),
    );
  },
),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// HEADER
// =====================================================

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
    final displayName = userName.trim().isEmpty
        ? "User"
        : userName.trim();

    final firstLetter =
        displayName[0].toUpperCase();

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
            borderRadius:
                BorderRadius.circular(16),
          ),
          child: Text(
            firstLetter,
            style:
                GoogleFonts.ibmPlexSansArabic(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

         SizedBox(width: 13),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                "Hello, $displayName 👋",
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: GoogleFonts
                    .ibmPlexSansArabic(
                  color: isDark
                      ? AppColors.darkText
                      : AppColors.lightText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                "Let's improve your finances today",
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: GoogleFonts
                    .ibmPlexSansArabic(
                  color: isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),

       // const SizedBox(width: 10),

        // InkWell(
        //   onTap: onNotificationTap,
        //   borderRadius:
        //       BorderRadius.circular(15),
        //   child: Container(
        //     width: 46,
        //     height: 46,
        //     decoration: BoxDecoration(
        //       color: isDark
        //           ? const Color(0xFF172624)
        //           : Colors.white,
        //       borderRadius:
        //           BorderRadius.circular(15),
        //       border: Border.all(
        //         color: isDark
        //             ? Colors.white
        //                 .withOpacity(0.05)
        //             : Colors.black
        //                 .withOpacity(0.05),
        //       ),
        //       boxShadow: isDark
        //           ? null
        //           : [
        //               BoxShadow(
        //                 color: Colors.black
        //                     .withOpacity(0.04),
        //                 blurRadius: 12,
        //                 offset:
        //                     const Offset(0, 5),
        //               ),
        //             ],
        //     ),
        //     child: const Icon(
        //       Icons.notifications_none_rounded,
        //       color: Color(0xFFF4C95D),
        //       size: 24,
        //     ),
        //   ),
        // ),
      ],
    );
  }
}

// =====================================================
// FINANCIAL SCORE
// =====================================================

class _FinancialScoreCard
    extends StatelessWidget {
  final int score;
  final String scoreMessage;
  final String scoreLevel;
  final bool isDark;

  const _FinancialScoreCard({
    required this.score,
    required this.scoreMessage,
    required this.scoreLevel,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final safeScore =
        score.clamp(0, 100);

    final scoreProgress =
        safeScore / 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
       color: isDark ? AppColors.darkPrimary.withOpacity(0.04) : AppColors.lightPrimary.withOpacity(0.04),
      
        borderRadius:
            BorderRadius.circular(26),
        border: Border.all(
          color: isDark
              ? AppColors.darkPrimary
              : AppColors.lightPrimary,
             
        ),
       
              
      ),
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 55,
            lineWidth: 9,
            percent:
                scoreProgress.clamp(0.0, 1.0),
            animation: true,
            animationDuration: 850,
            circularStrokeCap:
                CircularStrokeCap.round,
            backgroundColor: isDark
                ? AppColors.darkBorder : AppColors.lightBorder,
            progressColor:
                const Color(0xFF34D399),
            center: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(
                  "$safeScore",
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Text(
                  "Score",
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkText
                        : AppColors
                            .lightText,
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 20),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  "Financial Score",
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  scoreMessage.trim().isEmpty
                      ? 'Your financial score details will appear here.'
                      : scoreMessage,
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkSubText
                        : AppColors
                            .lightSubText,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                      isDark ? AppColors.darkPrimary.withOpacity(0.08) : AppColors.lightPrimary.withOpacity(0.08),
                    borderRadius:
                        BorderRadius.circular(30),
                  ),
                  child: Text(
                    scoreLevel.trim().isEmpty
                        ? 'Not available'
                        : scoreLevel,
                    style: GoogleFonts
                        .ibmPlexSansArabic(
                      color:
                          isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w600,
                    ),
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
// SUMMARY
// =====================================================

class _FinancialSummarySection
    extends StatelessWidget {
  final double income;
  final double expenses;
  final double savings;
  final bool isDark;

  const _FinancialSummarySection({
    required this.income,
    required this.expenses,
    required this.savings,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const IncomesScreen()),
              );
            },
            child: _SummaryCard(
              title: "Income",
              amount: income,
              icon: Icons.south_west_rounded,
              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              isDark: isDark,
            ),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _SummaryCard(
            title: "Expenses",
            amount: expenses,
            icon:
                Icons.north_east_rounded,
            color:
                isDark ? AppColors.darkError : AppColors.lightError,
            isDark: isDark,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _SummaryCard(
            title: "Savings",
            amount: savings,
            icon: Icons
                .account_balance_wallet_outlined,
            color:
                isDark ? AppColors.darkAccent : AppColors.lightAccent,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkBorder.withOpacity(0.4)
            :AppColors.lightBorder.withOpacity(0.4),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : AppColors.lightBorder
        ),
      
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkSubText
                  : AppColors.lightSubText,
              fontSize: 10,
            ),
          ),

          const SizedBox(height: 3),

          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "${amount.toStringAsFixed(0)} JD",
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
        ],
      ),
    );
  }
}

// =====================================================
// SECTION TITLE
// =====================================================

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;
  final String? actionText;
  final VoidCallback? onActionTap;

  const _SectionTitle({
    required this.title,
    required this.isDark,
    this.actionText,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style:
                GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        if (actionText != null)
          TextButton(
            onPressed: onActionTap,
            style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 6,
              ),
              minimumSize: Size.zero,
              tapTargetSize:
                  MaterialTapTargetSize
                      .shrinkWrap,
            ),
            child: Text(
              actionText!,
              style: GoogleFonts
                  .ibmPlexSansArabic(
                color:
                   isDark? AppColors.darkPrimary : AppColors.lightPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

// =====================================================
// TODAY INSIGHT
// =====================================================

class _TodayInsightCard
    extends StatelessWidget {
  final String insight;
  final bool isDark;
  final VoidCallback onViewAdvice;

  const _TodayInsightCard({
    required this.insight,
    required this.isDark,
    required this.onViewAdvice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
       color: isDark ? AppColors.darkAccent.withOpacity(0.2) : AppColors.lightAccent.withOpacity(0.2),
        borderRadius:
            BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color:
                     isDark ? AppColors.darkAccent.withOpacity(0.12) : AppColors.lightAccent.withOpacity(0.12),
                        
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child:  Icon(
                  Icons.auto_awesome_rounded,
                  color: isDark ?
                   AppColors.darkAccent : AppColors.lightAccent,
                  size: 21,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  "Alpha Smart Insight",
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkAccent.withOpacity(0.12) : AppColors.lightAccent.withOpacity(0.12),
                    
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child: Text(
                  "AI",
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: isDark ?
                      AppColors.darkAccent : AppColors.lightAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            insight.isEmpty
                ? "Your financial insight will appear here."
                : insight,
            style:
                GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontSize: 13,
              height: 1.65,
            ),
          ),

          const SizedBox(height: 15),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: onViewAdvice,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ?
                   AppColors.darkAccent : AppColors.lightAccent, 
                
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
              ),
              child: Text(
                "View Advice",
                style: GoogleFonts
                    .ibmPlexSansArabic(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
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
// ERROR VIEW
// =====================================================

class _HomeErrorView
    extends StatelessWidget {
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
                color:  isDark ? AppColors.darkError.withOpacity(0.12) : AppColors.lightError
                    .withOpacity(0.12),
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
              style:
                  GoogleFonts.ibmPlexSansArabic(
                color: isDark
                    ? AppColors.darkText
                    : AppColors.lightText,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.ibmPlexSansArabic(
                color: isDark
                    ? AppColors.darkSubText
                    : AppColors.lightSubText,
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
                backgroundColor: isDark
                    ? AppColors.darkPrimary
                    : AppColors.lightPrimary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
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