import React, { createContext, useContext, useEffect, useState, useMemo } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { router } from 'expo-router';
import { AuthRole, LoginResponse } from '../types/themis';
import { ApiClient } from '../services/api';

import { Platform } from 'react-native';
import Constants from 'expo-constants';

export function getAutoDetectedBaseUrl(): string {
  // Check hostUri from Expo Constants (the host that served the JS bundle to mobile)
  const hostUri =
    Constants.expoConfig?.hostUri ||
    (Constants as any).manifest?.debuggerHost ||
    (Constants as any).manifest2?.extra?.expoClient?.hostUri;

  if (hostUri) {
    const hostIp = hostUri.split(':')[0];
    if (hostIp && hostIp !== 'localhost' && hostIp !== '127.0.0.1') {
      return `http://${hostIp}:8080`;
    }
  }

  return process.env.EXPO_PUBLIC_API_BASE_URL || 'http://192.168.1.64:8080';
}

const STORAGE_KEYS = {
  TOKEN: 'themis_token',
  USER: 'themis_user',
  ROLE: 'themis_role',
  BASE_URL: 'themis_base_url',
  EXPIRY: 'themis_token_expiry',
};

interface AuthContextType {
  token: string | null;
  username: string | null;
  role: AuthRole | null;
  baseUrl: string;
  isLoading: boolean;
  api: ApiClient;
  login: (username: string, password: string) => Promise<LoginResponse>;
  logout: () => Promise<void>;
  updateBaseUrl: (newUrl: string) => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const dynamicUrl = useMemo(() => getAutoDetectedBaseUrl(), []);
  const [token, setToken] = useState<string | null>(null);
  const [username, setUsername] = useState<string | null>(null);
  const [role, setRole] = useState<AuthRole | null>(null);
  const [baseUrl, setBaseUrlState] = useState<string>(dynamicUrl);
  const [isLoading, setIsLoading] = useState<boolean>(true);

  // Initialize API client instance
  const api = useMemo(() => {
    return new ApiClient(baseUrl, token, () => {
      // Auto logout on 401
      logout();
    });
  }, [baseUrl, token]);

  // Load stored credentials on launch
  useEffect(() => {
    async function loadAuth() {
      try {
        const [savedToken, savedUser, savedRole, savedUrl, savedExpiry] =
          await Promise.all([
            AsyncStorage.getItem(STORAGE_KEYS.TOKEN),
            AsyncStorage.getItem(STORAGE_KEYS.USER),
            AsyncStorage.getItem(STORAGE_KEYS.ROLE),
            AsyncStorage.getItem(STORAGE_KEYS.BASE_URL),
            AsyncStorage.getItem(STORAGE_KEYS.EXPIRY),
          ]);

        const detectedHost = dynamicUrl.replace(/^https?:\/\//, '').split(':')[0];
        if (savedUrl) {
          const savedHost = savedUrl.replace(/^https?:\/\//, '').split(':')[0];
          // If savedHost is stale or localhost, auto sync with active detectedHost
          if (
            Platform.OS !== 'web' &&
            (savedHost === 'localhost' ||
              savedHost === '127.0.0.1' ||
              (detectedHost && savedHost !== detectedHost))
          ) {
            setBaseUrlState(dynamicUrl);
            await AsyncStorage.setItem(STORAGE_KEYS.BASE_URL, dynamicUrl);
          } else {
            setBaseUrlState(savedUrl);
          }
        } else {
          setBaseUrlState(dynamicUrl);
        }

        if (savedToken && savedExpiry) {
          const now = Date.now();
          if (now < Number(savedExpiry)) {
            setToken(savedToken);
            setUsername(savedUser);
            setRole(savedRole as AuthRole);
          } else {
            // Expired
            await AsyncStorage.multiRemove([
              STORAGE_KEYS.TOKEN,
              STORAGE_KEYS.USER,
              STORAGE_KEYS.ROLE,
              STORAGE_KEYS.EXPIRY,
            ]);
          }
        }
      } catch (err) {
        console.warn('Failed to load auth state from storage:', err);
      } finally {
        setIsLoading(false);
      }
    }
    loadAuth();
  }, []);

  const login = async (user: string, pass: string): Promise<LoginResponse> => {
    const res = await api.login({ username: user, password: pass });
    const expiryTimestamp = Date.now() + res.expires_in_secs * 1000;

    await AsyncStorage.multiSet([
      [STORAGE_KEYS.TOKEN, res.token],
      [STORAGE_KEYS.USER, res.username],
      [STORAGE_KEYS.ROLE, res.role],
      [STORAGE_KEYS.EXPIRY, expiryTimestamp.toString()],
    ]);

    setToken(res.token);
    setUsername(res.username);
    setRole(res.role);
    api.setToken(res.token);

    router.replace('/(tabs)');
    return res;
  };

  const logout = async () => {
    await AsyncStorage.multiRemove([
      STORAGE_KEYS.TOKEN,
      STORAGE_KEYS.USER,
      STORAGE_KEYS.ROLE,
      STORAGE_KEYS.EXPIRY,
    ]);
    setToken(null);
    setUsername(null);
    setRole(null);
    api.setToken(null);
    router.replace('/login');
  };

  const updateBaseUrl = async (newUrl: string) => {
    const cleanUrl = newUrl.trim().replace(/\/+$/, '');
    await AsyncStorage.setItem(STORAGE_KEYS.BASE_URL, cleanUrl);
    setBaseUrlState(cleanUrl);
    api.setBaseUrl(cleanUrl);
  };

  return (
    <AuthContext.Provider
      value={{
        token,
        username,
        role,
        baseUrl,
        isLoading,
        api,
        login,
        logout,
        updateBaseUrl,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = (): AuthContextType => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
