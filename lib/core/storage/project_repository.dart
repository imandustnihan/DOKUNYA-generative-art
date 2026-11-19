import 'dart:convert';

import '../graphics/art_model.dart';
import 'key_value_store.dart';

class ProjectRepository {
  ProjectRepository(this.store);
  final KeyValueStore store;
  int unreadableProjects = 0;
  Future<void> _queue = Future.value();
  Future<T> _serialize<T>(Future<T> Function() action) {
    final operation = _queue.then((_) => action());
    _queue = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<void> save(ArtDocument document) => _serialize(
    () => store.write('project_${document.id}', ProjectCodec.encode(document)),
  );
  Future<void> delete(String id) =>
      _serialize(() => store.remove('project_$id'));
  Future<List<ArtDocument>> list() async {
    await _queue;
    final docs = <ArtDocument>[];
    unreadableProjects = 0;
    for (final key in await store.keys()) {
      if (!key.startsWith('project_')) continue;
      try {
        final text = await store.read(key);
        if (text != null) docs.add(ProjectCodec.decode(text));
      } on FormatException {
        unreadableProjects++;
      }
    }
    docs.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return docs;
  }

  Future<Map<String, dynamic>> preferences() async {
    try {
      final s = await store.read('preferences');
      if (s == null) return {};
      final j = jsonDecode(s);
      return j is Map<String, dynamic> ? j : {};
    } on FormatException {
      return {};
    }
  }

  Future<void> savePreferences(Map<String, Object> preferences) =>
      _serialize(() => store.write('preferences', jsonEncode(preferences)));
}
