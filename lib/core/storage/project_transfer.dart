import 'package:flutter/foundation.dart';

import '../graphics/art_model.dart';

Future<ArtDocument> decodeProject(String text) async {
  if (text.length > maxImportBytes) throw const FormatException('size');
  if (!kIsWeb && text.length >= 65536) {
    return compute(ProjectCodec.decode, text);
  }
  return ProjectCodec.decode(text);
}

Future<String> encodeProject(ArtDocument project) async {
  final samples = project.strokes.fold<int>(
    0,
    (n, stroke) => n + stroke.points.length,
  );
  if (!kIsWeb && (samples >= 1024 || project.particles.length >= 4096)) {
    return compute(ProjectCodec.encode, project);
  }
  return ProjectCodec.encode(project);
}
