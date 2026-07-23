// Mapping utilities for categories, payment methods, and frequencies.
// Keys = UI display labels. Values = backend API values.

class FinanceMappings {
  FinanceMappings._();

  // =========================================================
  // NEEDS CATEGORIES
  // =========================================================

  static const Map<String, String> needsCategories = {
    'Rent': 'rent',
    'Electricity': 'electricity',
    'Water': 'water',
    'Internet': 'internet',
    'Transportation': 'transportation',
    'Healthcare': 'healthcare',
    'Education': 'education',
    'Family': 'family',
    'Loan': 'loan',
    'Other': 'other',
  };

  // =========================================================
  // WANTS CATEGORIES
  // =========================================================

  static const Map<String, String> wantsCategories = {
    'Restaurant': 'restaurant',
    'Coffee': 'coffee',
    'Entertainment': 'entertainment',
    'Shopping': 'shopping',
    'Travel': 'travel',
    'Subscription': 'subscription',
    'Hobbies': 'hobbies',
    'Other': 'other',
  };

  // =========================================================
  // PAYMENT METHODS
  // =========================================================

  static const Map<String, String> paymentMethods = {
    'Cash': 'cash',
    'Card': 'card',
    'Wallet': 'wallet',
    'Bank Transfer': 'bank_transfer',
    'Other': 'other',
  };

  // =========================================================
  // RECURRING FREQUENCIES
  // =========================================================

  static const Map<String, String> recurringFrequencies = {
    'Weekly': 'weekly',
    'Monthly': 'monthly',
    'Quarterly': 'quarterly',
    'Yearly': 'yearly',
  };

  // =========================================================
  // FLEXIBILITY OPTIONS
  // =========================================================

  static const Map<String, String> flexibilityOptions = {
    'Fixed': 'fixed',
    'Flexible': 'flexible',
  };

  // =========================================================
  // REVERSE LOOKUP HELPERS
  // =========================================================

  /// Returns the UI label for a given backend category value, or the raw value
  /// if no match is found.
  static String getCategoryLabel(String backendValue) {
    final allCategories = {...needsCategories, ...wantsCategories};
    return allCategories.entries
        .firstWhere(
          (e) => e.value == backendValue,
          orElse: () => MapEntry(backendValue, backendValue),
        )
        .key;
  }

  /// Returns the UI label for a given backend payment method value.
  static String getPaymentMethodLabel(String backendValue) {
    return paymentMethods.entries
        .firstWhere(
          (e) => e.value == backendValue,
          orElse: () => MapEntry(backendValue, backendValue),
        )
        .key;
  }

  /// Returns true if the given category belongs to the needs bucket.
  static bool isNeedsCategory(String backendCategory) {
    return needsCategories.values.contains(backendCategory);
  }

  /// Returns true if the given category belongs to the wants bucket.
  static bool isWantsCategory(String backendCategory) {
    return wantsCategories.values.contains(backendCategory);
  }

  /// Returns all categories for a given bucket label ('needs' or 'wants').
  static Map<String, String> categoriesForBucket(String bucket) {
    if (bucket == 'wants') return wantsCategories;
    return needsCategories;
  }

  /// Returns true if the given category key belongs to the given bucket.
  static bool categoryMatchesBucket(String backendCategory, String bucket) {
    final map = categoriesForBucket(bucket);
    return map.values.contains(backendCategory);
  }
}
