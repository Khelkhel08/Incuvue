import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'models/incubator_model.dart';
import 'screens/contact_admin_screen.dart';
import 'screens/start_incubation_screen.dart';
import 'services/auth_service.dart';
import 'services/batch_service.dart';
import 'services/incubator_service.dart';
import 'widgets/app_header.dart';
import 'widgets/app_logo.dart';

const _primaryText = Color(0xFF1F2D3D);
const _brandTeal = Color(0xFF1F6F7C);
const _brandLime = Color(0xFF9CCC3C);
const _brandGreen = Color(0xFF118339);
const _alertRed = Color(0xFFF05C53);
const _panelBlue = Color(0xFFD7E4EE);
const _waterGreen = Color(0xFF7CB342);
const _controlPagePadding = 14.0;
const _controlSectionSpacing = 18.0;

final _incubatorService = IncubatorService();
final _batchService = BatchService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const IncuVueApp());
}

class IncuVueApp extends StatelessWidget {
  const IncuVueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IncuVue',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _brandTeal),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      builder: (context, child) {
        final width = MediaQuery.sizeOf(context).width;
        if (width < 520) return child ?? const SizedBox.shrink();
        return ColoredBox(
          color: const Color(0xFFE8EEF3),
          child: Center(
            child: SizedBox(
              width: 390,
              child: child,
            ),
          ),
        );
      },
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == null) {
          return const LoginScreen();
        }
        return const HomeGate();
      },
    );
  }
}

class HomeGate extends StatelessWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<IncubatorData>(
      stream: _incubatorService.watchIncubator(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: Text('Unable to load incubator data')),
          );
        }
        final data = snapshot.data!;
        if (!data.isActive) {
          return const NoActiveIncubationScreen();
        }
        return const DashboardScreen();
      },
    );
  }
}

class NoActiveIncubationScreen extends StatelessWidget {
  const NoActiveIncubationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'IncuVue',
        showSettings: true,
        showLogoLeading: true,
        onSettings: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        },
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogo(size: 88),
              const SizedBox(height: 24),
              const Text(
                'No active incubation',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _primaryText,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Start a batch to open the dashboard and climate controls.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF5B6773)),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StartIncubationScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('START INCUBATION'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<String> _buildAlerts(IncubatorData data) {
  final alerts = <String>[];
  if (data.temperature < 36.5) {
    alerts.add(
      'Temperature too low (${data.temperature.toStringAsFixed(1)} °C)',
    );
  } else if (data.temperature > 38.5) {
    alerts.add(
      'Temperature too high (${data.temperature.toStringAsFixed(1)} °C)',
    );
  }
  if (data.humidity < 40) {
    alerts.add('Humidity too low (${data.humidity.toStringAsFixed(0)} %)');
  } else if (data.humidity > 70) {
    alerts.add('Humidity too high (${data.humidity.toStringAsFixed(0)} %)');
  }
  if (data.waterLevel < 5) {
    alerts.add('Water tray is empty');
  }
  return alerts;
}

String _tempStatus(double temperature) {
  if (temperature < 36.5) return 'Low';
  if (temperature > 38.5) return 'High';
  return 'Normal';
}

Color _tempStatusColor(double temperature) {
  if (temperature < 37.0) return const Color(0xFF64B5F6);
  if (temperature > 38.5) return const Color(0xFFF05C53);
  return const Color(0xFFE3FFAF);
}

String _humidityStatus(double humidity) {
  if (humidity < 40) return 'Low';
  if (humidity > 70) return 'High';
  return 'Normal';
}

String _actuatorLine(
  String name, {
  required bool allowed,
  required bool running,
}) {
  if (!allowed) return '$name: OFF';
  if (running) return '$name: RUNNING';
  return '$name: STANDBY';
}

Color _humidityStatusColor(double humidity) {
  if (humidity < 40) return const Color(0xFF64B5F6);
  if (humidity > 70) return const Color(0xFFF05C53);
  return const Color(0xFFE3FFAF);
}

String _authErrorMessage(FirebaseAuthException error) {
  switch (error.code) {
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Email or password is incorrect.';
    case 'too-many-requests':
      return 'Too many attempts. Try again later.';
    default:
      return 'Unable to sign in. Please try again.';
  }
}

Future<void> showCancelIncubationDialog(
  BuildContext context,
  IncubatorData data,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Cancel incubation?'),
      content: const Text(
        'This stops the current batch. Relays will turn off.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Keep running'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Cancel incubation'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await _batchService.cancelIncubation(data);
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService().signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (error) {
      setState(() => _error = _authErrorMessage(error));
    } catch (_) {
      setState(() => _error = 'Unable to sign in. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const AppLogo(size: 96),
              const SizedBox(height: 16),
              const Text(
                'IncuVue',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _primaryText,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: _alertRed)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('LOG IN'),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ContactAdminScreen(),
                    ),
                  );
                },
                child: const Text('Contact admin'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'Dashboard',
        showSettings: true,
        showLogoLeading: true,
        onSettings: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        },
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<IncubatorData>(
          stream: _incubatorService.watchIncubator(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text('Unable to load data.'));
            }

            final data = snapshot.data!;
            final alerts = _buildAlerts(data);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF2F7),
                      border: Border.all(
                        color: const Color(0xFFCDD8E3),
                        width: 0.8,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Color(0xFFCDD8E3),
                                width: 0.8,
                              ),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'System Alerts',
                              style: TextStyle(
                                color: _primaryText,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        if (alerts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Text(
                              'All systems normal',
                              style: TextStyle(
                                color: _brandGreen,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        else
                          ...alerts.map(
                            (alert) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Text(
                                alert,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _alertRed,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          title: 'Temperature',
                          value: data.temperature.toStringAsFixed(1),
                          unit: '°',
                          statusLabel: 'Status',
                          statusValue: _tempStatus(data.temperature),
                          statusColor: _tempStatusColor(data.temperature),
                          background: _brandTeal,
                          recommendedText: 'Recommended: 37.5°',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: MetricCard(
                          title: 'Humidity',
                          value: data.humidity.toStringAsFixed(0),
                          unit: '%',
                          statusLabel: 'Status',
                          statusValue: _humidityStatus(data.humidity),
                          statusColor: _humidityStatusColor(data.humidity),
                          background: _brandLime,
                          recommendedText: 'Recommended: 55%',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  WaterLevelBanner(
                    levelText:
                        'WATER TRAY LEVEL: ${data.waterLevel.toStringAsFixed(0)} %',
                  ),
                  const SizedBox(height: 10),
                  BatchSummaryTile(
                    label: data.displayBatchName.isEmpty
                        ? 'EGG TRAY'
                        : 'EGG TRAY • ${data.displayBatchName}',
                    color: _brandTeal,
                    onView: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EggTrayScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'System Status',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _WifiStatusCard(online: data.deviceOnline),
                  const SizedBox(height: 8),
                  _ControlModeCard(
                    isManual: data.isManualMode,
                    onChanged: (manual) => _incubatorService.setControlMode(
                      manual ? 'manual' : 'auto',
                    ),
                    onOpenControls: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ControlsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () =>
                          showCancelIncubationDialog(context, data),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _alertRed,
                        side: const BorderSide(color: _alertRed),
                      ),
                      child: const Text('Cancel Incubation'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showInfo(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'No email';

    return Scaffold(
      appBar: const AppHeader(
        title: 'SETTINGS',
        showBack: true,
        showLogoTrailing: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            const Center(child: AppLogo(size: 72)),
            const SizedBox(height: 10),
            Center(
              child: Text(
                userEmail,
                style: const TextStyle(color: _primaryText),
              ),
            ),
            const SizedBox(height: 16),
            _SettingsItem(
              icon: Icons.info_outline,
              label: 'About IncuVue',
              onTap: () => _showInfo(
                context,
                'About',
                'IncuVue incubator dashboard. Climate is controlled by the ESP32.',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await AuthService().signOut();
                if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
              },
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text(
                'LOG OUT',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(backgroundColor: _brandGreen),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: _primaryText),
      title: Text(
        label,
        style: const TextStyle(color: _primaryText, fontSize: 15),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF63717F)),
      onTap: onTap,
    );
  }
}

class ControlsScreen extends StatelessWidget {
  const ControlsScreen({super.key});

  Future<bool> _confirmRangeWarning(
    BuildContext context,
    String message,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Warning'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _adjustTargetTemperature(
    BuildContext context, {
    required double current,
    required double delta,
  }) async {
    const minSafe = 36.0;
    const maxSafe = 40.0;
    final next = (current + delta).clamp(30.0, 45.0);
    if (next == current) return;

    String? warning;
    if (current <= maxSafe && next > maxSafe) {
      warning =
          'Temperatures above 40 °C can cause overheating and may harm the eggs.\n\n'
          'Are you sure you want to continue?';
    } else if (current >= minSafe && next < minSafe) {
      warning =
          'Temperatures below 36 °C are too low for incubation and may harm the eggs.\n\n'
          'Are you sure you want to continue?';
    }

    if (warning != null && !await _confirmRangeWarning(context, warning)) {
      return;
    }

    await _incubatorService.updateField('targetTemperature', next);
  }

  Future<void> _adjustTargetHumidity(
    BuildContext context, {
    required double current,
    required double delta,
  }) async {
    const minSafe = 40.0;
    final next = (current + delta).clamp(20.0, 90.0);
    if (next == current) return;

    if (current >= minSafe && next < minSafe) {
      final confirmed = await _confirmRangeWarning(
        context,
        'Humidity below 40% is too dry for incubation and may harm the eggs.\n\n'
        'Are you sure you want to continue?',
      );
      if (!confirmed) return;
    }

    await _incubatorService.updateField('targetHumidity', next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'CONTROLS',
        showBack: true,
        showLogoTrailing: true,
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<IncubatorData>(
          stream: _incubatorService.watchIncubator(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text('Unable to load data.'));
            }

            final data = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                _controlPagePadding,
                12,
                _controlPagePadding,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ControlsMetricCard(
                    title: 'Temperature',
                    value: data.temperature.toStringAsFixed(1),
                    unit: '°',
                    statusValue:
                        '${_tempStatus(data.temperature)} · set ${data.targetTemperature.toStringAsFixed(1)}°',
                    statusColor: _tempStatusColor(data.temperature),
                    background: _brandTeal,
                    onIncrement: () => _adjustTargetTemperature(
                      context,
                      current: data.targetTemperature,
                      delta: 0.5,
                    ),
                    onDecrement: () => _adjustTargetTemperature(
                      context,
                      current: data.targetTemperature,
                      delta: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ControlsMetricCard(
                    title: 'Humidity',
                    value: data.humidity.toStringAsFixed(0),
                    unit: '%',
                    statusValue:
                        '${_humidityStatus(data.humidity)} · set ${data.targetHumidity.toStringAsFixed(0)}%',
                    statusColor: _humidityStatusColor(data.humidity),
                    background: _brandLime,
                    onIncrement: () => _adjustTargetHumidity(
                      context,
                      current: data.targetHumidity,
                      delta: 1,
                    ),
                    onDecrement: () => _adjustTargetHumidity(
                      context,
                      current: data.targetHumidity,
                      delta: -1,
                    ),
                  ),
                  const SizedBox(height: _controlSectionSpacing),
                  Text(
                    data.isManualMode
                        ? 'COMPONENT CONTROLS'
                        : 'COMPONENT CONTROLS (AUTO — LOCKED)',
                    style: const TextStyle(
                      color: _primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!data.isManualMode) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Switch to Manual on the dashboard to change these. Auto restores heater, fans, and egg tilting to on.',
                      style: TextStyle(color: _primaryText, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ComponentControlRow(
                    label: _actuatorLine(
                      'HEATER',
                      allowed: data.heaterEnabled,
                      running: data.heater,
                    ),
                    isOn: data.heaterEnabled,
                    enabled: data.isManualMode,
                    onToggle: (value) =>
                        _incubatorService.updateField('heaterEnabled', value),
                  ),
                  const SizedBox(height: 10),
                  ComponentControlRow(
                    label: _actuatorLine(
                      'CIRCULATION FAN',
                      allowed: data.fanCircEnabled,
                      running: data.fanCirc,
                    ),
                    isOn: data.fanCircEnabled,
                    enabled: data.isManualMode,
                    onToggle: (value) =>
                        _incubatorService.updateField('fanCircEnabled', value),
                  ),
                  const SizedBox(height: 10),
                  ComponentControlRow(
                    label: _actuatorLine(
                      'VENTILATION FAN',
                      allowed: data.fanVentEnabled,
                      running: data.fanVent,
                    ),
                    isOn: data.fanVentEnabled,
                    enabled: data.isManualMode,
                    onToggle: (value) =>
                        _incubatorService.updateField('fanVentEnabled', value),
                  ),
                  const SizedBox(height: 10),
                  ComponentControlRow(
                    label: data.eggTurner
                        ? 'EGG TILTING: ALLOWED (${data.turningIntervalLabel})'
                        : 'EGG TILTING: OFF',
                    isOn: data.eggTurner,
                    enabled: data.isManualMode,
                    onToggle: (value) => _incubatorService.updateFields({
                      'eggTurner': value,
                      'turningActive': value,
                    }),
                  ),
                  const SizedBox(height: _controlSectionSpacing),
                  const Text(
                    'INCUBATOR CONTROLS',
                    style: TextStyle(
                      color: _primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  IncubatorSettingRow(
                    label: 'EGG TILTING INTERVAL:',
                    value: data.turningIntervalLabel,
                    onEdit: () async {
                      final total = data.turningTotalSeconds;
                      final hoursController = TextEditingController(
                        text: '${total ~/ 3600}',
                      );
                      final minutesController = TextEditingController(
                        text: '${(total % 3600) ~/ 60}',
                      );
                      final secondsController = TextEditingController(
                        text: '${total % 60}',
                      );
                      final saved = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Egg Tilting Interval'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Set hours, minutes, seconds, or any mix. Example: 0 h, 0 m, 30 s.',
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: hoursController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Hours',
                                ),
                              ),
                              TextField(
                                controller: minutesController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Minutes',
                                ),
                              ),
                              TextField(
                                controller: secondsController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Seconds',
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      );
                      if (saved != true) return;
                      final hours = int.tryParse(hoursController.text.trim()) ?? 0;
                      final minutes =
                          int.tryParse(minutesController.text.trim()) ?? 0;
                      final seconds =
                          int.tryParse(secondsController.text.trim()) ?? 0;
                      final totalSeconds = hours * 3600 + minutes * 60 + seconds;
                      if (totalSeconds < 1) return;
                      await _incubatorService.updateFields({
                        'turningIntervalSeconds': totalSeconds,
                        'turningIntervalMinutes':
                            (totalSeconds / 60).ceil().clamp(1, 1000000),
                        'turningInterval': totalSeconds / 3600.0,
                      });
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class EggTrayScreen extends StatelessWidget {
  const EggTrayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'EGG TRAY',
        showBack: true,
        showLogoTrailing: true,
      ),
      body: SafeArea(
        child: StreamBuilder<IncubatorData>(
          stream: _incubatorService.watchIncubator(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final vision = snapshot.data!.vision;
            Widget preview = const Center(
              child: Text('No tray image yet'),
            );
            if (vision.imageBase64.isNotEmpty) {
              try {
                preview = Image.memory(
                  base64Decode(vision.imageBase64),
                  fit: BoxFit.contain,
                );
              } catch (_) {
                preview = const Center(child: Text('Could not decode image'));
              }
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Normal ${vision.normalEggs}  ·  Cracked ${vision.crackedEggs}  ·  Total ${vision.totalEggs}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _primaryText,
                  ),
                ),
                const SizedBox(height: 12),
                AspectRatio(aspectRatio: 4 / 3, child: preview),
              ],
            );
          },
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final String statusLabel;
  final String statusValue;
  final Color statusColor;
  final Color background;
  final String recommendedText;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.statusLabel,
    required this.statusValue,
    required this.statusColor,
    required this.background,
    required this.recommendedText,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w300,
                      height: 1.0,
                    ),
                  ),
                  TextSpan(
                    text: unit,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$statusLabel: ',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  TextSpan(
                    text: statusValue,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              recommendedText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WifiStatusCard extends StatelessWidget {
  final bool online;

  const _WifiStatusCard({required this.online});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _panelBlue,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFA8C4D8), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                online ? Icons.wifi : Icons.wifi_off,
                color: _brandTeal,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  online
                      ? 'Wi-Fi: incubator online'
                      : 'Wi-Fi: incubator offline',
                  style: const TextStyle(
                    color: _primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Nearby networks cannot be listed in Chrome. The ESP32 uses the SSID saved in firmware.',
            style: TextStyle(color: _primaryText, fontSize: 11, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _ControlModeCard extends StatelessWidget {
  final bool isManual;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenControls;

  const _ControlModeCard({
    required this.isManual,
    required this.onChanged,
    required this.onOpenControls,
  });

  Future<void> _confirmMode(
    BuildContext context, {
    required bool toManual,
  }) async {
    if (toManual == isManual) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(toManual ? 'Switch to Manual?' : 'Switch to Auto?'),
        content: Text(
          toManual
              ? 'Manual mode unlocks heater, fan, and egg-tilting switches. Climate will only run devices you leave on.\n\nContinue?'
              : 'Auto mode locks Component Controls and turns heater, fans, and egg tilting back on. Climate will follow your temperature and humidity setpoints.\n\nContinue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onChanged(toManual);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _panelBlue,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFA8C4D8), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONTROL MODE',
            style: TextStyle(
              color: _primaryText,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ModeButton(
                  label: 'Auto',
                  selected: !isManual,
                  onTap: () => _confirmMode(context, toManual: false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeButton(
                  label: 'Manual',
                  selected: isManual,
                  onTap: () => _confirmMode(context, toManual: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isManual
                ? 'Manual: Component Controls are unlocked.'
                : 'Auto: climate uses your setpoints. Component switches are locked and reset to on.',
            style: const TextStyle(color: _primaryText, fontSize: 11, height: 1.3),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton(
              onPressed: isManual ? onOpenControls : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandTeal,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFB7C6D1),
                disabledForegroundColor: Colors.white70,
              ),
              child: const Text(
                'Open Controls',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _brandTeal : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF8DADC0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _primaryText,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class WaterLevelBanner extends StatelessWidget {
  final String levelText;

  const WaterLevelBanner({super.key, required this.levelText});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: _waterGreen,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text(
            levelText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class BatchSummaryTile extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onView;

  const BatchSummaryTile({
    super.key,
    required this.label,
    required this.color,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, color: Colors.white, size: 10),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: onView,
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              minimumSize: const Size(64, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text(
              'View',
              style: TextStyle(color: _primaryText, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class ControlsMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final String statusValue;
  final Color statusColor;
  final Color background;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const ControlsMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.statusValue,
    required this.statusColor,
    required this.background,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '$value$unit',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w300,
            ),
          ),
          Text(
            statusValue,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SquareControlButton(label: '+', onTap: onIncrement),
              const SizedBox(width: 8),
              SquareControlButton(label: '-', onTap: onDecrement),
            ],
          ),
        ],
      ),
    );
  }
}

class SquareControlButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const SquareControlButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: const Color(0xFFB7C6D1),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class ComponentControlRow extends StatelessWidget {
  final String label;
  final bool isOn;
  final ValueChanged<bool> onToggle;
  final bool enabled;

  const ComponentControlRow({
    super.key,
    required this.label,
    required this.isOn,
    required this.onToggle,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _panelBlue,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFA8C4D8), width: 0.8),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.label_important_outline,
              size: 18,
              color: _brandTeal,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _primaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            OnOffSwitch(isOn: isOn, onToggle: onToggle, enabled: enabled),
          ],
        ),
      ),
    );
  }
}

class IncubatorSettingRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onEdit;

  const IncubatorSettingRow({
    super.key,
    required this.label,
    required this.value,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _panelBlue,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFA8C4D8), width: 0.8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(color: _primaryText, fontSize: 13),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onEdit, child: const Text('Edit')),
        ],
      ),
    );
  }
}

class OnOffSwitch extends StatelessWidget {
  final bool isOn;
  final ValueChanged<bool> onToggle;
  final bool enabled;

  const OnOffSwitch({
    super.key,
    required this.isOn,
    required this.onToggle,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFAFC6D8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: enabled ? () => onToggle(true) : null,
            child: Container(
              constraints: const BoxConstraints(minWidth: 32, minHeight: 30),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isOn ? _brandTeal : const Color(0xFFAFC6D8),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(3),
                ),
              ),
              child: Text(
                'On',
                style: TextStyle(
                  color: isOn ? Colors.white : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          InkWell(
            onTap: enabled ? () => onToggle(false) : null,
            child: Container(
              constraints: const BoxConstraints(minWidth: 32, minHeight: 30),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: !isOn ? _brandTeal : const Color(0xFFAFC6D8),
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(3),
                ),
              ),
              child: Text(
                'Off',
                style: TextStyle(
                  color: !isOn ? Colors.white : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

}