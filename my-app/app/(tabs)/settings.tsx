import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  ScrollView,
  Alert,
  ActivityIndicator,
  Animated,
  Easing,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAuth } from '../../src/context/AuthContext';

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

export default function SettingsScreen() {
  const insets = useSafeAreaInsets();
  const { baseUrl, updateBaseUrl, username, role, logout, api } = useAuth();
  const [urlInput, setUrlInput] = useState(baseUrl);
  const [testing, setTesting] = useState(false);
  const [testResult, setTestResult] = useState<{ success: boolean; msg: string } | null>(null);

  const handleSaveAndTest = async () => {
    if (!urlInput.trim()) {
      Alert.alert('Validation Error', 'API Base URL cannot be empty.');
      return;
    }

    setTesting(true);
    setTestResult(null);

    try {
      await updateBaseUrl(urlInput.trim());
      // Test health
      const h = await api.getHealth();
      setTestResult({
        success: true,
        msg: `Connected! Service: ${h.service}`,
      });
    } catch (err: any) {
      setTestResult({
        success: false,
        msg: `Connection Failed: ${err.message}`,
      });
    } finally {
      setTesting(false);
    }
  };

  const handleLogout = () => {
    Alert.alert(
      'Confirm Sign Out',
      'Are you sure you want to end your enforcement session?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Sign Out',
          style: 'destructive',
          onPress: () => logout(),
        },
      ]
    );
  };

  return (
    <View style={styles.screen}>
      <GlassyAnimatedBackground />
      <ScrollView
        contentContainerStyle={[
          styles.container,
          { paddingBottom: Math.max(insets.bottom + 85, 105) },
        ]}
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
      >
        {/* 1. OFFICER PROFILE CARD */}
        <View style={styles.card}>
          <Text style={styles.cardTitle}>Officer Profile & Credentials</Text>
          <View style={styles.profileRow}>
            <View style={styles.avatarCircle}>
              <Ionicons name="shield-checkmark" size={26} color="#166534" />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.officerName}>{username?.toUpperCase() || 'OFFICER'}</Text>
              <View style={styles.roleBadge}>
                <Text style={styles.roleBadgeText}>
                  {role === 'Admin' ? 'Director / Enforcement Admin' : 'Field Inspection Officer'}
                </Text>
              </View>
            </View>
          </View>
          <View style={styles.sessionBox}>
            <Ionicons name="key-outline" size={14} color="#059669" />
            <Text style={styles.sessionText}>Active 24-Hour Cryptographic JWT Session</Text>
          </View>
        </View>

        {/* 2. SERVER CONNECTION SETTINGS */}
        <View style={styles.card}>
          <Text style={styles.cardTitle}>Backend Server Configuration</Text>
          <Text style={styles.cardSub}>
            Configure the REST API endpoint of your local or remote PARAKH engine.
          </Text>

          <View style={styles.inputGroup}>
            <Text style={styles.inputLabel}>REST API Base URL</Text>
            <TextInput
              style={styles.textInput}
              value={urlInput}
              onChangeText={(text) => {
                setUrlInput(text);
                setTestResult(null);
              }}
              placeholder="http://localhost:8080"
              placeholderTextColor="#52796f"
              autoCapitalize="none"
              autoCorrect={false}
            />
          </View>

          <TouchableOpacity
            style={styles.saveBtn}
            onPress={handleSaveAndTest}
            disabled={testing}
            activeOpacity={0.85}
          >
            {testing ? (
              <ActivityIndicator size="small" color="#ffffff" />
            ) : (
              <>
                <Ionicons name="refresh-circle-outline" size={20} color="#ffffff" />
                <Text style={styles.saveBtnText}>Save & Verify Connection</Text>
              </>
            )}
          </TouchableOpacity>

          {/* Test Result Message */}
          {testResult && (
            <View
              style={[
                styles.testResultBox,
                {
                  backgroundColor: testResult.success
                    ? 'rgba(236, 253, 245, 0.7)'
                    : 'rgba(254, 226, 226, 0.7)',
                  borderColor: testResult.success
                    ? 'rgba(16, 185, 129, 0.4)'
                    : 'rgba(239, 68, 68, 0.4)',
                },
              ]}
            >
              <Ionicons
                name={testResult.success ? 'checkmark-circle' : 'alert-circle'}
                size={18}
                color={testResult.success ? '#047857' : '#dc2626'}
              />
              <Text
                style={[
                  styles.testResultText,
                  { color: testResult.success ? '#047857' : '#b91c1c' },
                ]}
              >
                {testResult.msg}
              </Text>
            </View>
          )}
        </View>

        {/* 3. STATUTORY COMPLIANCE INFO */}
        <View style={styles.card}>
          <Text style={styles.cardTitle}>Statutory Legal Framework</Text>
          <View style={styles.statutoryItem}>
            <Text style={styles.statutoryBullet}>•</Text>
            <Text style={styles.statutoryText}>
              <Text style={{ fontWeight: '800', color: '#022c22' }}>Legal Metrology Act, 2009:</Text> Section 18 & 36
              governing mandatory pre-packaged goods declarations.
            </Text>
          </View>
          <View style={styles.statutoryItem}>
            <Text style={styles.statutoryBullet}>•</Text>
            <Text style={styles.statutoryText}>
              <Text style={{ fontWeight: '800', color: '#022c22' }}>LMPC Rules, 2011:</Text> Rule 6 (Mandatory
              Declarations) & Rule 13 (Standard Units of Weights & Measures).
            </Text>
          </View>
          <View style={styles.statutoryItem}>
            <Text style={styles.statutoryBullet}>•</Text>
            <Text style={styles.statutoryText}>
              <Text style={{ fontWeight: '800', color: '#022c22' }}>Jan Vishwas Act, 2023:</Text> Compounding penal
              provisions for first and subsequent statutory offenses.
            </Text>
          </View>
        </View>

        {/* 4. LOGOUT BUTTON */}
        <TouchableOpacity style={styles.logoutBtn} onPress={handleLogout} activeOpacity={0.85}>
          <Ionicons name="log-out-outline" size={20} color="#dc2626" />
          <Text style={styles.logoutBtnText}>Sign Out of Enforcement Unit</Text>
        </TouchableOpacity>

        <Text style={styles.versionFooter}>
          PARAKH Client v1.0.0 • Mobile Legal Metrology Unit
        </Text>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: '#ebf4ed',
  },
  container: {
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
  cardTitle: {
    fontSize: 16,
    fontWeight: '900',
    color: '#022c22',
    letterSpacing: -0.2,
    marginBottom: 4,
  },
  cardSub: {
    fontSize: 12,
    fontWeight: '600',
    color: '#0f5132',
    marginBottom: 14,
    lineHeight: 17,
  },
  profileRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    marginTop: 10,
  },
  avatarCircle: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: 'rgba(34, 197, 94, 0.18)',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.8)',
  },
  officerName: {
    fontSize: 16,
    fontWeight: '900',
    color: '#022c22',
    letterSpacing: -0.2,
  },
  roleBadge: {
    backgroundColor: 'rgba(255, 255, 255, 0.52)',
    paddingHorizontal: 10,
    paddingVertical: 3,
    borderRadius: 8,
    marginTop: 4,
    alignSelf: 'flex-start',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.88)',
  },
  roleBadgeText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#047857',
  },
  sessionBox: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: 'rgba(236, 253, 245, 0.85)',
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 12,
    marginTop: 14,
    borderWidth: 1.2,
    borderColor: 'rgba(167, 243, 208, 0.7)',
  },
  sessionText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#047857',
  },

  // Input & Button
  inputGroup: {
    marginBottom: 14,
  },
  inputLabel: {
    fontSize: 11,
    fontWeight: '800',
    color: '#065f46',
    marginBottom: 6,
    letterSpacing: 0.8,
    textTransform: 'uppercase',
  },
  textInput: {
    backgroundColor: 'rgba(255, 255, 255, 0.48)',
    borderWidth: 1.2,
    borderColor: 'rgba(255, 255, 255, 0.88)',
    borderRadius: 14,
    paddingHorizontal: 12,
    height: 44,
    fontSize: 13,
    fontWeight: '700',
    color: '#022c22',
  },
  saveBtn: {
    backgroundColor: 'rgba(6, 42, 21, 0.92)',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    paddingVertical: 14,
    borderRadius: 20,
    borderWidth: 1.5,
    borderColor: 'rgba(74, 222, 128, 0.45)',
    shadowColor: '#062a15',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.25,
    shadowRadius: 16,
    elevation: 5,
  },
  saveBtnText: {
    color: '#ffffff',
    fontSize: 13,
    fontWeight: '900',
    letterSpacing: 0.2,
  },
  testResultBox: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    padding: 12,
    borderRadius: 14,
    marginTop: 12,
    borderWidth: 1,
  },
  testResultText: {
    fontSize: 12,
    fontWeight: '700',
    flex: 1,
  },

  // Statutory Items
  statutoryItem: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 8,
    marginBottom: 10,
  },
  statutoryBullet: {
    fontSize: 16,
    color: '#10b981',
    lineHeight: 18,
  },
  statutoryText: {
    fontSize: 12,
    fontWeight: '500',
    color: '#0f5132',
    flex: 1,
    lineHeight: 17,
  },

  // Logout Button
  logoutBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    backgroundColor: 'rgba(255, 255, 255, 0.55)',
    borderWidth: 1.5,
    borderColor: 'rgba(254, 202, 202, 0.8)',
    paddingVertical: 14,
    borderRadius: 20,
    marginTop: 6,
    marginBottom: 16,
  },
  logoutBtnText: {
    color: '#dc2626',
    fontSize: 13,
    fontWeight: '800',
  },
  versionFooter: {
    textAlign: 'center',
    fontSize: 11,
    fontWeight: '600',
    color: '#065f46',
    marginTop: 4,
    marginBottom: 10,
  },
});
