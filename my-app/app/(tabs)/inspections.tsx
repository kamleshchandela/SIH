import React, { useEffect, useState, useCallback, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  ScrollView,
  TextInput,
  TouchableOpacity,
  ActivityIndicator,
  RefreshControl,
  Image,
  Animated,
  Easing,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAuth } from '../../src/context/AuthContext';
import { InspectionSummary, RiskTier } from '../../src/types/themis';
import {
  formatDateTime,
  formatInr,
  getRiskTierInfo,
} from '../../src/utils/formatters';

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

export default function InspectionsScreen() {
  const insets = useSafeAreaInsets();
  const { api } = useAuth();
  const [inspections, setInspections] = useState<InspectionSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [errorNotice, setErrorNotice] = useState<string | null>(null);

  // Filters
  const [search, setSearch] = useState('');
  const [selectedTier, setSelectedTier] = useState<string>('All');
  const [complianceFilter, setComplianceFilter] = useState<'all' | 'true' | 'false'>('all');

  const fetchInspections = useCallback(async () => {
    setErrorNotice(null);
    try {
      const compliantVal =
        complianceFilter === 'all' ? undefined : complianceFilter === 'true';

      const res = await api.getInspections({
        search: search.trim() || undefined,
        risk_tier: selectedTier === 'All' ? undefined : selectedTier,
        compliant: compliantVal,
        limit: 50,
      });

      const list = res.items || res.inspections || [];
      setInspections(list);
    } catch (err: any) {
      setErrorNotice(err.message || 'Unable to fetch past inspections.');
      setInspections([]);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [api, search, selectedTier, complianceFilter]);

  useEffect(() => {
    fetchInspections();
  }, [fetchInspections]);

  const onRefresh = () => {
    setRefreshing(true);
    fetchInspections();
  };

  const openDetail = async (id: string) => {
    try {
      const detail = await api.getInspectionDetail(id);
      router.push({
        pathname: '/result',
        params: { data: JSON.stringify(detail) },
      });
    } catch (err: any) {
      alert(`Could not fetch details for ${id}: ${err.message}`);
    }
  };

  const renderItem = ({ item }: { item: InspectionSummary }) => {
    const risk = getRiskTierInfo(item.risk_tier);
    const isPass = item.overall_compliant;
    const hasPanels = item.scanned_panels && item.scanned_panels.length > 0;
    const thumbUrl = hasPanels
      ? api.getEvidenceUrl(item.inspection_id, item.scanned_panels[0])
      : null;

    return (
      <TouchableOpacity
        style={styles.card}
        onPress={() => openDetail(item.inspection_id)}
        activeOpacity={0.75}
      >
        <View style={styles.cardTopRow}>
          <Text style={styles.inspectionId}>{item.inspection_id}</Text>
          <Text style={styles.timestamp}>{formatDateTime(item.created_at)}</Text>
        </View>

        <View style={styles.cardContentRow}>
          <View style={styles.cardTextCol}>
            <Text style={styles.productName} numberOfLines={2}>
              {item.product_name || 'Standard Packaged Commodity'}
            </Text>

            <View style={styles.cardBadgesRow}>
              {/* Status Badge */}
              <View
                style={[
                  styles.statusPill,
                  {
                    backgroundColor: isPass
                      ? 'rgba(236, 253, 245, 0.45)'
                      : 'rgba(254, 226, 226, 0.45)',
                    borderColor: isPass
                      ? 'rgba(16, 185, 129, 0.4)'
                      : 'rgba(239, 68, 68, 0.4)',
                  },
                ]}
              >
                <Text
                  style={[
                    styles.statusPillText,
                    { color: isPass ? '#047857' : '#b91c1c' },
                  ]}
                >
                  {isPass ? 'COMPLIANT' : 'VIOLATION'}
                </Text>
              </View>

              {/* Risk Pill */}
              <View
                style={[
                  styles.riskPill,
                  {
                    backgroundColor: 'rgba(255, 255, 255, 0.3)',
                    borderColor: risk.color,
                  },
                ]}
              >
                <Text style={[styles.riskPillText, { color: risk.color }]}>
                  {risk.label}
                </Text>
              </View>

              {/* Score */}
              <Text style={styles.scoreText}>
                Score: {item.compliance_score_pct ? item.compliance_score_pct.toFixed(0) : '0'}%
              </Text>
            </View>
          </View>

          {thumbUrl && (
            <View style={styles.cardThumbWrap}>
              <Image
                source={{ uri: thumbUrl }}
                style={styles.cardThumbImage}
                resizeMode="cover"
              />
              {item.scanned_panels.length > 1 && (
                <View style={styles.cardThumbCountBadge}>
                  <Ionicons name="images" size={9} color="#ffffff" />
                  <Text style={styles.cardThumbCountText}>{item.scanned_panels.length}</Text>
                </View>
              )}
            </View>
          )}
        </View>

        <View style={styles.cardBottomRow}>
          <View style={styles.violationCountCol}>
            <Ionicons name="alert-circle-outline" size={14} color="#dc2626" />
            <Text style={styles.violationCountText}>
              {item.total_violations || 0} Violations Detected
            </Text>
          </View>

          <Text style={styles.fineText}>
            {formatInr(item.compounding_fine_inr || 0)}
          </Text>
        </View>
      </TouchableOpacity>
    );
  };

  return (
    <View style={styles.screen}>
      <GlassyAnimatedBackground />

      {/* Search Input */}
      <View style={styles.searchWrapper}>
        <Ionicons name="search-outline" size={18} color="#065f46" style={{ marginRight: 8 }} />
        <TextInput
          style={styles.searchInput}
          placeholder="Search by SKU name or ID..."
          placeholderTextColor="#52796f"
          value={search}
          onChangeText={setSearch}
        />
        {search.length > 0 && (
          <TouchableOpacity onPress={() => setSearch('')}>
            <Ionicons name="close-circle" size={18} color="#065f46" />
          </TouchableOpacity>
        )}
      </View>

      {/* Filter Chips Bar */}
      <View style={styles.filterSection}>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.chipsScroll}>
          {['All', 'LowRisk', 'ModerateRisk', 'HighRisk', 'CriticalRisk'].map((tier) => (
            <TouchableOpacity
              key={tier}
              style={[
                styles.filterChip,
                selectedTier === tier && styles.filterChipActive,
              ]}
              onPress={() => setSelectedTier(tier)}
              activeOpacity={0.8}
            >
              <Text
                style={[
                  styles.filterChipText,
                  selectedTier === tier && styles.filterChipTextActive,
                ]}
              >
                {tier === 'All' ? 'All Risk' : tier.replace('Risk', '')}
              </Text>
            </TouchableOpacity>
          ))}
        </ScrollView>
      </View>

      {/* Error / Notice Banner */}
      {errorNotice && (
        <View style={styles.noticeBox}>
          <Ionicons name="information-circle-outline" size={18} color="#059669" />
          <Text style={styles.noticeText}>
            {errorNotice.includes('database') || errorNotice.includes('503')
              ? 'Database repository is in stateless in-memory mode. Perform scans in the "Scan SKU" tab to view real-time audit reports!'
              : errorNotice}
          </Text>
        </View>
      )}

      {/* Main List */}
      {loading ? (
        <View style={styles.centerLoading}>
          <ActivityIndicator size="large" color="#059669" />
          <Text style={styles.loadingText}>Loading inspection audits...</Text>
        </View>
      ) : (
        <FlatList
          data={inspections}
          keyExtractor={(item) => item.inspection_id}
          renderItem={renderItem}
          contentContainerStyle={[
            styles.listContent,
            { paddingBottom: Math.max(insets.bottom + 85, 105) },
          ]}
          showsVerticalScrollIndicator={false}
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#10b981" />
          }
          ListEmptyComponent={
            <View style={styles.emptyBox}>
              <Ionicons name="file-tray-outline" size={48} color="#52796f" />
              <Text style={styles.emptyTitle}>No Inspections Found</Text>
              <Text style={styles.emptySub}>
                Upload product photos in the Scan tab to run your first compliance audit.
              </Text>
              <TouchableOpacity
                style={styles.scanNowBtn}
                onPress={() => router.push('/(tabs)/scan')}
                activeOpacity={0.85}
              >
                <Text style={styles.scanNowBtnText}>Start New Scan</Text>
              </TouchableOpacity>
            </View>
          }
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: '#ebf4ed',
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

  // Search Bar (Frosted Glass)
  searchWrapper: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255, 255, 255, 0.62)',
    marginHorizontal: 16,
    marginTop: 14,
    paddingHorizontal: 14,
    height: 46,
    borderRadius: 24,
    borderWidth: 1.5,
    borderColor: 'rgba(255, 255, 255, 0.95)',
    shadowColor: '#064e3b',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.08,
    shadowRadius: 18,
    elevation: 3,
  },
  searchInput: {
    flex: 1,
    fontSize: 13,
    fontWeight: '700',
    color: '#022c22',
  },

  // Filter Chips (Pill Row)
  filterSection: {
    marginVertical: 10,
  },
  chipsScroll: {
    paddingHorizontal: 16,
  },
  filterChip: {
    backgroundColor: 'rgba(255, 255, 255, 0.52)',
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 18,
    marginRight: 8,
    borderWidth: 1.2,
    borderColor: 'rgba(255, 255, 255, 0.95)',
  },
  filterChipActive: {
    backgroundColor: 'rgba(19, 56, 32, 0.92)',
    borderColor: 'rgba(74, 222, 128, 0.45)',
    shadowColor: '#062a15',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.2,
    shadowRadius: 8,
    elevation: 3,
  },
  filterChipText: {
    fontSize: 11,
    color: '#065f46',
    fontWeight: '800',
  },
  filterChipTextActive: {
    color: '#ffffff',
    fontWeight: '900',
  },

  // Notice Banner
  noticeBox: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: 'rgba(236, 253, 245, 0.85)',
    marginHorizontal: 16,
    marginBottom: 8,
    padding: 12,
    borderRadius: 16,
    borderWidth: 1.2,
    borderColor: 'rgba(167, 243, 208, 0.7)',
  },
  noticeText: {
    fontSize: 12,
    fontWeight: '600',
    color: '#064e3b',
    flex: 1,
  },

  listContent: {
    paddingHorizontal: 16,
    paddingTop: 4,
  },

  // Cards (Ultra Soft Frosted Glass matching index.tsx)
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
  cardTopRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  inspectionId: {
    fontSize: 11,
    fontFamily: 'monospace',
    fontWeight: '800',
    color: '#065f46',
    letterSpacing: 0.5,
  },
  timestamp: {
    fontSize: 11,
    fontWeight: '700',
    color: '#0f5132',
  },
  cardContentRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  cardTextCol: {
    flex: 1,
  },
  cardThumbWrap: {
    width: 60,
    height: 60,
    borderRadius: 14,
    backgroundColor: 'rgba(6, 42, 21, 0.6)',
    overflow: 'hidden',
    position: 'relative',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.95)',
  },
  cardThumbImage: {
    width: '100%',
    height: '100%',
  },
  cardThumbCountBadge: {
    position: 'absolute',
    bottom: 2,
    right: 2,
    backgroundColor: 'rgba(6, 42, 21, 0.85)',
    borderRadius: 6,
    paddingHorizontal: 4,
    paddingVertical: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
  },
  cardThumbCountText: {
    color: '#ffffff',
    fontSize: 9,
    fontWeight: '800',
  },
  productName: {
    fontSize: 15,
    fontWeight: '900',
    color: '#022c22',
    marginVertical: 4,
    letterSpacing: -0.2,
  },
  cardBadgesRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginVertical: 6,
    flexWrap: 'wrap',
  },
  statusPill: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 8,
    borderWidth: 1,
  },
  statusPillText: {
    fontSize: 10,
    fontWeight: '800',
  },
  riskPill: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 8,
    borderWidth: 1,
  },
  riskPillText: {
    fontSize: 10,
    fontWeight: '800',
  },
  scoreText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#065f46',
  },
  cardBottomRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 8,
    paddingTop: 8,
    borderTopWidth: 1,
    borderTopColor: 'rgba(255, 255, 255, 0.75)',
  },
  violationCountCol: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  violationCountText: {
    fontSize: 12,
    color: '#dc2626',
    fontWeight: '700',
  },
  fineText: {
    fontSize: 14,
    fontWeight: '900',
    color: '#78350f',
  },
  centerLoading: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 30,
  },
  loadingText: {
    fontSize: 13,
    fontWeight: '700',
    color: '#047857',
    marginTop: 10,
  },
  emptyBox: {
    alignItems: 'center',
    justifyContent: 'center',
    padding: 40,
    marginTop: 20,
    backgroundColor: 'rgba(255, 255, 255, 0.58)',
    borderRadius: 26,
    borderWidth: 1.5,
    borderColor: 'rgba(255, 255, 255, 0.95)',
    shadowColor: '#064e3b',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.08,
    shadowRadius: 20,
    elevation: 4,
  },
  emptyTitle: {
    fontSize: 16,
    fontWeight: '900',
    color: '#022c22',
    marginTop: 12,
  },
  emptySub: {
    fontSize: 12,
    color: '#065f46',
    fontWeight: '600',
    textAlign: 'center',
    marginTop: 4,
    lineHeight: 18,
    maxWidth: 260,
  },
  scanNowBtn: {
    marginTop: 16,
    backgroundColor: 'rgba(6, 42, 21, 0.92)',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 20,
    borderWidth: 1.5,
    borderColor: 'rgba(74, 222, 128, 0.45)',
    shadowColor: '#062a15',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.25,
    shadowRadius: 12,
  },
  scanNowBtnText: {
    color: '#ffffff',
    fontWeight: '900',
    fontSize: 13,
  },
});
