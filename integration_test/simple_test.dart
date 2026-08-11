import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/main.dart';
import 'package:flutter_rust_demo/generated/rust/frb_generated.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());
  testWidgets('App boots to login screen', (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.text('登录'), findsOneWidget);
  });
}
