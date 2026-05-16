import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_fire_detection_app/src/app/app_colors.dart';
import 'package:smart_fire_detection_app/src/data/models/app_settings.dart';
import 'package:smart_fire_detection_app/src/data/models/sensor_data.dart';
import 'package:smart_fire_detection_app/src/data/services/auth_service.dart';
import 'package:smart_fire_detection_app/src/data/services/backend_service.dart';

/// Settings screen for app configuration.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _phoneController;
  StreamSubscription<AppSettings>? _settingsSubscription;
  BackendService? _backend;

  bool autoEmergencyCall = true;
  bool notificationsEnabled = true;
  double temperatureThreshold = 40;
  double smokeThreshold = 70;
  bool _isSaving = false;
  bool _hasLoadedSettings = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: '+1-911-EMERGENCY');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final backend = context.read<BackendService>();
    if (_backend == backend) {
      return;
    }

    _settingsSubscription?.cancel();
    _backend = backend;
    _settingsSubscription = backend.watchSettings().listen(
      _applySettings,
      onError: (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _loadError = 'Settings could not be loaded.';
        });
      },
    );
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  void _applySettings(AppSettings settings) {
    if (!mounted) {
      return;
    }

    setState(() {
      _hasLoadedSettings = true;
      _loadError = null;
      _phoneController.text = settings.emergencyPhoneNumber;
      autoEmergencyCall = settings.autoEmergencyCall;
      notificationsEnabled = settings.notificationsEnabled;
      temperatureThreshold = settings.temperatureThreshold;
      smokeThreshold = settings.smokeThreshold;
    });
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.watch<BackendService>();
    final auth = context.watch<AuthController?>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: const Text('Settings'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showBackendHelp(context, backend),
          ),
          if (auth != null)
            IconButton(icon: const Icon(Icons.logout), onPressed: auth.signOut),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_hasLoadedSettings)
                const LinearProgressIndicator(color: AppColors.primary),
              if (_loadError != null) _buildErrorBanner(_loadError!),
              _buildSectionHeader('Emergency settings'),
              const SizedBox(height: 16),
              _buildEmergencyPhoneCard(),
              const SizedBox(height: 16),
              _buildToggleSetting(
                title: 'Auto Emergency Call',
                subtitle:
                    'Automatically call emergency services on fire detection',
                value: autoEmergencyCall,
                onChanged: (value) {
                  setState(() {
                    autoEmergencyCall = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Notification settings'),
              const SizedBox(height: 16),
              _buildToggleSetting(
                title: 'Enable Notifications',
                subtitle: 'Receive alerts and status updates',
                value: notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    notificationsEnabled = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Sensor thresholds'),
              const SizedBox(height: 16),
              _buildThresholdCard(
                title: 'Temperature Threshold',
                value: temperatureThreshold,
                unit: '\u00B0C',
                min: 30,
                max: 80,
                onChanged: (value) {
                  setState(() {
                    temperatureThreshold = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildThresholdCard(
                title: 'Smoke Level Threshold',
                value: smokeThreshold,
                unit: '%',
                min: 30,
                max: 100,
                onChanged: (value) {
                  setState(() {
                    smokeThreshold = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Device information'),
              const SizedBox(height: 16),
              _buildDeviceInfo(backend),
              const SizedBox(height: 32),
              _buildActionButtons(backend),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildEmergencyPhoneCard() {
    return _buildSettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Text(
                'Emergency Phone Number',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: 'Enter phone number',
              prefixIcon: Icon(
                Icons.call,
                color: AppColors.textMuted,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSettingCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  Widget _buildToggleSetting({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _buildSettingCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
            inactiveThumbColor: AppColors.textMuted,
            inactiveTrackColor: AppColors.textMuted.withValues(alpha: 0.25),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdCard({
    required String title,
    required double value,
    required String unit,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return _buildSettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primary, width: 1),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  '${value.toStringAsFixed(0)}$unit',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.border,
            thumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${min.toStringAsFixed(0)}$unit',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              Text(
                '${max.toStringAsFixed(0)}$unit',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfo(BackendService backend) {
    return StreamBuilder<SensorData>(
      stream: backend.watchCurrentSensorData(),
      builder: (context, snapshot) {
        final sensorData = snapshot.data;
        return Column(
          children: [
            _buildInfoRow('Device ID', backend.deviceId),
            _buildInfoRow('Backend', backend.backendName),
            _buildInfoRow('Firmware', 'v2.1.4'),
            _buildInfoRow(
              'Last Sync',
              sensorData == null ? 'Pending' : _formatLastSync(sensorData),
            ),
            _buildInfoRow(
              'Battery',
              sensorData == null
                  ? 'Pending'
                  : '${sensorData.batteryLevel.toStringAsFixed(0)}%',
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _buildSettingCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BackendService backend) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isSaving ? null : () => _saveSettings(backend),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              _isSaving ? 'SAVING...' : 'SAVE SETTINGS',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: _isSaving
                ? null
                : () => _showResetDialog(context, backend),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'RESET',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  AppSettings _draftSettings(BackendService backend) {
    return AppSettings(
      deviceId: backend.deviceId,
      emergencyPhoneNumber: _phoneController.text.trim(),
      autoEmergencyCall: autoEmergencyCall,
      notificationsEnabled: notificationsEnabled,
      temperatureThreshold: temperatureThreshold,
      smokeThreshold: smokeThreshold,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _saveSettings(BackendService backend) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await backend.saveSettings(_draftSettings(backend));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Settings saved'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save settings'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _resetSettings(BackendService backend) async {
    final defaults = AppSettings.defaults(deviceId: backend.deviceId);
    setState(() {
      _phoneController.text = defaults.emergencyPhoneNumber;
      autoEmergencyCall = defaults.autoEmergencyCall;
      notificationsEnabled = defaults.notificationsEnabled;
      temperatureThreshold = defaults.temperatureThreshold;
      smokeThreshold = defaults.smokeThreshold;
    });
    await backend.saveSettings(defaults);
  }

  String _formatLastSync(SensorData sensorData) {
    final diff = DateTime.now().difference(sensorData.lastUpdated);
    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    return '${diff.inHours}h ago';
  }

  void _showResetDialog(BuildContext context, BackendService backend) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'Reset Settings',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Reset all settings to default values?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _resetSettings(backend);
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Settings reset to default'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
            child: const Text('RESET'),
          ),
        ],
      ),
    );
  }

  void _showBackendHelp(BuildContext context, BackendService backend) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'Backend',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          backend.isRemoteBackend
              ? 'Connected to ${backend.backendName} for device ${backend.deviceId}.'
              : 'Using local in-app data. Add a Laravel API service when the backend is ready.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
