import React, { useEffect, useRef } from 'react';
import { Animated, View, Text, TouchableOpacity, StyleSheet, Easing } from 'react-native';
import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import type { BottomTabBarProps } from '@react-navigation/bottom-tabs';

interface TabItemProps {
  isFocused: boolean;
  onPress: () => void;
  onLongPress: () => void;
  iconName: keyof typeof Ionicons.glyphMap;
  label: string;
}

function TabItem({ isFocused, onPress, onLongPress, iconName, label }: TabItemProps) {
  const anim = useRef(new Animated.Value(isFocused ? 1 : 0)).current;

  useEffect(() => {
    Animated.timing(anim, {
      toValue: isFocused ? 1 : 0,
      duration: 340,
      easing: Easing.bezier(0.2, 0.9, 0.25, 1),
      useNativeDriver: false,
    }).start();
  }, [isFocused]);

  const textOpacity = anim.interpolate({
    inputRange: [0, 0.45, 1],
    outputRange: [0, 0.15, 1],
  });

  const textTranslateX = anim.interpolate({
    inputRange: [0, 1],
    outputRange: [-4, 0],
  });

  const textWidth = anim.interpolate({
    inputRange: [0, 1],
    outputRange: [0, 62],
  });

  const bgInterpolate = anim.interpolate({
    inputRange: [0, 1],
    outputRange: ['rgba(255, 255, 255, 0.08)', 'rgba(74, 222, 128, 0.25)'],
  });

  const paddingHorizontal = anim.interpolate({
    inputRange: [0, 1],
    outputRange: [9, 14],
  });

  return (
    <TouchableOpacity
      onPress={onPress}
      onLongPress={onLongPress}
      activeOpacity={0.7}
      style={styles.tabItemTouch}
    >
      <Animated.View
        style={[
          styles.tabItemPill,
          {
            backgroundColor: bgInterpolate,
            paddingHorizontal: paddingHorizontal,
          },
        ]}
      >
        <Ionicons
          name={iconName}
          size={20}
          color={isFocused ? '#4ade80' : '#a7f3d0'}
        />

        <Animated.View
          style={{
            maxWidth: textWidth,
            opacity: textOpacity,
            transform: [{ translateX: textTranslateX }],
            overflow: 'hidden',
          }}
        >
          <Text numberOfLines={1} style={styles.tabItemLabel}>
            {label}
          </Text>
        </Animated.View>
      </Animated.View>
    </TouchableOpacity>
  );
}

function CustomTabBar({ state, descriptors, navigation }: BottomTabBarProps) {
  const insets = useSafeAreaInsets();

  return (
    <View
      pointerEvents="box-none"
      style={[
        styles.tabBarWrapper,
        { paddingBottom: Math.max(insets.bottom, 12) },
      ]}
    >
      <View style={styles.floatingBar}>
        {state.routes.map((route, index) => {
          const isFocused = state.index === index;

          const onPress = () => {
            const event = navigation.emit({
              type: 'tabPress',
              target: route.key,
              canPreventDefault: true,
            });

            if (!isFocused && !event.defaultPrevented) {
              navigation.navigate(route.name, route.params);
            }
          };

          const onLongPress = () => {
            navigation.emit({
              type: 'tabLongPress',
              target: route.key,
            });
          };

          let iconName: keyof typeof Ionicons.glyphMap = 'cube-outline';
          let label = 'Tab';

          if (route.name === 'index') {
            label = 'Home';
            iconName = isFocused ? 'stats-chart' : 'stats-chart-outline';
          } else if (route.name === 'scan') {
            label = 'Scan';
            iconName = isFocused ? 'scan' : 'scan-outline';
          } else if (route.name === 'inspections') {
            label = 'Audits';
            iconName = isFocused ? 'folder-open' : 'folder-open-outline';
          } else if (route.name === 'settings') {
            label = 'Settings';
            iconName = isFocused ? 'settings' : 'settings-outline';
          }

          return (
            <TabItem
              key={route.key}
              isFocused={isFocused}
              onPress={onPress}
              onLongPress={onLongPress}
              iconName={iconName}
              label={label}
            />
          );
        })}
      </View>
    </View>
  );
}

export default function TabLayout() {
  return (
    <Tabs
      tabBar={(props) => <CustomTabBar {...props} />}
      screenOptions={{
        headerStyle: {
          backgroundColor: '#14532d',
          elevation: 0,
          shadowOpacity: 0,
          borderBottomWidth: 0,
        },
        headerTintColor: '#ffffff',
        headerTitleStyle: {
          fontWeight: '800',
          fontSize: 18,
          letterSpacing: -0.2,
        },
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'Dashboard',
          headerTitle: 'Themis Enforcement',
        }}
      />
      <Tabs.Screen
        name="scan"
        options={{
          title: 'Scan SKU',
          headerTitle: 'Statutory Compliance Scan',
        }}
      />
      <Tabs.Screen
        name="inspections"
        options={{
          title: 'Audits',
          headerTitle: 'Inspection Repository',
        }}
      />
      <Tabs.Screen
        name="settings"
        options={{
          title: 'Settings',
          headerTitle: 'Enforcement Settings',
        }}
      />
    </Tabs>
  );
}

const styles = StyleSheet.create({
  tabBarWrapper: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: 'transparent',
    paddingHorizontal: 16,
    alignItems: 'center',
  },
  floatingBar: {
    backgroundColor: '#133820',
    borderRadius: 28,
    height: 54,
    paddingHorizontal: 10,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    shadowColor: '#133820',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.16,
    shadowRadius: 8,
    elevation: 5,
  },
  tabItemTouch: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  tabItemPill: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    height: 40,
    borderRadius: 20,
  },
  tabItemLabel: {
    marginLeft: 5,
    fontSize: 12.5,
    fontWeight: '700',
    color: '#ffffff',
    letterSpacing: 0.2,
  },
});
