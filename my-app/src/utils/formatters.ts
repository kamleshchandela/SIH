import { RiskTier, RuleStatus } from '../types/themis';

/**
 * Formats a number into Indian currency representation (e.g. ₹25,000, ₹1,50,000)
 */
export function formatInr(amount?: number | null): string {
  if (amount === undefined || amount === null || isNaN(amount)) {
    return '₹0';
  }
  const parts = Math.round(amount).toString().split('.');
  let lastThree = parts[0].substring(parts[0].length - 3);
  const otherNumbers = parts[0].substring(0, parts[0].length - 3);
  if (otherNumbers !== '') {
    lastThree = ',' + lastThree;
  }
  const formatted =
    otherNumbers.replace(/\B(?=(\d{2})+(?!\d))/g, ',') + lastThree;
  return `₹${formatted}`;
}

/**
 * Formats ISO date string to a clean readable date/time (e.g. 07 Sep 2026, 05:03 PM)
 */
export function formatDateTime(isoString?: string | null): string {
  if (!isoString) return '—';
  try {
    const date = new Date(isoString);
    if (isNaN(date.getTime())) return isoString;
    return date.toLocaleString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      hour12: true,
    });
  } catch {
    return isoString;
  }
}

/**
 * Returns color hex and friendly label for Risk Tier
 */
export function getRiskTierInfo(tier?: RiskTier | string | null): {
  label: string;
  color: string;
  bgColor: string;
} {
  switch (tier) {
    case 'LowRisk':
      return { label: 'Low Risk', color: '#16a34a', bgColor: '#dcfce7' };
    case 'ModerateRisk':
      return { label: 'Moderate Risk', color: '#ca8a04', bgColor: '#fef9c3' };
    case 'HighRisk':
      return { label: 'High Risk', color: '#ea580c', bgColor: '#ffedd5' };
    case 'CriticalRisk':
      return { label: 'Critical Risk', color: '#dc2626', bgColor: '#fee2e2' };
    default:
      return { label: tier || 'Unknown', color: '#64748b', bgColor: '#f1f5f9' };
  }
}

/**
 * Returns color hex and friendly label for Rule Status
 */
export function getRuleStatusInfo(status?: RuleStatus | string | null): {
  label: string;
  color: string;
  bgColor: string;
} {
  switch (status) {
    case 'Compliant':
      return { label: 'PASS', color: '#16a34a', bgColor: '#dcfce7' };
    case 'Violation':
      return { label: 'FAIL', color: '#dc2626', bgColor: '#fee2e2' };
    case 'Warning':
      return { label: 'WARN', color: '#ca8a04', bgColor: '#fef9c3' };
    case 'NotApplicable':
      return { label: 'N/A', color: '#64748b', bgColor: '#f1f5f9' };
    default:
      return { label: status || '—', color: '#64748b', bgColor: '#f1f5f9' };
  }
}

/**
 * Generates an RFC 4180 compliant CSV string directly from real inspection report
 */
export function generateCsvContent(report: any): string {
  const rows: string[] = [];
  rows.push('Inspection ID,Timestamp,Product SKU,Field,Status,Source Panel,Matched Value,Remarks');

  if (report.evaluations && Array.isArray(report.evaluations)) {
    for (const ev of report.evaluations) {
      const field = `"${ev.field || ''}"`;
      const status = `"${ev.status || ''}"`;
      const panel = `"${ev.source_panel || 'N/A'}"`;
      const matched = `"${(ev.matched_token || 'N/A').replace(/"/g, '""')}"`;
      const remarks = `"${(ev.remarks || '').replace(/"/g, '""')}"`;
      rows.push(
        `"${report.inspection_id}","${report.timestamp}","${(report.product_name || 'N/A').replace(/"/g, '""')}",${field},${status},${panel},${matched},${remarks}`
      );
    }
  }

  rows.push('');
  rows.push('--- STATUTORY AUDIT SUMMARY ---');
  rows.push(`Overall Compliance,"${report.overall_compliant ? 'COMPLIANT (PASS)' : 'STATUTORY VIOLATION (FAIL)'}"`);
  rows.push(`Statutory Risk Tier,"${report.risk_tier || ''}"`);
  rows.push(`Compliance Score,"${(report.compliance_score_pct || 0).toFixed(1)}%"`);

  const penalties = report.violations?.statutory_penalties || [];
  const totalFine = penalties.reduce(
    (acc: number, p: any) => acc + (p.compoundable_fine_inr || 0),
    0
  );
  rows.push(`Total Jan Vishwas Compounding Fine,"INR ${totalFine}"`);

  if (report.violations?.mandatory_missing?.length) {
    rows.push(`Mandatory Rule 6 Missing Declarations,"${report.violations.mandatory_missing.join(', ')}"`);
  }
  if (report.violations?.non_standard_units?.length) {
    rows.push(`Rule 13 Illegal Non-Standard Units,"${report.violations.non_standard_units.join(', ')}"`);
  }

  return rows.join('\n');
}

