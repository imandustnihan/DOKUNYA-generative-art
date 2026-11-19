import '../../core/graphics/art_model.dart';

class ArtPreset {
  const ArtPreset(this.name, this.mode, this.palette, this.seed);
  final String name;
  final ArtMode mode;
  final int palette, seed;
}

const studioPresets = [
  ArtPreset('Violet current', ArtMode.neonFlow, 0, 2749),
  ArtPreset('Borealis drift', ArtMode.particleGalaxy, 1, 7193),
  ArtPreset('Sacred orbit', ArtMode.symmetryLab, 3, 6102),
  ArtPreset('Afterglow', ArtMode.liquidLight, 2, 8491),
  ArtPreset('Quiet geometry', ArtMode.geometryPulse, 4, 9306),
  ArtPreset('Midnight silk', ArtMode.neonFlow, 5, 4207),
  ArtPreset('Event horizon', ArtMode.particleGalaxy, 0, 6811),
  ArtPreset('Rose window', ArtMode.symmetryLab, 3, 1777),
  ArtPreset('Glacial light', ArtMode.liquidLight, 4, 5263),
  ArtPreset('Solar rhythm', ArtMode.geometryPulse, 2, 2901),
];
