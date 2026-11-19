/// A stable catalog of 100 procedural instruments grouped by ten mathematics
/// families. IDs are persisted in project JSON, so never reorder entries.
const engineFamilies = <String>[
  'Cosmic Orbits',
  'Aurora Ribbons',
  'Kinetic Geometry',
  'Flow Fields',
  'Fractal Gardens',
  'Celestial Particles',
  'Optical Structures',
  'Resonance Forms',
  'Topographic Dreams',
  'Kaleidoscope Atelier',
];

const engineTitles = <List<String>>[
  [
    'Fermat Drift',
    'Logarithmic Bloom',
    'Helical Halo',
    'Quasar Loop',
    'Binary Orbit',
    'Comet Spiral',
    'Cosmic Knot',
    'Elliptic Tide',
    'Vortex Bloom',
    'Orbital Filigree',
  ],
  [
    'Silk Horizon',
    'Aurora Cascade',
    'Midnight Current',
    'Sonic Ribbon',
    'Prismatic Rain',
    'Glacial Veil',
    'Solar Wind',
    'Tidal Threads',
    'Velvet Frequency',
    'Electric Current',
  ],
  [
    'Polygon Ballet',
    'Dodeca Pulse',
    'Starlight Grid',
    'Tessellation',
    'Spinning Prism',
    'Crystal Crown',
    'Geometric Drift',
    'Orbiting Diamonds',
    'Chromatic Lattice',
    'Framed Infinity',
  ],
  [
    'Magnetic North',
    'Curl Domain',
    'River Delta',
    'Whirlpool Field',
    'Wind Atlas',
    'Turbulent Stream',
    'Counterflow',
    'Bioluminescent Drift',
    'Gravity Lines',
    'Perlin Current',
  ],
  [
    'Coral Branch',
    'Electric Fern',
    'Forest Veins',
    'Dendrite Bloom',
    'Lightning Roots',
    'Sakura Stems',
    'River Tree',
    'Silver Thicket',
    'Copper Vines',
    'Infinite Branches',
  ],
  [
    'Dust Nebula',
    'Starseed',
    'Firefly Cluster',
    'Ion Storm',
    'Stellar Rain',
    'Digital Pollen',
    'Meteor Dust',
    'Quantum Noise',
    'Luminous Spores',
    'Celestial Swarm',
  ],
  [
    'Moiré Halo',
    'Wave Interference',
    'Parallax Nets',
    'Op Art Rings',
    'Interlaced Lines',
    'Spectral Mesh',
    'Offset Grids',
    'Optical Echo',
    'Crossfade Lattice',
    'Contour Mirage',
  ],
  [
    'Harmonic Pulse',
    'Sine Cathedral',
    'Oscillator Bloom',
    'Pulse Cathedral',
    'Resonant Circle',
    'Frequency Weave',
    'Phase Tension',
    'Sonic Petals',
    'Spectral Organ',
    'Standing Waves',
  ],
  [
    'Midnight Atlas',
    'Coastal Contours',
    'Mountain Echo',
    'Elevation Lines',
    'Crystal Terrain',
    'Tectonic Flow',
    'Weather Patterns',
    'Mist Map',
    'Valley Network',
    'Topographic Bloom',
  ],
  [
    'Lotus Prism',
    'Glass Mandala',
    'Sacred Petals',
    'Kaleido Rose',
    'Chromatic Fans',
    'Radiant Silk',
    'Snowflake Bloom',
    'Mandala Eclipse',
    'Petal Labyrinth',
    'Endless Mosaic',
  ],
];

const instrumentCount = 100;

String instrumentName(int id) {
  if (id < 0 || id >= instrumentCount)
    throw RangeError.range(id, 0, instrumentCount - 1);
  return engineTitles[id ~/ 10][id % 10];
}

String instrumentFamily(int id) {
  if (id < 0 || id >= instrumentCount)
    throw RangeError.range(id, 0, instrumentCount - 1);
  return engineFamilies[id ~/ 10];
}
