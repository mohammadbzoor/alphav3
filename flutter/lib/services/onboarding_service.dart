import 'package:alpha_app/services/api_service.dart';

class OnboardingService {
  OnboardingService._();

  static Future<Map<String, dynamic>> checkOnboardingStatus() async {
    final response = await ApiService.get('/onboarding/status');
    return ApiService.parseJson(response);
  }

  static Future<Map<String, dynamic>> savePersonalInfo(
      Map<String, dynamic> data) async {
    final response = await ApiService.post(
      '/onboarding/personal-info',
      body: data,
    );
    return ApiService.parseJson(response);
  }

  static Future<Map<String, dynamic>> saveFinancialSetup(
      Map<String, dynamic> data) async {
    final response = await ApiService.post(
      '/onboarding/financial-setup',
      body: data,
    );
    return ApiService.parseJson(response);
  }

  static Future<Map<String, dynamic>> approveAllocation(
      Map<String, dynamic> data) async {
    final response = await ApiService.post(
      '/onboarding/allocation/approve',
      body: data,
    );
    return ApiService.parseJson(response);
  }
}
