import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_remote/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: LgRemoteApp()));
    expect(find.text('LG Remote'), findsOneWidget);
  });
}
