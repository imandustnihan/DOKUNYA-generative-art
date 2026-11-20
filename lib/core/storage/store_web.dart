import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'key_value_store.dart';

Future<KeyValueStore> createStore() async {
  final completer = Completer<KeyValueStore>();
  final request = web.window.indexedDB.open('artpulse-studio', 1);
  request.onupgradeneeded = ((web.Event event) {
    final database = request.result as web.IDBDatabase;
    database.createObjectStore('documents');
  }).toJS;
  request.onsuccess = ((web.Event event) {
    final database = request.result as web.IDBDatabase;
    if (completer.isCompleted) {
      database.close();
      return;
    }
    database.onversionchange = ((web.Event _) => database.close()).toJS;
    completer.complete(BrowserStore(database));
  }).toJS;
  request.onerror = ((web.Event event) {
    if (!completer.isCompleted) completer.completeError(StateError('storage'));
  }).toJS;
  request.onblocked = ((web.Event event) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('storage blocked'));
    }
  }).toJS;
  return completer.future;
}

class BrowserStore implements KeyValueStore {
  BrowserStore(this.database);
  final web.IDBDatabase database;
  Future<JSAny?> _readRequest(web.IDBRequest request) {
    final c = Completer<JSAny?>();
    request.onsuccess = ((web.Event e) => c.complete(request.result)).toJS;
    request.onerror = ((web.Event e) => c.completeError(
      StateError('storage'),
    )).toJS;
    return c.future;
  }

  @override
  Future<String?> read(String key) async {
    final tx = database.transaction('documents'.toJS, 'readonly');
    final value = await _readRequest(tx.objectStore('documents').get(key.toJS));
    if (value == null || value.isUndefinedOrNull) return null;
    if (!value.isA<JSString>()) throw const FormatException('storage type');
    return (value as JSString).toDart;
  }

  Future<void> _mutate(void Function(web.IDBObjectStore) action) async {
    final c = Completer<void>(),
        tx = database.transaction('documents'.toJS, 'readwrite');
    tx.oncomplete = ((web.Event e) {
      if (!c.isCompleted) c.complete();
    }).toJS;
    void fail(web.Event e) {
      if (!c.isCompleted) c.completeError(StateError('storage'));
    }

    tx.onerror = fail.toJS;
    tx.onabort = fail.toJS;
    action(tx.objectStore('documents'));
    await c.future;
  }

  @override
  Future<void> write(String key, String value) =>
      _mutate((store) => store.put(value.toJS, key.toJS));
  @override
  Future<void> remove(String key) => _mutate((store) => store.delete(key.toJS));
  @override
  Future<List<String>> keys() async {
    final tx = database.transaction('documents'.toJS, 'readonly');
    final raw = await _readRequest(tx.objectStore('documents').getAllKeys());
    return (raw as JSArray<JSString>).toDart.map((key) => key.toDart).toList();
  }
}
