import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Image,
  TextInput,
  ActivityIndicator,
  Alert,
  Animated,
  Easing,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as ImagePicker from 'expo-image-picker';
import { router } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAuth } from '../../src/context/AuthContext';

type ScanMode = 'single' | 'sku' | 'path';

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

export default function ScanScreen() {
  const insets = useSafeAreaInsets();
  const { api } = useAuth();
  const [mode, setMode] = useState<ScanMode>('single');
  const [loading, setLoading] = useState(false);
  const [loadingMessage, setLoadingMessage] = useState('');
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Single scan state
  const [singleImage, setSingleImage] = useState<string | null>(null);

  // Multi-panel SKU scan state
  const [productName, setProductName] = useState('');
  const [panelImages, setPanelImages] = useState<Array<{ uri: string; name: string }>>([]);

  // Advanced Server Path scan state
  const [filePath, setFilePath] = useState('');
  const [productDir, setProductDir] = useState('');
  const [dirProductName, setDirProductName] = useState('');

  // Animated Sliding Pill & Content Transition
  const [segmentWidth, setSegmentWidth] = useState(0);
  const slideAnim = useRef(new Animated.Value(0)).current;
  const contentFadeAnim = useRef(new Animated.Value(1)).current;

  const MODES: ScanMode[] = ['single', 'sku', 'path'];

  const switchMode = (newMode: ScanMode) => {
    if (newMode === mode) return;
    setErrorMessage(null);
    const targetIdx = MODES.indexOf(newMode);

    // Smooth sliding pill animation across the tabs
    Animated.spring(slideAnim, {
      toValue: targetIdx,
      useNativeDriver: true,
      bounciness: 4,
      speed: 13,
    }).start();

    // Soft content glide & crossfade
    contentFadeAnim.setValue(0);
    setMode(newMode);
    Animated.timing(contentFadeAnim, {
      toValue: 1,
      duration: 240,
      easing: Easing.out(Easing.quad),
      useNativeDriver: true,
    }).start();
  };

  // Pick single image
  const pickSingleImage = async (useCamera = false) => {
    try {
      const options: ImagePicker.ImagePickerOptions = {
        mediaTypes: ['images'],
        quality: 0.9,
      };

      const result = useCamera
        ? await ImagePicker.launchCameraAsync(options)
        : await ImagePicker.launchImageLibraryAsync(options);

      if (!result.canceled && result.assets && result.assets.length > 0) {
        setSingleImage(result.assets[0].uri);
        setErrorMessage(null);
      }
    } catch (err: any) {
      Alert.alert('Permission Error', 'Camera or Gallery access was denied.');
    }
  };

  // Pick multi-panel images
  const pickMultiPanelImage = async (useCamera = false) => {
    try {
      const options: ImagePicker.ImagePickerOptions = {
        mediaTypes: ['images'],
        quality: 0.9,
        allowsMultipleSelection: !useCamera,
      };

      const result = useCamera
        ? await ImagePicker.launchCameraAsync(options)
        : await ImagePicker.launchImageLibraryAsync(options);

      if (!result.canceled && result.assets) {
        const newImages = result.assets.map((asset, index) => ({
          uri: asset.uri,
          name: asset.fileName || `panel_${panelImages.length + index + 1}.jpg`,
        }));
        setPanelImages((prev) => [...prev, ...newImages]);
        setErrorMessage(null);
      }
    } catch (err: any) {
      Alert.alert('Permission Error', 'Camera or Gallery access was denied.');
    }
  };

  const removePanel = (index: number) => {
    setPanelImages((prev) => prev.filter((_, idx) => idx !== index));
  };

  // Submit Single Scan
  const handleSingleScan = async () => {
    if (!singleImage) {
      setErrorMessage('Please select or capture a packaging panel image first.');
      return;
    }
    setLoading(true);
    setLoadingMessage('Performing OCR & Statutory Rule Validation on CPU...');
    setErrorMessage(null);

    try {
      const report = await api.scanSingle(singleImage);
      // Navigate to Result Screen with report
      router.push({
        pathname: '/result',
        params: { data: JSON.stringify(report) },
      });
    } catch (err: any) {
      setErrorMessage(err.message || 'Single scan failed. Check server status.');
    } finally {
      setLoading(false);
    }
  };

  // Submit Multi-Panel SKU Scan
  const handleSkuScan = async () => {
    if (panelImages.length === 0) {
      setErrorMessage('Please add at least 1 packaging panel image.');
      return;
    }
    setLoading(true);
    setLoadingMessage(`Pooling and auditing ${panelImages.length} packaging panels...`);
    setErrorMessage(null);

    try {
      const report = await api.scanSku(productName, panelImages);
      router.push({
        pathname: '/result',
        params: { data: JSON.stringify(report) },
      });
    } catch (err: any) {
      setErrorMessage(err.message || 'Multi-panel SKU scan failed.');
    } finally {
      setLoading(false);
    }
  };

  // Submit File Path Scan
  const handlePathScan = async () => {
    if (!filePath.trim()) {
      setErrorMessage('Please enter an absolute server image path.');
      return;
    }
    setLoading(true);
    setLoadingMessage('Processing server file path scan...');
    setErrorMessage(null);

    try {
      const report = await api.scanPath(filePath.trim());
      router.push({
        pathname: '/result',
        params: { data: JSON.stringify(report) },
      });
    } catch (err: any) {
      setErrorMessage(err.message || 'Path scan failed.');
    } finally {
      setLoading(false);
    }
  };

  // Submit Folder Scan
  const handleFolderScan = async () => {
    if (!productDir.trim()) {
      setErrorMessage('Please enter a server directory path.');
      return;
    }
    setLoading(true);
    setLoadingMessage('Scanning all SKU panels in directory...');
    setErrorMessage(null);

    try {
      const report = await api.scanProductPath({
        product_dir: productDir.trim(),
        product_name: dirProductName.trim() || undefined,
      });
      router.push({
        pathname: '/result',
        params: { data: JSON.stringify(report) },
      });
    } catch (err: any) {
      setErrorMessage(err.message || 'Product directory scan failed.');
    } finally {
      setLoading(false);
    }
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
        {/* Mode Switcher Tabs with Animated Sliding Pill */}
        <View
          style={styles.segmentContainer}
          onLayout={(e) => {
            const w = e.nativeEvent.layout.width - 8;
            if (w > 0) setSegmentWidth(w);
          }}
        >
          {/* Animated sliding indicator pill */}
          {segmentWidth > 0 && (
            <Animated.View
              style={[
                styles.animatedPillIndicator,
                {
                  width: segmentWidth / 3,
                  transform: [
                    {
                      translateX: slideAnim.interpolate({
                        inputRange: [0, 1, 2],
                        outputRange: [0, segmentWidth / 3, (segmentWidth / 3) * 2],
                      }),
                    },
                  ],
                },
              ]}
            />
          )}

          <TouchableOpacity
            style={styles.segmentBtn}
            onPress={() => switchMode('single')}
            activeOpacity={0.85}
          >
            <Text style={[styles.segmentText, mode === 'single' && styles.segmentTextActive]}>
              Single Panel
            </Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={styles.segmentBtn}
            onPress={() => switchMode('sku')}
            activeOpacity={0.85}
          >
            <Text style={[styles.segmentText, mode === 'sku' && styles.segmentTextActive]}>
              Full SKU (Multi)
            </Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={styles.segmentBtn}
            onPress={() => switchMode('path')}
            activeOpacity={0.85}
          >
            <Text style={[styles.segmentText, mode === 'path' && styles.segmentTextActive]}>
              Server Path
            </Text>
          </TouchableOpacity>
        </View>

        {/* Error Banner */}
        {errorMessage && (
          <View style={styles.errorBox}>
            <Ionicons name="alert-circle" size={18} color="#dc2626" />
            <Text style={styles.errorText}>{errorMessage}</Text>
          </View>
        )}

        {/* Loading Overlay State */}
        {loading && (
          <View style={styles.loadingBox}>
            <ActivityIndicator size="large" color="#059669" />
            <Text style={styles.loadingTitle}>Processing Compliance Audit</Text>
            <Text style={styles.loadingSub}>{loadingMessage}</Text>
          </View>
        )}

        {/* Animated Modes Container */}
        {!loading && (
          <Animated.View
            style={{
              opacity: contentFadeAnim,
              transform: [
                {
                  translateY: contentFadeAnim.interpolate({
                    inputRange: [0, 1],
                    outputRange: [8, 0],
                  }),
                },
              ],
            }}
          >
            {/* MODE 1: SINGLE PANEL SCAN */}
            {mode === 'single' && (
              <View style={styles.card}>
            <Text style={styles.cardHeader}>Scan Packaging Panel</Text>
            <Text style={styles.cardSub}>
              Upload a single product face to verify MRP, Net Qty, Dates, and Manufacturer declarations.
            </Text>

            {singleImage ? (
              <View style={styles.previewContainer}>
                <Image source={{ uri: singleImage }} style={styles.previewImage} resizeMode="contain" />
                <TouchableOpacity
                  style={styles.removeBtn}
                  onPress={() => setSingleImage(null)}
                >
                  <Ionicons name="close" size={16} color="#ffffff" />
                </TouchableOpacity>
              </View>
            ) : (
              <View style={styles.uploadDashedBox}>
                <Ionicons name="cloud-upload-outline" size={46} color="#10b981" />
                <Text style={styles.uploadPrompt}>Tap below to capture or select image</Text>
                <Text style={styles.supportedFormats}>Supports JPG, PNG, WEBP</Text>
              </View>
            )}

            {/* Action Buttons for Picking */}
            <View style={styles.pickButtonsRow}>
              <TouchableOpacity
                style={styles.pickerBtn}
                onPress={() => pickSingleImage(true)}
                activeOpacity={0.8}
              >
                <Ionicons name="camera-outline" size={18} color="#022c22" />
                <Text style={styles.pickerBtnText}>Take Photo</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.pickerBtn}
                onPress={() => pickSingleImage(false)}
                activeOpacity={0.8}
              >
                <Ionicons name="images-outline" size={18} color="#022c22" />
                <Text style={styles.pickerBtnText}>Choose Gallery</Text>
              </TouchableOpacity>
            </View>

            {/* Execute Button */}
            <TouchableOpacity
              style={[styles.primaryActionBtn, !singleImage && styles.btnDisabled]}
              disabled={!singleImage}
              onPress={handleSingleScan}
              activeOpacity={0.85}
            >
              <Ionicons name="scan-circle-outline" size={22} color="#ffffff" />
              <Text style={styles.primaryActionBtnText}>Run Legal Metrology Audit</Text>
            </TouchableOpacity>
          </View>
        )}

            {/* MODE 2: MULTI-PANEL SKU SCAN */}
            {mode === 'sku' && (
              <View style={styles.card}>
                <Text style={styles.cardHeader}>Multi-Panel Pooled SKU Audit</Text>
                <Text style={styles.cardSub}>
                  Pool declarations across Front, Back, Nutritional, and Barcode sides for a comprehensive pack evaluation.
                </Text>

                {/* Product Name Input */}
                <View style={styles.inputGroup}>
                  <Text style={styles.inputLabel}>Product SKU Name (Optional)</Text>
                  <TextInput
                    style={styles.textInput}
                    placeholder="e.g. Amul Butter 100g or Oreo Pack"
                    placeholderTextColor="#52796f"
                    value={productName}
                    onChangeText={setProductName}
                  />
                </View>

                {/* Panels Strip */}
                <Text style={styles.inputLabel}>Packaging Panels ({panelImages.length})</Text>
                <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.panelsStrip}>
                  {panelImages.map((panel, idx) => (
                    <View key={idx} style={styles.panelCard}>
                      <Image source={{ uri: panel.uri }} style={styles.panelThumb} />
                      <Text style={styles.panelLabel} numberOfLines={1}>
                        Panel {idx + 1}
                      </Text>
                      <TouchableOpacity
                        style={styles.panelRemoveBtn}
                        onPress={() => removePanel(idx)}
                      >
                        <Ionicons name="close" size={12} color="#ffffff" />
                      </TouchableOpacity>
                    </View>
                  ))}

                  {/* Add More Tile */}
                  <TouchableOpacity
                    style={styles.addPanelTile}
                    onPress={() => pickMultiPanelImage(false)}
                    activeOpacity={0.8}
                  >
                    <Ionicons name="add-circle-outline" size={28} color="#047857" />
                    <Text style={styles.addPanelText}>+ Add Panel</Text>
                  </TouchableOpacity>
                </ScrollView>

                {/* Capture Actions */}
                <View style={styles.pickButtonsRow}>
                  <TouchableOpacity
                    style={styles.pickerBtn}
                    onPress={() => pickMultiPanelImage(true)}
                    activeOpacity={0.8}
                  >
                    <Ionicons name="camera-outline" size={16} color="#022c22" />
                    <Text style={styles.pickerBtnText}>Snap Panel</Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={styles.pickerBtn}
                    onPress={() => pickMultiPanelImage(false)}
                    activeOpacity={0.8}
                  >
                    <Ionicons name="images-outline" size={16} color="#022c22" />
                    <Text style={styles.pickerBtnText}>Browse Gallery</Text>
                  </TouchableOpacity>
                </View>

                {/* Execute SKU Scan */}
                <TouchableOpacity
                  style={[styles.primaryActionBtn, panelImages.length === 0 && styles.btnDisabled]}
                  disabled={panelImages.length === 0}
                  onPress={handleSkuScan}
                  activeOpacity={0.85}
                >
                  <Ionicons name="checkmark-done-circle-outline" size={22} color="#ffffff" />
                  <Text style={styles.primaryActionBtnText}>Run Pooled SKU Scan</Text>
                </TouchableOpacity>
              </View>
            )}

            {/* MODE 3: ADVANCED SERVER PATH SCAN */}
            {mode === 'path' && (
              <View style={styles.card}>
                <Text style={styles.cardHeader}>Server Filesystem Audit</Text>
                <Text style={styles.cardSub}>
                  Directly scan files or SKU folders stored on the server filesystem.
                </Text>

                {/* Section A: Single Image Path */}
                <View style={styles.subCard}>
                  <Text style={styles.subCardTitle}>Option 1: Single File Path</Text>
                  <TextInput
                    style={styles.textInput}
                    placeholder="e:/New folder/PARAKH/dataset/.../panel_raw_1.jpg"
                    placeholderTextColor="#52796f"
                    value={filePath}
                    onChangeText={setFilePath}
                    autoCapitalize="none"
                  />
                  <TouchableOpacity
                    style={[styles.secondaryActionBtn, !filePath.trim() && styles.btnDisabled]}
                    disabled={!filePath.trim()}
                    onPress={handlePathScan}
                    activeOpacity={0.85}
                  >
                    <Text style={styles.secondaryActionBtnText}>Audit Server Image File</Text>
                  </TouchableOpacity>
                </View>

                {/* Section B: Folder Path */}
                <View style={[styles.subCard, { marginTop: 14 }]}>
                  <Text style={styles.subCardTitle}>Option 2: Entire SKU Folder</Text>
                  <TextInput
                    style={styles.textInput}
                    placeholder="e:/New folder/PARAKH/dataset/real_products/8901262010320_Amul_Butter"
                    placeholderTextColor="#52796f"
                    value={productDir}
                    onChangeText={setProductDir}
                    autoCapitalize="none"
                  />
                  <TextInput
                    style={[styles.textInput, { marginTop: 8 }]}
                    placeholder="Optional Product Title (e.g. Amul Butter)"
                    placeholderTextColor="#52796f"
                    value={dirProductName}
                    onChangeText={setDirProductName}
                  />
                  <TouchableOpacity
                    style={[styles.secondaryActionBtn, !productDir.trim() && styles.btnDisabled]}
                    disabled={!productDir.trim()}
                    onPress={handleFolderScan}
                    activeOpacity={0.85}
                  >
                    <Text style={styles.secondaryActionBtnText}>Audit Entire Product Folder</Text>
                  </TouchableOpacity>
                </View>
              </View>
            )}
          </Animated.View>
        )}
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

  // Segment Mode Switcher Tabs (Frosted Glass)
  segmentContainer: {
    flexDirection: 'row',
    backgroundColor: 'rgba(255, 255, 255, 0.62)',
    borderRadius: 24,
    padding: 4,
    marginBottom: 14,
    borderWidth: 1.5,
    borderColor: 'rgba(255, 255, 255, 0.95)',
    shadowColor: '#064e3b',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.08,
    shadowRadius: 18,
    elevation: 3,
    position: 'relative',
  },
  animatedPillIndicator: {
    position: 'absolute',
    top: 4,
    left: 4,
    bottom: 4,
    backgroundColor: 'rgba(19, 56, 32, 0.92)',
    borderRadius: 20,
    shadowColor: '#062a15',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.22,
    shadowRadius: 8,
    elevation: 4,
  },
  segmentBtn: {
    flex: 1,
    paddingVertical: 10,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 20,
    zIndex: 2,
  },
  segmentText: {
    fontSize: 12,
    fontWeight: '800',
    color: '#065f46',
  },
  segmentTextActive: {
    color: '#ffffff',
    fontWeight: '900',
  },

  // Error Banner
  errorBox: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: 'rgba(255, 241, 242, 0.88)',
    borderWidth: 1.2,
    borderColor: 'rgba(254, 202, 202, 0.8)',
    padding: 12,
    borderRadius: 16,
    marginBottom: 14,
  },
  errorText: {
    color: '#991b1b',
    fontSize: 12,
    fontWeight: '700',
    flex: 1,
  },

  // Loading Overlay
  loadingBox: {
    backgroundColor: 'rgba(240, 253, 244, 0.85)',
    borderRadius: 26,
    padding: 30,
    alignItems: 'center',
    marginVertical: 14,
    borderWidth: 1.5,
    borderColor: 'rgba(255, 255, 255, 0.95)',
    shadowColor: '#064e3b',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.08,
    shadowRadius: 20,
    elevation: 4,
  },
  loadingTitle: {
    fontSize: 16,
    fontWeight: '900',
    color: '#022c22',
    marginTop: 14,
  },
  loadingSub: {
    fontSize: 12,
    fontWeight: '700',
    color: '#065f46',
    marginTop: 6,
    textAlign: 'center',
    lineHeight: 17,
  },

  // Main Card (Ultra Soft Frosted Glass matching index.tsx)
  card: {
    backgroundColor: 'rgba(255, 255, 255, 0.58)',
    borderRadius: 26,
    padding: 18,
    borderWidth: 1.5,
    borderColor: 'rgba(255, 255, 255, 0.95)',
    shadowColor: '#064e3b',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.08,
    shadowRadius: 20,
    elevation: 4,
    marginBottom: 14,
  },
  cardHeader: {
    fontSize: 18,
    fontWeight: '900',
    color: '#022c22',
    letterSpacing: -0.2,
  },
  cardSub: {
    fontSize: 12,
    fontWeight: '600',
    color: '#0f5132',
    marginTop: 3,
    marginBottom: 16,
    lineHeight: 17,
  },

  // Upload Area
  uploadDashedBox: {
    borderWidth: 1.5,
    borderColor: 'rgba(74, 222, 128, 0.5)',
    borderStyle: 'dashed',
    borderRadius: 20,
    padding: 30,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(255, 255, 255, 0.45)',
    marginBottom: 14,
  },
  uploadPrompt: {
    fontSize: 13,
    fontWeight: '800',
    color: '#022c22',
    marginTop: 10,
  },
  supportedFormats: {
    fontSize: 11,
    fontWeight: '700',
    color: '#065f46',
    marginTop: 3,
  },

  // Preview Container
  previewContainer: {
    height: 220,
    borderRadius: 20,
    overflow: 'hidden',
    backgroundColor: 'rgba(6, 42, 21, 0.6)',
    marginBottom: 14,
    position: 'relative',
    borderWidth: 1.5,
    borderColor: 'rgba(255, 255, 255, 0.95)',
  },
  previewImage: {
    width: '100%',
    height: '100%',
  },
  removeBtn: {
    position: 'absolute',
    top: 10,
    right: 10,
    backgroundColor: 'rgba(220, 38, 38, 0.9)',
    width: 28,
    height: 28,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.2,
    shadowRadius: 4,
  },

  // Pick Action Buttons Row
  pickButtonsRow: {
    flexDirection: 'row',
    gap: 10,
    marginBottom: 16,
  },
  pickerBtn: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    backgroundColor: 'rgba(255, 255, 255, 0.65)',
    paddingVertical: 12,
    borderRadius: 16,
    borderWidth: 1.2,
    borderColor: 'rgba(255, 255, 255, 0.95)',
  },
  pickerBtnText: {
    fontSize: 13,
    fontWeight: '800',
    color: '#022c22',
  },

  // Primary Action Button (Glossy Emerald Glass Banner)
  primaryActionBtn: {
    backgroundColor: 'rgba(6, 42, 21, 0.92)',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    paddingVertical: 14,
    borderRadius: 22,
    borderWidth: 1.5,
    borderColor: 'rgba(74, 222, 128, 0.45)',
    shadowColor: '#062a15',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.25,
    shadowRadius: 16,
    elevation: 5,
  },
  primaryActionBtnText: {
    color: '#ffffff',
    fontSize: 14,
    fontWeight: '900',
    letterSpacing: 0.2,
  },
  btnDisabled: {
    opacity: 0.45,
  },

  // Input Groups
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

  // Panels Strip
  panelsStrip: {
    flexDirection: 'row',
    marginBottom: 14,
  },
  panelCard: {
    width: 90,
    marginRight: 10,
    position: 'relative',
    alignItems: 'center',
  },
  panelThumb: {
    width: 90,
    height: 90,
    borderRadius: 16,
    backgroundColor: 'rgba(255, 255, 255, 0.52)',
    borderWidth: 1.2,
    borderColor: 'rgba(255, 255, 255, 0.95)',
  },
  panelLabel: {
    fontSize: 11,
    fontWeight: '800',
    color: '#022c22',
    marginTop: 4,
  },
  panelRemoveBtn: {
    position: 'absolute',
    top: 4,
    right: 4,
    backgroundColor: 'rgba(220, 38, 38, 0.9)',
    width: 20,
    height: 20,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  addPanelTile: {
    width: 90,
    height: 90,
    borderRadius: 16,
    borderWidth: 1.5,
    borderColor: 'rgba(16, 185, 129, 0.5)',
    borderStyle: 'dashed',
    backgroundColor: 'rgba(236, 253, 245, 0.6)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  addPanelText: {
    fontSize: 11,
    fontWeight: '800',
    color: '#047857',
    marginTop: 4,
  },

  // Sub Cards (Server Path)
  subCard: {
    backgroundColor: 'rgba(255, 255, 255, 0.48)',
    borderWidth: 1.2,
    borderColor: 'rgba(255, 255, 255, 0.88)',
    padding: 14,
    borderRadius: 18,
  },
  subCardTitle: {
    fontSize: 13,
    fontWeight: '800',
    color: '#022c22',
    marginBottom: 8,
  },
  secondaryActionBtn: {
    backgroundColor: 'rgba(19, 56, 32, 0.88)',
    borderWidth: 1.2,
    borderColor: 'rgba(74, 222, 128, 0.35)',
    paddingVertical: 12,
    borderRadius: 14,
    alignItems: 'center',
    marginTop: 10,
  },
  secondaryActionBtnText: {
    color: '#ffffff',
    fontSize: 13,
    fontWeight: '800',
  },
});
