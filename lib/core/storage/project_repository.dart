import 'dart:convert';

import '../graphics/art_model.dart';
import 'key_value_store.dart';
import 'project_transfer.dart';

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
    () async =>
        store.write('project_${document.id}', await encodeProject(document)),
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
        if (text != null) docs.add(await decodeProject(text));
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

  String _draftKey = 'workspace_draft';

  /// Keeps in-progress artwork separate from the user's named projects.
  Future<void> saveDraft(ArtDocument document) => _serialize(
    () async => store.write(_draftKey, await encodeProject(document)),
  );

  bool unreadableDraft = false;

  /// Invalid project JSON remains on disk so it can be recovered manually.
  Future<ArtDocument?> loadDraft() async {
    await _queue;
    unreadableDraft = false;
    _draftKey = 'workspace_draft';
    for (var slot = 1; ; slot++) {
      try {
        final raw = await store.read(_draftKey);
        return raw == null ? null : await decodeProject(raw);
      } on FormatException {
        // Preserve damaged or oversized bytes in place, including when a new
        // drawing is saved or cleared. A later launch follows the same slots.
        unreadableDraft = true;
        _draftKey = 'workspace_draft_after_damage_$slot';
      }
    }
  }

  Future<void> clearDraft() => _serialize(() => store.remove(_draftKey));
}
