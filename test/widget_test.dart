import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fire_detection_app/src/app/app.dart';
import 'package:smart_fire_detection_app/src/data/services/local_backend_service.dart';

void main() {
  testWidgets('renders dashboard with backend data', (tester) async {
    await tester.pumpWidget(SmartFireApp(backend: LocalBackendService()));
    await tester.pump();

    expect(find.text('Operations Dashboard'), findsOneWidget);
    expect(find.text('Sensor readings'), findsOneWidget);
    expect(find.text('Temperature'), findsOneWidget);
  });
}
