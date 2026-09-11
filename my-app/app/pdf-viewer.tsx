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
import * as Print from 'expo-print';
import * as Sharing from 'expo-sharing';
import { ComplianceReport } from '../src/types/themis';
import { formatDateTime, formatInr, getRuleStatusInfo } from '../src/utils/formatters';

// Generate true high-resolution HTML for PDF export with zero overlapping
function generateNoticeHtml(report: ComplianceReport): string {
  const isCompliant = report.overall_compliant;
  const totalFine =
    report.violations?.statutory_penalties?.reduce(
      (acc, p) => acc + (p.compoundable_fine_inr || 0),
      0
    ) || 0;

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Statutory Notice - ${report.inspection_id}</title>
  <style>
    @page {
      size: A4 portrait;
      margin: 12mm 14mm 14mm 14mm;
    }
    * {
      box-sizing: border-box;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    body {
      font-family: 'Times New Roman', Times, Georgia, serif;
      color: #0f172a;
      line-height: 1.4;
      margin: 0;
      padding: 0;
      background: #ffffff;
      font-size: 9.5pt;
    }
    .header {
      text-align: center;
      border-bottom: 2.5px solid #0f172a;
      padding-bottom: 6px;
      margin-bottom: 2px;
    }
    .sub-rule {
      border-bottom: 1px solid #047857;
      margin-bottom: 10px;
    }
    .emblem-title {
      font-size: 13pt;
      font-weight: bold;
      letter-spacing: 1.5px;
      margin: 0;
      text-transform: uppercase;
      color: #0f172a;
    }
    .ministry-title {
      font-size: 10pt;
      font-weight: bold;
      color: #334155;
      margin: 2px 0 0 0;
      letter-spacing: 0.5px;
    }
    .dept-title {
      font-size: 11pt;
      font-weight: bold;
      color: #047857;
      margin: 2px 0 0 0;
      letter-spacing: 0.8px;
    }
    .div-title {
      font-size: 8.5pt;
      color: #64748b;
      margin: 2px 0 0 0;
      letter-spacing: 0.4px;
    }
    .notice-banner {
      border: 1.5px solid ${isCompliant ? '#15803d' : '#b91c1c'};
      background: ${isCompliant ? '#f0fdf4' : '#fef2f2'};
      padding: 8px 12px;
      text-align: center;
      margin-bottom: 12px;
      border-radius: 2px;
      page-break-inside: avoid;
    }
    .notice-title {
      font-size: 13pt;
      font-weight: bold;
      color: ${isCompliant ? '#15803d' : '#b91c1c'};
      margin: 0;
      letter-spacing: 0.5px;
    }
    .notice-act {
      font-size: 8.5pt;
      color: #334155;
      margin: 3px 0 0 0;
      font-style: italic;
    }
    .schedule-table {
      width: 100%;
      table-layout: fixed;
      border-collapse: collapse;
      margin-bottom: 12px;
      font-size: 9pt;
      word-wrap: break-word;
      overflow-wrap: break-word;
      page-break-inside: avoid;
    }
    .schedule-table td {
      padding: 5px 8px;
      border: 1px solid #cbd5e1;
      vertical-align: top;
      word-break: break-word;
    }
    .schedule-key {
      background: #f8fafc;
      font-weight: bold;
      width: 22%;
      color: #475569;
    }
    .schedule-val {
      width: 28%;
      color: #0f172a;
    }
    .schedule-val-bold {
      font-weight: bold;
      color: #0f172a;
    }
    .section-title {
      font-size: 10pt;
      font-weight: bold;
      color: #0f172a;
      letter-spacing: 0.5px;
      margin: 12px 0 5px 0;
      text-transform: uppercase;
      border-bottom: 1px solid #cbd5e1;
      padding-bottom: 3px;
      page-break-after: avoid;
    }
    .findings-table {
      width: 100%;
      table-layout: fixed;
      border-collapse: collapse;
      margin-bottom: 10px;
      font-size: 8.5pt;
      word-wrap: break-word;
      overflow-wrap: break-word;
    }
    .findings-table th {
      background: #0f172a;
      color: #ffffff;
      padding: 6px 7px;
      text-align: left;
      font-size: 8pt;
      font-weight: bold;
      letter-spacing: 0.5px;
    }
    .findings-table td {
      padding: 6px 7px;
      border: 1px solid #cbd5e1;
      vertical-align: top;
      word-break: break-word;
    }
    .findings-table tr {
      page-break-inside: avoid;
    }
    .findings-table tr:nth-child(even) {
      background: #f8fafc;
    }
    .badge-pass {
      color: #15803d;
      font-weight: bold;
      background: #dcfce7;
      padding: 2px 6px;
      border-radius: 3px;
      display: inline-block;
      font-size: 7.5pt;
      border: 0.5px solid #86efac;
    }
    .badge-fail {
      color: #b91c1c;
      font-weight: bold;
      background: #fee2e2;
      padding: 2px 6px;
      border-radius: 3px;
      display: inline-block;
      font-size: 7.5pt;
      border: 0.5px solid #fca5a5;
    }
    .deficiency-box {
      border: 1px solid #fca5a5;
      background: #fef2f2;
      padding: 7px 10px;
      margin-bottom: 10px;
      font-size: 8.5pt;
      page-break-inside: avoid;
    }
    .deficiency-item {
      color: #7f1d1d;
      margin: 3px 0;
    }
    .penalties-box {
      border: 1px solid #fde68a;
      background: #fffbeb;
      padding: 7px 10px;
      margin-bottom: 10px;
      font-size: 8.5pt;
      page-break-inside: avoid;
    }
    .total-penalty {
      font-weight: bold;
      font-size: 10pt;
      color: #b45309;
      margin-top: 5px;
      text-align: right;
      border-top: 1px solid #fde68a;
      padding-top: 4px;
    }
    .seal-section {
      margin-top: 14px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-top: 1px solid #cbd5e1;
      padding-top: 10px;
      page-break-inside: avoid;
    }
    .seal-box {
      border: 1.5px dashed #047857;
      padding: 6px 12px;
      text-align: center;
      font-size: 7pt;
      font-weight: bold;
      color: #047857;
      display: inline-block;
      line-height: 1.3;
      flex-shrink: 0;
    }
    .auth-text {
      font-size: 8pt;
      color: #64748b;
      max-width: 72%;
      line-height: 1.35;
      text-align: right;
    }
    .footer {
      text-align: center;
      font-size: 7.5pt;
      color: #94a3b8;
      margin-top: 12px;
      border-top: 0.5px solid #e2e8f0;
      padding-top: 5px;
      page-break-inside: avoid;
    }
  </style>
</head>
<body>
  <div class="header">
    <div class="emblem-title">GOVERNMENT OF INDIA</div>
    <div class="ministry-title">MINISTRY OF CONSUMER AFFAIRS, FOOD & PUBLIC DISTRIBUTION</div>
    <div class="dept-title">DIRECTORATE OF LEGAL METROLOGY</div>
    <div class="div-title">ENFORCEMENT & STATUTORY INSPECTION DIVISION • NEW DELHI</div>
  </div>
  <div class="sub-rule"></div>

  <div class="notice-banner">
    <h1 class="notice-title">
      ${isCompliant ? 'CERTIFICATE OF STATUTORY COMPLIANCE' : 'STATUTORY NOTICE OF NON-COMPLIANCE'}
    </h1>
    <div class="notice-act">
      Issued under Section 36(1) of Legal Metrology Act, 2009 read with Legal Metrology (Packaged Commodities) Rules, 2011 & Jan Vishwas Act, 2023
    </div>
  </div>

  <table class="schedule-table">
    <tr>
      <td class="schedule-key">Notice Ref ID:</td>
      <td class="schedule-val-bold" style="font-family: monospace; font-size: 8pt; word-break: break-all;">${report.inspection_id}</td>
      <td class="schedule-key">Inspection Date:</td>
      <td class="schedule-val">${formatDateTime(report.timestamp)}</td>
    </tr>
    <tr>
      <td class="schedule-key">Packaged Commodity:</td>
      <td class="schedule-val-bold">${report.product_name || 'Standard Packaged Commodity'}</td>
      <td class="schedule-key">Audited Panels:</td>
      <td class="schedule-val">${report.scanned_panels?.length ? report.scanned_panels.join(', ') : 'All Packaging Panels'}</td>
    </tr>
    <tr>
      <td class="schedule-key">Statutory Verdict:</td>
      <td class="schedule-val-bold" style="color: ${isCompliant ? '#15803d' : '#b91c1c'};">
        ${isCompliant ? 'COMPLIANT (PASS)' : 'STATUTORY VIOLATION'}
      </td>
      <td class="schedule-key">Compliance Score:</td>
      <td class="schedule-val-bold">${report.compliance_score_pct.toFixed(1)}% (${report.risk_tier || 'N/A'})</td>
    </tr>
  </table>

  <div class="section-title">1. Rule-by-Rule Mandated Declarations Findings</div>
  <table class="findings-table">
    <thead>
      <tr>
        <th style="width: 5%;">#</th>
        <th style="width: 25%;">Mandated Declaration</th>
        <th style="width: 13%;">Panel</th>
        <th style="width: 14%;">Status</th>
        <th style="width: 43%;">Regulatory Findings & Observed Token</th>
      </tr>
    </thead>
    <tbody>
      ${report.evaluations
      .map(
        (ev, idx) => `
      <tr>
        <td style="text-align: center; font-weight: bold;">${idx + 1}</td>
        <td><strong>${ev.field}</strong></td>
        <td>${ev.source_panel || 'N/A'}</td>
        <td>
          <span class="${ev.status === 'Violation' ? 'badge-fail' : 'badge-pass'}">
            ${ev.status.toUpperCase()}
          </span>
        </td>
        <td>
          ${ev.remarks}
          ${ev.matched_token ? `<div style="font-size: 7.5pt; color: #047857; margin-top: 3px; font-family: monospace; word-break: break-all;"><em>Observed: "${ev.matched_token}"</em></div>` : ''}
        </td>
      </tr>`
      )
      .join('')}
    </tbody>
  </table>

  ${report.violations?.mandatory_missing?.length
      ? `
  <div class="section-title" style="color: #b91c1c;">2. Mandatory Declarations Missing (Rule 6)</div>
  <div class="deficiency-box">
    ${report.violations.mandatory_missing.map((m) => `<div class="deficiency-item">• Absence of mandatory statutory declaration: <strong>${m}</strong></div>`).join('')}
  </div>`
      : ''
    }

  ${report.violations?.non_standard_units?.length
      ? `
  <div class="section-title" style="color: #b45309;">3. Illegal Non-Standard Measurement Units (Rule 13)</div>
  <div class="deficiency-box" style="border-color: #fde68a; background: #fffbeb;">
    ${report.violations.non_standard_units.map((u) => `<div class="deficiency-item" style="color: #78350f;">• Non-standard unit declared: <strong>'${u}'</strong> (Requires standard SI metric units)</div>`).join('')}
  </div>`
      : ''
    }

  ${report.violations?.statutory_penalties?.length
      ? `
  <div class="section-title" style="color: #b45309;">4. Statutory Compounding Penalties (Jan Vishwas Act, 2023)</div>
  <div class="penalties-box">
    ${report.violations.statutory_penalties.map((p) => `<div>• <strong>Section ${p.section}</strong>: INR ${p.compoundable_fine_inr} (${p.offense || 'Absence of mandatory statutory declarations'})</div>`).join('')}
    <div class="total-penalty">Total Compounding Fine: ${formatInr(totalFine)}</div>
  </div>`
      : ''
    }

  <div class="seal-section">
    <div class="seal-box">
      <div>★ DIRECTORATE OF LEGAL METROLOGY ★</div>
      <div style="font-size: 6pt; margin-top: 1px;">GOVERNMENT OF INDIA</div>
      <div style="margin-top: 1px;">OFFICIAL STATUTORY SEAL</div>
    </div>
    <div class="auth-text">
      <strong>Digitally Authenticated Statutory Record</strong><br>
      Issued by PARAKH Regulatory Engine under Section 65B of Indian Evidence Act, 1872.<br>
      <em>Certified: ${formatDateTime(report.timestamp)}</em>
    </div>
  </div>

  <div class="footer">
    Official Notice • Government of India Legal Metrology Audit Repository • System Generated Document
  </div>
</body>
</html>
  `;
}

export default function PdfViewerScreen() {
  const insets = useSafeAreaInsets();
  const { data } = useLocalSearchParams<{ data: string }>();
  const [sharing, setSharing] = useState(false);

  let report: ComplianceReport | null = null;
  try {
    if (data) {
      report = JSON.parse(data);
    }
  } catch (err) {
    console.warn('Failed to parse report in PDF viewer:', err);
  }

  if (!report) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.errorBox}>
          <View style={styles.errorIconWrap}>
            <Ionicons name="alert-circle-outline" size={48} color="#dc2626" />
          </View>
          <Text style={styles.errorTitle}>Inspection Record Missing</Text>
          <Text style={styles.errorText}>
            Unable to load the inspection dataset required to view the statutory notice.
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

  const isCompliant = report.overall_compliant;
  const totalFine =
    report.violations?.statutory_penalties?.reduce(
      (acc, p) => acc + (p.compoundable_fine_inr || 0),
      0
    ) || 0;

  // Generate real PDF file and share it
  const handleSharePdf = async () => {
    if (!report) return;
    setSharing(true);
    try {
      const html = generateNoticeHtml(report);
      // expo-print compiles a genuine .pdf file
      const file = await Print.printToFileAsync({
        html,
        base64: false,
      });

      if (await Sharing.isAvailableAsync()) {
        await Sharing.shareAsync(file.uri, {
          mimeType: 'application/pdf',
          dialogTitle: `Statutory Notice - ${report.inspection_id}.pdf`,
          UTI: 'com.adobe.pdf',
        });
      } else {
        Alert.alert('PDF Ready', `PDF file created at: ${file.uri}`);
      }
    } catch (err: any) {
      Alert.alert('PDF Error', err.message || 'Failed to generate PDF document.');
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
            Statutory Legal Notice
          </Text>
          <Text style={styles.headerSubtitle} numberOfLines={1}>
            Official PDF Document
          </Text>
        </View>

        <TouchableOpacity
          style={[styles.navActionBtn, sharing && { opacity: 0.7 }]}
          onPress={handleSharePdf}
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

      {/* 2. PDF Viewport with Centered A4 Document Sheet */}
      <ScrollView
        style={styles.viewport}
        contentContainerStyle={[
          styles.viewportContent,
          { paddingBottom: Math.max(insets.bottom + 36, 56) },
        ]}
        showsVerticalScrollIndicator={true}
      >
        {/* The Authentic A4 Document Sheet (Zero Overlap Layout) */}
        <View style={styles.a4PageSheet}>
          {/* Official Letterhead Header */}
          <View style={styles.letterhead}>
            <View style={styles.emblemBadge}>
              <Ionicons name="shield-checkmark" size={24} color="#047857" />
            </View>
            <Text style={styles.govtHeaderTitle}>GOVERNMENT OF INDIA</Text>
            <Text style={styles.govtMinistryTitle}>
              MINISTRY OF CONSUMER AFFAIRS, FOOD & PUBLIC DISTRIBUTION
            </Text>
            <Text style={styles.govtDepartmentTitle}>
              DIRECTORATE OF LEGAL METROLOGY
            </Text>
            <Text style={styles.govtDivisionTitle}>
              ENFORCEMENT & STATUTORY INSPECTION DIVISION • NEW DELHI
            </Text>
          </View>

          <View style={styles.doubleRuleTop} />
          <View style={styles.doubleRuleBottom} />

          {/* Notice Title Banner */}
          <View
            style={[
              styles.noticeBanner,
              {
                backgroundColor: isCompliant ? '#f0fdf4' : '#fef2f2',
                borderColor: isCompliant ? '#86efac' : '#fca5a5',
              },
            ]}
          >
            <Text
              style={[
                styles.noticeTitle,
                { color: isCompliant ? '#15803d' : '#b91c1c' },
              ]}
            >
              {isCompliant
                ? 'CERTIFICATE OF STATUTORY COMPLIANCE'
                : 'STATUTORY NOTICE OF NON-COMPLIANCE'}
            </Text>
            <Text style={styles.noticeSubtext}>
              Issued under Section 36(1) of Legal Metrology Act, 2009 read with Legal
              Metrology (Packaged Commodities) Rules, 2011 & Jan Vishwas Act, 2023
            </Text>
          </View>

          {/* Schedule of Inspection & Commodity (Clean, Zero-Overlap Card) */}
          <View style={styles.scheduleCard}>
            <View style={styles.scheduleHeaderRow}>
              <Ionicons name="document-text-outline" size={15} color="#047857" />
              <Text style={styles.scheduleHeaderTitle}>
                SCHEDULE OF INSPECTION & COMMODITY
              </Text>
            </View>

            {/* Notice Ref ID Banner */}
            <View style={styles.refIdStrip}>
              <Text style={styles.refIdLabel}>NOTICE REFERENCE ID:</Text>
              <Text style={styles.refIdValue} selectable>
                {report.inspection_id}
              </Text>
            </View>

            {/* Schedule Items: Clear 2-column or stacked layout */}
            <View style={styles.scheduleItemsList}>
              <View style={styles.scheduleRow}>
                <Text style={styles.scheduleKeyText}>Inspection Date</Text>
                <Text style={styles.scheduleValText}>
                  {formatDateTime(report.timestamp)}
                </Text>
              </View>

              <View style={styles.scheduleRow}>
                <Text style={styles.scheduleKeyText}>Packaged Commodity</Text>
                <Text style={styles.scheduleValBold}>
                  {report.product_name || 'Standard Packaged Commodity'}
                </Text>
              </View>

              <View style={styles.scheduleRow}>
                <Text style={styles.scheduleKeyText}>Audited Panels</Text>
                <Text style={styles.scheduleValText}>
                  {report.scanned_panels?.length
                    ? report.scanned_panels.join(', ')
                    : 'Complete Packaging SKU'}
                </Text>
              </View>

              {/* Dedicated Verdict Highlight Box */}
              <View
                style={[
                  styles.verdictHighlightBox,
                  {
                    backgroundColor: isCompliant ? '#f0fdf4' : '#fef2f2',
                    borderColor: isCompliant ? '#bbf7d0' : '#fecaca',
                  },
                ]}
              >
                <View style={styles.verdictTopLine}>
                  <Text style={styles.verdictLabelText}>STATUTORY VERDICT</Text>
                  <View
                    style={[
                      styles.verdictBadgePill,
                      {
                        backgroundColor: isCompliant ? '#dcfce7' : '#fee2e2',
                        borderColor: isCompliant ? '#86efac' : '#fca5a5',
                      },
                    ]}
                  >
                    <Ionicons
                      name={isCompliant ? 'shield-checkmark' : 'alert-circle'}
                      size={12}
                      color={isCompliant ? '#15803d' : '#b91c1c'}
                    />
                    <Text
                      style={[
                        styles.verdictBadgePillText,
                        { color: isCompliant ? '#15803d' : '#b91c1c' },
                      ]}
                    >
                      {isCompliant ? 'COMPLIANT (PASS)' : 'STATUTORY VIOLATION'}
                    </Text>
                  </View>
                </View>

                <View style={styles.verdictScoreLine}>
                  <Text style={styles.verdictScoreLabel}>Compliance Score:</Text>
                  <Text
                    style={[
                      styles.verdictScoreValue,
                      { color: isCompliant ? '#15803d' : '#b91c1c' },
                    ]}
                  >
                    {report.compliance_score_pct.toFixed(1)}% ({report.risk_tier || 'N/A'})
                  </Text>
                </View>
              </View>
            </View>
          </View>

          {/* Section 1: Formal Audit Findings (Zero-Overlap Clause Cards) */}
          <View style={styles.sectionHeaderWrap}>
            <View style={styles.sectionNumberCircle}>
              <Text style={styles.sectionNumberText}>1</Text>
            </View>
            <Text style={styles.docSectionHeading}>
              Rule-by-Rule Mandated Declarations Findings
            </Text>
          </View>
          <Text style={styles.docSectionSubDesc}>
            Statutory examination of packaging declarations under Legal Metrology Rules:
          </Text>

          <View style={styles.clausesList}>
            {report.evaluations.map((ev, idx) => {
              const st = getRuleStatusInfo(ev.status);
              const isViolation = ev.status === 'Violation';

              return (
                <View
                  key={idx}
                  style={[
                    styles.clauseCard,
                    isViolation ? styles.clauseCardFail : styles.clauseCardPass,
                  ]}
                >
                  {/* Card Header Line 1: Number + Panel tag on left, Status badge on right */}
                  <View style={styles.clauseMetaRow}>
                    <View style={styles.clauseMetaLeft}>
                      <View style={styles.clauseNumberPill}>
                        <Text style={styles.clauseNumberPillText}>#{idx + 1}</Text>
                      </View>
                      {ev.source_panel && (
                        <View style={styles.panelTagPill}>
                          <Ionicons name="scan-outline" size={10} color="#475569" />
                          <Text style={styles.panelTagPillText}>
                            {ev.source_panel}
                          </Text>
                        </View>
                      )}
                    </View>

                    <View
                      style={[
                        styles.clauseStatusPill,
                        {
                          backgroundColor: isViolation ? '#fee2e2' : '#dcfce7',
                          borderColor: isViolation ? '#fca5a5' : '#86efac',
                        },
                      ]}
                    >
                      <Ionicons
                        name={isViolation ? 'close-circle' : 'checkmark-circle'}
                        size={12}
                        color={st.color}
                      />
                      <Text
                        style={[
                          styles.clauseStatusPillText,
                          { color: st.color },
                        ]}
                      >
                        {st.label}
                      </Text>
                    </View>
                  </View>

                  {/* Card Header Line 2: Full Width Mandated Declaration Title (Never squeezed) */}
                  <Text style={styles.clauseFieldTitle}>{ev.field}</Text>

                  {/* Remarks (Full width, clear line-height) */}
                  <Text style={styles.clauseRemarksText}>{ev.remarks}</Text>

                  {/* Detected OCR Token Snippet */}
                  {ev.matched_token ? (
                    <View style={styles.clauseTokenBox}>
                      <Text style={styles.clauseTokenHeader}>
                        OBSERVED TEXT ON PACKAGING:
                      </Text>
                      <Text style={styles.clauseTokenValue} selectable>
                        "{ev.matched_token}"
                      </Text>
                    </View>
                  ) : null}
                </View>
              );
            })}
          </View>

          {/* Section 2: Missing Mandatory Statements */}
          {report.violations?.mandatory_missing &&
            report.violations.mandatory_missing.length > 0 && (
              <View style={styles.deficiencyContainer}>
                <View style={styles.sectionHeaderWrap}>
                  <View
                    style={[
                      styles.sectionNumberCircle,
                      styles.sectionNumberCircleAlert,
                    ]}
                  >
                    <Text style={styles.sectionNumberText}>2</Text>
                  </View>
                  <Text style={styles.docSectionHeadingAlert}>
                    Mandatory Declarations Missing (Rule 6)
                  </Text>
                </View>

                <View style={styles.deficiencyBoxAlert}>
                  {report.violations.mandatory_missing.map((item, idx) => (
                    <View key={idx} style={styles.deficiencyItemRow}>
                      <Ionicons
                        name="alert-circle"
                        size={16}
                        color="#b91c1c"
                        style={{ marginTop: 2 }}
                      />
                      <Text style={styles.deficiencyItemText}>
                        Absence of statutory declaration:{' '}
                        <Text style={{ fontWeight: 'bold' }}>{item}</Text>
                      </Text>
                    </View>
                  ))}
                </View>
              </View>
            )}

          {/* Section 3: Non-Standard Units */}
          {report.violations?.non_standard_units &&
            report.violations.non_standard_units.length > 0 && (
              <View style={styles.deficiencyContainer}>
                <View style={styles.sectionHeaderWrap}>
                  <View
                    style={[
                      styles.sectionNumberCircle,
                      styles.sectionNumberCircleAlert,
                    ]}
                  >
                    <Text style={styles.sectionNumberText}>3</Text>
                  </View>
                  <Text style={styles.docSectionHeadingAlert}>
                    Non-Standard Measurement Units (Rule 13)
                  </Text>
                </View>

                <View style={styles.deficiencyBoxWarning}>
                  {report.violations.non_standard_units.map((unit, idx) => (
                    <View key={idx} style={styles.deficiencyItemRow}>
                      <Ionicons
                        name="warning"
                        size={16}
                        color="#b45309"
                        style={{ marginTop: 2 }}
                      />
                      <Text style={styles.deficiencyItemWarningText}>
                        Non-standard unit declared:{' '}
                        <Text style={{ fontWeight: 'bold' }}>'{unit}'</Text> (Mandatory SI metric units required)
                      </Text>
                    </View>
                  ))}
                </View>
              </View>
            )}

          {/* Section 4: Jan Vishwas Penalties */}
          {report.violations?.statutory_penalties &&
            report.violations.statutory_penalties.length > 0 && (
              <View style={styles.penaltiesContainer}>
                <View style={styles.sectionHeaderWrap}>
                  <View
                    style={[
                      styles.sectionNumberCircle,
                      styles.sectionNumberCircleGold,
                    ]}
                  >
                    <Text style={styles.sectionNumberText}>4</Text>
                  </View>
                  <Text style={styles.docSectionHeadingGold}>
                    Statutory Compounding Penalties (Jan Vishwas Act, 2023)
                  </Text>
                </View>

                <View style={styles.penaltiesCard}>
                  {report.violations.statutory_penalties.map((pen, idx) => (
                    <View key={idx} style={styles.penaltyItemRow}>
                      <View style={{ flex: 1, paddingRight: 8 }}>
                        <Text style={styles.penaltySectionCode}>
                          Section {pen.section}
                        </Text>
                        <Text style={styles.penaltyOffenseDetail}>
                          {pen.offense || 'Absence of mandated packaging declarations'}
                        </Text>
                      </View>
                      <View style={styles.penaltyFinePill}>
                        <Text style={styles.penaltyFinePillText}>
                          {formatInr(pen.compoundable_fine_inr)}
                        </Text>
                      </View>
                    </View>
                  ))}

                  <View style={styles.totalFineRow}>
                    <Text style={styles.totalFineLabel}>
                      Total Compounding Fine Payable:
                    </Text>
                    <Text style={styles.totalFineAmount}>
                      {formatInr(totalFine)}
                    </Text>
                  </View>
                </View>
              </View>
            )}

          {/* Section 5: Official Seal & Legal Certification */}
          <View style={styles.sealBlock}>
            <View style={styles.sealGraphicCircle}>
              <Ionicons name="ribbon-outline" size={24} color="#047857" />
              <Text style={styles.sealGraphicText}>DIRECTORATE OF</Text>
              <Text style={styles.sealGraphicText}>LEGAL METROLOGY</Text>
              <Text style={styles.sealGraphicSub}>OFFICIAL SEAL</Text>
            </View>

            <View style={styles.sealInfoDetails}>
              <Text style={styles.sealAuthHeading}>
                DIRECTORATE OF LEGAL METROLOGY
              </Text>
              <Text style={styles.sealLegalBody}>
                Digitally authenticated statutory inspection notice issued in accordance
                with Section 65B of Indian Evidence Act, 1872 & Information Technology
                Act, 2000.
              </Text>
              <Text style={styles.sealTimestampText}>
                Certified on: {formatDateTime(report.timestamp)}
              </Text>
            </View>
          </View>

          {/* Page Footer */}
          <View style={styles.documentFooter}>
            <Text style={styles.documentFooterText}>
              Official Notice • Directorate of Legal Metrology, Government of India
            </Text>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#ebf4ed', // Unified premium soft mint backdrop
  },

  // 1. PDF Toolbar (Clean, Floating Glassmorphic Header)
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

  // 2. Viewport
  viewport: {
    flex: 1,
    backgroundColor: '#ebf4ed',
  },
  viewportContent: {
    alignItems: 'center',
    paddingVertical: 10,
    paddingHorizontal: 12,
  },

  // 3. The Authentic A4 Document Sheet (Clean, No Horizontal Overlap)
  a4PageSheet: {
    width: '100%',
    maxWidth: 680,
    backgroundColor: '#ffffff',
    borderRadius: 10,
    paddingHorizontal: 18,
    paddingVertical: 20,
    shadowColor: '#064e3b',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.12,
    shadowRadius: 16,
    elevation: 6,
    borderWidth: 1.5,
    borderColor: '#cbd5e1',
    gap: 12,
  },

  // Letterhead
  letterhead: {
    alignItems: 'center',
    paddingBottom: 2,
  },
  emblemBadge: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: '#ecfdf5',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1.5,
    borderColor: '#047857',
    marginBottom: 6,
  },
  govtHeaderTitle: {
    fontSize: 13.5,
    fontWeight: '900',
    color: '#0f172a',
    letterSpacing: 1.4,
    fontFamily: Platform.OS === 'ios' ? 'Georgia' : 'serif',
    textAlign: 'center',
  },
  govtMinistryTitle: {
    fontSize: 10.5,
    fontWeight: '700',
    color: '#334155',
    letterSpacing: 0.4,
    marginTop: 2,
    textAlign: 'center',
    fontFamily: Platform.OS === 'ios' ? 'Georgia' : 'serif',
  },
  govtDepartmentTitle: {
    fontSize: 11.5,
    fontWeight: '900',
    color: '#047857',
    letterSpacing: 0.6,
    marginTop: 2,
    textAlign: 'center',
    fontFamily: Platform.OS === 'ios' ? 'Georgia' : 'serif',
  },
  govtDivisionTitle: {
    fontSize: 9,
    fontWeight: '600',
    color: '#64748b',
    letterSpacing: 0.3,
    marginTop: 2,
    textAlign: 'center',
    fontFamily: Platform.OS === 'ios' ? 'Georgia' : 'serif',
  },
  doubleRuleTop: {
    height: 2,
    backgroundColor: '#0f172a',
    marginTop: 4,
  },
  doubleRuleBottom: {
    height: 1,
    backgroundColor: '#047857',
    marginTop: 2,
    marginBottom: 2,
  },

  // Notice Banner
  noticeBanner: {
    padding: 10,
    borderRadius: 4,
    borderWidth: 1.5,
    alignItems: 'center',
  },
  noticeTitle: {
    fontSize: 14,
    fontWeight: '900',
    letterSpacing: 0.3,
    textAlign: 'center',
    fontFamily: Platform.OS === 'ios' ? 'Georgia' : 'serif',
  },
  noticeSubtext: {
    fontSize: 10.5,
    color: '#334155',
    fontStyle: 'italic',
    textAlign: 'center',
    marginTop: 3,
    lineHeight: 15,
    fontFamily: Platform.OS === 'ios' ? 'Georgia' : 'serif',
  },

  // Schedule Card (Zero Overlap Layout)
  scheduleCard: {
    backgroundColor: '#f8fafc',
    borderRadius: 8,
    borderWidth: 1.5,
    borderColor: '#e2e8f0',
    padding: 12,
    gap: 8,
  },
  scheduleHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    borderBottomWidth: 1,
    borderBottomColor: '#cbd5e1',
    paddingBottom: 6,
  },
  scheduleHeaderTitle: {
    fontSize: 11,
    fontWeight: '900',
    color: '#0f172a',
    letterSpacing: 0.5,
  },
  refIdStrip: {
    backgroundColor: '#ffffff',
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#cbd5e1',
    paddingHorizontal: 10,
    paddingVertical: 6,
    gap: 2,
  },
  refIdLabel: {
    fontSize: 9.5,
    fontWeight: '800',
    color: '#64748b',
    letterSpacing: 0.5,
  },
  refIdValue: {
    fontSize: 12,
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    fontWeight: '800',
    color: '#047857',
  },
  scheduleItemsList: {
    gap: 4,
  },
  scheduleRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    paddingVertical: 6,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#e2e8f0',
    gap: 8,
  },
  scheduleKeyText: {
    fontSize: 12,
    color: '#64748b',
    fontWeight: '700',
    flex: 1,
  },
  scheduleValText: {
    fontSize: 12.5,
    color: '#0f172a',
    fontWeight: '600',
    textAlign: 'right',
    flex: 1.4,
  },
  scheduleValBold: {
    fontSize: 12.5,
    fontWeight: '800',
    color: '#0f172a',
    textAlign: 'right',
    flex: 1.4,
  },

  // Dedicated Verdict Highlight Box inside Schedule
  verdictHighlightBox: {
    borderRadius: 6,
    borderWidth: 1,
    padding: 10,
    marginTop: 4,
    gap: 6,
  },
  verdictTopLine: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 8,
  },
  verdictLabelText: {
    fontSize: 10.5,
    fontWeight: '900',
    color: '#475569',
    letterSpacing: 0.4,
  },
  verdictBadgePill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 4,
    borderWidth: 1,
  },
  verdictBadgePillText: {
    fontSize: 10.5,
    fontWeight: '900',
  },
  verdictScoreLine: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#e2e8f0',
    paddingTop: 4,
  },
  verdictScoreLabel: {
    fontSize: 11,
    fontWeight: '700',
    color: '#64748b',
  },
  verdictScoreValue: {
    fontSize: 12,
    fontWeight: '900',
  },

  // Document Section Headings
  sectionHeaderWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginTop: 4,
  },
  sectionNumberCircle: {
    width: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: '#0f172a',
    alignItems: 'center',
    justifyContent: 'center',
  },
  sectionNumberCircleAlert: {
    backgroundColor: '#b91c1c',
  },
  sectionNumberCircleGold: {
    backgroundColor: '#b45309',
  },
  sectionNumberText: {
    fontSize: 10.5,
    fontWeight: '900',
    color: '#ffffff',
  },
  docSectionHeading: {
    fontSize: 12.5,
    fontWeight: '900',
    color: '#0f172a',
    letterSpacing: 0.3,
    fontFamily: Platform.OS === 'ios' ? 'Georgia' : 'serif',
  },
  docSectionHeadingAlert: {
    fontSize: 12.5,
    fontWeight: '900',
    color: '#b91c1c',
    letterSpacing: 0.3,
    fontFamily: Platform.OS === 'ios' ? 'Georgia' : 'serif',
  },
  docSectionHeadingGold: {
    fontSize: 12.5,
    fontWeight: '900',
    color: '#b45309',
    letterSpacing: 0.3,
    fontFamily: Platform.OS === 'ios' ? 'Georgia' : 'serif',
  },
  docSectionSubDesc: {
    fontSize: 11,
    color: '#64748b',
    marginTop: -3,
    marginBottom: 2,
  },

  // Clauses List (Zero Overlap Layout)
  clausesList: {
    gap: 8,
  },
  clauseCard: {
    padding: 10,
    borderRadius: 6,
    borderWidth: 1.5,
    gap: 5,
  },
  clauseCardPass: {
    backgroundColor: '#f8fafc',
    borderColor: '#e2e8f0',
  },
  clauseCardFail: {
    backgroundColor: '#fff5f5',
    borderColor: '#fca5a5',
  },
  clauseMetaRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 8,
  },
  clauseMetaLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    flex: 1,
  },
  clauseNumberPill: {
    backgroundColor: '#e2e8f0',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 4,
  },
  clauseNumberPillText: {
    fontSize: 10.5,
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    fontWeight: '800',
    color: '#334155',
  },
  panelTagPill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
    backgroundColor: '#ffffff',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 4,
    borderWidth: 1,
    borderColor: '#e2e8f0',
  },
  panelTagPillText: {
    fontSize: 10,
    color: '#475569',
    fontWeight: '700',
  },
  clauseStatusPill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
    paddingHorizontal: 7,
    paddingVertical: 2.5,
    borderRadius: 4,
    borderWidth: 1,
    flexShrink: 0,
  },
  clauseStatusPillText: {
    fontSize: 10,
    fontWeight: '900',
  },
  clauseFieldTitle: {
    fontSize: 13,
    fontWeight: '800',
    color: '#0f172a',
    fontFamily: Platform.OS === 'ios' ? 'Georgia' : 'serif',
    lineHeight: 17,
  },
  clauseRemarksText: {
    fontSize: 11.5,
    color: '#334155',
    lineHeight: 17,
    fontFamily: Platform.OS === 'ios' ? 'Georgia' : 'serif',
  },
  clauseTokenBox: {
    backgroundColor: '#ffffff',
    padding: 7,
    borderRadius: 4,
    borderWidth: 1,
    borderColor: '#cbd5e1',
    gap: 2,
    marginTop: 2,
  },
  clauseTokenHeader: {
    fontSize: 9,
    fontWeight: '800',
    color: '#047857',
    letterSpacing: 0.5,
  },
  clauseTokenValue: {
    fontSize: 11.5,
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    fontWeight: '700',
    color: '#0f172a',
  },

  // Deficiencies
  deficiencyContainer: {
    gap: 6,
  },
  deficiencyBoxAlert: {
    borderWidth: 1.5,
    borderColor: '#fca5a5',
    backgroundColor: '#fef2f2',
    padding: 10,
    borderRadius: 6,
    gap: 5,
  },
  deficiencyBoxWarning: {
    borderWidth: 1.5,
    borderColor: '#fde68a',
    backgroundColor: '#fffbeb',
    padding: 10,
    borderRadius: 6,
    gap: 5,
  },
  deficiencyItemRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 6,
  },
  deficiencyItemText: {
    flex: 1,
    fontSize: 11.5,
    color: '#7f1d1d',
    lineHeight: 16,
  },
  deficiencyItemWarningText: {
    flex: 1,
    fontSize: 11.5,
    color: '#78350f',
    lineHeight: 16,
  },

  // Penalties
  penaltiesContainer: {
    gap: 6,
  },
  penaltiesCard: {
    borderWidth: 1.5,
    borderColor: '#fde68a',
    backgroundColor: '#fffbeb',
    padding: 10,
    borderRadius: 6,
    gap: 6,
  },
  penaltyItemRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingBottom: 5,
    borderBottomWidth: 1,
    borderBottomColor: '#fef3c7',
    gap: 6,
  },
  penaltySectionCode: {
    fontSize: 12,
    fontWeight: '800',
    color: '#78350f',
  },
  penaltyOffenseDetail: {
    fontSize: 10.5,
    color: '#92400e',
    marginTop: 1,
  },
  penaltyFinePill: {
    backgroundColor: '#fef3c7',
    paddingHorizontal: 7,
    paddingVertical: 2.5,
    borderRadius: 4,
    borderWidth: 1,
    borderColor: '#f59e0b',
    flexShrink: 0,
  },
  penaltyFinePillText: {
    fontSize: 11.5,
    fontWeight: '900',
    color: '#b45309',
  },
  totalFineRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingTop: 4,
  },
  totalFineLabel: {
    fontSize: 11.5,
    fontWeight: '800',
    color: '#78350f',
  },
  totalFineAmount: {
    fontSize: 13,
    fontWeight: '900',
    color: '#b45309',
  },

  // Seal Block (Zero Overlap)
  sealBlock: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    borderTopWidth: 1,
    borderTopColor: '#cbd5e1',
    paddingTop: 10,
    marginTop: 2,
  },
  sealGraphicCircle: {
    width: 68,
    height: 68,
    borderRadius: 34,
    borderWidth: 1.5,
    borderColor: '#047857',
    borderStyle: 'dashed',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#ecfdf5',
    flexShrink: 0,
  },
  sealGraphicText: {
    fontSize: 6,
    fontWeight: '900',
    color: '#022c22',
    letterSpacing: 0.2,
  },
  sealGraphicSub: {
    fontSize: 5.5,
    fontWeight: '700',
    color: '#047857',
    marginTop: 1,
  },
  sealInfoDetails: {
    flex: 1,
    gap: 2,
  },
  sealAuthHeading: {
    fontSize: 10.5,
    fontWeight: '900',
    color: '#0f172a',
    letterSpacing: 0.3,
  },
  sealLegalBody: {
    fontSize: 9,
    color: '#475569',
    lineHeight: 13,
  },
  sealTimestampText: {
    fontSize: 9,
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    color: '#047857',
    fontWeight: '700',
  },

  // Footer
  documentFooter: {
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#e2e8f0',
    paddingTop: 6,
    alignItems: 'center',
  },
  documentFooterText: {
    fontSize: 8.5,
    color: '#94a3b8',
    letterSpacing: 0.2,
    textAlign: 'center',
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
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: '#fee2e2',
    alignItems: 'center',
    justifyContent: 'center',
  },
  errorTitle: {
    fontSize: 16,
    fontWeight: '900',
    color: '#0f172a',
  },
  errorText: {
    fontSize: 12.5,
    color: '#475569',
    textAlign: 'center',
    lineHeight: 18,
  },
  backBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: '#047857',
    paddingHorizontal: 18,
    paddingVertical: 10,
    borderRadius: 12,
    marginTop: 6,
  },
  backBtnText: {
    color: '#ffffff',
    fontWeight: '800',
    fontSize: 13.5,
  },
});
