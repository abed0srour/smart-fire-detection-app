import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fire_detection_app/src/app/app.dart';
import 'package:smart_fire_detection_app/src/data/models/sensor_data.dart';
import 'package:smart_fire_detection_app/src/data/services/local_backend_service.dart';

void main() {
  test('maps backend fire status to high risk until flame is detected', () {
    expect(riskLevelFromBackend('fire'), RiskLevel.high);
    expect(riskLevelFromBackend('critical'), RiskLevel.high);
    expect(riskLevelFromBackend('fire', flameDetected: true), RiskLevel.fire);
  });

  test('normalizes gas-only alert history status', () {
    final alert = AlertHistory.fromMap({
      'message': 'Fire Detected',
      'riskLevel': 'fire',
      'flameDetected': false,
      'timestamp': DateTime.now(),
      'smokeLevel': 850,
    });

    expect(alert.riskLevel, RiskLevel.high);
    expect(alert.status, 'Danger: High Gas Leakage');
    expect(alert.flameDetected, isFalse);
  });

  testWidgets('renders dashboard shell', (tester) async {
    await tester.pumpWidget(SmartFireApp(backend: LocalBackendService()));
    await tester.pump();

    expect(find.text('Operations Dashboard'), findsOneWidget);
    expect(find.text('Sensor readings'), findsOneWidget);
    expect(find.text('Temperature'), findsOneWidget);
  });
}
