import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/screens/expenses/advice_screen.dart';
import 'package:alpha_app/screens/expenses/new_expense_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ChooseExpenseActionScreen extends StatelessWidget {
  const ChooseExpenseActionScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        context.watch<Themeprovider>().isDark;

    final double screenW =
        Device.width(context);

    final double screenH =
        Device.height(context);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          physics:
              const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: screenW * 0.055,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: screenH * 0.022,
              ),

              Row(
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    borderRadius:
                        BorderRadius.circular(12),
                    child: Container(
                      width: screenW * 0.11,
                      height: screenW * 0.11,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(
                                0xFF203330,
                              )
                            : Colors.white,
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white
                                  .withOpacity(0.04)
                              : Colors.black
                                  .withOpacity(0.05),
                        ),
                      ),
                      child: Icon(
                        Icons
                            .arrow_back_ios_new_rounded,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                        size: screenW * 0.05,
                      ),
                    ),
                  ),

                  SizedBox(
                    width: screenW * 0.035,
                  ),

                  Expanded(
                    child: Text(
                      "New Activity",
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                        fontSize:
                            screenW * 0.065,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(
                height: screenH * 0.018,
              ),

              Text(
                "How would you like to use Alpha today?",
                style:
                    GoogleFonts.ibmPlexSansArabic(
                  color: isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                  fontSize: screenW * 0.036,
                  height: 1.5,
                ),
              ),

              SizedBox(
                height: screenH * 0.035,
              ),

              _ActionCard(
                isDark: isDark,
                screenW: screenW,
                icon:
                    Icons.receipt_long_outlined,
                title: "Record Real Expense",
                subtitle:
                    "Save an actual expense and update your spending analysis.",
                points: const [
                  "Update your real expense balance",
                  "Track needs and wants",
                  "Improve Alpha insights",
                  "Include it in charts and reports",
                ],
                accentColor:
                    const Color(0xFF34D399),
                buttonText: "Record Expense",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const NewExpenseScreen(),
                    ),
                  );
                },
              ),

              SizedBox(
                height: screenH * 0.022,
              ),

              _ActionCard(
                isDark: isDark,
                screenW: screenW,
                icon:
                    Icons.psychology_alt_outlined,
                title: "Ask Financial Advice",
                subtitle:
                    "Thinking about buying something? Ask Alpha before spending.",
                points: const [
                  "Run a what-if simulation",
                  "Check the effect on your goals",
                  "Explore cheaper alternatives",
                  "No expense will be saved",
                ],
                accentColor:
                    const Color(0xFFF4C95D),
                buttonText: "Ask Alpha",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const AdviceScreen(),
                    ),
                  );
                },
              ),

              SizedBox(
                height: screenH * 0.03,
              ),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSecondary
                          .withOpacity(0.08)
                      : AppColors.lightSecondary
                          .withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(
                      0xFF14B8A6,
                    ).withOpacity(0.13),
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 39,
                      height: 39,
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFF14B8A6,
                        ).withOpacity(0.12),
                        borderRadius:
                            BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        color:
                            Color(0xFF14B8A6),
                        size: 21,
                      ),
                    ),

                    const SizedBox(width: 11),

                    Expanded(
                      child: Text(
                        "Recording an expense changes your actual totals. Financial advice is only a simulation and does not affect your balance.",
                        style: GoogleFonts
                            .ibmPlexSansArabic(
                          color: isDark
                              ? AppColors.darkSubText
                              : AppColors.lightSubText,
                          fontSize:
                              screenW * 0.031,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(
                height: screenH * 0.03,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final bool isDark;
  final double screenW;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> points;
  final Color accentColor;
  final String buttonText;
  final VoidCallback onTap;

  const _ActionCard({
    required this.isDark,
    required this.screenW,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.points,
    required this.accentColor,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF172624)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(23),
        border: Border.all(
          color: accentColor.withOpacity(
            isDark ? 0.18 : 0.14,
          ),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color:
                      Colors.black.withOpacity(0.04),
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
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color:
                      accentColor.withOpacity(0.13),
                  borderRadius:
                      BorderRadius.circular(17),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 28,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                        fontSize:
                            screenW * 0.047,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      subtitle,
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkSubText
                            : AppColors.lightSubText,
                        fontSize:
                            screenW * 0.031,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          ...points.map(
            (point) {
              return Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 10,
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      margin:
                          const EdgeInsets.only(
                        top: 1,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor
                            .withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        color: accentColor,
                        size: 13,
                      ),
                    ),

                    const SizedBox(width: 9),

                    Expanded(
                      child: Text(
                        point,
                        style: GoogleFonts
                            .ibmPlexSansArabic(
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                          fontSize:
                              screenW * 0.031,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onTap,
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    accentColor,
                foregroundColor:
                    const Color(0xFF09231E),
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Text(
                    buttonText,
                    style: GoogleFonts
                        .ibmPlexSansArabic(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(width: 7),

                  const Icon(
                    Icons
                        .arrow_forward_rounded,
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}