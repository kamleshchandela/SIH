class BoundingBox {
  final int x;
  final int y;
  final int width;
  final int height;

  BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      x: (json['x'] as num).toInt(),
      y: (json['y'] as num).toInt(),
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }
}

class OcrToken {
  final String text;
  final double confidence;
  final BoundingBox bbox;
  final String? sourceImage;

  OcrToken({
    required this.text,
    required this.confidence,
    required this.bbox,
    this.sourceImage,
  });

  factory OcrToken.fromJson(Map<String, dynamic> json) {
    return OcrToken(
      text: json['text'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      bbox: BoundingBox.fromJson(json['bbox'] as Map<String, dynamic>? ?? {'x': 0, 'y': 0, 'width': 0, 'height': 0}),
      sourceImage: json['source_image'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'confidence': confidence,
      'bbox': bbox.toJson(),
      if (sourceImage != null) 'source_image': sourceImage,
    };
  }
}

class RuleEvaluation {
  final String field;
  final String clause;
  final String status;
  final String? sourcePanel;
  final String remarks;
  final String? detectedText;

  RuleEvaluation({
    required this.field,
    required this.clause,
    required this.status,
    this.sourcePanel,
    required this.remarks,
    this.detectedText,
  });

  factory RuleEvaluation.fromJson(Map<String, dynamic> json) {
    return RuleEvaluation(
      field: json['field'] as String? ?? '',
      clause: json['clause'] as String? ?? json['legal_clause'] as String? ?? '',
      status: json['status'] as String? ?? 'Unknown',
      sourcePanel: json['source_panel'] as String?,
      remarks: json['remarks'] as String? ?? '',
      detectedText: json['detected_text'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      'clause': clause,
      'status': status,
      if (sourcePanel != null) 'source_panel': sourcePanel,
      'remarks': remarks,
      if (detectedText != null) 'detected_text': detectedText,
    };
  }

  bool get isCompliant => status.toLowerCase() == 'compliant';
  bool get isViolation => status.toLowerCase() == 'violation';
  bool get isWarning => status.toLowerCase() == 'warning';
  bool get isNotApplicable => status.toLowerCase() == 'notapplicable';
}

class StatutoryPenalty {
  final String section;
  final String act;
  final String description;
  final int compoundableFineInr;

  StatutoryPenalty({
    required this.section,
    required this.act,
    required this.description,
    required this.compoundableFineInr,
  });

  factory StatutoryPenalty.fromJson(Map<String, dynamic> json) {
    return StatutoryPenalty(
      section: json['section'] as String? ?? '',
      act: json['act'] as String? ?? '',
      description: json['description'] as String? ?? '',
      compoundableFineInr: (json['compoundable_fine_inr'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'section': section,
      'act': act,
      'description': description,
      'compoundable_fine_inr': compoundableFineInr,
    };
  }
}

class ViolationsSummary {
  final int totalViolations;
  final List<String> mandatoryMissing;
  final List<String> nonStandardUnits;
  final List<StatutoryPenalty> statutoryPenalties;

  ViolationsSummary({
    required this.totalViolations,
    required this.mandatoryMissing,
    required this.nonStandardUnits,
    required this.statutoryPenalties,
  });

  factory ViolationsSummary.fromJson(Map<String, dynamic> json) {
    return ViolationsSummary(
      totalViolations: (json['total_violations'] as num?)?.toInt() ?? 0,
      mandatoryMissing: (json['mandatory_missing'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      nonStandardUnits: (json['non_standard_units'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      statutoryPenalties: (json['statutory_penalties'] as List<dynamic>?)
              ?.map((e) => StatutoryPenalty.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_violations': totalViolations,
      'mandatory_missing': mandatoryMissing,
      'non_standard_units': nonStandardUnits,
      'statutory_penalties': statutoryPenalties.map((p) => p.toJson()).toList(),
    };
  }

  int get totalFineInr {
    return statutoryPenalties.fold(0, (sum, p) => sum + p.compoundableFineInr);
  }
}

class ComplianceReport {
  final String inspectionId;
  final String timestamp;
  final String? productName;
  final List<String> scannedPanels;
  final bool overallCompliant;
  final String riskTier;
  final double complianceScorePct;
  final List<RuleEvaluation> evaluations;
  final ViolationsSummary violations;
  final List<OcrToken> rawOcrTokens;
  final String captureMode;

  ComplianceReport({
    required this.inspectionId,
    required this.timestamp,
    this.productName,
    required this.scannedPanels,
    required this.overallCompliant,
    required this.riskTier,
    required this.complianceScorePct,
    required this.evaluations,
    required this.violations,
    required this.rawOcrTokens,
    this.captureMode = 'one-shot',
  });

  factory ComplianceReport.fromJson(Map<String, dynamic> json) {
    return ComplianceReport(
      inspectionId: json['inspection_id'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      productName: json['product_name'] as String?,
      scannedPanels: (json['scanned_panels'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      overallCompliant: json['overall_compliant'] as bool? ?? false,
      riskTier: json['risk_tier'] as String? ?? 'CriticalSevere',
      complianceScorePct: (json['compliance_score_pct'] as num?)?.toDouble() ?? 0.0,
      evaluations: (json['evaluations'] as List<dynamic>?)
              ?.map((e) => RuleEvaluation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      violations: ViolationsSummary.fromJson(json['violations'] as Map<String, dynamic>? ?? {}),
      rawOcrTokens: (json['raw_ocr_tokens'] as List<dynamic>?)
              ?.map((e) => OcrToken.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      captureMode: json['capture_mode'] as String? ?? 'one-shot',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'inspection_id': inspectionId,
      'timestamp': timestamp,
      if (productName != null) 'product_name': productName,
      'scanned_panels': scannedPanels,
      'overall_compliant': overallCompliant,
      'risk_tier': riskTier,
      'compliance_score_pct': complianceScorePct,
      'evaluations': evaluations.map((e) => e.toJson()).toList(),
      'violations': violations.toJson(),
      'raw_ocr_tokens': rawOcrTokens.map((t) => t.toJson()).toList(),
      'capture_mode': captureMode,
    };
  }

  Map<String, dynamic> toSummaryMap() {
    return {
      'inspection_id': inspectionId,
      'product_name': productName ?? 'Pre-packaged Commodity',
      'risk_tier': riskTier,
      'compounding_fine_inr': violations.totalFineInr,
      'compliance_score_pct': complianceScorePct,
      'scanned_panels': scannedPanels,
      'total_violations': violations.totalViolations,
      'overall_compliant': overallCompliant,
      'created_at': timestamp,
      'timestamp': timestamp,
    };
  }

  String get riskTierFormatted {
    switch (riskTier) {
      case 'Compliant':
        return 'COMPLIANT';
      case 'LowRiskMinor':
        return 'LOW RISK';
      case 'ModerateRisk':
        return 'MODERATE RISK';
      case 'HighRiskMajor':
        return 'HIGH RISK';
      case 'CriticalSevere':
        return 'CRITICAL RISK';
      default:
        return riskTier.toUpperCase();
    }
  }
}
