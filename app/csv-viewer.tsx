import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Alert,
  ActivityIndicator,
  Platform,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useLocalSearchParams, router } from 'expo-router';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import * as FileSystem from 'expo-file-system/legacy';
import * as Sharing from 'expo-sharing';
import { ComplianceReport } from '../src/types/themis';
import { formatDateTime, formatInr, generateCsvContent, getRuleStatusInfo } from '../src/utils/formatters';

export default function CsvViewerScreen() {
  const insets = useSafeAreaInsets();
  const { data } = useLocalSearchParams<{ data: string }>();
  const [sharing, setSharing] = useState(false);
  const [viewMode, setViewMode] = useState<'cards' | 'table'>('cards');

  let report: ComplianceReport | null = null;
  try {
    if (data) {
      report = JSON.parse(data);
    }
  } catch (err) {
    console.warn('Failed to parse report in CSV viewer:', err);
  }

  if (!report) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.errorBox}>
          <View style={styles.errorIconWrap}>
            <Ionicons name="alert-circle-outline" size={48} color="#dc2626" />
          </View>
          <Text style={styles.errorTitle}>Inspection Dataset Missing</Text>
          <Text style={styles.errorText}>
            Unable to load the inspection dataset required to view the statutory CSV.
          </Text>
          <TouchableOpacity
            style={styles.backBtn}
            onPress={() => router.back()}
            activeOpacity={0.8}
          >
            <Ionicons name="arrow-back" size={18} color="#ffffff" />
            <Text style={styles.backBtnText}>Return to Report</Text>
          </TouchableOpacity>
        </View>
      </SafeAreaView>
    );
  }

  const csvString = generateCsvContent(report);

  const totalFine =
    report.violations?.statutory_penalties?.reduce(
      (acc, p) => acc + (p.compoundable_fine_inr || 0),
      0
    ) || 0;

  const handleShareCsv = async () => {
    if (!report) return;
    setSharing(true);
    try {
      const fileUri = `${FileSystem.cacheDirectory}statutory_audit_${report.inspection_id}.csv`;
      await FileSystem.writeAsStringAsync(fileUri, csvString, {
        encoding: FileSystem.EncodingType.UTF8,
      });

      if (await Sharing.isAvailableAsync()) {
        await Sharing.shareAsync(fileUri, {
          mimeType: 'text/csv',
          dialogTitle: `Share Audit CSV (${report.inspection_id})`,
          UTI: 'public.comma-separated-values-text',
        });
      } else {
        Alert.alert('CSV Ready', `CSV exported to: ${fileUri}`);
      }
    } catch (err: any) {
      Alert.alert('Export Error', err.message || 'Failed to export CSV dataset.');
    } finally {
      setSharing(false);
    }
  };

  return (
    <SafeAreaView style={styles.container} edges={['top', 'left', 'right']}>
      {/* 1. Top Bar */}
      <View style={styles.topBar}>
        <TouchableOpacity
          style={styles.navBackBtn}
          onPress={() => router.back()}
          activeOpacity={0.7}
        >
          <Ionicons name="arrow-back" size={22} color="#0f172a" />
        </TouchableOpacity>

        <View style={styles.headerCenter}>
          <Text style={styles.headerTitle} numberOfLines={1}>
            Statutory CSV Audit
          </Text>
          <Text style={styles.headerSubtitle} numberOfLines={1}>
            RFC 4180 Dataset Specification
          </Text>
        </View>

        <TouchableOpacity
          style={[styles.navActionBtn, sharing && { opacity: 0.7 }]}
          onPress={handleShareCsv}
          disabled={sharing}
          activeOpacity={0.7}
        >
          {sharing ? (
            <ActivityIndicator size="small" color="#047857" />
          ) : (
            <Ionicons name="share-social-outline" size={20} color="#0f172a" />
          )}
        </TouchableOpacity>
      </View>

      <ScrollView
        contentContainerStyle={[
          styles.scrollArea,
          { paddingBottom: Math.max(insets.bottom + 28, 48) },
        ]}
        showsVerticalScrollIndicator={true}
      >
        {/* 2. Metadata Card */}
        <View style={styles.metaCard}>
          <View style={styles.metaCardTop}>
            <View style={styles.metaIconBadge}>
              <Ionicons name="grid-outline" size={20} color="#047857" />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.metaDocTitle}>Statutory Metrology Dataset</Text>
              <Text style={styles.metaDocSub}>Legal Metrology Act, 2009 • Packaged Commodities</Text>
            </View>
            <View
              style={[
                styles.verdictBadge,
                {
                  backgroundColor: report.overall_compliant ? '#dcfce7' : '#fee2e2',
                  borderColor: report.overall_compliant ? '#86efac' : '#fca5a5',
                },
              ]}
            >
              <Ionicons
                name={report.overall_compliant ? 'checkmark-circle' : 'alert-circle'}
                size={13}
                color={report.overall_compliant ? '#15803d' : '#b91c1c'}
              />
              <Text
                style={[
                  styles.verdictBadgeText,
                  { color: report.overall_compliant ? '#15803d' : '#b91c1c' },
                ]}
              >
                {report.overall_compliant ? 'COMPLIANT' : 'VIOLATION'}
              </Text>
            </View>
          </View>

          <View style={styles.metaDivider} />

          <View style={styles.metaFieldsList}>
            <View style={styles.metaFieldRow}>
              <Text style={styles.metaFieldLabel}>Audit Reference</Text>
              <Text style={styles.metaFieldValMono} selectable>
                {report.inspection_id}
              </Text>
            </View>

            <View style={styles.metaFieldRow}>
              <Text style={styles.metaFieldLabel}>Timestamp</Text>
              <Text style={styles.metaFieldVal}>
                {formatDateTime(report.timestamp)}
              </Text>
            </View>

            <View style={styles.metaFieldRow}>
              <Text style={styles.metaFieldLabel}>Commodity Title</Text>
              <Text style={styles.metaFieldValBold}>
                {report.product_name || 'Standard Packaged Commodity'}
              </Text>
            </View>

            <View style={styles.metaFieldRow}>
              <Text style={styles.metaFieldLabel}>Score & Tier</Text>
              <Text style={[styles.metaFieldValBold, { color: report.overall_compliant ? '#15803d' : '#b91c1c' }]}>
                {report.compliance_score_pct.toFixed(1)}% • {report.risk_tier || 'Standard Risk'}
              </Text>
            </View>
          </View>
        </View>

        {/* 3. View Switcher Bar */}
        <View style={styles.viewSwitcherBar}>
          <TouchableOpacity
            style={[styles.viewSwitchTab, viewMode === 'cards' && styles.viewSwitchTabActive]}
            onPress={() => setViewMode('cards')}
            activeOpacity={0.8}
          >
            <Ionicons
              name="list"
              size={16}
              color={viewMode === 'cards' ? '#ffffff' : '#065f46'}
            />
            <Text
              style={[
                styles.viewSwitchText,
                viewMode === 'cards' && styles.viewSwitchTextActive,
              ]}
            >
              Readable Cards ({report.evaluations?.length || 0})
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.viewSwitchTab, viewMode === 'table' && styles.viewSwitchTabActive]}
            onPress={() => setViewMode('table')}
            activeOpacity={0.8}
          >
            <Ionicons
              name="grid"
              size={15}
              color={viewMode === 'table' ? '#ffffff' : '#065f46'}
            />
            <Text
              style={[
                styles.viewSwitchText,
                viewMode === 'table' && styles.viewSwitchTextActive,
              ]}
            >
              Spreadsheet Grid
            </Text>
          </TouchableOpacity>
        </View>

        {/* 4. Display Content */}
        {viewMode === 'cards' ? (
          <View style={styles.cardsContainer}>
            {report.evaluations?.map((ev, idx) => {
              const st = getRuleStatusInfo(ev.status);
              const isViolation = ev.status === 'Violation';

              return (
                <View
                  key={idx}
                  style={[
                    styles.evalCard,
                    isViolation ? styles.evalCardViolation : styles.evalCardCompliant,
                  ]}
                >
                  <View style={styles.evalCardHeader}>
                    <View style={styles.clausePill}>
                      <Text style={styles.clausePillText}>#{idx + 1}</Text>
                    </View>
                    <View style={{ flex: 1 }}>
                      <Text style={styles.evalCardTitle}>{ev.field}</Text>
                      {ev.source_panel && (
                        <Text style={styles.evalCardPanel}>
                          Panel: {ev.source_panel}
                        </Text>
                      )}
                    </View>

                    <View
                      style={[
                        styles.evalStatusBadge,
                        {
                          backgroundColor: isViolation ? '#fee2e2' : '#dcfce7',
                          borderColor: isViolation ? '#fca5a5' : '#86efac',
                        },
                      ]}
                    >
                      <Ionicons
                        name={isViolation ? 'close-circle' : 'checkmark-circle'}
                        size={13}
                        color={st.color}
                      />
                      <Text style={[styles.evalStatusBadgeText, { color: st.color }]}>
                        {st.label}
                      </Text>
                    </View>
                  </View>

                  <Text style={styles.evalCardRemarks}>{ev.remarks}</Text>

                  {ev.matched_token && (
                    <View style={styles.detectedWrap}>
                      <Text style={styles.detectedLabel}>DETECTED VALUE:</Text>
                      <Text style={styles.detectedVal} selectable>
                        "{ev.matched_token}"
                      </Text>
                    </View>
                  )}
                </View>
              );
            })}
          </View>
        ) : (
          <View style={styles.tableCard}>
            <Text style={styles.tableInstruction}>
              Scroll horizontally to view all columns
            </Text>
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={true}
              style={styles.horizontalScroll}
            >
              <View style={styles.tableContainer}>
                <View style={styles.tableHeaderRow}>
                  <Text style={[styles.thCell, { width: 160 }]}>Mandated Field</Text>
                  <Text style={[styles.thCell, { width: 120 }]}>Status</Text>
                  <Text style={[styles.thCell, { width: 120 }]}>Panel</Text>
                  <Text style={[styles.thCell, { width: 220 }]}>Detected Value</Text>
                  <Text style={[styles.thCell, { width: 280 }]}>Statutory Remarks</Text>
                </View>

                {report.evaluations?.map((ev, idx) => {
                  const st = getRuleStatusInfo(ev.status);
                  const isEven = idx % 2 === 0;

                  return (
                    <View
                      key={idx}
                      style={[
                        styles.tableDataRow,
                        isEven ? styles.tableRowEven : styles.tableRowOdd,
                      ]}
                    >
                      <Text style={[styles.tdCell, styles.fieldCell, { width: 160 }]}>
                        {ev.field}
                      </Text>

                      <View style={{ width: 120, paddingHorizontal: 6, justifyContent: 'center' }}>
                        <View style={[styles.tableStatusBadge, { backgroundColor: st.bgColor }]}>
                          <Text style={[styles.tableStatusText, { color: st.color }]}>
                            {st.label}
                          </Text>
                        </View>
                      </View>

                      <Text style={[styles.tdCell, styles.panelCell, { width: 120 }]}>
                        {ev.source_panel || 'N/A'}
                      </Text>

                      <View style={{ width: 220, paddingHorizontal: 6, justifyContent: 'center' }}>
                        {ev.matched_token ? (
                          <View style={styles.tableTokenBox}>
                            <Text style={styles.tableTokenText} selectable>
                              "{ev.matched_token}"
                            </Text>
                          </View>
                        ) : (
                          <Text style={styles.tableEmptyToken}>—</Text>
                        )}
                      </View>

                      <Text style={[styles.tdCell, styles.remarksCell, { width: 280 }]}>
                        {ev.remarks}
                      </Text>
                    </View>
                  );
                })}
              </View>
            </ScrollView>
          </View>
        )}

        {/* 5. Statutory Audit Totals Summary Card */}
        <View style={styles.summaryCard}>
          <View style={styles.summaryHeaderRow}>
            <Ionicons name="stats-chart" size={18} color="#047857" />
            <Text style={styles.summaryMainTitle}>STATUTORY AUDIT TOTALS</Text>
          </View>

          <View style={styles.summaryGrid}>
            <View style={styles.summaryRow}>
              <Text style={styles.summaryLabel}>Overall Status</Text>
              <Text
                style={[
                  styles.summaryValueBold,
                  { color: report.overall_compliant ? '#15803d' : '#b91c1c' },
                ]}
              >
                {report.overall_compliant ? 'COMPLIANT (PASS)' : 'STATUTORY VIOLATION'}
              </Text>
            </View>

            <View style={styles.summaryRow}>
              <Text style={styles.summaryLabel}>Statutory Compliance Score</Text>
              <Text style={styles.summaryValueBold}>
                {(report.compliance_score_pct || 0).toFixed(1)}%
              </Text>
            </View>

            <View style={styles.summaryRow}>
              <Text style={styles.summaryLabel}>Statutory Risk Tier</Text>
              <Text style={styles.summaryValueBold}>{report.risk_tier || 'N/A'}</Text>
            </View>

            {totalFine > 0 && (
              <View style={[styles.summaryRow, styles.penaltySummaryHighlight]}>
                <Text style={styles.penaltySummaryLabel}>Jan Vishwas Compounding Total</Text>
                <Text style={styles.penaltySummaryAmount}>{formatInr(totalFine)}</Text>
              </View>
            )}

            {report.violations?.mandatory_missing && report.violations.mandatory_missing.length > 0 && (
              <View style={styles.deficiencySummaryBlock}>
                <Text style={styles.deficiencySummaryHeading}>
                  Missing Mandatory Declarations ({report.violations.mandatory_missing.length}):
                </Text>
                {report.violations.mandatory_missing.map((item, idx) => (
                  <Text key={idx} style={styles.deficiencySummaryItem}>
                    • {item}
                  </Text>
                ))}
              </View>
            )}

            {report.violations?.non_standard_units && report.violations.non_standard_units.length > 0 && (
              <View style={styles.deficiencySummaryBlock}>
                <Text style={styles.deficiencySummaryHeading}>
                  Non-Standard Units ({report.violations.non_standard_units.length}):
                </Text>
                {report.violations.non_standard_units.map((unit, idx) => (
                  <Text key={idx} style={styles.deficiencySummaryItem}>
                    • '{unit}' (Standard SI units required)
                  </Text>
                ))}
              </View>
            )}
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#ebf4ed',
  },

  // 1. Top Bar
  topBar: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginHorizontal: 16,
    marginTop: 8,
    marginBottom: 8,
    paddingHorizontal: 14,
    paddingVertical: 12,
    backgroundColor: 'rgba(255, 255, 255, 0.85)',
    borderRadius: 22,
    borderWidth: 1.5,
    borderColor: 'rgba(255, 255, 255, 0.95)',
    shadowColor: '#064e3b',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.08,
    shadowRadius: 10,
    elevation: 3,
    gap: 12,
  },
  navBackBtn: {
    width: 42,
    height: 42,
    borderRadius: 21,
    backgroundColor: '#f1f5f9',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: '#cbd5e1',
    flexShrink: 0,
  },
  headerCenter: {
    flex: 1,
    alignItems: 'center',
  },
  headerTitle: {
    fontSize: 16,
    fontWeight: '900',
    color: '#0f172a',
    letterSpacing: 0.2,
  },
  headerSubtitle: {
    fontSize: 12,
    color: '#047857',
    fontWeight: '700',
    marginTop: 1,
  },
  navActionBtn: {
    width: 42,
    height: 42,
    borderRadius: 21,
    backgroundColor: '#f1f5f9',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: '#cbd5e1',
    flexShrink: 0,
  },

  // 2. Scroll Area
  scrollArea: {
    paddingHorizontal: 14,
    paddingTop: 8,
    gap: 14,
  },

  // Metadata Card
  metaCard: {
    backgroundColor: '#ffffff',
    borderRadius: 20,
    padding: 18,
    borderWidth: 1.5,
    borderColor: '#cbd5e1',
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.06,
    shadowRadius: 10,
    elevation: 3,
  },
  metaCardTop: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  metaIconBadge: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: '#ecfdf5',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1.5,
    borderColor: '#047857',
    flexShrink: 0,
  },
  metaDocTitle: {
    fontSize: 15,
    fontWeight: '900',
    color: '#0f172a',
  },
  metaDocSub: {
    fontSize: 12,
    color: '#64748b',
    fontWeight: '600',
    marginTop: 2,
  },
  verdictBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 10,
    borderWidth: 1.5,
    flexShrink: 0,
  },
  verdictBadgeText: {
    fontSize: 11,
    fontWeight: '900',
  },
  metaDivider: {
    height: 1,
    backgroundColor: '#e2e8f0',
    marginVertical: 14,
  },
  metaFieldsList: {
    gap: 10,
  },
  metaFieldRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: 10,
  },
  metaFieldLabel: {
    fontSize: 13,
    color: '#64748b',
    fontWeight: '600',
    flexShrink: 0,
  },
  metaFieldVal: {
    fontSize: 13.5,
    color: '#0f172a',
    fontWeight: '700',
    textAlign: 'right',
    flex: 1,
  },
  metaFieldValMono: {
    fontSize: 13,
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    fontWeight: '800',
    color: '#047857',
    textAlign: 'right',
    flex: 1,
  },
  metaFieldValBold: {
    fontSize: 14,
    fontWeight: '900',
    color: '#0f172a',
    textAlign: 'right',
    flex: 1,
  },

  // 3. View Switcher
  viewSwitcherBar: {
    flexDirection: 'row',
    backgroundColor: 'rgba(255, 255, 255, 0.85)',
    borderRadius: 18,
    padding: 4,
    borderWidth: 1.5,
    borderColor: 'rgba(255, 255, 255, 0.95)',
    gap: 4,
  },
  viewSwitchTab: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    paddingVertical: 10,
    borderRadius: 14,
  },
  viewSwitchTabActive: {
    backgroundColor: '#047857',
    shadowColor: '#047857',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
    elevation: 3,
  },
  viewSwitchText: {
    fontSize: 13,
    fontWeight: '800',
    color: '#065f46',
  },
  viewSwitchTextActive: {
    color: '#ffffff',
    fontWeight: '900',
  },

  // 4. Cards View
  cardsContainer: {
    gap: 12,
  },
  evalCard: {
    padding: 16,
    borderRadius: 16,
    borderWidth: 1.5,
    backgroundColor: '#ffffff',
    gap: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.05,
    shadowRadius: 8,
    elevation: 2,
  },
  evalCardCompliant: {
    borderColor: '#e2e8f0',
  },
  evalCardViolation: {
    backgroundColor: '#fff5f5',
    borderColor: '#fca5a5',
  },
  evalCardHeader: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 10,
  },
  clausePill: {
    backgroundColor: '#f1f5f9',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 8,
    marginTop: 1,
    borderWidth: 1,
    borderColor: '#cbd5e1',
  },
  clausePillText: {
    fontSize: 12,
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    fontWeight: '800',
    color: '#334155',
  },
  evalCardTitle: {
    fontSize: 15,
    fontWeight: '900',
    color: '#0f172a',
  },
  evalCardPanel: {
    fontSize: 12,
    color: '#64748b',
    fontWeight: '600',
    marginTop: 2,
  },
  evalStatusBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: 9,
    paddingVertical: 4,
    borderRadius: 8,
    borderWidth: 1.5,
    flexShrink: 0,
  },
  evalStatusBadgeText: {
    fontSize: 11.5,
    fontWeight: '900',
  },
  evalCardRemarks: {
    fontSize: 13.5,
    color: '#1e293b',
    lineHeight: 20,
    fontWeight: '500',
  },
  detectedWrap: {
    backgroundColor: '#f8fafc',
    padding: 10,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#cbd5e1',
    gap: 3,
  },
  detectedLabel: {
    fontSize: 10.5,
    fontWeight: '800',
    color: '#047857',
    letterSpacing: 0.5,
  },
  detectedVal: {
    fontSize: 13,
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    fontWeight: '700',
    color: '#0f172a',
  },

  // 4b. Table View
  tableCard: {
    backgroundColor: '#ffffff',
    borderRadius: 18,
    padding: 14,
    borderWidth: 1.5,
    borderColor: '#cbd5e1',
    gap: 10,
  },
  tableInstruction: {
    fontSize: 12,
    color: '#64748b',
    fontWeight: '600',
  },
  horizontalScroll: {
    borderRadius: 12,
    overflow: 'hidden',
  },
  tableContainer: {
    borderRadius: 12,
    borderWidth: 1.5,
    borderColor: '#cbd5e1',
    overflow: 'hidden',
  },
  tableHeaderRow: {
    flexDirection: 'row',
    backgroundColor: '#0f172a',
    paddingVertical: 12,
    paddingHorizontal: 10,
  },
  thCell: {
    color: '#ffffff',
    fontSize: 12.5,
    fontWeight: '800',
    paddingHorizontal: 8,
  },
  tableDataRow: {
    flexDirection: 'row',
    paddingVertical: 12,
    paddingHorizontal: 10,
    borderBottomWidth: 1,
    borderBottomColor: '#f1f5f9',
    alignItems: 'center',
  },
  tableRowEven: {
    backgroundColor: '#ffffff',
  },
  tableRowOdd: {
    backgroundColor: '#f8fafc',
  },
  tdCell: {
    fontSize: 13,
    paddingHorizontal: 8,
    lineHeight: 18,
  },
  fieldCell: {
    fontWeight: '800',
    color: '#0f172a',
  },
  panelCell: {
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    fontSize: 12,
    color: '#64748b',
  },
  tableStatusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
    alignSelf: 'flex-start',
  },
  tableStatusText: {
    fontSize: 11,
    fontWeight: '800',
  },
  tableTokenBox: {
    backgroundColor: '#f1f5f9',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
  },
  tableTokenText: {
    fontSize: 12,
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    fontWeight: '700',
    color: '#0f172a',
  },
  tableEmptyToken: {
    fontSize: 13,
    color: '#94a3b8',
    textAlign: 'center',
  },
  remarksCell: {
    fontSize: 12.5,
    color: '#334155',
  },

  // 5. Totals Card
  summaryCard: {
    backgroundColor: '#ffffff',
    borderRadius: 20,
    padding: 18,
    borderWidth: 1.5,
    borderColor: '#cbd5e1',
    gap: 12,
  },
  summaryHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#e2e8f0',
    paddingBottom: 10,
  },
  summaryMainTitle: {
    fontSize: 13.5,
    fontWeight: '900',
    color: '#0f172a',
    letterSpacing: 0.6,
  },
  summaryGrid: {
    gap: 10,
  },
  summaryRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 8,
  },
  summaryLabel: {
    fontSize: 13,
    fontWeight: '600',
    color: '#64748b',
  },
  summaryValueBold: {
    fontSize: 14,
    fontWeight: '900',
    color: '#0f172a',
  },
  penaltySummaryHighlight: {
    backgroundColor: '#fef3c7',
    padding: 12,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#fde68a',
  },
  penaltySummaryLabel: {
    fontSize: 13,
    fontWeight: '800',
    color: '#92400e',
  },
  penaltySummaryAmount: {
    fontSize: 16,
    fontWeight: '900',
    color: '#b45309',
  },
  deficiencySummaryBlock: {
    marginTop: 6,
    paddingTop: 10,
    borderTopWidth: 1,
    borderTopColor: '#e2e8f0',
    gap: 4,
  },
  deficiencySummaryHeading: {
    fontSize: 12.5,
    fontWeight: '800',
    color: '#b91c1c',
  },
  deficiencySummaryItem: {
    fontSize: 12.5,
    color: '#7f1d1d',
    fontWeight: '600',
    paddingLeft: 4,
    lineHeight: 18,
  },

  // Error State
  errorBox: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
    gap: 12,
  },
  errorIconWrap: {
    width: 68,
    height: 68,
    borderRadius: 34,
    backgroundColor: '#fee2e2',
    alignItems: 'center',
    justifyContent: 'center',
  },
  errorTitle: {
    fontSize: 17,
    fontWeight: '900',
    color: '#0f172a',
  },
  errorText: {
    fontSize: 13,
    color: '#475569',
    textAlign: 'center',
    lineHeight: 19,
  },
  backBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: '#047857',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 14,
    marginTop: 8,
  },
  backBtnText: {
    color: '#ffffff',
    fontWeight: '800',
    fontSize: 14,
  },
});
