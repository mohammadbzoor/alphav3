class FinancialAnalysisModel {
  final AnalysisUser user;
  final AnalysisContent content;
  final AnalysisMetrics metrics;
  final AnalysisAudio audio;
  final AnalysisMetadata metadata;

  const FinancialAnalysisModel({
    required this.user,
    required this.content,
    required this.metrics,
    required this.audio,
    required this.metadata,
  });

  factory FinancialAnalysisModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final data = Map<String, dynamic>.from(
      json['data'] ?? {},
    );

    return FinancialAnalysisModel(
      user: AnalysisUser.fromJson(
        Map<String, dynamic>.from(
          json['User'] ?? {},
        ),
      ),
      content: AnalysisContent.fromJson(
        Map<String, dynamic>.from(
          data['content'] ?? {},
        ),
      ),
      metrics: AnalysisMetrics.fromJson(
        Map<String, dynamic>.from(
          data['uiMetrics'] ?? {},
        ),
      ),
      audio: AnalysisAudio.fromJson(
        Map<String, dynamic>.from(
          data['audio'] ?? {},
        ),
      ),
      metadata: AnalysisMetadata.fromJson(
        Map<String, dynamic>.from(
          json['metadata'] ?? {},
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'User': user.toJson(),
      'data': {
        'content': content.toJson(),
        'uiMetrics': metrics.toJson(),
        'audio': audio.toJson(),
      },
      'metadata': metadata.toJson(),
    };
  }
}

// =====================================================
// USER
// =====================================================

class AnalysisUser {
  final String userId;
  final String name;
  final String displayName;
  final String language;
  final String locale;
  final String currency;
  final String timezone;

  const AnalysisUser({
    required this.userId,
    required this.name,
    required this.displayName,
    required this.language,
    required this.locale,
    required this.currency,
    required this.timezone,
  });

  factory AnalysisUser.fromJson(
    Map<String, dynamic> json,
  ) {
    return AnalysisUser(
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      displayName:
          json['displayName']?.toString() ?? '',
      language:
          json['language']?.toString() ?? 'ar',
      locale:
          json['locale']?.toString() ?? 'ar-JO',
      currency:
          json['currency']?.toString() ?? 'JOD',
      timezone:
          json['timezone']?.toString() ??
              'Asia/Amman',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'displayName': displayName,
      'language': language,
      'locale': locale,
      'currency': currency,
      'timezone': timezone,
    };
  }
}

// =====================================================
// CONTENT
// =====================================================

class AnalysisContent {
  final String summary;
  final List<String> insights;
  final List<String> recommendations;
  final String speechText;

  const AnalysisContent({
    required this.summary,
    required this.insights,
    required this.recommendations,
    required this.speechText,
  });

  factory AnalysisContent.fromJson(
    Map<String, dynamic> json,
  ) {
    return AnalysisContent(
      summary: json['summary']?.toString() ?? '',
      insights: _stringList(
        json['insights'],
      ),
      recommendations: _stringList(
        json['recommendations'],
      ),
      speechText:
          json['speechText']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'insights': insights,
      'recommendations': recommendations,
      'speechText': speechText,
    };
  }
}

// =====================================================
// METRICS
// =====================================================

class AnalysisMetrics {
  final AnalysisMetric savings;
  final AnalysisMetric needs;
  final AnalysisMetric wants;

  const AnalysisMetrics({
    required this.savings,
    required this.needs,
    required this.wants,
  });

  factory AnalysisMetrics.fromJson(
    Map<String, dynamic> json,
  ) {
    return AnalysisMetrics(
      savings: AnalysisMetric.fromJson(
        Map<String, dynamic>.from(
          json['savings'] ?? {},
        ),
      ),
      needs: AnalysisMetric.fromJson(
        Map<String, dynamic>.from(
          json['needs'] ?? {},
        ),
      ),
      wants: AnalysisMetric.fromJson(
        Map<String, dynamic>.from(
          json['wants'] ?? {},
        ),
      ),
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
  final double current;
  final double target;
  final double percent;
  final AnalysisStatus status;

  const AnalysisMetric({
    required this.current,
    required this.target,
    required this.percent,
    required this.status,
  });

  factory AnalysisMetric.fromJson(
    Map<String, dynamic> json,
  ) {
    return AnalysisMetric(
      current: _toDouble(
        json['current'],
      ),
      target: _toDouble(
        json['target'],
      ),
      percent: _toDouble(
        json['percent'],
      ),
      status: AnalysisStatusX.fromString(
        json['status']?.toString(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current': current,
      'target': target,
      'percent': percent,
      'status': status.name,
    };
  }
}

enum AnalysisStatus {
  onTrack,
  warning,
  critical,
  unknown,
}

extension AnalysisStatusX on AnalysisStatus {
  static AnalysisStatus fromString(
    String? value,
  ) {
    switch (value) {
      case 'on_track':
        return AnalysisStatus.onTrack;

      case 'warning':
        return AnalysisStatus.warning;

      case 'critical':
        return AnalysisStatus.critical;

      default:
        return AnalysisStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case AnalysisStatus.onTrack:
        return 'On track';

      case AnalysisStatus.warning:
        return 'Warning';

      case AnalysisStatus.critical:
        return 'Critical';

      case AnalysisStatus.unknown:
        return 'Unknown';
    }
  }
}

// =====================================================
// AUDIO
// =====================================================

class AnalysisAudio {
  final String url;
  final double duration;

  const AnalysisAudio({
    required this.url,
    required this.duration,
  });

  bool get hasAudio =>
      url.trim().isNotEmpty;

  factory AnalysisAudio.fromJson(
    Map<String, dynamic> json,
  ) {
    return AnalysisAudio(
      url: json['url']?.toString() ?? '',
      duration: _toDouble(
        json['duration'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'duration': duration,
    };
  }
}

// =====================================================
// METADATA
// =====================================================

class AnalysisMetadata {
  final String requestId;
  final DateTime? analysisAsOfDate;
  final DateTime? generatedAt;

  const AnalysisMetadata({
    required this.requestId,
    required this.analysisAsOfDate,
    required this.generatedAt,
  });

  factory AnalysisMetadata.fromJson(
    Map<String, dynamic> json,
  ) {
    return AnalysisMetadata(
      requestId:
          json['requestId']?.toString() ?? '',
      analysisAsOfDate: DateTime.tryParse(
        json['analysisAsOfDate']?.toString() ?? '',
      ),
      generatedAt: DateTime.tryParse(
        json['generatedAt']?.toString() ?? '',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'analysisAsOfDate':
          analysisAsOfDate?.toIso8601String(),
      'generatedAt':
          generatedAt?.toIso8601String(),
    };
  }
}

// =====================================================
// HELPERS
// =====================================================

double _toDouble(
  dynamic value,
) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(
        value?.toString() ?? '',
      ) ??
      0;
}

List<String> _stringList(
  dynamic value,
) {
  if (value is! List) {
    return const [];
  }

  return value
      .map(
        (item) => item.toString(),
      )
      .where(
        (item) => item.trim().isNotEmpty,
      )
      .toList();
}