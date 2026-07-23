class FinancialAnalysisListItem {
  final int id;
  final String analysisId;
  final String status;
  final String summaryPreview;
  final String scope;
  final DateTime? analysisAsOfDate;
  final DateTime? generatedAt;
  final int insightCount;
  final bool hasAudio;

  const FinancialAnalysisListItem({
    required this.id,
    required this.analysisId,
    required this.status,
    required this.summaryPreview,
    required this.scope,
    required this.analysisAsOfDate,
    required this.generatedAt,
    required this.insightCount,
    required this.hasAudio,
  });

  factory FinancialAnalysisListItem.fromJson(Map<String, dynamic> json) {
    return FinancialAnalysisListItem(
      id: _toInt(json['id']),
      analysisId: json['analysisId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      summaryPreview: json['summaryPreview']?.toString() ?? '',
      scope: json['scope']?.toString() ?? '',
      analysisAsOfDate: DateTime.tryParse(json['analysisAsOfDate']?.toString() ?? ''),
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? ''),
      insightCount: _toInt(json['insightCount']),
      hasAudio: json['hasAudio'] == true,
    );
  }
}

class FinancialAnalysisModel {
  final int id;
  final String analysisId;
  final String status;
  final String scope;
  final AnalysisUser user;
  final AnalysisContent content;
  final AnalysisMetrics metrics;
  final AnalysisAudio audio;
  final AnalysisMetadata metadata;
  final AnalysisDataQuality dataQuality;

  const FinancialAnalysisModel({
    required this.id,
    required this.analysisId,
    required this.status,
    required this.scope,
    required this.user,
    required this.content,
    required this.metrics,
    required this.audio,
    required this.metadata,
    required this.dataQuality,
  });

  factory FinancialAnalysisModel.fromJson(Map<String, dynamic> json) {
    final uiMetrics = Map<String, dynamic>.from(json['uiMetrics'] ?? {});
    final audio = Map<String, dynamic>.from(json['audio'] ?? {});
    final dataQuality = Map<String, dynamic>.from(json['dataQuality'] ?? {});

    final contentBlock = json['content'] != null && json['content'] is Map 
        ? Map<String, dynamic>.from(json['content']) 
        : json;

    return FinancialAnalysisModel(
      id: _toInt(json['id']),
      analysisId: json['analysisId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      scope: json['scope']?.toString() ?? '',
      user: const AnalysisUser(
        currency: 'JOD',
        language: 'ar',
        locale: 'ar-JO',
        timezone: 'Asia/Amman',
      ),
      content: AnalysisContent(
        summary: contentBlock['summary']?.toString() ?? '',
        insights: _stringList(contentBlock['insights']),
        recommendations: _stringList(contentBlock['recommendations']),
        speechText: contentBlock['speechText']?.toString(),
      ),
      metrics: AnalysisMetrics.fromJson(uiMetrics),
      audio: AnalysisAudio.fromJson(audio),
      metadata: AnalysisMetadata(
        requestId: json['analysisId']?.toString() ?? '',
        analysisAsOfDate: DateTime.tryParse(json['asOfDate']?.toString() ?? ''),
        generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? ''),
      ),
      dataQuality: AnalysisDataQuality.fromJson(dataQuality),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'analysisId': analysisId,
      'status': status,
      'generatedAt': metadata.generatedAt?.toIso8601String(),
      'asOfDate': metadata.analysisAsOfDate?.toIso8601String(),
      'scope': scope,
      'summary': content.summary,
      'insights': content.insights,
      'recommendations': content.recommendations,
      'speechText': content.speechText,
      'uiMetrics': metrics.toJson(),
      'audio': audio.toJson(),
      'dataQuality': dataQuality.toJson(),
    };
  }
}

class AnalysisUser {
  final String language;
  final String locale;
  final String currency;
  final String timezone;

  const AnalysisUser({
    required this.language,
    required this.locale,
    required this.currency,
    required this.timezone,
  });
}

class AnalysisContent {
  final String summary;
  final List<String> insights;
  final List<String> recommendations;
  final String? speechText;

  const AnalysisContent({
    required this.summary,
    required this.insights,
    required this.recommendations,
    required this.speechText,
  });
}

class AnalysisMetrics {
  final AnalysisMetric savings;
  final AnalysisMetric needs;
  final AnalysisMetric wants;

  const AnalysisMetrics({
    required this.savings,
    required this.needs,
    required this.wants,
  });

  factory AnalysisMetrics.fromJson(Map<String, dynamic> json) {
    return AnalysisMetrics(
      savings: AnalysisMetric.fromJson(Map<String, dynamic>.from(json['savings'] ?? {})),
      needs: AnalysisMetric.fromJson(Map<String, dynamic>.from(json['needs'] ?? {})),
      wants: AnalysisMetric.fromJson(Map<String, dynamic>.from(json['wants'] ?? {})),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'savings': savings.toJson(),
      'needs': needs.toJson(),
      'wants': wants.toJson(),
    };
  }
}

class AnalysisMetric {
  final double? current;
  final double? target;
  final double? percent;
  final AnalysisStatus status;

  const AnalysisMetric({
    required this.current,
    required this.target,
    required this.percent,
    required this.status,
  });

  bool get isUnavailable => status == AnalysisStatus.unavailable;

  factory AnalysisMetric.fromJson(Map<String, dynamic> json) {
    final status = AnalysisStatusX.fromString(json['status']?.toString());
    return AnalysisMetric(
      current: status == AnalysisStatus.unavailable ? null : _toNullableDouble(json['current']),
      target: status == AnalysisStatus.unavailable ? null : _toNullableDouble(json['target']),
      percent: status == AnalysisStatus.unavailable ? null : _toNullableDouble(json['percent']),
      status: status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current': current,
      'target': target,
      'percent': percent,
      'status': status.apiValue,
    };
  }
}

enum AnalysisStatus {
  unavailable,
  onTrack,
  warning,
  exceeded,
  completed,
}

extension AnalysisStatusX on AnalysisStatus {
  static AnalysisStatus fromString(String? value) {
    switch (value) {
      case 'on_track':
        return AnalysisStatus.onTrack;
      case 'warning':
        return AnalysisStatus.warning;
      case 'exceeded':
        return AnalysisStatus.exceeded;
      case 'completed':
        return AnalysisStatus.completed;
      default:
        return AnalysisStatus.unavailable;
    }
  }

  String get apiValue {
    switch (this) {
      case AnalysisStatus.onTrack:
        return 'on_track';
      case AnalysisStatus.warning:
        return 'warning';
      case AnalysisStatus.exceeded:
        return 'exceeded';
      case AnalysisStatus.completed:
        return 'completed';
      case AnalysisStatus.unavailable:
        return 'unavailable';
    }
  }

  String get label {
    switch (this) {
      case AnalysisStatus.onTrack:
        return 'On track';
      case AnalysisStatus.warning:
        return 'Warning';
      case AnalysisStatus.exceeded:
        return 'Exceeded';
      case AnalysisStatus.completed:
        return 'Completed';
      case AnalysisStatus.unavailable:
        return 'Unavailable';
    }
  }
}

class AnalysisAudio {
  final String? url;
  final double? duration;

  const AnalysisAudio({
    required this.url,
    required this.duration,
  });

  bool get hasAudio => url?.trim().isNotEmpty == true;

  factory AnalysisAudio.fromJson(Map<String, dynamic> json) {
    return AnalysisAudio(
      url: json['url']?.toString(),
      duration: _toNullableDouble(json['duration']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'duration': duration,
    };
  }
}

class AnalysisMetadata {
  final String requestId;
  final DateTime? analysisAsOfDate;
  final DateTime? generatedAt;

  const AnalysisMetadata({
    required this.requestId,
    required this.analysisAsOfDate,
    required this.generatedAt,
  });
}

class AnalysisDataQuality {
  final bool isPartialCycle;
  final bool hasCurrentCycle;
  final List<String> missingFields;

  const AnalysisDataQuality({
    required this.isPartialCycle,
    required this.hasCurrentCycle,
    required this.missingFields,
  });

  bool get shouldShowNotice => isPartialCycle || !hasCurrentCycle || missingFields.isNotEmpty;

  factory AnalysisDataQuality.fromJson(Map<String, dynamic> json) {
    return AnalysisDataQuality(
      isPartialCycle: json['isPartialCycle'] == true,
      hasCurrentCycle: json['hasCurrentCycle'] != false,
      missingFields: _stringList(json['missingFields']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isPartialCycle': isPartialCycle,
      'hasCurrentCycle': hasCurrentCycle,
      'missingFields': missingFields,
    };
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _toNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}
