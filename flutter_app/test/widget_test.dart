import 'package:container_packing_test/core/strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Arabic and English have the same text keys', () {
    final en = kStrings['en']!.keys.toSet();
    final ar = kStrings['ar']!.keys.toSet();
    expect(ar.difference(en), isEmpty);
    expect(en.difference(ar), isEmpty);
  });

  test('translate fills placeholders', () {
    expect(translate('en', 'hello', {'name': 'Wafaa'}), 'Hello, Wafaa');
    expect(translate('ar', 'hello', {'name': 'وفاء'}), 'مرحبًا، وفاء');
  });
}
