import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

Future<bool> exportBytes(
  Uint8List bytes,
  String name,
  String mime,
  Rect origin,
) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body!.append(a);
  a.click();
  a.remove();
  // Keep the object URL alive while the browser starts the download.
  Future<void>.delayed(
    const Duration(seconds: 30),
    () => web.URL.revokeObjectURL(url),
  );
  return true;
}

Future<void> initializeWindow() async {}
Future<bool> detectTv() async => false;
Future<void> setFullscreen(bool value) async {
  if (value && web.document.fullscreenEnabled) {
    await web.document.documentElement!.requestFullscreen().toDart;
  } else if (!value && web.document.fullscreenElement != null) {
    await web.document.exitFullscreen().toDart;
  }
}
