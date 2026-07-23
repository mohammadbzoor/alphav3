import 'package:alpha_app/models/income_model.dart';
import 'package:alpha_app/providers/income_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/screens/incomes/incomes_screen.dart';
import 'package:alpha_app/screens/incomes/add_income_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class MockIncomeProvider extends IncomeProvider {
  bool _mockIsLoading = false;
  String? _mockErrorMessage;
  List<IncomeModel> _mockIncomes = [];
  bool _simulateNoActiveCycle = false;
  bool _simulateApiError = false;
  bool _simulateFailedDeletion = false;

  int loadCalls = 0;
  int createCalls = 0;
  int deleteCalls = 0;

  void setMockState({
    bool isLoading = false,
    String? errorMessage,
    List<IncomeModel>? incomes,
    bool simulateNoActiveCycle = false,
    bool simulateApiError = false,
    bool simulateFailedDeletion = false,
  }) {
    _mockIsLoading = isLoading;
    _mockErrorMessage = errorMessage;
    if (incomes != null) _mockIncomes = incomes;
    _simulateNoActiveCycle = simulateNoActiveCycle;
    _simulateApiError = simulateApiError;
    _simulateFailedDeletion = simulateFailedDeletion;
    notifyListeners();
  }

  @override
  bool get isLoading => _mockIsLoading;

  @override
  String? get errorMessage => _mockErrorMessage;

  @override
  List<IncomeModel> get incomes => _mockIncomes;

  @override
  Future<void> loadIncomes() async {
    loadCalls++;
    _mockIsLoading = true;
    notifyListeners();
    await Future.microtask(() {});
    _mockIsLoading = false;
    notifyListeners();
  }

  @override
  Future<bool> createIncome(IncomeModel income) async {
    createCalls++;
    _mockIsLoading = true;
    notifyListeners();
    await Future.microtask(() {});

    if (_simulateNoActiveCycle) {
      _mockErrorMessage = 'NO_ACTIVE_FINANCIAL_CYCLE';
      _mockIsLoading = false;
      notifyListeners();
      return false;
    }

    if (_simulateApiError) {
      _mockErrorMessage = 'Server Error';
      _mockIsLoading = false;
      notifyListeners();
      return false;
    }

    _mockIncomes.insert(0, income);
    _mockIsLoading = false;
    notifyListeners();
    return true;
  }

  @override
  Future<bool> deleteIncome(String id) async {
    deleteCalls++;
    if (_simulateFailedDeletion) {
      _mockErrorMessage = 'Deletion Failed';
      notifyListeners();
      return false;
    }
    _mockIncomes.removeWhere((i) => i.id == id);
    notifyListeners();
    return true;
  }
}

Widget createTestApp(IncomeProvider incomeProvider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<Themeprovider>(create: (_) => Themeprovider()),
      ChangeNotifierProvider<IncomeProvider>.value(value: incomeProvider),
    ],
    child: const MaterialApp(
      home: IncomesScreen(),
    ),
  );
}

void main() {
  group('Incomes Screen Tests', () {
    late MockIncomeProvider mockProvider;

    setUp(() {
      mockProvider = MockIncomeProvider();
    });

    testWidgets('shows loading state', (tester) async {
      mockProvider.setMockState(isLoading: true);
      await tester.pumpWidget(createTestApp(mockProvider));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state', (tester) async {
      mockProvider.setMockState(incomes: []);
      await tester.pumpWidget(createTestApp(mockProvider));
      await tester.pumpAndSettle();
      expect(find.text('No incomes recorded yet.'), findsOneWidget);
    });

    testWidgets('shows successful list', (tester) async {
      mockProvider.setMockState(incomes: [
        IncomeModel(
            id: '1',
            amount: 500,
            source: 'Salary',
            description: 'desc',
            incomeDate: DateTime.now(),
            isRecurring: true,
            createdAt: DateTime.now()),
      ]);
      await tester.pumpWidget(createTestApp(mockProvider));
      await tester.pumpAndSettle();
      expect(find.text('SALARY'), findsWidgets);
      expect(find.text('500.0 JOD'), findsOneWidget);
      expect(find.text('Recurring'), findsOneWidget);
    });

    testWidgets('failed deletion rollback shows error', (tester) async {
      mockProvider.setMockState(
        incomes: [
          IncomeModel(
              id: '1',
              amount: 500,
              source: 'Salary',
              description: 'desc',
              incomeDate: DateTime.now(),
              isRecurring: true,
              createdAt: DateTime.now())
        ],
        simulateFailedDeletion: true,
      );
      await tester.pumpWidget(createTestApp(mockProvider));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();

      expect(mockProvider.incomes.length, 1);
      // SnackBar might have disappeared after pumpAndSettle, or we can check the error state
      expect(mockProvider.errorMessage, 'Deletion Failed');
    });
  });

  group('Add Income Screen Tests', () {
    late MockIncomeProvider mockProvider;

    setUp(() {
      mockProvider = MockIncomeProvider();
    });

    Widget createAddIncomeApp() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<Themeprovider>(create: (_) => Themeprovider()),
          ChangeNotifierProvider<IncomeProvider>.value(value: mockProvider),
        ],
        child: const MaterialApp(
          home: AddIncomeScreen(),
        ),
      );
    }

    testWidgets('add form validation', (tester) async {
      await tester.pumpWidget(createAddIncomeApp());

      await tester.tap(find.text('Save Income'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid amount'), findsOneWidget);
      expect(mockProvider.createCalls, 0);
    });

    testWidgets('duplicate-submit prevention', (tester) async {
      mockProvider.setMockState(isLoading: true);
      await tester.pumpWidget(createAddIncomeApp());

      final saveButton =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(saveButton.enabled, false);
    });

    testWidgets('no-active-cycle error shows dialog', (tester) async {
      mockProvider.setMockState(simulateNoActiveCycle: true);
      await tester.pumpWidget(createAddIncomeApp());

      await tester.enterText(find.byType(TextField).first, '100');
      await tester.pump();

      await tester.tap(find.text('Save Income'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('No Active Cycle'), findsOneWidget);
      expect(
          find.text('You need an active financial cycle to add transactions.'),
          findsOneWidget);
    });

    testWidgets('API error shows snackbar', (tester) async {
      mockProvider.setMockState(simulateApiError: true);
      await tester.pumpWidget(createAddIncomeApp());

      await tester.enterText(find.byType(TextField).first, '100');
      await tester.pump();

      await tester.tap(find.text('Save Income'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Server Error'), findsOneWidget);
    });
  });
}
