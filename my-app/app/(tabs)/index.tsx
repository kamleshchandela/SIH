import React, { useEffect, useState, useCallback, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  RefreshControl,
  TouchableOpacity,
  ActivityIndicator,
  Animated,
  Easing,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAuth } from '../../src/context/AuthContext';
import { HealthResponse, InspectionStats } from '../../src/types/themis';
import { formatDateTime, formatInr } from '../../src/utils/formatters';

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

      {/* Orb 4: Deep Soft Teal Aura in bottom left */}
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

      {/* Themis AI Scanning Beam */}
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

export default function DashboardScreen() {
  const insets = useSafeAreaInsets();
  const { api, username, role } = useAuth();
  const [health, setHealth] = useState<HealthResponse | null>(null);
  const [stats, setStats] = useState<InspectionStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [healthError, setHealthError] = useState<string | null>(null);
  const [statsError, setStatsError] = useState<string | null>(null);

  const fetchData = useCallback(async () => {
    setHealthError(null);
    setStatsError(null);

    // 1. Health API
    try {
      const h = await api.getHealth();
      setHealth(h);
    } catch (err: any) {
      setHealthError(err.message || 'Server unreachable');
    }

    // 2. Stats API
    try {
      const s = await api.getStats();
      setStats(s);
    } catch (err: any) {
      setStatsError(err.message || 'Database running in stateless mode');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [api]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const onRefresh = () => {
    setRefreshing(true);
    fetchData();
  };

  const isHealthy = health?.status?.toLowerCase() === 'healthy';

  return (
    <View style={styles.screen}>
      <GlassyAnimatedBackground />
      <ScrollView
        contentContainerStyle={[
          styles.scrollContent,
          { paddingBottom: Math.max(insets.bottom + 85, 105) },
        ]}
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#16a34a" />
        }
      >
        {/* TOP OFFICER BAR */}
        <View style={styles.officerBar}>
          <View style={styles.officerAvatarCircle}>
            <Ionicons name="shield-checkmark" size={20} color="#166534" />
          </View>
          <View style={styles.officerInfoCol}>
            <Text style={styles.officerPreText}>OFFICER IN CHARGE</Text>
            <Text style={styles.officerNameText} numberOfLines={1}>
              {username ? username.toUpperCase() : 'INSPECTION OFFICER'}
            </Text>
            <Text style={styles.officerRoleSub}>
              {role === 'Admin' ? 'Enforcement Director' : 'Field Inspector'}
            </Text>
          </View>
          <View style={styles.statusChip}>
            <View
              style={[
                styles.statusPulseDot,
                {
                  backgroundColor: loading
                    ? '#059669'
                    : isHealthy
                      ? '#10b981'
                      : '#dc2626',
                },
              ]}
            />
            <Text
              style={[
                styles.statusChipText,
                {
                  color: loading
                    ? '#059669'
                    : isHealthy
                      ? '#14532d'
                      : '#dc2626',
                },
              ]}
            >
              {loading ? 'Connecting...' : isHealthy ? 'Live Online' : 'Engine Offline'}
            </Text>
          </View>
        </View>

        {/* 1. SYSTEM ENGINE HEALTH CARD */}
        <View style={styles.card}>
          <View style={styles.cardHeader}>
            <View style={styles.cardHeaderLeft}>
              <View style={styles.cardHeaderIconBubble}>
                <Ionicons name="hardware-chip-outline" size={18} color="#166534" />
              </View>
              <View>
                <Text style={styles.cardHeading}>Engine & AI Core</Text>
                <Text style={styles.cardSubHeading}>OCR Inference & Engine Status</Text>
              </View>
            </View>
            <View
              style={[
                styles.pillBadge,
                {
                  backgroundColor: loading
                    ? '#ecfdf5'
                    : isHealthy
                      ? '#ecfdf5'
                      : '#fee2e2',
                },
              ]}
            >
              <Text
                style={[
                  styles.pillBadgeText,
                  {
                    color: loading
                      ? '#059669'
                      : isHealthy
                        ? '#047857'
                        : '#b91c1c',
                  },
                ]}
              >
                {loading ? 'Checking...' : isHealthy ? 'Live Online' : 'Offline'}
              </Text>
            </View>
          </View>

          {loading && !health ? (
            <View style={styles.loadingBox}>
              <ActivityIndicator size="small" color="#166534" />
              <Text style={styles.loadingText}>
                Connecting to Themis Engine ({api.getBaseUrl()})...
              </Text>
            </View>
          ) : healthError ? (
            <View style={styles.errorAlertBox}>
              <View style={styles.errorAlertTop}>
                <Ionicons name="alert-circle" size={20} color="#dc2626" />
                <View style={{ flex: 1 }}>
                  <Text style={styles.errorAlertTitle}>Engine Connection Failed</Text>
                  <Text style={styles.errorAlertText}>{healthError}</Text>
                  <Text style={styles.errorServerUrl}>
                    Server: {api.getBaseUrl()}
                  </Text>
                </View>
              </View>
              <View style={styles.errorActionsRow}>
                <TouchableOpacity
                  style={styles.retryActionBtn}
                  onPress={fetchData}
                  activeOpacity={0.8}
                >
                  <Ionicons name="refresh" size={14} color="#ffffff" />
                  <Text style={styles.retryActionBtnText}>Retry Connection</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={styles.settingsActionBtn}
                  onPress={() => router.push('/(tabs)/settings')}
                  activeOpacity={0.8}
                >
                  <Ionicons name="settings-outline" size={14} color="#0f172a" />
                  <Text style={styles.settingsActionBtnText}>Change IP / URL</Text>
                </TouchableOpacity>
              </View>
            </View>
          ) : health ? (
            <View style={styles.metadataList}>
              {/* Service Item */}
              <View style={styles.metaPillRow}>
                <Text style={styles.metaLabel}>ENGINE CORE</Text>
                <Text style={styles.metaValue}>{health.service}</Text>
              </View>

              {/* Inference Device Item */}
              <View style={styles.metaPillRow}>
                <Text style={styles.metaLabel}>AI OCR ENGINE</Text>
                <Text style={styles.metaValue}>{health.inference_device}</Text>
              </View>

              {/* Active Regulations */}
              <View style={styles.metaPillRow}>
                <Text style={styles.metaLabel}>LEGAL REGULATIONS</Text>
                <Text style={styles.metaValue}>{health.active_regulations}</Text>
              </View>

              {/* Database Status Item */}
              <View style={styles.metaPillRow}>
                <Text style={styles.metaLabel}>DATA PERSISTENCE</Text>
                <View style={styles.dbStatusRow}>
                  <View
                    style={[
                      styles.dbStatusIndicator,
                      {
                        backgroundColor: health.database_connected
                          ? '#10b981'
                          : '#d97706',
                      },
                    ]}
                  />
                  <Text style={styles.dbStatusText}>
                    {health.database_connected
                      ? 'PostgreSQL Persistent Storage'
                      : 'Stateless In-Memory Mode'}
                  </Text>
                </View>
              </View>

              {/* Heartbeat Item */}
              <View style={styles.metaPillRow}>
                <Text style={styles.metaLabel}>LAST HEARTBEAT</Text>
                <Text style={styles.metaTimeValue}>{formatDateTime(health.timestamp)}</Text>
              </View>
            </View>
          ) : null}
        </View>

        {/* 2. STATUTORY INSPECTION ANALYTICS */}
        <View style={styles.card}>
          <View style={styles.cardHeader}>
            <View style={styles.cardHeaderLeft}>
              <View style={styles.cardHeaderIconBubble}>
                <Ionicons name="analytics-outline" size={18} color="#166534" />
              </View>
              <View>
                <Text style={styles.cardHeading}>Compliance Metrics</Text>
                <Text style={styles.cardSubHeading}>LMPC Rules 2011</Text>
              </View>
            </View>
          </View>

          {statsError ? (
            <View style={styles.infoAlertBox}>
              <Ionicons name="information-circle-outline" size={18} color="#059669" />
              <Text style={styles.infoAlertText}>
                {statsError.includes('database') || statsError.includes('503')
                  ? 'Database is in in-memory mode. New scans are audited and reported in real time!'
                  : statsError}
              </Text>
            </View>
          ) : null}

          {/* 4 Stat Tiles Grid */}
          <View style={styles.grid2x2}>
            {/* Tile 1 */}
            <View style={[styles.statBox, styles.statBoxNeutral]}>
              <View style={[styles.statIconBadge, { backgroundColor: 'rgba(22, 101, 52, 0.08)' }]}>
                <Ionicons name="documents-outline" size={15} color="#166534" />
              </View>
              <Text style={styles.statBigNumber}>{stats?.total_inspections ?? 0}</Text>
              <Text style={styles.statBoxLabel}>Total Audits</Text>
            </View>

            {/* Tile 2 */}
            <View style={[styles.statBox, styles.statBoxSuccess]}>
              <View style={[styles.statIconBadge, { backgroundColor: 'rgba(16, 185, 129, 0.14)' }]}>
                <Ionicons name="checkmark-circle-outline" size={15} color="#059669" />
              </View>
              <Text style={[styles.statBigNumber, { color: '#059669' }]}>
                {stats?.compliant_count ?? stats?.total_compliant ?? 0}
              </Text>
              <Text style={[styles.statBoxLabel, { color: '#065f46' }]}>Compliant SKUs</Text>
            </View>

            {/* Tile 3 */}
            <View style={[styles.statBox, styles.statBoxDanger]}>
              <View style={[styles.statIconBadge, { backgroundColor: 'rgba(239, 68, 68, 0.12)' }]}>
                <Ionicons name="alert-circle-outline" size={15} color="#dc2626" />
              </View>
              <Text style={[styles.statBigNumber, { color: '#dc2626' }]}>
                {stats?.violation_count ?? stats?.total_violations ?? 0}
              </Text>
              <Text style={[styles.statBoxLabel, { color: '#991b1b' }]}>Non-Compliant</Text>
            </View>

            {/* Tile 4 */}
            <View style={[styles.statBox, styles.statBoxRate]}>
              <View style={[styles.statIconBadge, { backgroundColor: 'rgba(34, 197, 94, 0.14)' }]}>
                <Ionicons name="pie-chart-outline" size={15} color="#166534" />
              </View>
              <Text style={[styles.statBigNumber, { color: '#166534' }]}>
                {stats && stats.total_inspections > 0
                  ? `${(((stats.compliant_count ?? stats.total_compliant ?? 0) / stats.total_inspections) * 100).toFixed(0)}%`
                  : '—'}
              </Text>
              <Text style={[styles.statBoxLabel, { color: '#14532d' }]}>Pass Rate</Text>
            </View>
          </View>

          {/* Total Compounding Fines Highlight */}
          <View style={styles.penaltiesBox}>
            <View style={styles.penaltiesTextCol}>
              <Text style={styles.penaltiesLabel}>JAN VISHWAS ACT PENALTIES</Text>
              <Text style={styles.penaltiesAmount}>
                {formatInr(stats?.total_compounding_fines_inr ?? stats?.total_penalties_inr ?? 0)}
              </Text>
              <Text style={styles.penaltiesCaption}>
                Compounding fines calculated for statutory Rule 6 & 13 offenses
              </Text>
            </View>
            <View style={styles.gavelCircle}>
              <Ionicons name="cash-outline" size={26} color="#b45309" />
            </View>
          </View>

          {/* Statutory Risk Distribution Bar */}
          <View style={styles.riskBlock}>
            <Text style={styles.riskTitle}>Statutory Risk Classification</Text>
            {stats && (stats.tier_breakdown || stats.risk_distribution) ? (
              <>
                <View style={styles.riskProgressBar}>
                  <View
                    style={[
                      styles.riskSegment,
                      {
                        flex: (stats.tier_breakdown?.LowRisk ?? stats.risk_distribution?.LowRisk ?? 0) || 0.001,
                        backgroundColor: '#10b981',
                      },
                    ]}
                  />
                  <View
                    style={[
                      styles.riskSegment,
                      {
                        flex: (stats.tier_breakdown?.ModerateRisk ?? stats.risk_distribution?.ModerateRisk ?? 0) || 0.001,
                        backgroundColor: '#ca8a04',
                      },
                    ]}
                  />
                  <View
                    style={[
                      styles.riskSegment,
                      {
                        flex: (stats.tier_breakdown?.HighRisk ?? stats.risk_distribution?.HighRisk ?? 0) || 0.001,
                        backgroundColor: '#ea580c',
                      },
                    ]}
                  />
                  <View
                    style={[
                      styles.riskSegment,
                      {
                        flex: (stats.tier_breakdown?.CriticalRisk ?? stats.risk_distribution?.CriticalRisk ?? 0) || 0.001,
                        backgroundColor: '#dc2626',
                      },
                    ]}
                  />
                </View>
                <View style={styles.riskLegendGrid}>
                  <View style={styles.legendEntry}>
                    <View style={[styles.legendDot, { backgroundColor: '#10b981' }]} />
                    <Text style={styles.legendLabel}>
                      Low ({stats.tier_breakdown?.LowRisk ?? stats.risk_distribution?.LowRisk ?? 0})
                    </Text>
                  </View>
                  <View style={styles.legendEntry}>
                    <View style={[styles.legendDot, { backgroundColor: '#ca8a04' }]} />
                    <Text style={styles.legendLabel}>
                      Mod ({stats.tier_breakdown?.ModerateRisk ?? stats.risk_distribution?.ModerateRisk ?? 0})
                    </Text>
                  </View>
                  <View style={styles.legendEntry}>
                    <View style={[styles.legendDot, { backgroundColor: '#ea580c' }]} />
                    <Text style={styles.legendLabel}>
                      High ({stats.tier_breakdown?.HighRisk ?? stats.risk_distribution?.HighRisk ?? 0})
                    </Text>
                  </View>
                  <View style={styles.legendEntry}>
                    <View style={[styles.legendDot, { backgroundColor: '#dc2626' }]} />
                    <Text style={styles.legendLabel}>
                      Crit ({stats.tier_breakdown?.CriticalRisk ?? stats.risk_distribution?.CriticalRisk ?? 0})
                    </Text>
                  </View>
                </View>
              </>
            ) : (
              <Text style={styles.emptyRiskText}>
                No statutory audits recorded yet. Upload an image to start!
              </Text>
            )}
          </View>
        </View>

        {/* 3. NEW INSPECTION BUTTON */}
        <TouchableOpacity
          style={styles.actionBanner}
          onPress={() => router.push('/(tabs)/scan')}
          activeOpacity={0.88}
        >
          <View style={styles.actionBannerIconBox}>
            <Ionicons name="scan" size={24} color="#ffffff" />
          </View>
          <View style={styles.actionBannerTextCol}>
            <Text style={styles.actionBannerTitle}>Start New Product Audit</Text>
            <Text style={styles.actionBannerSubtitle}>
              Scan packaging labels to verify MRP, Net Qty & Dates
            </Text>
          </View>
          <Ionicons name="chevron-forward" size={20} color="#bbf7d0" />
        </TouchableOpacity>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: '#ebf4ed',
  },
  scrollContent: {
    paddingHorizontal: 16,
    paddingTop: 14,
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

  // Officer Bar (Frosted Glass)
  officerBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: 'rgba(255, 255, 255, 0.62)',
    borderRadius: 24,
    paddingHorizontal: 16,
    paddingVertical: 14,
    marginBottom: 14,
    borderWidth: 1.5,
    borderColor: 'rgba(255, 255, 255, 0.95)',
    shadowColor: '#064e3b',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.08,
    shadowRadius: 18,
    elevation: 3,
  },
  officerAvatarCircle: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: 'rgba(34, 197, 94, 0.18)',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.8)',
  },
  officerInfoCol: {
    flex: 1,
    marginRight: 10,
  },
  officerPreText: {
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 0.9,
    color: '#065f46',
    marginBottom: 2,
  },
  officerNameText: {
    fontSize: 16,
    fontWeight: '900',
    color: '#022c22',
    letterSpacing: -0.2,
  },
  officerRoleSub: {
    fontSize: 12,
    fontWeight: '700',
    color: '#047857',
    marginTop: 2,
  },
  statusChip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: 'rgba(255, 255, 255, 0.72)',
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 20,
    borderWidth: 1.2,
    borderColor: 'rgba(34, 197, 94, 0.4)',
  },
  statusPulseDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  statusChipText: {
    fontSize: 11,
    fontWeight: '800',
    color: '#022c22',
  },

  // Cards (Ultra Soft Frosted Glass)
  card: {
    backgroundColor: 'rgba(255, 255, 255, 0.58)',
    borderRadius: 26,
    padding: 18,
    marginBottom: 14,
    borderWidth: 1.5,
    borderColor: 'rgba(255, 255, 255, 0.95)',
    shadowColor: '#064e3b',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.08,
    shadowRadius: 20,
    elevation: 4,
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 14,
  },
  cardHeaderLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  cardHeaderIconBubble: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: 'rgba(34, 197, 94, 0.18)',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.8)',
  },
  cardHeading: {
    fontSize: 16,
    fontWeight: '900',
    color: '#022c22',
    letterSpacing: -0.2,
  },
  cardSubHeading: {
    fontSize: 11,
    fontWeight: '600',
    color: '#0f5132',
    marginTop: 1,
  },
  pillBadge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 14,
    borderWidth: 1.2,
    borderColor: 'rgba(16, 185, 129, 0.4)',
  },
  pillBadgeText: {
    fontSize: 11,
    fontWeight: '800',
  },
  loadingBox: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
    paddingVertical: 20,
    backgroundColor: 'rgba(240, 253, 244, 0.85)',
    borderRadius: 16,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.9)',
  },
  loadingText: {
    fontSize: 12,
    color: '#047857',
    fontWeight: '700',
  },

  // Metadata List (Glass Pill Rows)
  metadataList: {
    gap: 7,
  },
  metaPillRow: {
    backgroundColor: 'rgba(255, 255, 255, 0.48)',
    borderRadius: 14,
    paddingVertical: 9,
    paddingHorizontal: 12,
    borderWidth: 1.2,
    borderColor: 'rgba(255, 255, 255, 0.88)',
  },
  metaLabel: {
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 0.8,
    color: '#065f46',
    marginBottom: 3,
  },
  metaValue: {
    fontSize: 13,
    fontWeight: '700',
    color: '#022c22',
    lineHeight: 18,
    flexWrap: 'wrap',
  },
  metaTimeValue: {
    fontSize: 12,
    fontWeight: '700',
    color: '#0f172a',
  },
  dbStatusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginTop: 2,
  },
  dbStatusIndicator: {
    width: 7,
    height: 7,
    borderRadius: 3.5,
  },
  dbStatusText: {
    fontSize: 12,
    fontWeight: '800',
    color: '#022c22',
  },

  // Alerts
  errorAlertBox: {
    backgroundColor: 'rgba(255, 241, 242, 0.88)',
    borderRadius: 16,
    padding: 14,
    gap: 10,
    borderWidth: 1,
    borderColor: 'rgba(254, 202, 202, 0.7)',
  },
  errorAlertTop: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 8,
  },
  errorAlertTitle: {
    fontSize: 13,
    fontWeight: '800',
    color: '#991b1b',
  },
  errorAlertText: {
    fontSize: 12,
    color: '#b91c1c',
    marginTop: 2,
    lineHeight: 16,
    fontWeight: '600',
  },
  errorServerUrl: {
    fontSize: 11,
    fontFamily: 'monospace',
    color: '#7f1d1d',
    marginTop: 4,
    fontWeight: '600',
  },
  errorActionsRow: {
    flexDirection: 'row',
    gap: 8,
    paddingTop: 6,
    borderTopWidth: 1,
    borderTopColor: '#ffe4e6',
  },
  retryActionBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: '#dc2626',
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 8,
  },
  retryActionBtnText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#ffffff',
  },
  settingsActionBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: 'rgba(255, 255, 255, 0.9)',
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: 'rgba(254, 202, 202, 0.8)',
  },
  settingsActionBtnText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#991b1b',
  },
  infoAlertBox: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: 'rgba(236, 253, 245, 0.85)',
    borderRadius: 14,
    padding: 12,
    marginBottom: 14,
    borderWidth: 1.2,
    borderColor: 'rgba(167, 243, 208, 0.7)',
  },
  infoAlertText: {
    flex: 1,
    fontSize: 12,
    color: '#064e3b',
    fontWeight: '600',
    lineHeight: 16,
  },

  // 2x2 Stats Grid (Frosted Glass Tiles)
  grid2x2: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
    marginBottom: 14,
  },
  statBox: {
    flexBasis: '48%',
    flexGrow: 1,
    paddingVertical: 14,
    paddingHorizontal: 12,
    borderRadius: 20,
    alignItems: 'center',
    borderWidth: 1.2,
    borderColor: 'rgba(255, 255, 255, 0.95)',
  },
  statIconBadge: {
    width: 34,
    height: 34,
    borderRadius: 17,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 6,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.8)',
  },
  statBoxNeutral: {
    backgroundColor: 'rgba(255, 255, 255, 0.52)',
  },
  statBoxSuccess: {
    backgroundColor: 'rgba(236, 253, 245, 0.58)',
  },
  statBoxDanger: {
    backgroundColor: 'rgba(254, 242, 242, 0.60)',
  },
  statBoxRate: {
    backgroundColor: 'rgba(240, 253, 244, 0.60)',
  },
  statBigNumber: {
    fontSize: 26,
    fontWeight: '900',
    color: '#022c22',
    letterSpacing: -0.5,
  },
  statBoxLabel: {
    fontSize: 11,
    fontWeight: '800',
    color: '#065f46',
    marginTop: 4,
    textAlign: 'center',
    letterSpacing: 0.2,
  },

  // Penalties Box (Frosted Glass)
  penaltiesBox: {
    backgroundColor: 'rgba(254, 252, 232, 0.65)',
    borderRadius: 22,
    padding: 16,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 14,
    borderWidth: 1.2,
    borderColor: 'rgba(254, 240, 138, 0.85)',
  },
  penaltiesTextCol: {
    flex: 1,
    marginRight: 10,
  },
  penaltiesLabel: {
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 0.8,
    color: '#78350f',
  },
  penaltiesAmount: {
    fontSize: 22,
    fontWeight: '900',
    color: '#78350f',
    marginTop: 2,
    letterSpacing: -0.3,
  },
  penaltiesCaption: {
    fontSize: 11,
    color: '#713f12',
    fontWeight: '700',
    marginTop: 3,
    lineHeight: 15,
    flexWrap: 'wrap',
  },
  gavelCircle: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: 'rgba(254, 240, 138, 0.75)',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: 'rgba(253, 224, 71, 0.6)',
  },

  // Risk Classification
  riskBlock: {
    marginTop: 4,
  },
  riskTitle: {
    fontSize: 12,
    fontWeight: '900',
    color: '#022c22',
    marginBottom: 8,
  },
  riskProgressBar: {
    height: 8,
    borderRadius: 4,
    flexDirection: 'row',
    overflow: 'hidden',
    marginBottom: 10,
    backgroundColor: 'rgba(255, 255, 255, 0.65)',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.85)',
  },
  riskSegment: {
    height: '100%',
  },
  riskLegendGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  legendEntry: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  legendDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  legendLabel: {
    fontSize: 11,
    fontWeight: '700',
    color: '#064e3b',
  },
  emptyRiskText: {
    fontSize: 12,
    color: '#065f46',
    fontWeight: '700',
    fontStyle: 'italic',
    paddingVertical: 2,
  },

  // Action Banner (Glossy Deep Emerald Glass)
  actionBanner: {
    backgroundColor: 'rgba(6, 42, 21, 0.92)',
    borderRadius: 26,
    padding: 16,
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1.5,
    borderColor: 'rgba(74, 222, 128, 0.45)',
    shadowColor: '#062a15',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.25,
    shadowRadius: 16,
    elevation: 5,
  },
  actionBannerIconBox: {
    width: 46,
    height: 46,
    borderRadius: 23,
    backgroundColor: 'rgba(74, 222, 128, 0.25)',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
    borderWidth: 1,
    borderColor: 'rgba(74, 222, 128, 0.35)',
  },
  actionBannerTextCol: {
    flex: 1,
    marginRight: 8,
  },
  actionBannerTitle: {
    fontSize: 15,
    fontWeight: '900',
    color: '#ffffff',
  },
  actionBannerSubtitle: {
    fontSize: 11,
    color: '#dcfce7',
    fontWeight: '600',
    marginTop: 2,
    lineHeight: 15,
    flexWrap: 'wrap',
  },
});
