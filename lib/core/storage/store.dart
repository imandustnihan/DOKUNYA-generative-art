export 'key_value_store.dart';
export 'store_stub.dart'
    if (dart.library.io) 'store_io.dart'
    if (dart.library.js_interop) 'store_web.dart';
