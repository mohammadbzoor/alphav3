class ProfileCompletionModel {
  final bool isComplete;
  final int percentage;
  final List<String> missingFields;
  final List<String> missingSections;
  final String? nextRequiredSection;
  final String analysisReliability;

  ProfileCompletionModel({
    required this.isComplete,
    required this.percentage,
    required this.missingFields,
    required this.missingSections,
    this.nextRequiredSection,
    required this.analysisReliability,
  });

  factory ProfileCompletionModel.fromJson(Map<String, dynamic> json) {
    return ProfileCompletionModel(
      isComplete: json['isComplete'] ?? false,
      percentage: json['percentage'] ?? 0,
      missingFields: List<String>.from(json['missingFields'] ?? []),
      missingSections: List<String>.from(json['missingSections'] ?? []),
      nextRequiredSection: json['nextRequiredSection'],
      analysisReliability: json['analysisReliability'] ?? 'limited',
    );
  }
}
