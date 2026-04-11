import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgram/features/templates/domain/collage_layout.dart';

void main() {
  test('Parses templates JSON', () {
    final file = File('assets/templates.json');
    final jsonStr = file.readAsStringSync();
    final data = jsonDecode(jsonStr);

    final templates = data['templates'] as List;
    for (final t in templates) {
      try {
        final model = TemplateModel.fromJson(t);
        expect(model.id, isNotNull);
      } catch (e, stack) {
        fail('Failed parsing template ${t['id']}: $e\n$stack');
      }
    }
  });
}
