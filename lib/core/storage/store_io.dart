import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'key_value_store.dart';

Future<KeyValueStore> createStore() async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory('${base.path}/artpulse_projects');
  await dir.create(recursive: true);
  return FileStore(dir);
}

class FileStore implements KeyValueStore {
  FileStore(this.directory);
  final Directory directory;
  File _file(String key) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(key)) {
      throw const FormatException('key');
    }
    return File('${directory.path}/$key.json');
  }

  @override
  Future<String?> read(String key) async {
    final file = _file(key), backup = File('${_file(key).path}.bak');
    if (!await file.exists() && await backup.exists()) {
      await backup.rename(file.path);
    }
    if (!await file.exists()) return null;
    if (await file.length() > 4 * 1024 * 1024) {
      throw const FormatException('size');
    }
    return file.readAsString();
  }

  @override
  Future<void> write(String key, String value) async {
    final file = _file(key),
        temp = File('${_file(key).path}.tmp'),
        backup = File('${_file(key).path}.bak');
    await temp.writeAsString(value, flush: true);
    if (await file.exists()) {
      if (await backup.exists()) await backup.delete();
      await file.rename(backup.path);
    }
    try {
      await temp.rename(file.path);
    } catch (_) {
      if (!await file.exists() && await backup.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    }
    if (await backup.exists()) await backup.delete();
  }

  @override
  Future<void> remove(String key) async {
    for (final suffix in ['', '.bak', '.tmp']) {
      final f = File('${_file(key).path}$suffix');
      if (await f.exists()) await f.delete();
    }
  }

  @override
  Future<List<String>> keys() async {
    final names = <String>{};
    await for (final e in directory.list()) {
      final n = e.uri.pathSegments.last;
      if (n.endsWith('.json')) names.add(n.substring(0, n.length - 5));
      if (n.endsWith('.json.bak')) names.add(n.substring(0, n.length - 9));
    }
    return names.toList();
  }
}
