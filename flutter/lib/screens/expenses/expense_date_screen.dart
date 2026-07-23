import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:table_calendar/table_calendar.dart';

class ExpenseDateScreen extends StatefulWidget {
  final DateTime? initialDate;
  final bool isRecurring;

  const ExpenseDateScreen({
    super.key,
    this.initialDate,
    this.isRecurring = false,
  });

  @override
  State<ExpenseDateScreen> createState() => _ExpenseDateScreenState();
}

class _ExpenseDateScreenState extends State<ExpenseDateScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  late int _selectedYear;

  DateTime get _today {
    final now = DateTime.now();

    return DateTime(
      now.year,
      now.month,
      now.day,
    );
  }

  @override
  void initState() {
    super.initState();

    final initialDate = widget.initialDate ?? _today;

    final normalizedInitialDate = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );

    _selectedDay =
        (widget.isRecurring || !normalizedInitialDate.isAfter(_today))
            ? normalizedInitialDate
            : _today;

    _focusedDay = _selectedDay!;
    _selectedYear = _selectedDay!.year;
  }

  @override
  Widget build(BuildContext context) {
    final screenW = Device.width(context);
    final screenH = Device.height(context);

    final themeProvider = context.watch<Themeprovider>();

    final bool isDark = themeProvider.isDark;

    return SafeArea(
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenW * 0.05,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                SizedBox(
                  height: screenH * 0.03,
                ),

                // ================= HEADER =================

                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: screenW * 0.11,
                        height: screenW * 0.11,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          borderRadius: BorderRadius.circular(
                            12,
                          ),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color:
                              isDark ? AppColors.darkText : AppColors.lightText,
                          size: screenW * 0.05,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: screenW * 0.035,
                    ),
                    Expanded(
                      child: Text(
                        "Expense Date",
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: screenW * 0.065,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(
                  height: screenH * 0.015,
                ),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Select the date when this expense occurred.",
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: screenW * 0.034,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.darkSubText
                          : AppColors.lightSubText,
                    ),
                  ),
                ),

                SizedBox(
                  height: screenH * 0.025,
                ),

                // ================= YEARS =================

                SizedBox(
                  height: screenH * 0.06,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    itemCount: widget.isRecurring ? 30 : 20,
                    itemBuilder: (
                      context,
                      index,
                    ) {
                      final baseYear = widget.isRecurring
                          ? DateTime.now().year + 10
                          : DateTime.now().year;
                      final year = baseYear - index;

                      final isSelected = year == _selectedYear;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedYear = year;

                            int month = _focusedDay.month;

                            int day = _focusedDay.day;

                            DateTime newFocused = DateTime(
                              year,
                              month,
                              day,
                            );

                            if (!widget.isRecurring &&
                                newFocused.isAfter(_today)) {
                              newFocused = _today;
                            }

                            _focusedDay = newFocused;
                            _selectedDay = newFocused;
                          });
                        },
                        child: Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: screenW * 0.015,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: screenW * 0.05,
                            vertical: screenH * 0.01,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                    ? AppColors.darkSecondary
                                    : AppColors.lightSecondary)
                                : (isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder),
                            borderRadius: BorderRadius.circular(
                              20,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              "$year",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? AppColors.darkBorder
                                    : (isDark
                                        ? AppColors.darkSubText
                                        : AppColors.lightSubText),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                SizedBox(
                  height: screenH * 0.02,
                ),

                // ================= CALENDAR =================

                Container(
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: TableCalendar(
                    locale: 'en_US',

                    // يسمح بتاريخ قديم حتى 20 سنة.
                    firstDay: DateTime(
                      DateTime.now().year - 20,
                      1,
                      1,
                    ),

                    // لا يسمح بالمستقبل.
                    lastDay: widget.isRecurring
                        ? DateTime(_today.year + 10, 12, 31)
                        : _today,

                    focusedDay:
                        (!widget.isRecurring && _focusedDay.isAfter(_today))
                            ? _today
                            : _focusedDay,

                    calendarFormat: CalendarFormat.month,

                    selectedDayPredicate: (
                      day,
                    ) {
                      return isSameDay(
                        _selectedDay,
                        day,
                      );
                    },

                    enabledDayPredicate: (
                      day,
                    ) {
                      if (widget.isRecurring) return true;

                      final normalizedDay = DateTime(
                        day.year,
                        day.month,
                        day.day,
                      );

                      return !normalizedDay.isAfter(_today);
                    },

                    onDaySelected: (
                      selectedDay,
                      focusedDay,
                    ) {
                      final normalizedDay = DateTime(
                        selectedDay.year,
                        selectedDay.month,
                        selectedDay.day,
                      );

                      if (!widget.isRecurring &&
                          normalizedDay.isAfter(_today)) {
                        return;
                      }

                      setState(() {
                        _selectedDay = normalizedDay;

                        _focusedDay = normalizedDay;

                        _selectedYear = normalizedDay.year;
                      });
                    },

                    onPageChanged: (
                      focusedDay,
                    ) {
                      DateTime safeDate = focusedDay;

                      if (!widget.isRecurring && safeDate.isAfter(_today)) {
                        safeDate = _today;
                      }

                      setState(() {
                        _focusedDay = safeDate;

                        _selectedYear = safeDate.year;
                      });
                    },

                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: GoogleFonts.ibmPlexSansArabic(
                        fontSize: screenW * 0.055,
                        fontWeight: FontWeight.bold,
                        color:
                            isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                      leftChevronIcon: Icon(
                        Icons.chevron_left,
                        color:
                            isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                      rightChevronIcon: Icon(
                        Icons.chevron_right,
                        color:
                            isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),

                    calendarStyle: CalendarStyle(
                      defaultTextStyle: TextStyle(
                        color: isDark
                            ? AppColors.darkSubText
                            : AppColors.lightSubText,
                        fontWeight: FontWeight.w500,
                      ),
                      weekendTextStyle: TextStyle(
                        color: isDark
                            ? AppColors.darkSubText
                            : AppColors.lightSubText,
                        fontWeight: FontWeight.w500,
                      ),
                      disabledTextStyle: TextStyle(
                        color: isDark
                            ? AppColors.darkSubText.withOpacity(
                                0.35,
                              )
                            : AppColors.lightSubText.withOpacity(
                                0.35,
                              ),
                      ),
                      selectedDecoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSecondary
                            : AppColors.lightSecondary,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary,
                        ),
                      ),
                      todayTextStyle: TextStyle(
                        color: isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                SizedBox(
                  height: screenH * 0.02,
                ),

                // ================= SELECTED DATE =================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(
                    20,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Selected date",
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkSubText
                              : AppColors.lightSubText,
                          fontSize: screenW * 0.04,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(
                        height: screenH * 0.01,
                      ),
                      Text(
                        DateFormat(
                          'MMMM d, yyyy',
                          'en_US',
                        ).format(
                          _selectedDay!,
                        ),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: screenW * 0.06,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  height: screenH * 0.025,
                ),

                // ================= CONFIRM =================

                Padding(
                  padding: EdgeInsets.only(
                    bottom: screenH * 0.02,
                  ),
                  child: AppButton(
                    text: "Confirm Date",
                    isDark: themeProvider.isDark,
                    width: screenW,
                    height: screenH * 0.065,
                    onPressed: () {
                      if (_selectedDay != null) {
                        Navigator.pop(
                          context,
                          _selectedDay,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
