import React, { useState, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Image,
  ActivityIndicator,
  TouchableOpacity,
  Alert,
  Animated,
  PanResponder,
  Platform,
  StatusBar,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import * as Sharing from 'expo-sharing';
import * as FileSystem from 'expo-file-system/legacy';
import { useAuth } from '../src/context/AuthContext';

export default function EvidenceViewerScreen() {
  const insets = useSafeAreaInsets();
  const { id, panel } = useLocalSearchParams<{ id: string; panel: string }>();
  const { api, token } = useAuth();

  const [loading, setLoading] = useState(true);
  const [hasError, setHasError] = useState(false);
  const [sharing, setSharing] = useState(false);

  // Zoom and Pan tracking values
  const scale = useRef(new Animated.Value(1)).current;
  const translateX = useRef(new Animated.Value(0)).current;
  const translateY = useRef(new Animated.Value(0)).current;

  const currentScale = useRef(1);
  const currentTranslateX = useRef(0);
  const currentTranslateY = useRef(0);

  const [displayScale, setDisplayScale] = useState(1);
  const [layoutDim, setLayoutDim] = useState({ width: 360, height: 640 });

  // Touch gesture helper refs
  const initialDistance = useRef(0);
  const initialScale = useRef(1);
  const lastTap = useRef<number>(0);
  const lastPanX = useRef(0);
  const lastPanY = useRef(0);

  const evidenceUrl = api.getEvidenceUrl(id || '', panel || '');

  // Reset zoom and pan to default 1x
  const resetZoom = () => {
    currentScale.current = 1;
    currentTranslateX.current = 0;
    currentTranslateY.current = 0;
    setDisplayScale(1);

    Animated.parallel([
      Animated.spring(scale, {
        toValue: 1,
        useNativeDriver: true,
        tension: 45,
        friction: 7,
      }),
      Animated.spring(translateX, {
        toValue: 0,
        useNativeDriver: true,
        tension: 45,
        friction: 7,
      }),
      Animated.spring(translateY, {
        toValue: 0,
        useNativeDriver: true,
        tension: 45,
        friction: 7,
      }),
    ]).start();
  };

  // Zoom to specific target scale
  const zoomTo = (targetScale: number) => {
    const clamped = Math.max(1, Math.min(5, targetScale));
    currentScale.current = clamped;
    setDisplayScale(clamped);

    const targetX = clamped <= 1 ? 0 : currentTranslateX.current;
    const targetY = clamped <= 1 ? 0 : currentTranslateY.current;
    currentTranslateX.current = targetX;
    currentTranslateY.current = targetY;

    Animated.parallel([
      Animated.spring(scale, {
        toValue: clamped,
        useNativeDriver: true,
        tension: 45,
        friction: 7,
      }),
      Animated.spring(translateX, {
        toValue: targetX,
        useNativeDriver: true,
        tension: 45,
        friction: 7,
      }),
      Animated.spring(translateY, {
        toValue: targetY,
        useNativeDriver: true,
        tension: 45,
        friction: 7,
      }),
    ]).start();
  };

  const zoomInStep = () => {
    zoomTo(currentScale.current + 0.8);
  };

  const zoomOutStep = () => {
    if (currentScale.current <= 1.4) {
      resetZoom();
    } else {
      zoomTo(currentScale.current - 0.8);
    }
  };

  // Pinch-to-zoom & Pan gesture handler
  const panResponder = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponder: () => true,

      onPanResponderGrant: (evt) => {
        const touches = evt.nativeEvent.touches;
        if (touches.length === 2) {
          const dx = touches[0].pageX - touches[1].pageX;
          const dy = touches[0].pageY - touches[1].pageY;
          initialDistance.current = Math.hypot(dx, dy);
          initialScale.current = currentScale.current;
        } else if (touches.length === 1) {
          lastPanX.current = currentTranslateX.current;
          lastPanY.current = currentTranslateY.current;

          // Double tap to quick zoom in / out
          const now = Date.now();
          if (now - lastTap.current < 300) {
            if (currentScale.current > 1.2) {
              resetZoom();
            } else {
              zoomTo(2.6);
            }
            lastTap.current = 0;
            return;
          }
          lastTap.current = now;
        }
      },

      onPanResponderMove: (evt, gestureState) => {
        const touches = evt.nativeEvent.touches;
        if (touches.length >= 2) {
          // Pinch Zooming with 2 fingers
          const dx = touches[0].pageX - touches[1].pageX;
          const dy = touches[0].pageY - touches[1].pageY;
          const distance = Math.hypot(dx, dy);

          if (initialDistance.current > 0) {
            const factor = distance / initialDistance.current;
            let newScale = initialScale.current * factor;
            if (newScale < 0.85) newScale = 0.85;
            if (newScale > 5.5) newScale = 5.5;

            currentScale.current = newScale;
            scale.setValue(newScale);
            setDisplayScale(newScale);
          }
        } else if (touches.length === 1) {
          // 1 Finger Pan / Drag when zoomed in
          if (currentScale.current > 1.05) {
            const newX = lastPanX.current + gestureState.dx;
            const newY = lastPanY.current + gestureState.dy;

            const maxPanX = (layoutDim.width * (currentScale.current - 1)) / 2 + 60;
            const maxPanY = (layoutDim.height * (currentScale.current - 1)) / 2 + 60;

            const clampedX = Math.max(-maxPanX, Math.min(maxPanX, newX));
            const clampedY = Math.max(-maxPanY, Math.min(maxPanY, newY));

            currentTranslateX.current = clampedX;
            currentTranslateY.current = clampedY;
            translateX.setValue(clampedX);
            translateY.setValue(clampedY);
          }
        }
      },

      onPanResponderRelease: () => {
        if (currentScale.current < 1) {
          resetZoom();
        } else {
          // Smooth bounce-back within boundaries
          const maxPanX = (layoutDim.width * (currentScale.current - 1)) / 2;
          const maxPanY = (layoutDim.height * (currentScale.current - 1)) / 2;

          const clampedX = Math.max(-maxPanX, Math.min(maxPanX, currentTranslateX.current));
          const clampedY = Math.max(-maxPanY, Math.min(maxPanY, currentTranslateY.current));

          if (clampedX !== currentTranslateX.current || clampedY !== currentTranslateY.current) {
            currentTranslateX.current = clampedX;
            currentTranslateY.current = clampedY;
            Animated.parallel([
              Animated.spring(translateX, { toValue: clampedX, useNativeDriver: true }),
              Animated.spring(translateY, { toValue: clampedY, useNativeDriver: true }),
            ]).start();
          }
        }
      },
    })
  ).current;

  const handleShare = async () => {
    try {
      setSharing(true);
      const filename = `evidence_${panel ? panel.replace(/[^a-zA-Z0-9_-]/g, '_') : 'photo'}.jpg`;
      const localUri = `${FileSystem.cacheDirectory}${filename}`;

      const downloadRes = await FileSystem.downloadAsync(evidenceUrl, localUri, {
        headers: token ? { Authorization: `Bearer ${token}` } : {},
      });

      if (await Sharing.isAvailableAsync()) {
        await Sharing.shareAsync(downloadRes.uri, {
          mimeType: 'image/jpeg',
          dialogTitle: `Share Evidence: ${panel || 'Packaging Photo'}`,
        });
      } else {
        Alert.alert('Sharing Unavailable', 'Native sharing is not supported on this device.');
      }
    } catch (err: any) {
      Alert.alert('Share Error', err.message || 'Failed to download or share evidence photograph.');
    } finally {
      setSharing(false);
    }
  };

  const handleRetry = () => {
    setLoading(true);
    setHasError(false);
  };

  return (
    <View style={styles.container}>
      <Stack.Screen options={{ headerShown: false }} />
      <StatusBar barStyle="light-content" backgroundColor="#040d0a" translucent />

      {/* Floating Translucent Top Header */}
      <View
        style={[
          styles.topHeader,
          {
            paddingTop: Math.max(insets.top, 16) + 4,
          },
        ]}
      >
        <TouchableOpacity
          style={styles.headerBtn}
          onPress={() => router.back()}
          activeOpacity={0.7}
          hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}
        >
          <Ionicons name="arrow-back" size={22} color="#ffffff" />
        </TouchableOpacity>

        <View style={styles.headerInfo}>
          <Text style={styles.headerTitle} numberOfLines={1}>
            {panel || 'Packaging Evidence'}
          </Text>
          {id ? (
            <Text style={styles.headerSubtitle} numberOfLines={1}>
              Audit ID: {id}
            </Text>
          ) : null}
        </View>

        {/* Share Button */}
        <TouchableOpacity
          style={[styles.headerBtn, styles.shareBtn, sharing && { opacity: 0.6 }]}
          onPress={handleShare}
          disabled={sharing}
          activeOpacity={0.7}
          hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}
        >
          {sharing ? (
            <ActivityIndicator size="small" color="#ffffff" />
          ) : (
            <Ionicons name="share-social-outline" size={20} color="#ffffff" />
          )}
        </TouchableOpacity>
      </View>

      {/* Full Page Zoomable Image Canvas */}
      <View
        style={styles.fullScreenCanvas}
        onLayout={(e) => {
          const { width, height } = e.nativeEvent.layout;
          setLayoutDim({ width, height });
        }}
        {...panResponder.panHandlers}
      >
        {loading && (
          <View style={styles.loadingOverlay} pointerEvents="none">
            <ActivityIndicator size="large" color="#10b981" />
            <Text style={styles.loadingText}>Loading High-Res Evidence...</Text>
          </View>
        )}

        {hasError ? (
          <View style={styles.errorContainer}>
            <View style={styles.errorIconCircle}>
              <Ionicons name="image-outline" size={44} color="#f87171" />
            </View>
            <Text style={styles.errorTitle}>Evidence Asset Unavailable</Text>
            <Text style={styles.errorSub}>
              Unable to load the packaging photo from the audit server.
            </Text>
            <TouchableOpacity style={styles.retryBtn} onPress={handleRetry} activeOpacity={0.8}>
              <Ionicons name="reload-outline" size={16} color="#022c22" />
              <Text style={styles.retryBtnText}>Retry</Text>
            </TouchableOpacity>
          </View>
        ) : (
          <Animated.View
            style={[
              styles.imageTransformWrapper,
              {
                transform: [
                  { translateX },
                  { translateY },
                  { scale },
                ],
              },
            ]}
          >
            <Image
              source={{
                uri: evidenceUrl,
                headers: token ? { Authorization: `Bearer ${token}` } : undefined,
              }}
              style={styles.fullPageImage}
              resizeMode="contain"
              onLoadEnd={() => setLoading(false)}
              onError={() => {
                setLoading(false);
                setHasError(true);
              }}
            />
          </Animated.View>
        )}
      </View>

      {/* Floating Finger Zoom Assist Controls (Zoom In, Zoom Out, Scale Reset) */}
      <View style={[styles.floatingControls, { bottom: Math.max(insets.bottom, 20) + 10 }]}>
        {displayScale > 1.1 && (
          <TouchableOpacity
            style={styles.scaleResetBadge}
            onPress={resetZoom}
            activeOpacity={0.8}
          >
            <Ionicons name="refresh-outline" size={14} color="#a7f3d0" />
            <Text style={styles.scaleResetText}>{displayScale.toFixed(1)}x Reset</Text>
          </TouchableOpacity>
        )}

        <View style={styles.zoomButtonsColumn}>
          <TouchableOpacity
            style={styles.zoomBtn}
            onPress={zoomInStep}
            activeOpacity={0.7}
          >
            <Ionicons name="add" size={22} color="#ffffff" />
          </TouchableOpacity>

          <View style={styles.zoomBtnDivider} />

          <TouchableOpacity
            style={styles.zoomBtn}
            onPress={zoomOutStep}
            activeOpacity={0.7}
          >
            <Ionicons name="remove" size={22} color="#ffffff" />
          </TouchableOpacity>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#040d0a',
  },

  // Floating Top Header
  topHeader: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    zIndex: 50,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingBottom: 12,
    backgroundColor: 'rgba(4, 13, 10, 0.75)',
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: 'rgba(255, 255, 255, 0.12)',
  },
  headerBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(255, 255, 255, 0.14)',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.2)',
  },
  shareBtn: {
    backgroundColor: 'rgba(16, 185, 129, 0.3)',
    borderColor: 'rgba(52, 211, 153, 0.4)',
  },
  headerInfo: {
    flex: 1,
    marginHorizontal: 12,
    alignItems: 'center',
  },
  headerTitle: {
    fontSize: 16,
    fontWeight: '800',
    color: '#ffffff',
    textAlign: 'center',
  },
  headerSubtitle: {
    fontSize: 11,
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    color: '#34d399',
    marginTop: 2,
    fontWeight: '600',
  },

  // Full Screen Image Canvas
  fullScreenCanvas: {
    flex: 1,
    width: '100%',
    height: '100%',
    justifyContent: 'center',
    alignItems: 'center',
    overflow: 'hidden',
    backgroundColor: '#040d0a',
  },
  imageTransformWrapper: {
    width: '100%',
    height: '100%',
    justifyContent: 'center',
    alignItems: 'center',
  },
  fullPageImage: {
    width: '100%',
    height: '100%',
  },

  // Loading Overlay
  loadingOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: '#040d0a',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 10,
    gap: 12,
  },
  loadingText: {
    fontSize: 13,
    color: '#d1fae5',
    fontWeight: '600',
  },

  // Error Container
  errorContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 32,
    gap: 10,
  },
  errorIconCircle: {
    width: 68,
    height: 68,
    borderRadius: 34,
    backgroundColor: 'rgba(239, 68, 68, 0.15)',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: 'rgba(239, 68, 68, 0.3)',
    marginBottom: 4,
  },
  errorTitle: {
    fontSize: 16,
    fontWeight: '800',
    color: '#fee2e2',
    textAlign: 'center',
  },
  errorSub: {
    fontSize: 12,
    color: '#94a3b8',
    textAlign: 'center',
    lineHeight: 18,
  },
  retryBtn: {
    marginTop: 8,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: '#10b981',
    paddingHorizontal: 18,
    paddingVertical: 10,
    borderRadius: 14,
  },
  retryBtnText: {
    fontSize: 13,
    fontWeight: '800',
    color: '#022c22',
  },

  // Floating Zoom Controls (Bottom Right)
  floatingControls: {
    position: 'absolute',
    right: 18,
    alignItems: 'flex-end',
    gap: 10,
    zIndex: 60,
  },
  scaleResetBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    backgroundColor: 'rgba(6, 42, 21, 0.88)',
    paddingHorizontal: 12,
    paddingVertical: 7,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: 'rgba(52, 211, 153, 0.4)',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
    elevation: 3,
  },
  scaleResetText: {
    fontSize: 11,
    fontWeight: '800',
    color: '#a7f3d0',
  },
  zoomButtonsColumn: {
    backgroundColor: 'rgba(20, 30, 25, 0.82)',
    borderRadius: 20,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.18)',
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.4,
    shadowRadius: 6,
    elevation: 4,
  },
  zoomBtn: {
    width: 44,
    height: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  zoomBtnDivider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: 'rgba(255, 255, 255, 0.15)',
    marginHorizontal: 8,
  },
});
