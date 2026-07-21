import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class GoalDateScreen extends StatefulWidget {
  final DateTime? initialDate;

  const GoalDateScreen({
    super.key,
    this.initialDate,
  });

  @override
  State<GoalDateScreen> createState() => _GoalDateScreenState();
}

class _GoalDateScreenState extends State<GoalDateScreen> {
  late DateTime _focusedDay;

  DateTime? _selectedDay;

  late int _selectedYear;

  @override
  void initState() {
    super.initState();

    // تاريخ افتراضي بعد شهر لأنه هدف مستقبلي

    _selectedDay = widget.initialDate ??
        DateTime.now().add(
          const Duration(days: 30),
        );

    _focusedDay = _selectedDay!;

    _selectedYear = _selectedDay!.year;
  }

  @override
  Widget build(BuildContext context) {
    final screenW = Device.width(context);

    final screenH = Device.height(context);

    final themeprovider = Provider.of<Themeprovider>(context);

    return SafeArea(
      child: Scaffold(
        backgroundColor: themeprovider.isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
        body: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenW * 0.05,
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    top: screenH * 0.05,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Goal Date",
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: screenW * 0.08,
                          fontWeight: FontWeight.bold,
                          color: themeprovider.isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                      Card(
                        color: themeprovider.isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                        child: IconButton(
                          icon: Icon(
                            Icons.close,
                            color: themeprovider.isDark
                                ? AppColors.darkSubText
                                : AppColors.lightSubText,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: screenH * 0.02,
                ),
                SizedBox(
                  height: screenH * 0.06,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 20,
                    itemBuilder: (context, index) {
                      final year = DateTime.now().year + index;

                      final isSelected = year == _selectedYear;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedYear = year;

                            _focusedDay = DateTime(
                              year,
                              _focusedDay.month,
                              1,
                            );

                            _selectedDay = _focusedDay;
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
                                ? (themeprovider.isDark
                                    ? AppColors.darkPrimary
                                    : AppColors.lightPrimary)
                                : (themeprovider.isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              "$year",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? AppColors.lightText
                                    : (themeprovider.isDark
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
                Container(
                  decoration: BoxDecoration(
                    color: themeprovider.isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TableCalendar(
                    locale: 'en_US',

                    // يبدأ من بكرا فقط

                    firstDay: DateTime.now().add(
                      const Duration(days: 1),
                    ),

                    lastDay: DateTime(
                      DateTime.now().year + 20,
                      12,
                      31,
                    ),

                    focusedDay: _focusedDay,

                    calendarFormat: CalendarFormat.month,

                    selectedDayPredicate: (day) {
                      return isSameDay(
                        _selectedDay,
                        day,
                      );
                    },

                    // منع اختيار اليوم والماضي

                    enabledDayPredicate: (day) {
                      final today = DateTime.now();

                      final currentDay = DateTime(
                        today.year,
                        today.month,
                        today.day,
                      );

                      return day.isAfter(currentDay);
                    },

                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;

                        _focusedDay = focusedDay;

                        _selectedYear = selectedDay.year;
                      });
                    },

                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: GoogleFonts.ibmPlexSansArabic(
                        fontSize: screenW * 0.055,
                        fontWeight: FontWeight.bold,
                        color: themeprovider.isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                      leftChevronIcon: Icon(
                        Icons.chevron_left,
                        color: themeprovider.isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                      rightChevronIcon: Icon(
                        Icons.chevron_right,
                        color: themeprovider.isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),

                    calendarStyle: CalendarStyle(
                      defaultTextStyle: TextStyle(
                        color: themeprovider.isDark
                            ? AppColors.darkSubText
                            : AppColors.lightSubText,
                        fontWeight: FontWeight.w500,
                      ),
                      weekendTextStyle: TextStyle(
                        color: themeprovider.isDark
                            ? AppColors.darkSubText
                            : AppColors.lightSubText,
                        fontWeight: FontWeight.w500,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: themeprovider.isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: screenH * 0.02,
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: themeprovider.isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Selected date",
                        style: TextStyle(
                          color: themeprovider.isDark
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
                        ).format(_selectedDay!),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: screenW * 0.06,
                          fontWeight: FontWeight.bold,
                          color: themeprovider.isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: screenH * 0.02,
                ),
              Padding(
  padding: EdgeInsets.only(
    bottom: screenH * 0.02,
  ),
  child: AppButton(
    text: "Confirm Date",
    isDark: themeprovider.isDark,
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
