import 'dart:io';

import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

bool get _desktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;
Future<bool> exportBytes(
  Uint8List bytes,
  String name,
  String mime,
  Rect origin,
) async {
  if (_desktop) {
    final location = await getSaveLocation(suggestedName: name);
    if (location == null) return false;
    await XFile.fromData(
      bytes,
      mimeType: mime,
      name: name,
    ).saveTo(location.path);
    return true;
  }
  final result = await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: mime, name: name)],
      fileNameOverrides: [name],
      sharePositionOrigin: origin,
    ),
  );
  return result.status != ShareResultStatus.dismissed;
}

const _windowChannel = MethodChannel('dev.artpulse/window');
Future<void> initializeWindow() async {}
Future<void> setFullscreen(bool value) async {
  if (_desktop) {
    await _windowChannel.invokeMethod<void>('fullscreen', value);
  } else {
    await SystemChrome.setEnabledSystemUIMode(
      value ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }
}

Future<bool> detectTv() async {
  if (!Platform.isAndroid) return false;
  try {
    return await const MethodChannel('dev.artpulse/device')
            .invokeMethod<bool>('isTelevision') ??
        false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}

Map<String, String> takeStudioLink() => const {};
