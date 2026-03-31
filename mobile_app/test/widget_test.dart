import 'package:flutter_test/flutter_test.dart';

import 'package:vibe_court_mobile/main.dart';

void main() {
  testWidgets('renders Vibe Court entry screen', (tester) async {
    await tester.pumpWidget(const VibeCourtApp());

    expect(find.text('Vibe Court'), findsOneWidget);
    expect(find.text('Open the case'), findsOneWidget);
    expect(find.text('Calendar Evidence'), findsOneWidget);
    expect(find.text('Recently Played'), findsOneWidget);
  });
}
