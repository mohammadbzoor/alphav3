import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_app/providers/goal_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late HttpServer server;
  late String baseUrl;
  Map<String, dynamic> nextResponse = {};
  int nextStatusCode = 200;

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://${server.address.host}:${server.port}/api/v1';
    
    // We need shared preferences to avoid ApiService crashing on token read
    SharedPreferences.setMockInitialValues({'access_token': 'fake_token'});
    
    try {
      await dotenv.load();
    } catch (_) {}
    dotenv.env['API_BASE_URL'] = baseUrl;
    
    server.listen((HttpRequest request) async {
      request.response.statusCode = nextStatusCode;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(nextResponse));
      await request.response.close();
    });
  });

  tearDownAll(() async {
    await server.close();
  });

  group('GoalProvider Server-ID Parsing and State Synchronization', () {
    late GoalProvider provider;

    setUp(() {
      provider = GoalProvider();
      dotenv.env['API_BASE_URL'] = baseUrl;
    });

    Future<void> simulateForm() async {
      provider.setCategory('Other');
      provider.customNameController.text = 'Test Goal';
      provider.amountController.text = '6000'; // Target 6000
      provider.setDate(DateTime.now().add(const Duration(days: 30)));
      // Auto suggestion should calculate 6000 / 1 month = 6000, or let's say 2 months = 3000
    }

    test('isSaving flag prevents double submission', () async {
      await simulateForm();
      nextResponse = {'success': true, 'data': {'goalId': 123}};
      nextStatusCode = 200;

      final Future<bool> first = provider.saveCurrentGoal();
      final Future<bool> second = provider.saveCurrentGoal();
      
      expect(await second, isFalse, reason: 'Second call should abort immediately because _isSaving is true');
      expect(await first, isTrue, reason: 'First call should succeed');
    });

    test('Valid backend response sets actual ID', () async {
      await simulateForm();
      nextResponse = {'success': true, 'data': {'goalId': 456}};
      nextStatusCode = 200;

      final result = await provider.saveCurrentGoal();
      expect(result, isTrue);
      expect(provider.goals.length, 1);
      expect(provider.goals.first.id, '456', reason: 'Must use real ID, not timestamp fallback');
    });

    test('Response missing goalId produces failure and no phantom goal', () async {
      await simulateForm();
      nextResponse = {'success': true, 'data': {}};
      nextStatusCode = 200;

      final result = await provider.saveCurrentGoal();
      expect(result, isFalse);
      expect(provider.goals.length, 0, reason: 'Phantom goal must not be added');
      expect(provider.errorMessage, contains('Invalid server response'));
    });

    test('Response with invalid formats (zero, negative, text) are rejected', () async {
      await simulateForm();
      
      nextResponse = {'success': true, 'data': {'goalId': 0}};
      expect(await provider.saveCurrentGoal(), isFalse);
      expect(provider.goals.length, 0);

      nextResponse = {'success': true, 'data': {'goalId': -15}};
      expect(await provider.saveCurrentGoal(), isFalse);

      nextResponse = {'success': true, 'data': {'goalId': 'abc'}};
      expect(await provider.saveCurrentGoal(), isFalse);
    });

    test('HTTP 400 or 500 do not append phantom goal', () async {
      await simulateForm();
      nextResponse = {'success': false};
      nextStatusCode = 400;

      final result = await provider.saveCurrentGoal();
      expect(result, isFalse);
      expect(provider.goals.length, 0);
    });
  });

  group('GoalProvider G2 Task: Target Amount vs Planned Contribution', () {
    late GoalProvider provider;

    setUp(() {
      provider = GoalProvider();
      dotenv.env['API_BASE_URL'] = baseUrl;
    });

    test('Total target and monthly contribution have separate state', () {
      provider.amountController.text = '5000';
      provider.contributionController.text = '500';
      
      expect(provider.targetAmountValue, 5000);
      expect(provider.plannedContributionValue, 500);
    });

    test('Automatic suggestion is calculated deterministically', () {
      provider.amountController.text = '1200';
      
      final targetDate = DateTime.now().add(const Duration(days: 60)); // ~2 months ahead
      provider.setDate(targetDate);

      // It should have calculated suggestion
      expect(provider.plannedContributionValue, greaterThan(0));
      expect(provider.isContributionManuallyEdited, isFalse);
    });

    test('Manual override is preserved', () {
      provider.amountController.text = '1200';
      provider.setDate(DateTime.now().add(const Duration(days: 60)));
      
      // User types manually
      provider.contributionController.text = '150';
      provider.onContributionEdited();

      expect(provider.isContributionManuallyEdited, isTrue);

      // Date changes
      provider.setDate(DateTime.now().add(const Duration(days: 120)));

      // Suggestion should NOT have overridden the manual value
      expect(provider.plannedContributionValue, 150);
    });

    test('Recalculate/reset restores the suggestion', () {
      provider.amountController.text = '1200';
      provider.setDate(DateTime.now().add(const Duration(days: 30))); // 1 month
      
      provider.contributionController.text = '150';
      provider.onContributionEdited();

      provider.resetContributionToSuggestion();
      expect(provider.isContributionManuallyEdited, isFalse);
      expect(provider.plannedContributionValue, 1200); // 1200 / 1
    });
  });
}
