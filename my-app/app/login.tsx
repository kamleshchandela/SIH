import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useAuth } from '../src/context/AuthContext';

export default function LoginScreen() {
  const { login, baseUrl, updateBaseUrl } = useAuth();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const [showUrlConfig, setShowUrlConfig] = useState(false);
  const [tempUrl, setTempUrl] = useState(baseUrl);

  const handleLogin = async () => {
    if (!username.trim() || !password.trim()) {
      setErrorMessage('Please enter both username and password.');
      return;
    }

    setErrorMessage(null);
    setLoading(true);

    try {
      await login(username.trim(), password.trim());
    } catch (err: any) {
      setErrorMessage(err.message || 'Failed to authenticate. Check server connection.');
    } finally {
      setLoading(false);
    }
  };

  const setCredentials = (user: string, pass: string) => {
    setUsername(user);
    setPassword(pass);
    setErrorMessage(null);
  };

  const handleSaveUrl = async () => {
    if (tempUrl.trim()) {
      await updateBaseUrl(tempUrl.trim());
      setShowUrlConfig(false);
    }
  };

  React.useEffect(() => {
    setTempUrl(baseUrl);
  }, [baseUrl]);

  const setPresetUrl = async (url: string) => {
    setTempUrl(url);
    await updateBaseUrl(url);
    setShowUrlConfig(false);
  };

  return (
    <SafeAreaView style={styles.container}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={{ flex: 1 }}
      >
      <ScrollView contentContainerStyle={styles.scrollContent} keyboardShouldPersistTaps="handled">
        {/* Logo & Header */}
        <View style={styles.headerArea}>
          <View style={styles.iconCircle}>
            <Ionicons name="scale-outline" size={44} color="#38bdf8" />
          </View>
          <Text style={styles.brandTitle}>PARAKH</Text>
          <Text style={styles.brandSubtitle}>
            Automated Legal Metrology Compliance Engine
          </Text>
          <View style={styles.lawPill}>
            <Text style={styles.lawText}>LMPC Rules, 2011 • Jan Vishwas Act, 2023</Text>
          </View>
        </View>

        {/* Error Banner */}
        {errorMessage && (
          <View style={styles.errorBanner}>
            <Ionicons name="alert-circle" size={20} color="#dc2626" />
            <Text style={styles.errorText}>{errorMessage}</Text>
          </View>
        )}

        {/* Login Form Card */}
        <View style={styles.card}>
          <Text style={styles.cardTitle}>Sign In to Continue</Text>

          {/* Username Input */}
          <View style={styles.inputGroup}>
            <Text style={styles.inputLabel}>Badge ID / Username</Text>
            <View style={styles.inputWrapper}>
              <Ionicons name="person-outline" size={18} color="#64748b" style={styles.inputIcon} />
              <TextInput
                style={styles.textInput}
                placeholder="e.g. admin or inspector"
                placeholderTextColor="#94a3b8"
                value={username}
                onChangeText={setUsername}
                autoCapitalize="none"
                autoCorrect={false}
              />
            </View>
          </View>

          {/* Password Input */}
          <View style={styles.inputGroup}>
            <Text style={styles.inputLabel}>Security Password</Text>
            <View style={styles.inputWrapper}>
              <Ionicons name="lock-closed-outline" size={18} color="#64748b" style={styles.inputIcon} />
              <TextInput
                style={styles.textInput}
                placeholder="Enter password"
                placeholderTextColor="#94a3b8"
                value={password}
                onChangeText={setPassword}
                secureTextEntry={!showPassword}
                autoCapitalize="none"
              />
              <TouchableOpacity
                onPress={() => setShowPassword(!showPassword)}
                style={styles.eyeButton}
              >
                <Ionicons
                  name={showPassword ? 'eye-off-outline' : 'eye-outline'}
                  size={19}
                  color="#64748b"
                />
              </TouchableOpacity>
            </View>
          </View>

          {/* Login Button */}
          <TouchableOpacity
            style={[styles.primaryButton, loading && styles.buttonDisabled]}
            onPress={handleLogin}
            disabled={loading}
            activeOpacity={0.8}
          >
            {loading ? (
              <ActivityIndicator color="#ffffff" size="small" />
            ) : (
              <>
                <Text style={styles.primaryButtonText}>Authenticate & Proceed</Text>
                <Ionicons name="arrow-forward" size={18} color="#ffffff" style={{ marginLeft: 6 }} />
              </>
            )}
          </TouchableOpacity>

          {/* Quick Credential Chips */}
          <View style={styles.demoSection}>
            <Text style={styles.demoTitle}>Quick Select Statutory Role:</Text>
            <View style={styles.demoRow}>
              <TouchableOpacity
                style={styles.demoChip}
                onPress={() => setCredentials('admin', 'admin@themis2026')}
              >
                <Text style={styles.demoChipText}>👔 Admin (Director)</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.demoChip}
                onPress={() => setCredentials('inspector', 'inspector@themis2026')}
              >
                <Text style={styles.demoChipText}>🔍 Field Inspector</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>

        {/* Server Config Toggle */}
        <View style={styles.serverConfigArea}>
          <TouchableOpacity
            onPress={() => setShowUrlConfig(!showUrlConfig)}
            style={styles.serverConfigToggle}
          >
            <Ionicons name="settings-outline" size={15} color="#64748b" />
            <Text style={styles.serverConfigText}>
              Backend Server: <Text style={{ fontWeight: '700', color: '#38bdf8' }}>{baseUrl}</Text>
            </Text>
          </TouchableOpacity>

          {showUrlConfig && (
            <View style={{ width: '100%', marginTop: 10 }}>
              <View style={styles.urlConfigBox}>
                <TextInput
                  style={styles.urlInput}
                  value={tempUrl}
                  onChangeText={setTempUrl}
                  placeholder="http://192.168.1.64:8080"
                  autoCapitalize="none"
                />
                <TouchableOpacity style={styles.saveUrlBtn} onPress={handleSaveUrl}>
                  <Text style={styles.saveUrlBtnText}>Save</Text>
                </TouchableOpacity>
              </View>

              {/* Presets */}
              <View style={{ flexDirection: 'row', gap: 6, marginTop: 8, justifyContent: 'center' }}>
                <TouchableOpacity
                  style={{ backgroundColor: '#1e293b', paddingHorizontal: 10, paddingVertical: 5, borderRadius: 4 }}
                  onPress={() => setPresetUrl('http://192.168.1.64:8080')}
                >
                  <Text style={{ fontSize: 11, color: '#38bdf8', fontWeight: '600' }}>Use Wi-Fi IP (Phone)</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={{ backgroundColor: '#1e293b', paddingHorizontal: 10, paddingVertical: 5, borderRadius: 4 }}
                  onPress={() => setPresetUrl('http://localhost:8080')}
                >
                  <Text style={{ fontSize: 11, color: '#94a3b8', fontWeight: '600' }}>Use Localhost (Web)</Text>
                </TouchableOpacity>
              </View>
            </View>
          )}
        </View>
      </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#090d16',
  },
  scrollContent: {
    padding: 24,
    justifyContent: 'center',
    minHeight: '100%',
  },
  headerArea: {
    alignItems: 'center',
    marginBottom: 28,
  },
  iconCircle: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: 'rgba(56, 189, 248, 0.12)',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: 'rgba(56, 189, 248, 0.25)',
    marginBottom: 16,
  },
  brandTitle: {
    fontSize: 28,
    fontWeight: '800',
    letterSpacing: 3,
    color: '#ffffff',
  },
  brandSubtitle: {
    fontSize: 13,
    color: '#94a3b8',
    marginTop: 6,
    textAlign: 'center',
  },
  lawPill: {
    marginTop: 10,
    backgroundColor: 'rgba(255, 255, 255, 0.06)',
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: 12,
  },
  lawText: {
    fontSize: 11,
    color: '#38bdf8',
    fontWeight: '500',
  },
  errorBanner: {
    backgroundColor: '#fee2e2',
    borderColor: '#fca5a5',
    borderWidth: 1,
    borderRadius: 8,
    padding: 12,
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
    gap: 8,
  },
  errorText: {
    color: '#b91c1c',
    fontSize: 13,
    flex: 1,
  },
  card: {
    backgroundColor: '#ffffff',
    borderRadius: 16,
    padding: 24,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.15,
    shadowRadius: 12,
    elevation: 5,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: '#0f172a',
    marginBottom: 18,
  },
  inputGroup: {
    marginBottom: 16,
  },
  inputLabel: {
    fontSize: 12,
    fontWeight: '600',
    color: '#475569',
    marginBottom: 6,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  inputWrapper: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#f8fafc',
    borderWidth: 1,
    borderColor: '#cbd5e1',
    borderRadius: 8,
    paddingHorizontal: 12,
  },
  inputIcon: {
    marginRight: 8,
  },
  textInput: {
    flex: 1,
    height: 44,
    color: '#0f172a',
    fontSize: 14,
  },
  eyeButton: {
    padding: 6,
  },
  primaryButton: {
    backgroundColor: '#0284c7',
    height: 48,
    borderRadius: 8,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 8,
  },
  buttonDisabled: {
    opacity: 0.6,
  },
  primaryButtonText: {
    color: '#ffffff',
    fontSize: 15,
    fontWeight: '700',
  },
  demoSection: {
    marginTop: 20,
    borderTopWidth: 1,
    borderTopColor: '#f1f5f9',
    paddingTop: 16,
  },
  demoTitle: {
    fontSize: 12,
    color: '#64748b',
    marginBottom: 8,
    fontWeight: '500',
  },
  demoRow: {
    flexDirection: 'row',
    gap: 8,
  },
  demoChip: {
    flex: 1,
    backgroundColor: '#f1f5f9',
    paddingVertical: 8,
    borderRadius: 6,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#e2e8f0',
  },
  demoChipText: {
    fontSize: 12,
    fontWeight: '600',
    color: '#334155',
  },
  serverConfigArea: {
    marginTop: 20,
    alignItems: 'center',
  },
  serverConfigToggle: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    padding: 6,
  },
  serverConfigText: {
    fontSize: 12,
    color: '#94a3b8',
  },
  urlConfigBox: {
    flexDirection: 'row',
    marginTop: 10,
    width: '100%',
    gap: 8,
  },
  urlInput: {
    flex: 1,
    backgroundColor: '#ffffff',
    borderWidth: 1,
    borderColor: '#cbd5e1',
    borderRadius: 6,
    paddingHorizontal: 12,
    height: 38,
    fontSize: 13,
    color: '#0f172a',
  },
  saveUrlBtn: {
    backgroundColor: '#38bdf8',
    paddingHorizontal: 16,
    justifyContent: 'center',
    borderRadius: 6,
  },
  saveUrlBtnText: {
    color: '#0f172a',
    fontWeight: '700',
    fontSize: 13,
  },
});
