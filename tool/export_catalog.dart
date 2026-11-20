import 'dart:convert';
import 'dart:io';

import 'package:dokunya/core/graphics/engine_catalog.dart';

void main(List<String> arguments) {
  final file = File.fromUri(
    Platform.script.resolve('../site/src/data/instruments.json'),
  );
  final catalog = [
    for (var id = 0; id < instrumentCount; id++)
      {'id': id, 'name': instrumentName(id), 'family': instrumentFamily(id)},
  ];
  final text = '${const JsonEncoder.withIndent('  ').convert(catalog)}\n';
  if (arguments.contains('--check')) {
    if (!file.existsSync() || file.readAsStringSync() != text) {
      stderr.writeln(
        'Update the web catalog with dart tool/export_catalog.dart',
      );
      exitCode = 1;
    }
  } else {
    file.writeAsStringSync(text);
  }
}
