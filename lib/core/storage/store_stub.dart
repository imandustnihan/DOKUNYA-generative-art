import 'key_value_store.dart';

Future<KeyValueStore> createStore() async => MemoryStore();
