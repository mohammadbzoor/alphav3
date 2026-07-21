import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/providers/profile_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/widgets/option_chip.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class PersonalInfoScreen extends StatefulWidget {
  final bool isEditing;

  const PersonalInfoScreen({super.key, this.isEditing = false});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? _gender;
  DateTime? _birthDate;

  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final profileProvider = context.read<ProfileProvider>();
      if (widget.isEditing) {
        profileProvider.loadFullProfile().then((_) {
          if (mounted) {
            final profile = profileProvider.profile;
            setState(() {
              _nameController.text = profile?.name ?? '';
              _emailController.text = profile?.email ?? '';
              _phoneController.text = profile?.phone ?? '';
              _gender = profile?.gender;
              _birthDate = profile?.birthDate;
            });
          }
        });
      }
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final profileProvider = context.read<ProfileProvider>();
    final success = await profileProvider.updateProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      gender: _gender,
      birthDate: _birthDate,
    );

    if (success && mounted) {
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(profileProvider.errorMessage ?? 'Update failed'),
          backgroundColor: AppColors.darkError,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final themeprovider = Provider.of<Themeprovider>(context);
    final screenW = Device.width(context);
    final screenH = Device.height(context);
    final isDark = themeprovider.isDark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: widget.isEditing
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
              title: Text(
                'Edit Profile',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: profileProvider.isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                ),
              )
            : profileProvider.errorMessage != null && !profileProvider.hasProfile
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: AppColors.darkError),
                        const SizedBox(height: 16),
                        Text(
                          'Could not load profile',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () {
                            final provider = context.read<ProfileProvider>();
                            provider.loadFullProfile().then((_) {
                              if (mounted) {
                                final profile = provider.profile;
                                setState(() {
                                  _nameController.text = profile?.name ?? '';
                                  _emailController.text = profile?.email ?? '';
                                  _phoneController.text = profile?.phone ?? '';
                                  _gender = profile?.gender;
                                  _birthDate = profile?.birthDate;
                                });
                              }
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            'Retry',
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: screenW * 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.isEditing) ...[
                      SizedBox(height: screenH * 0.03),
                      Text(
                        "Step 1 of 3",
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: screenW * 0.04,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                        ),
                      ),
                      SizedBox(height: screenH * 0.02),
                      Text(
                        "Personal Information",
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: screenW * 0.075,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                      SizedBox(height: screenH * 0.01),
                      Text(
                        "Accurate data means sharper advice from Alpha",
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: screenW * 0.035,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                        ),
                      ),
                      SizedBox(height: screenH * 0.03),
                    ],

                    Text(
                      "Full Name",
                      style: TextStyle(
                        fontSize: screenW * 0.04,
                        color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: screenH * 0.01),
                    TextField(
                      controller: _nameController,
                      style: TextStyle(color: isDark ? AppColors.darkText : AppColors.lightText),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? AppColors.darkBorder : Colors.grey[200],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    SizedBox(height: screenH * 0.02),

                    Text(
                      "Email",
                      style: TextStyle(
                        fontSize: screenW * 0.04,
                        color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: screenH * 0.01),
                    TextField(
                      controller: _emailController,
                      style: TextStyle(color: isDark ? AppColors.darkText : AppColors.lightText),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? AppColors.darkBorder : Colors.grey[200],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    SizedBox(height: screenH * 0.02),

                    Text(
                      "Phone",
                      style: TextStyle(
                        fontSize: screenW * 0.04,
                        color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: screenH * 0.01),
                    TextField(
                      controller: _phoneController,
                      style: TextStyle(color: isDark ? AppColors.darkText : AppColors.lightText),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? AppColors.darkBorder : Colors.grey[200],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    SizedBox(height: screenH * 0.02),

                    Text(
                      "Gender",
                      style: TextStyle(
                        fontSize: screenW * 0.04,
                        color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: screenH * 0.01),
                    OptionChip(
                      items: const ["Female", "Male"],
                      selected: _gender,
                      onTap: (val) => setState(() => _gender = val),
                    ),
                    SizedBox(height: screenH * 0.05),

                    SizedBox(
                      width: double.infinity,
                      height: screenH * 0.065,
                      child: ElevatedButton(
                        onPressed: profileProvider.isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: profileProvider.isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                widget.isEditing ? "Save Changes" : "Next",
                                style: TextStyle(
                                  fontSize: screenW * 0.055,
                                  color: AppColors.darkBorder,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: screenH * 0.05),
                  ],
                ),
              ),
      ),
    );
  }
}
