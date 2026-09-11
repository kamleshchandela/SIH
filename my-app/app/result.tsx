import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Platform,
  Image,
  ActivityIndicator,
  Animated,
  Easing,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useLocalSearchParams, router } from 'expo-router';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { ComplianceReport, PanelQuality } from '../src/types/themis';
import { useAuth } from '../src/context/AuthContext';
import {
  formatDateTime,
  formatInr,
  getRiskTierInfo,
  getRuleStatusInfo,
} from '../src/utils/formatters';

function GlassyAnimatedBackground() {
  const orb1 = useRef(new Animated.Value(0)).current;
  const orb2 = useRef(new Animated.Value(0)).current;
  const scanLine = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    // Ambient Emerald Aura drifting loop
    Animated.loop(
      Animated.sequence([
        Animated.timing(orb1, {
          toValue: 1,
          duration: 7000,
          easing: Easing.inOut(Easing.sin),
          useNativeDriver: true,
        }),
        Animated.timing(orb1, {
          toValue: 0,
          duration: 7000,
          easing: Easing.inOut(Easing.sin),
          useNativeDriver: true,
        }),
      ])
    ).start();

    // Ambient Mint Aura drifting loop
    Animated.loop(
      Animated.sequence([
        Animated.timing(orb2, {
          toValue: 1,
          duration: 9000,
          easing: Easing.inOut(Easing.quad),
          useNativeDriver: true,
        }),
        Animated.timing(orb2, {
          toValue: 0,
          duration: 9000,
          easing: Easing.inOut(Easing.quad),
          useNativeDriver: true,
        }),
      ])
    ).start();

    // AI Compliance Scanner Beam loop
    Animated.loop(
      Animated.timing(scanLine, {
        toValue: 1,
        duration: 5500,
        easing: Easing.inOut(Easing.cubic),
        useNativeDriver: true,
      })
    ).start();
  }, [orb1, orb2, scanLine]);

  const orb1TranslateX = orb1.interpolate({
    inputRange: [0, 1],
    outputRange: [0, -45],
  });
  const orb1TranslateY = orb1.interpolate({
    inputRange: [0, 1],
    outputRange: [0, 60],
  });
  const orb1Scale = orb1.interpolate({
    inputRange: [0, 1],
    outputRange: [1, 1.3],
  });
  const orb1Opacity = orb1.interpolate({
    inputRange: [0, 1],
    outputRange: [0.45, 0.7],
  });

  const orb2TranslateX = orb2.interpolate({
    inputRange: [0, 1],
    outputRange: [0, 60],
  });
  const orb2TranslateY = orb2.interpolate({
    inputRange: [0, 1],
    outputRange: [0, -50],
  });
  const orb2Scale = orb2.interpolate({
    inputRange: [0, 1],
    outputRange: [1, 1.25],
  });
  const orb2Opacity = orb2.interpolate({
    inputRange: [0, 1],
    outputRange: [0.38, 0.62],
  });

  const scanLineTranslateY = scanLine.interpolate({
    inputRange: [0, 1],
    outputRange: [-30, 850],
  });
  const scanLineOpacity = scanLine.interpolate({
    inputRange: [0, 0.15, 0.85, 1],
    outputRange: [0, 0.32, 0.32, 0],
  });

  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="none">
      {/* Orb 1: Emerald Aura */}
      <Animated.View
        style={[
          styles.ambientOrb,
          {
            top: -20,
            right: -30,
            width: 300,
            height: 300,
            borderRadius: 150,
            backgroundColor: '#10b981',
            opacity: orb1Opacity,
            transform: [
              { translateX: orb1TranslateX },
              { translateY: orb1TranslateY },
              { scale: orb1Scale },
            ],
          },
        ]}
      />

      {/* Orb 2: Mint/Cyan Aura */}
      <Animated.View
        style={[
          styles.ambientOrb,
          {
            top: 260,
            left: -60,
            width: 290,
            height: 290,
            borderRadius: 145,
            backgroundColor: '#06b6d4',
            opacity: orb2Opacity,
            transform: [
              { translateX: orb2TranslateX },
              { translateY: orb2TranslateY },
              { scale: orb2Scale },
            ],
          },
        ]}
      />

      {/* Orb 3: Soft Spring Lime Aura */}
      <Animated.View
        style={[
          styles.ambientOrb,
          {
            bottom: 70,
            right: -30,
            width: 280,
            height: 280,
            borderRadius: 140,
            backgroundColor: '#84cc16',
            opacity: orb1Opacity,
            transform: [
              { translateX: orb2TranslateX },
              { translateY: orb1TranslateY },
              { scale: orb2Scale },
            ],
          },
        ]}
      />

      {/* Orb 4: Deep Soft Teal Aura */}
      <Animated.View
        style={[
          styles.ambientOrb,
          {
            bottom: 300,
            left: -40,
            width: 240,
            height: 240,
            borderRadius: 120,
            backgroundColor: '#059669',
            opacity: orb2Opacity,
            transform: [
              { translateX: orb1TranslateX },
              { translateY: orb2TranslateY },
              { scale: orb1Scale },
            ],
          },
        ]}
      />

      {/* PARAKH AI Scanning Beam */}
      <Animated.View
        style={[
          styles.scannerBeam,
          {
            opacity: scanLineOpacity,
            transform: [{ translateY: scanLineTranslateY }],
          },
        ]}
      />
    </View>
  );
}

interface EvidencePanelCardProps {
  panelName: string;
  index: number;
  total: number;
  inspectionId: string;
  quality?: PanelQuality;
  api: any;
  token?: string | null;
}

function EvidencePanelCard({
  panelName,
  index,
  total,
  inspectionId,
  quality,
  api,
  token,
}: EvidencePanelCardProps) {
  const [loading, setLoading] = useState(true);
  const [hasError, setHasError] = useState(false);
  const evidenceUrl = api.getEvidenceUrl(inspectionId, panelName);

  const handleOpenFullPage = () => {
    router.push({
      pathname: '/evidence',
      params: { id: inspectionId, panel: panelName },
    });
  };

  return (
    <View style={styles.evidenceCard}>
      <View style={styles.evidenceHeaderRow}>
        <View style={styles.panelTitleWrap}>
          <View style={styles.panelNumberPill}>
            <Text style={styles.panelNumberPillText}>{index + 1}</Text>
          </View>
          <View style={{ flex: 1, flexShrink: 1 }}>
            <Text style={styles.panelNameHeading} numberOfLines={1}>
              {panelName}
            </Text>
            <Text style={styles.panelIndexSub} numberOfLines={1}>
              Image {index + 1} of {total} • Tap to view full
            </Text>
          </View>
        </View>

        {quality && (
          <View
            style={[
              styles.qualityBadge,
              {
                backgroundColor: quality.is_blurry
                  ? 'rgba(254, 226, 226, 0.85)'
                  : 'rgba(220, 252, 231, 0.85)',
                borderColor: quality.is_blurry
                  ? 'rgba(248, 113, 113, 0.5)'
                  : 'rgba(74, 222, 128, 0.5)',
              },
            ]}
          >
            <Ionicons
              name={quality.is_blurry ? 'warning-outline' : 'checkmark-circle-outline'}
              size={12}
              color={quality.is_blurry ? '#b91c1c' : '#15803d'}
            />
            <Text
              style={[
                styles.qualityBadgeText,
                { color: quality.is_blurry ? '#b91c1c' : '#15803d' },
              ]}
              numberOfLines={1}
            >
              {quality.is_blurry ? 'BLURRY' : 'LEGIBLE'}
            </Text>
          </View>
        )}
      </View>

      {/* Direct Tap-to-Full-Page Image Container */}
      <TouchableOpacity
        style={styles.evidenceImageContainer}
        onPress={handleOpenFullPage}
        activeOpacity={0.85}
      >
        {loading && (
          <View style={styles.imageLoadingOverlay}>
            <ActivityIndicator size="small" color="#10b981" />
            <Text style={styles.imageLoadingText}>Loading packaging evidence...</Text>
          </View>
        )}

        {hasError ? (
          <View style={styles.imageErrorWrap}>
            <Ionicons name="image-outline" size={42} color="#94a3b8" />
            <Text style={styles.imageErrorTitle}>Evidence image unavailable</Text>
            <Text style={styles.imageErrorSub}>
              Panel asset could not be loaded from backend server
            </Text>
          </View>
        ) : (
          <Image
            source={{
              uri: evidenceUrl,
              headers: token ? { Authorization: `Bearer ${token}` } : undefined,
            }}
            style={styles.evidenceImage}
            resizeMode="cover"
            onLoadEnd={() => setLoading(false)}
            onError={() => {
              setLoading(false);
              setHasError(true);
            }}
          />
        )}

        {!hasError && (
          <View style={styles.zoomOverlayBadge}>
            <Ionicons name="expand-outline" size={13} color="#ffffff" />
            <Text style={styles.zoomOverlayText}>Tap to View Full Page & Share</Text>
          </View>
        )}
      </TouchableOpacity>
    </View>
  );
}

export default function ResultScreen() {
  const insets = useSafeAreaInsets();
  const { api, token } = useAuth();
  const { data } = useLocalSearchParams<{ data: string }>();

  let report: ComplianceReport | null = null;
  try {
    if (data) {
      report = JSON.parse(data);
    }
  } catch (err) {
    console.warn('Failed to parse report data param:', err);
  }

  const [evalFilter, setEvalFilter] = useState<'all' | 'violation' | 'compliant'>('all');
  const [showOcrTokens, setShowOcrTokens] = useState(false);

  if (!report) {
    return (
      <View style={styles.errorContainer}>
        <GlassyAnimatedBackground />
        <View style={styles.errorIconWrap}>
          <Ionicons name="alert-circle-outline" size={48} color="#dc2626" />
        </View>
        <Text style={styles.errorTitle}>Inspection Data Not Found</Text>
        <Text style={styles.errorSubtitle}>
          The requested inspection report could not be loaded from memory.
        </Text>
        <TouchableOpacity style={styles.backBtn} onPress={() => router.back()} activeOpacity={0.8}>
          <Ionicons name="arrow-back" size={16} color="#ffffff" />
          <Text style={styles.backBtnText}>Return to Previous Screen</Text>
        </TouchableOpacity>
      </View>
    );
  }

  const riskInfo = getRiskTierInfo(report.risk_tier);
  const isCompliant = report.overall_compliant;

  // Filter evaluations
  const filteredEvaluations = report.evaluations.filter((ev) => {
    if (evalFilter === 'violation') return ev.status === 'Violation';
    if (evalFilter === 'compliant') return ev.status === 'Compliant';
    return true;
  });

  const violationCount = report.evaluations.filter((ev) => ev.status === 'Violation').length;
  const passCount = report.evaluations.filter((ev) => ev.status === 'Compliant').length;

  // Calculate total compounding fine
  const totalFine =
    report.violations?.statutory_penalties?.reduce(
      (acc, p) => acc + (p.compoundable_fine_inr || 0),
      0
    ) || 0;

  // Navigate directly to in-app CSV Spreadsheet Viewer
  const handleOpenCsvViewer = () => {
    if (!report) return;
    router.push({
      pathname: '/csv-viewer',
      params: { data: JSON.stringify(report) },
    });
  };

  // Navigate directly to in-app Statutory Notice (PDF) Viewer
  const handleOpenPdfViewer = () => {
    if (!report) return;
    router.push({
      pathname: '/pdf-viewer',
      params: { data: JSON.stringify(report) },
    });
  };

  return (
    <View style={styles.screenWrapper}>
      <GlassyAnimatedBackground />
      <ScrollView
        contentContainerStyle={[styles.container, { paddingBottom: 100 + insets.bottom }]}
        showsVerticalScrollIndicator={false}
      >
        {/* 1. TOP STATUTORY HEADER */}
        <View style={styles.headerCard}>
          <View style={styles.headerTopRow}>
            <View style={styles.badgeInspection}>
              <Ionicons name="shield-checkmark" size={13} color="#047857" />
              <Text style={styles.inspectionIdLabel}>AUDIT ID</Text>
            </View>
            <View style={styles.timestampWrap}>
              <Ionicons name="calendar-outline" size={12} color="#065f46" />
              <Text style={styles.timestampText}>{formatDateTime(report.timestamp)}</Text>
            </View>
          </View>

          <Text style={styles.inspectionIdText} selectable numberOfLines={1} adjustsFontSizeToFit>
            {report.inspection_id}
          </Text>

          {report.product_name && (
            <View style={styles.productBanner}>
              <Ionicons name="cube-outline" size={16} color="#047857" style={{ marginTop: 2, flexShrink: 0 }} />
              <View style={{ flex: 1, flexShrink: 1 }}>
                <Text style={styles.productLabel}>Packaged Commodity</Text>
                <Text style={styles.productNameText}>{report.product_name}</Text>
              </View>
            </View>
          )}

          {report.scanned_panels && report.scanned_panels.length > 0 && (
            <View style={styles.panelsRow}>
              <Text style={styles.panelsRowLabel}>Panels Audited:</Text>
              {report.scanned_panels.map((p, idx) => (
                <View key={idx} style={styles.panelTag}>
                  <Text style={styles.panelTagText}>{p.toUpperCase()}</Text>
                </View>
              ))}
            </View>
          )}
        </View>

        {/* 2. STATUTORY VERDICT & COMPLIANCE SCORE BANNER */}
        <View
          style={[
            styles.statusBanner,
            isCompliant ? styles.statusBannerSuccess : styles.statusBannerDanger,
          ]}
        >
          <View style={styles.verdictTopRow}>
            <View style={styles.verdictTitleWrap}>
              <View
                style={[
                  styles.verdictIconCircle,
                  { backgroundColor: isCompliant ? '#dcfce7' : '#fee2e2' },
                ]}
              >
                <Ionicons
                  name={isCompliant ? 'checkmark-circle' : 'alert-circle'}
                  size={24}
                  color={isCompliant ? '#16a34a' : '#dc2626'}
                />
              </View>
              <View style={{ flex: 1, flexShrink: 1 }}>
                <Text
                  style={[
                    styles.statusVerdictLabel,
                    { color: isCompliant ? '#15803d' : '#b91c1c' },
                  ]}
                  numberOfLines={1}
                  adjustsFontSizeToFit
                >
                  {isCompliant ? 'STATUTORY COMPLIANT' : 'STATUTORY VIOLATION'}
                </Text>
                <Text style={styles.verdictSubtext}>
                  {isCompliant
                    ? 'Packaged commodity complies with Metrology Rules'
                    : 'Non-compliances detected under Act / Rules'}
                </Text>
              </View>
            </View>

            <View style={[styles.riskTierPill, { backgroundColor: riskInfo.bgColor, flexShrink: 0 }]}>
              <Text style={[styles.riskTierText, { color: riskInfo.color }]} numberOfLines={1}>
                {riskInfo.label}
              </Text>
            </View>
          </View>

          {/* Compliance Score Bar */}
          <View style={styles.scoreSection}>
            <View style={styles.scoreHeaderRow}>
              <Text style={styles.scoreTitle}>Statutory Compliance Score</Text>
              <Text
                style={[
                  styles.scorePercentageText,
                  { color: isCompliant ? '#15803d' : '#b91c1c' },
                ]}
              >
                {report.compliance_score_pct.toFixed(1)}%
              </Text>
            </View>
            <View style={styles.progressBarTrack}>
              <View
                style={[
                  styles.progressBarFill,
                  {
                    width: `${Math.min(Math.max(report.compliance_score_pct, 0), 100)}%`,
                    backgroundColor: isCompliant ? '#16a34a' : '#dc2626',
                  },
                ]}
              />
            </View>
          </View>
        </View>

        {/* 3. UPLOADED PACKAGING EVIDENCE (ALL IMAGES DISPLAYED) */}
        {(() => {
          const panelsToDisplay =
            report.scanned_panels && report.scanned_panels.length > 0
              ? report.scanned_panels
              : report.panel_qualities && report.panel_qualities.length > 0
                ? report.panel_qualities.map((pq) => pq.panel_name)
                : [];

          if (panelsToDisplay.length === 0) return null;

          return (
            <View style={styles.sectionCard}>
              <View style={styles.sectionHeaderRow}>
                <View style={styles.sectionTitleWrap}>
                  <Ionicons name="images-outline" size={18} color="#022c22" />
                  <Text style={styles.sectionTitle} numberOfLines={1}>
                    Packaging Evidence ({panelsToDisplay.length})
                  </Text>
                </View>
                <View style={styles.evidenceSecBadge}>
                  <Ionicons name="finger-print-outline" size={12} color="#047857" />
                  <Text style={styles.evidenceSecBadgeText} numberOfLines={1}>Official Evidence</Text>
                </View>
              </View>

              <Text style={styles.sectionSubtitleText}>
                All packaging panel photographs uploaded and inspected for this audit.
              </Text>

              <View style={styles.evidenceCardsList}>
                {panelsToDisplay.map((panelName, idx) => {
                  const quality = report?.panel_qualities?.find(
                    (q) => q.panel_name === panelName || panelName.includes(q.panel_name)
                  );
                  return (
                    <EvidencePanelCard
                      key={`${panelName}-${idx}`}
                      panelName={panelName}
                      index={idx}
                      total={panelsToDisplay.length}
                      inspectionId={report.inspection_id}
                      quality={quality}
                      api={api}
                      token={token}
                    />
                  );
                })}
              </View>
            </View>
          );
        })()}

        {/* 4. RULE-BY-RULE STATUTORY EVALUATIONS */}
        <View style={styles.sectionCard}>
          <View style={styles.evalHeaderRow}>
            <View style={styles.sectionTitleWrap}>
              <Ionicons name="list-outline" size={18} color="#022c22" />
              <Text style={styles.sectionTitle} numberOfLines={1}>
                Rule Evaluations ({report.evaluations.length})
              </Text>
            </View>
          </View>

          {/* Filter Pills */}
          <View style={styles.evalFilterBar}>
            <TouchableOpacity
              style={[styles.evalFilterTab, evalFilter === 'all' && styles.evalFilterTabActive]}
              onPress={() => setEvalFilter('all')}
              activeOpacity={0.8}
            >
              <Text
                style={[styles.evalFilterText, evalFilter === 'all' && styles.evalFilterTextActive]}
                numberOfLines={1}
                adjustsFontSizeToFit
              >
                All ({report.evaluations.length})
              </Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[
                styles.evalFilterTab,
                evalFilter === 'violation' && styles.evalFilterTabActiveViolation,
              ]}
              onPress={() => setEvalFilter('violation')}
              activeOpacity={0.8}
            >
              <Text
                style={[
                  styles.evalFilterText,
                  evalFilter === 'violation' && styles.evalFilterTabActiveViolation,
                ]}
                numberOfLines={1}
                adjustsFontSizeToFit
              >
                Violations ({violationCount})
              </Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[
                styles.evalFilterTab,
                evalFilter === 'compliant' && styles.evalFilterTabActivePass,
              ]}
              onPress={() => setEvalFilter('compliant')}
              activeOpacity={0.8}
            >
              <Text
                style={[
                  styles.evalFilterText,
                  evalFilter === 'compliant' && styles.evalFilterTabActivePass,
                ]}
                numberOfLines={1}
                adjustsFontSizeToFit
              >
                Pass ({passCount})
              </Text>
            </TouchableOpacity>
          </View>

          {filteredEvaluations.length === 0 ? (
            <View style={styles.emptyFilterBox}>
              <Ionicons name="filter-outline" size={24} color="#52796f" />
              <Text style={styles.emptyText}>No evaluations match this filter.</Text>
            </View>
          ) : (
            filteredEvaluations.map((evalItem, idx) => {
              const st = getRuleStatusInfo(evalItem.status);
              const isViolation = evalItem.status === 'Violation';

              return (
                <View
                  key={idx}
                  style={[
                    styles.evalCard,
                    isViolation ? styles.evalCardViolation : styles.evalCardCompliant,
                  ]}
                >
                  <View style={styles.evalCardHeader}>
                    <View style={styles.evalFieldGroup}>
                      <Text style={styles.evalFieldTitle}>{evalItem.field}</Text>
                      {evalItem.source_panel && (
                        <View style={styles.sourceBadge}>
                          <Ionicons name="scan-outline" size={11} color="#065f46" />
                          <Text style={styles.sourceBadgeText}>{evalItem.source_panel}</Text>
                        </View>
                      )}
                    </View>

                    <View style={[styles.ruleStatusBadge, { backgroundColor: st.bgColor }]}>
                      <Ionicons
                        name={isViolation ? 'close-circle' : 'checkmark-circle'}
                        size={12}
                        color={st.color}
                        style={{ marginRight: 3, flexShrink: 0 }}
                      />
                      <Text style={[styles.ruleStatusText, { color: st.color }]} numberOfLines={1}>
                        {st.label}
                      </Text>
                    </View>
                  </View>

                  {/* Remarks Description */}
                  <Text style={styles.evalRemarks}>{evalItem.remarks}</Text>

                  {/* Detected OCR Value */}
                  {evalItem.matched_token && (
                    <View style={styles.detectedWrap}>
                      <View style={styles.detectedHeader}>
                        <Ionicons name="document-text-outline" size={13} color="#047857" style={{ flexShrink: 0 }} />
                        <Text style={styles.detectedLabel}>Detected OCR Text</Text>
                      </View>
                      <Text style={styles.detectedValue} selectable>
                        "{evalItem.matched_token}"
                      </Text>
                    </View>
                  )}
                </View>
              );
            })
          )}
        </View>

        {/* 5. STATUTORY PENALTIES & JAN VISHWAS COMPOUNDING */}
        {report.violations && (
          <View style={styles.sectionCard}>
            <View style={styles.sectionHeaderRow}>
              <View style={styles.sectionTitleWrap}>
                <Ionicons name="hammer-outline" size={18} color="#b45309" />
                <Text style={styles.sectionTitle} numberOfLines={1}>Statutory Penalties</Text>
              </View>
              <View style={styles.actBadge}>
                <Text style={styles.actBadgeText} numberOfLines={1}>Jan Vishwas Act</Text>
              </View>
            </View>

            {/* Total Compounding Box */}
            <View style={styles.totalFineBox}>
              <View style={{ flex: 1, flexShrink: 1 }}>
                <Text style={styles.totalFineLabel}>Statutory Compounding Estimate</Text>
                <Text style={styles.totalFineAmount}>{formatInr(totalFine)}</Text>
                <Text style={styles.totalFineNote}>
                  Estimated compounding fee for first offense under Section 36(1) / Section 49
                </Text>
              </View>
              <View style={styles.fineIconCircle}>
                <Ionicons name="shield" size={28} color="#b45309" />
              </View>
            </View>

            {/* Mandatory Missing Declarations (Rule 6) */}
            {report.violations.mandatory_missing && report.violations.mandatory_missing.length > 0 && (
              <View style={styles.missingSection}>
                <View style={styles.missingSectionTitleRow}>
                  <Ionicons name="alert-circle" size={15} color="#dc2626" style={{ flexShrink: 0 }} />
                  <Text style={styles.missingTitle}>
                    Missing Mandatory Declarations (Rule 6):
                  </Text>
                </View>
                <View style={styles.chipRow}>
                  {report.violations.mandatory_missing.map((item, idx) => (
                    <View key={idx} style={styles.missingChip}>
                      <Ionicons name="close-circle" size={13} color="#dc2626" style={{ flexShrink: 0 }} />
                      <Text style={styles.missingChipText}>{item}</Text>
                    </View>
                  ))}
                </View>
              </View>
            )}

            {/* Illegal Non Standard Units (Rule 13) */}
            {report.violations.non_standard_units && report.violations.non_standard_units.length > 0 && (
              <View style={styles.missingSection}>
                <View style={styles.missingSectionTitleRow}>
                  <Ionicons name="warning" size={15} color="#d97706" style={{ flexShrink: 0 }} />
                  <Text style={styles.missingTitle}>
                    Illegal Non-Standard Units (Rule 13):
                  </Text>
                </View>
                <View style={styles.chipRow}>
                  {report.violations.non_standard_units.map((unit, idx) => (
                    <View key={idx} style={styles.unitChip}>
                      <Text style={styles.unitChipText}>
                        '{unit}' <Text style={styles.unitChipSub}>(Must use SI units)</Text>
                      </Text>
                    </View>
                  ))}
                </View>
              </View>
            )}

            {/* Individual Penalty Clauses */}
            {report.violations.statutory_penalties &&
              report.violations.statutory_penalties.map((penalty, idx) => (
                <View key={idx} style={styles.penaltyItem}>
                  <View style={styles.penaltyTopRow}>
                    <View style={styles.penaltySectionBadge}>
                      <Text style={styles.penaltySectionText}>{penalty.section}</Text>
                    </View>
                    <Text style={styles.penaltyAmount}>
                      {formatInr(penalty.compoundable_fine_inr)}
                    </Text>
                  </View>
                  {penalty.offense && (
                    <Text style={styles.penaltyOffense}>{penalty.offense}</Text>
                  )}
                </View>
              ))}
          </View>
        )}

        {/* 6. RAW OCR DETECTED TOKENS (COLLAPSIBLE) */}
        <View style={styles.sectionCard}>
          <TouchableOpacity
            style={styles.accordionHeader}
            onPress={() => setShowOcrTokens(!showOcrTokens)}
            activeOpacity={0.7}
          >
            <View style={styles.accordionTitleRow}>
              <Ionicons name="scan-circle-outline" size={20} color="#047857" style={{ flexShrink: 0 }} />
              <Text style={styles.sectionTitle} numberOfLines={1}>
                Extracted OCR ({report.raw_ocr_tokens?.length || 0})
              </Text>
            </View>
            <View style={styles.chevronCircle}>
              <Ionicons
                name={showOcrTokens ? 'chevron-up' : 'chevron-down'}
                size={18}
                color="#065f46"
              />
            </View>
          </TouchableOpacity>

          {showOcrTokens && (
            <View style={styles.tokensContainer}>
              <Text style={styles.tokensDesc}>
                Raw bounding-box extracted text tokens with inference confidence scores:
              </Text>
              {report.raw_ocr_tokens?.length === 0 ? (
                <Text style={styles.emptyText}>No text tokens extracted.</Text>
              ) : (
                report.raw_ocr_tokens?.map((tok, idx) => (
                  <View key={idx} style={styles.tokenItem}>
                    <Text style={styles.tokenText}>"{tok.text}"</Text>
                    <View style={styles.tokenMetaRow}>
                      <View style={styles.confBadge}>
                        <Ionicons name="checkmark" size={11} color="#16a34a" />
                        <Text style={styles.tokenConfidence}>
                          {(tok.confidence * 100).toFixed(1)}%
                        </Text>
                      </View>
                      {tok.bbox && (
                        <Text style={styles.tokenCoords}>
                          ({tok.bbox.x}, {tok.bbox.y}) {tok.bbox.width}x{tok.bbox.height}
                        </Text>
                      )}
                    </View>
                  </View>
                ))
              )}
            </View>
          )}
        </View>
      </ScrollView>

      {/* 7. FIXED FLOATING BOTTOM ACTION BAR */}
      <View style={[styles.actionBar, { paddingBottom: Math.max(insets.bottom, 12) }]}>
        <TouchableOpacity
          style={styles.actionBtnSecondary}
          onPress={handleOpenCsvViewer}
          activeOpacity={0.8}
        >
          <Ionicons name="grid-outline" size={18} color="#022c22" style={{ flexShrink: 0 }} />
          <Text style={styles.actionBtnSecondaryText} numberOfLines={1}>View CSV Audit</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.actionBtnPrimary}
          onPress={handleOpenPdfViewer}
          activeOpacity={0.8}
        >
          <Ionicons name="newspaper-outline" size={18} color="#ffffff" style={{ flexShrink: 0 }} />
          <Text style={styles.actionBtnPrimaryText} numberOfLines={1}>View Legal Notice</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  screenWrapper: {
    flex: 1,
    backgroundColor: '#ebf4ed',
  },
  container: {
    padding: 16,
    gap: 14,
  },

  // Ambient Glow Orbs & Scanner
  ambientOrb: {
    position: 'absolute',
  },
  scannerBeam: {
    position: 'absolute',
    left: 0,
    right: 0,
    height: 2.5,
    backgroundColor: '#34d399',
    shadowColor: '#34d399',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.85,
    shadowRadius: 10,
  },

  // Error State Screen
  errorContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
    backgroundColor: '#ebf4ed',
  },
  errorIconWrap: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: 'rgba(254, 226, 226, 0.8)',
    borderWidth: 1.5,
    borderColor: 'rgba(248, 113, 113, 0.5)',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 16,
  },
  errorTitle: {
    fontSize: 18,
    fontWeight: '900',
    color: '#022c22',
    textAlign: 'center',
  },
  errorSubtitle: {
    fontSize: 13,
    color: '#065f46',
    textAlign: 'center',
    marginTop: 6,
    lineHeight: 18,
    fontWeight: '600',
  },
  backBtn: {
    marginTop: 20,
    backgroundColor: 'rgba(6, 42, 21, 0.92)',
    paddingHorizontal: 22,
    paddingVertical: 13,
    borderRadius: 18,
    borderWidth: 1.5,
    borderColor: 'rgba(74, 222, 128, 0.45)',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    shadowColor: '#052e16',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 3,
  },
  backBtnText: {
    color: '#ffffff',
    fontWeight: '800',
    fontSize: 14,
  },

  // 1. Header Card (Frosted Glass)
  headerCard: {
    backgroundColor: 'rgba(255, 255, 255, 0.58)',
    padding: 18,
    borderRadius: 26,
    borderWidth: 1.5,
    borderColor: 'rgba(255, 255, 255, 0.95)',
    shadowColor: '#064e3b',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.08,
    shadowRadius: 18,
    elevation: 3,
  },
  headerTopRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
    flexWrap: 'wrap',
    gap: 6,
  },
  badgeInspection: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    backgroundColor: 'rgba(16, 185, 129, 0.12)',
    paddingHorizontal: 9,
    paddingVertical: 4,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: 'rgba(16, 185, 129, 0.28)',
    flexShrink: 0,
  },
  inspectionIdLabel: {
    fontSize: 11,
    fontWeight: '900',
    color: '#065f46',
    letterSpacing: 0.5,
  },
  timestampWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    flexShrink: 1,
  },
  timestampText: {
    fontSize: 12,
    color: '#0f5132',
    fontWeight: '600',
  },
  inspectionIdText: {
    fontSize: 16,
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    fontWeight: '900',
    color: '#022c22',
    letterSpacing: 0.5,
  },
  productBanner: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 10,
    marginTop: 12,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: 'rgba(255, 255, 255, 0.9)',
    backgroundColor: 'rgba(255, 255, 255, 0.45)',
    padding: 12,
    borderRadius: 14,
  },
  productLabel: {
    fontSize: 11,
    fontWeight: '800',
    color: '#065f46',
    textTransform: 'uppercase',
  },
  productNameText: {
    fontSize: 15,
    fontWeight: '900',
    color: '#022c22',
    marginTop: 1,
  },
  panelsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    flexWrap: 'wrap',
    gap: 6,
    marginTop: 10,
    paddingTop: 10,
    borderTopWidth: 1,
    borderTopColor: 'rgba(255, 255, 255, 0.9)',
  },
  panelsRowLabel: {
    fontSize: 12,
    fontWeight: '700',
    color: '#065f46',
  },
  panelTag: {
    backgroundColor: 'rgba(255, 255, 255, 0.65)',
    paddingHorizontal: 9,
    paddingVertical: 3,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: 'rgba(6, 95, 70, 0.2)',
  },
  panelTagText: {
    fontSize: 11,
    fontWeight: '800',
    color: '#022c22',
  },

  // 2. Status Banner
  statusBanner: {
    padding: 18,
    borderRadius: 26,
    borderWidth: 1.5,
    shadowColor: '#064e3b',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.08,
    shadowRadius: 18,
    elevation: 3,
  },
  statusBannerSuccess: {
    backgroundColor: 'rgba(236, 253, 245, 0.68)',
    borderColor: 'rgba(110, 231, 183, 0.9)',
  },
  statusBannerDanger: {
    backgroundColor: 'rgba(254, 242, 242, 0.68)',
    borderColor: 'rgba(252, 165, 165, 0.9)',
  },
  verdictTopRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    flexWrap: 'wrap',
    gap: 10,
  },
  verdictTitleWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    flex: 1,
    minWidth: 180,
  },
  verdictIconCircle: {
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.8)',
    flexShrink: 0,
  },
  statusVerdictLabel: {
    fontSize: 15,
    fontWeight: '900',
    letterSpacing: 0.5,
  },
  verdictSubtext: {
    fontSize: 12,
    color: '#0f5132',
    fontWeight: '600',
    marginTop: 2,
    lineHeight: 16,
  },
  riskTierPill: {
    paddingHorizontal: 11,
    paddingVertical: 6,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.7)',
    flexShrink: 0,
    alignSelf: 'flex-start',
  },
  riskTierText: {
    fontSize: 11,
    fontWeight: '900',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  scoreSection: {
    marginTop: 14,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: 'rgba(6, 95, 70, 0.1)',
  },
  scoreHeaderRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  scoreTitle: {
    fontSize: 13,
    fontWeight: '800',
    color: '#022c22',
  },
  scorePercentageText: {
    fontSize: 22,
    fontWeight: '900',
  },
  progressBarTrack: {
    height: 9,
    backgroundColor: 'rgba(6, 95, 70, 0.12)',
    borderRadius: 5,
    overflow: 'hidden',
  },
  progressBarFill: {
    height: '100%',
    borderRadius: 5,
  },

  // Section Cards (Frosted Glass)
  sectionCard: {
    backgroundColor: 'rgba(255, 255, 255, 0.58)',
    borderRadius: 26,
    padding: 18,
    borderWidth: 1.5,
    borderColor: 'rgba(255, 255, 255, 0.95)',
    shadowColor: '#064e3b',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.08,
    shadowRadius: 18,
    elevation: 3,
  },
  sectionHeaderRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
    flexWrap: 'wrap',
    gap: 8,
  },
  sectionTitleWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    flex: 1,
    minWidth: 160,
  },
  sectionTitle: {
    fontSize: 15,
    fontWeight: '900',
    color: '#022c22',
  },
  sectionSubtitleBadge: {
    fontSize: 11,
    fontWeight: '700',
    color: '#065f46',
    backgroundColor: 'rgba(255, 255, 255, 0.65)',
    paddingHorizontal: 9,
    paddingVertical: 3,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: 'rgba(6, 95, 70, 0.2)',
    flexShrink: 0,
  },
  sectionSubtitleText: {
    fontSize: 12,
    color: '#0f5132',
    marginTop: 2,
    marginBottom: 14,
    lineHeight: 18,
    fontWeight: '600',
  },

  // 3. Panel Image Quality
  qualityList: {
    gap: 8,
  },
  qualityItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 10,
    paddingHorizontal: 12,
    backgroundColor: 'rgba(255, 255, 255, 0.52)',
    borderRadius: 14,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.9)',
  },
  qualityLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    flex: 1,
  },
  panelNameText: {
    fontSize: 13,
    fontWeight: '800',
    color: '#022c22',
  },
  qualityBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
    borderWidth: 1,
    flexShrink: 0,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  qualityBadgeText: {
    fontSize: 10,
    fontWeight: '900',
    letterSpacing: 0.3,
  },

  // 4. Rule Evaluations
  evalHeaderRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  evalFilterBar: {
    flexDirection: 'row',
    backgroundColor: 'rgba(255, 255, 255, 0.65)',
    borderRadius: 18,
    padding: 3,
    marginBottom: 14,
    gap: 3,
    borderWidth: 1.2,
    borderColor: 'rgba(255, 255, 255, 0.95)',
  },
  evalFilterTab: {
    flex: 1,
    paddingVertical: 7,
    paddingHorizontal: 2,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 14,
  },
  evalFilterTabActive: {
    backgroundColor: 'rgba(255, 255, 255, 0.95)',
    shadowColor: '#064e3b',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 4,
    elevation: 2,
  },
  evalFilterTabActiveViolation: {
    backgroundColor: 'rgba(254, 226, 226, 0.92)',
    shadowColor: '#991b1b',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 4,
    elevation: 2,
  },
  evalFilterTabActivePass: {
    backgroundColor: 'rgba(220, 252, 231, 0.92)',
    shadowColor: '#065f46',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 4,
    elevation: 2,
  },
  evalFilterText: {
    fontSize: 10.5,
    fontWeight: '800',
    color: '#065f46',
    textAlign: 'center',
  },
  evalFilterTextActive: {
    color: '#022c22',
    fontWeight: '900',
  },
  evalFilterTextActiveViolation: {
    color: '#991b1b',
    fontWeight: '900',
  },
  evalFilterTextActivePass: {
    color: '#065f46',
    fontWeight: '900',
  },
  emptyFilterBox: {
    alignItems: 'center',
    paddingVertical: 24,
    gap: 8,
  },
  emptyText: {
    fontSize: 13,
    color: '#52796f',
    textAlign: 'center',
    fontWeight: '600',
  },
  evalCard: {
    backgroundColor: 'rgba(255, 255, 255, 0.55)',
    borderRadius: 20,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1.5,
    borderColor: 'rgba(255, 255, 255, 0.95)',
    shadowColor: '#064e3b',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.04,
    shadowRadius: 8,
  },
  evalCardViolation: {
    borderColor: 'rgba(248, 113, 113, 0.65)',
    backgroundColor: 'rgba(254, 242, 242, 0.65)',
  },
  evalCardCompliant: {
    borderColor: 'rgba(110, 231, 183, 0.65)',
    backgroundColor: 'rgba(240, 253, 244, 0.65)',
  },
  evalCardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 8,
    gap: 8,
  },
  evalFieldGroup: {
    flex: 1,
    flexShrink: 1,
    marginRight: 4,
  },
  evalFieldTitle: {
    fontSize: 15,
    fontWeight: '900',
    color: '#022c22',
  },
  sourceBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    marginTop: 3,
  },
  sourceBadgeText: {
    fontSize: 11,
    color: '#065f46',
    fontWeight: '700',
  },
  ruleStatusBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 9,
    paddingVertical: 4,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.6)',
    flexShrink: 0,
  },
  ruleStatusText: {
    fontSize: 10,
    fontWeight: '900',
    letterSpacing: 0.3,
  },
  evalRemarks: {
    fontSize: 13,
    color: '#0f5132',
    lineHeight: 20,
    fontWeight: '600',
  },
  detectedWrap: {
    backgroundColor: 'rgba(255, 255, 255, 0.6)',
    borderRadius: 14,
    borderWidth: 1,
    borderColor: 'rgba(16, 185, 129, 0.3)',
    padding: 10,
    marginTop: 10,
  },
  detectedHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    marginBottom: 4,
  },
  detectedLabel: {
    fontSize: 10,
    fontWeight: '800',
    color: '#065f46',
    textTransform: 'uppercase',
  },
  detectedValue: {
    fontSize: 12,
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    color: '#022c22',
    fontWeight: '700',
  },

  // 5. Statutory Penalties
  actBadge: {
    backgroundColor: 'rgba(254, 240, 138, 0.65)',
    paddingHorizontal: 9,
    paddingVertical: 4,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: 'rgba(234, 179, 8, 0.4)',
    flexShrink: 0,
  },
  actBadgeText: {
    fontSize: 10,
    fontWeight: '900',
    color: '#854d0e',
  },
  totalFineBox: {
    backgroundColor: 'rgba(254, 252, 232, 0.72)',
    borderWidth: 1.5,
    borderColor: 'rgba(250, 204, 21, 0.7)',
    padding: 18,
    borderRadius: 22,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginVertical: 10,
    shadowColor: '#854d0e',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.08,
    shadowRadius: 10,
  },
  totalFineLabel: {
    fontSize: 11,
    fontWeight: '900',
    color: '#854d0e',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  totalFineAmount: {
    fontSize: 26,
    fontWeight: '900',
    color: '#78350f',
    marginTop: 2,
  },
  totalFineNote: {
    fontSize: 11,
    color: '#854d0e',
    marginTop: 4,
    lineHeight: 16,
    fontWeight: '600',
  },
  fineIconCircle: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: 'rgba(254, 240, 138, 0.8)',
    alignItems: 'center',
    justifyContent: 'center',
    marginLeft: 12,
    flexShrink: 0,
  },
  missingSection: {
    marginTop: 14,
  },
  missingSectionTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginBottom: 8,
    flexWrap: 'wrap',
  },
  missingTitle: {
    fontSize: 12,
    fontWeight: '800',
    color: '#022c22',
  },
  chipRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
  },
  missingChip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    backgroundColor: 'rgba(254, 226, 226, 0.75)',
    borderColor: 'rgba(248, 113, 113, 0.6)',
    borderWidth: 1,
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 12,
    maxWidth: '100%',
  },
  missingChipText: {
    fontSize: 12,
    color: '#991b1b',
    fontWeight: '800',
    flexShrink: 1,
  },
  unitChip: {
    backgroundColor: 'rgba(254, 243, 199, 0.75)',
    borderColor: 'rgba(251, 191, 36, 0.6)',
    borderWidth: 1,
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 12,
    maxWidth: '100%',
  },
  unitChipText: {
    fontSize: 12,
    color: '#854d0e',
    fontWeight: '800',
    flexShrink: 1,
  },
  unitChipSub: {
    fontSize: 11,
    fontWeight: '600',
    color: '#78350f',
  },
  penaltyItem: {
    backgroundColor: 'rgba(255, 255, 255, 0.55)',
    padding: 14,
    borderRadius: 16,
    marginTop: 8,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.95)',
  },
  penaltyTopRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    flexWrap: 'wrap',
    gap: 6,
  },
  penaltySectionBadge: {
    backgroundColor: 'rgba(6, 95, 70, 0.12)',
    paddingHorizontal: 9,
    paddingVertical: 4,
    borderRadius: 8,
    flexShrink: 1,
  },
  penaltySectionText: {
    fontSize: 11,
    fontWeight: '900',
    color: '#065f46',
  },
  penaltyAmount: {
    fontSize: 15,
    fontWeight: '900',
    color: '#b91c1c',
    flexShrink: 0,
  },
  penaltyOffense: {
    fontSize: 12,
    color: '#0f5132',
    marginTop: 4,
    lineHeight: 18,
    fontWeight: '600',
  },

  // 6. Accordion
  accordionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  accordionTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    flex: 1,
    flexShrink: 1,
  },
  chevronCircle: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: 'rgba(255, 255, 255, 0.75)',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.95)',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  },
  tokensContainer: {
    marginTop: 14,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: 'rgba(255, 255, 255, 0.9)',
    gap: 8,
  },
  tokensDesc: {
    fontSize: 11,
    color: '#065f46',
    marginBottom: 4,
    fontWeight: '600',
  },
  tokenItem: {
    backgroundColor: 'rgba(255, 255, 255, 0.55)',
    padding: 12,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.95)',
  },
  tokenText: {
    fontSize: 12,
    fontWeight: '800',
    color: '#022c22',
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
  },
  tokenMetaRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 6,
    flexWrap: 'wrap',
    gap: 4,
  },
  confBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
    backgroundColor: 'rgba(220, 252, 231, 0.8)',
    paddingHorizontal: 7,
    paddingVertical: 3,
    borderRadius: 6,
    flexShrink: 0,
  },
  tokenConfidence: {
    fontSize: 10,
    color: '#065f46',
    fontWeight: '900',
  },
  tokenCoords: {
    fontSize: 10,
    color: '#065f46',
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    fontWeight: '600',
    flexShrink: 1,
  },

  // 7. Bottom Floating Action Bar
  actionBar: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: 'rgba(255, 255, 255, 0.72)',
    borderTopWidth: 1.5,
    borderTopColor: 'rgba(255, 255, 255, 0.95)',
    paddingHorizontal: 16,
    paddingTop: 12,
    flexDirection: 'row',
    gap: 12,
    shadowColor: '#064e3b',
    shadowOffset: { width: 0, height: -4 },
    shadowOpacity: 0.1,
    shadowRadius: 16,
    elevation: 8,
  },
  actionBtnSecondary: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    backgroundColor: 'rgba(255, 255, 255, 0.85)',
    paddingVertical: 14,
    borderRadius: 18,
    borderWidth: 1.5,
    borderColor: 'rgba(6, 95, 70, 0.25)',
  },
  actionBtnSecondaryText: {
    fontSize: 13,
    fontWeight: '900',
    color: '#022c22',
  },
  actionBtnPrimary: {
    flex: 1.2,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    backgroundColor: 'rgba(6, 42, 21, 0.92)',
    paddingVertical: 14,
    borderRadius: 18,
    borderWidth: 1.5,
    borderColor: 'rgba(74, 222, 128, 0.45)',
    shadowColor: '#052e16',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.35,
    shadowRadius: 10,
    elevation: 4,
  },
  actionBtnPrimaryText: {
    fontSize: 13,
    fontWeight: '900',
    color: '#ffffff',
  },

  // EVIDENCE PHOTO GALLERY & MODAL STYLES
  evidenceSecBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: 'rgba(16, 185, 129, 0.12)',
    paddingHorizontal: 9,
    paddingVertical: 4,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: 'rgba(16, 185, 129, 0.28)',
    flexShrink: 0,
  },
  evidenceSecBadgeText: {
    fontSize: 11,
    fontWeight: '900',
    color: '#065f46',
  },
  evidenceCardsList: {
    gap: 14,
  },
  evidenceCard: {
    backgroundColor: 'rgba(255, 255, 255, 0.58)',
    borderRadius: 20,
    borderWidth: 1.5,
    borderColor: 'rgba(255, 255, 255, 0.95)',
    overflow: 'hidden',
    shadowColor: '#064e3b',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.05,
    shadowRadius: 10,
  },
  evidenceHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 14,
    paddingVertical: 11,
    backgroundColor: 'rgba(255, 255, 255, 0.72)',
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255, 255, 255, 0.9)',
    gap: 8,
  },
  panelTitleWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    flex: 1,
    flexShrink: 1,
  },
  panelNumberPill: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: 'rgba(6, 42, 21, 0.92)',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: 'rgba(74, 222, 128, 0.45)',
    flexShrink: 0,
  },
  panelNumberPillText: {
    color: '#ffffff',
    fontSize: 11,
    fontWeight: '900',
  },
  panelNameHeading: {
    fontSize: 14,
    fontWeight: '900',
    color: '#022c22',
  },
  panelIndexSub: {
    fontSize: 11,
    color: '#065f46',
    marginTop: 1,
    fontWeight: '600',
  },
  evidenceImageContainer: {
    width: '100%',
    height: 240,
    backgroundColor: '#022c22',
    position: 'relative',
    alignItems: 'center',
    justifyContent: 'center',
  },
  evidenceImage: {
    width: '100%',
    height: '100%',
  },
  imageLoadingOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(2, 44, 34, 0.75)',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
  },
  imageLoadingText: {
    fontSize: 11,
    color: '#a7f3d0',
    fontWeight: '700',
  },
  imageErrorWrap: {
    alignItems: 'center',
    justifyContent: 'center',
    padding: 20,
    gap: 6,
  },
  imageErrorTitle: {
    fontSize: 13,
    fontWeight: '800',
    color: '#d1fae5',
  },
  imageErrorSub: {
    fontSize: 11,
    color: '#a7f3d0',
    textAlign: 'center',
    fontWeight: '500',
  },
  zoomOverlayBadge: {
    position: 'absolute',
    bottom: 10,
    right: 10,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    backgroundColor: 'rgba(6, 42, 21, 0.85)',
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: 'rgba(74, 222, 128, 0.35)',
  },
  zoomOverlayText: {
    fontSize: 10,
    fontWeight: '800',
    color: '#ffffff',
  },
});
