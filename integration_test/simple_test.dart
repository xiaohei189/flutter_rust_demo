import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/main.dart';
import 'package:flutter_rust_demo/src/rust/frb_generated.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());
  testWidgets('App boots to login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('登录'), findsOneWidget);
  });
}
