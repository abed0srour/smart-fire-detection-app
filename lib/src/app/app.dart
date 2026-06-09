import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_fire_detection_app/src/app/app_colors.dart';
import 'package:smart_fire_detection_app/src/data/models/sensor_data.dart';
import 'package:smart_fire_detection_app/src/data/services/auth_service.dart';
import 'package:smart_fire_detection_app/src/data/services/backend_bootstrap.dart';
import 'package:smart_fire_detection_app/src/data/services/backend_service.dart';
import 'package:smart_fire_detection_app/src/data/services/local_backend_service.dart';
import 'package:smart_fire_detection_app/src/features/alerts/presentation/alert_screen.dart';
import 'package:smart_fire_detection_app/src/features/auth/presentation/auth_screen.dart';
import 'package:smart_fire_detection_app/src/features/dashboard/presentation/dashboard_screen.dart';
import 'package:smart_fire_detection_app/src/features/history/presentation/history_screen.dart';
import 'package:smart_fire_detection_app/src/features/rooms/presentation/rooms_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:smart_fire_detection_app/src/shared/widgets/custom_navbar.dart';

class SmartFireApp extends StatefulWidget {
  const SmartFireApp({super.key, this.backend});

  final BackendService? backend;

  @override
  State<SmartFireApp> createState() => _SmartFireAppState();
}

class _SmartFireAppState extends State<SmartFireApp> {
  late final BackendService _backend = widget.backend ?? LocalBackendService();
  late final AuthController? _authController = widget.backend == null
      ? AuthController(
          authService: BackendBootstrap.createAuthService(),
          deviceId: BackendBootstrap.deviceId,
        )
      : null;

  @override
  void dispose() {
    _authController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'Smart Fire Detection',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: widget.backend == null ? const AuthGate() : const MainShell(),
    );

    if (_authController != null) {
      return ChangeNotifierProvider<AuthController>.value(
        value: _authController,
        child: app,
      );
    }

    return Provider<BackendService>.value(value: _backend, child: app);
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        surface: AppColors.surface,
        surfaceContainer: AppColors.surfaceHigh,
        surfaceContainerHigh: AppColors.surfaceHighest,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textMuted,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        labelStyle: const TextStyle(color: AppColors.textMuted),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary.withValues(alpha: 0.3);
          }
          return AppColors.textMuted.withValues(alpha: 0.25);
        }),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.primary,
        overlayColor: Color(0x33FF7A1A),
        valueIndicatorColor: AppColors.primary,
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final backend = auth.backend;

    if (auth.isLoading) {
      return const _StartupScreen();
    }

    if (!auth.isSignedIn || backend == null) {
      return const AuthScreen();
    }

    return Provider<BackendService>.value(
      value: backend,
      child: const MainShell(),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  BackendService? _alertBackend;
  StreamSubscription<SensorData>? _criticalAlertSubscription;
  bool _criticalAlertActive = false;
  String? _activeCriticalDeviceId;
  String? _activeCriticalAlertType;
  late final AudioPlayer _audioPlayer;
  bool _isAudioPlaying = false;

  final List<Widget> _screens = const [
    DashboardScreen(),
    RoomsScreen(),
    AlertScreen(),
    HistoryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.audioCache = AudioCache(prefix: '');
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final backend = context.read<BackendService>();
    if (_alertBackend == backend) {
      return;
    }

    _criticalAlertSubscription?.cancel();
    _alertBackend = backend;
    _criticalAlertActive = false;
    _activeCriticalDeviceId = null;
    _activeCriticalAlertType = null;
    _stopDangerSound();
    _criticalAlertSubscription = backend.watchCurrentSensorData().listen(
      _handleCriticalSensorData,
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _criticalAlertSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: CustomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }

  void _playDangerSound() async {
    if (!_isAudioPlaying) {
      try {
        _isAudioPlaying = true;
        await _audioPlayer.play(AssetSource('sound/videoplayback.mp3'));
      } catch (e) {
        debugPrint('Error playing danger sound: $e');
        _isAudioPlaying = false;
      }
    }
  }

  void _stopDangerSound() async {
    if (_isAudioPlaying) {
      try {
        await _audioPlayer.stop();
      } catch (e) {
        debugPrint('Error stopping danger sound: $e');
      } finally {
        _isAudioPlaying = false;
      }
    }
  }

  void _handleCriticalSensorData(SensorData sensorData) {
    final isCritical =
        sensorData.riskLevel == RiskLevel.fire ||
        sensorData.riskLevel == RiskLevel.high;

    if (!isCritical) {
      _clearCriticalAlert();
      return;
    }

    final alertType = sensorData.riskLevel == RiskLevel.fire ? 'fire' : 'gas';
    if (_criticalAlertActive &&
        _activeCriticalDeviceId == sensorData.deviceId &&
        _activeCriticalAlertType == alertType) {
      if (sensorData.alarmMuted) {
        _stopDangerSound();
      } else {
        _playDangerSound();
      }
      return;
    }

    _criticalAlertActive = true;
    _activeCriticalDeviceId = sensorData.deviceId;
    _activeCriticalAlertType = alertType;
    _showCriticalAlert(sensorData);
  }

  void _clearCriticalAlert() {
    if (!_criticalAlertActive) {
      return;
    }

    _criticalAlertActive = false;
    _activeCriticalDeviceId = null;
    _activeCriticalAlertType = null;
    _stopDangerSound();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_currentIndex == 2) {
          setState(() {
            _currentIndex = 0;
          });
        }
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
    });
  }

  void _showCriticalAlert(SensorData sensorData) {
    if (!sensorData.alarmMuted) {
      _playDangerSound();
    } else {
      _stopDangerSound();
    }
    final isFireAlert = sensorData.riskLevel == RiskLevel.fire;
    final bannerText = isFireAlert
        ? 'Critical fire alert from ${sensorData.deviceId}'
        : 'Danger: high gas leakage from ${sensorData.deviceId} - gas level ${sensorData.smokeLevel.toStringAsFixed(1)} ppm';
    final bannerIcon = isFireAlert
        ? Icons.local_fire_department
        : Icons.gas_meter;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (_currentIndex != 2) {
        setState(() {
          _currentIndex = 2;
        });
      }

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentMaterialBanner();
      messenger.showMaterialBanner(
        MaterialBanner(
          backgroundColor: AppColors.danger,
          leading: Icon(bannerIcon, color: Colors.white),
          content: Text(
            bannerText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => messenger.hideCurrentMaterialBanner(),
              child: const Text(
                'DISMISS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
