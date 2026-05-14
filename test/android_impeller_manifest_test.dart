import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest disables Impeller renderer', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains('android:name="io.flutter.embedding.android.EnableImpeller"'),
    );
    expect(manifest, contains('android:value="false"'));
  });
}
