import React from 'react';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { AuthProvider } from '../src/context/AuthContext';

export const unstable_settings = {
  anchor: '(tabs)',
};

export default function RootLayout() {
  return (
    <SafeAreaProvider>
      <AuthProvider>
        <Stack
          screenOptions={{
            headerStyle: { backgroundColor: '#14532d' },
            headerTintColor: '#ffffff',
            headerTitleStyle: { fontWeight: '700', fontSize: 17 },
            headerBackTitle: 'Back',
            contentStyle: { backgroundColor: '#f4f8f5' },
          }}
        >
          <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
          <Stack.Screen
            name="login"
            options={{
              headerShown: false,
              presentation: 'card',
            }}
          />
          <Stack.Screen
            name="result"
            options={{
              title: 'Inspection Report',
              headerShown: true,
            }}
          />
          <Stack.Screen
            name="evidence"
            options={{
              title: 'Evidence Asset',
              headerShown: false,
            }}
          />
          <Stack.Screen
            name="csv-viewer"
            options={{
              title: 'Statutory CSV Audit',
              headerShown: false,
            }}
          />
          <Stack.Screen
            name="pdf-viewer"
            options={{
              title: 'Statutory Notice PDF',
              headerShown: false,
            }}
          />
        </Stack>
        <StatusBar style="light" />
      </AuthProvider>
    </SafeAreaProvider>
  );
}
