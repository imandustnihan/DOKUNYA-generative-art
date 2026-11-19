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

  /// Keeps in-progress artwork separate from the user's named projects.
  Future<void> saveDraft(ArtDocument document) => _serialize(
    () => store.write('workspace_draft', ProjectCodec.encode(document)),
  );

  bool unreadableDraft = false;

  /// Invalid project JSON remains on disk so it can be recovered manually.
  Future<ArtDocument?> loadDraft() async {
    await _queue;
    final raw = await store.read('workspace_draft');
    unreadableDraft = false;
    if (raw == null) return null;
    try {
      return ProjectCodec.decode(raw);
    } on FormatException {
      unreadableDraft = true;
      return null;
    } on TypeError {
      unreadableDraft = true;
      return null;
    }
  }

  Future<void> clearDraft() =>
      _serialize(() => store.remove('workspace_draft'));
}
