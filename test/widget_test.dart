// Copyright (C) 2026 AuraStudio Corporation • Pritam
// AuraResize - Widget Smoke Test

import 'package:flutter_test/flutter_test.dart';
import 'package:sarkari_resize/main.dart';

void main() {
  testWidgets('AuraResize smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AuraResizeApp());
    expect(find.text('AuraResize'), findsWidgets);
  });
}
