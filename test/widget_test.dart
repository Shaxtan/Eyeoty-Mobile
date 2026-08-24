import 'package:flutter_test/flutter_test.dart';
import 'package:eyeoty_mobile/main.dart';

// Minimal smoke test. NOTE: this could not be executed in the
// environment that generated this project (no Flutter SDK available —
// see README.md "What I could not verify"). Run `flutter test` locally
// to confirm it passes.
void main() {
  testWidgets('App boots to the splash screen without throwing', (tester) async {
    await tester.pumpWidget(const EyeotyApp());
    await tester.pump();
    expect(find.textContaining('eye'), findsWidgets);
  });
}
