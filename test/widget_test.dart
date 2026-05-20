import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpad_pilot/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: LgRemoteApp(initialSavedTvs: [])),
    );
    expect(find.text('LG Remote'), findsOneWidget);
  });
}
