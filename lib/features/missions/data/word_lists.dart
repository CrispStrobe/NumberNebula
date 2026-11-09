// lib/features/missions/data/word_lists.dart
//
// Space-themed codewords by locale and grade.
// Grade gates word length: grade 1 = short, grade 4 = long.

const Map<String, Map<int, List<String>>> spaceWords = {
  'en': {
    1: [
      'MARS', 'MOON', 'STAR', 'NOVA', 'ORBIT',
      'SUN', 'VOID', 'WARP', 'BEAM', 'FUEL',
      'CREW', 'DOCK', 'HULL', 'CORE', 'PULSE',
    ],
    2: [
      'ROCKET', 'SATURN', 'NEBULA', 'COMET', 'GALAXY',
      'LAUNCH', 'QUASAR', 'PLASMA', 'METEOR', 'THRUST',
      'SHIELD', 'PHOTON', 'FUSION', 'ASTRAL', 'SIGNAL',
    ],
    3: [
      'ASTEROID', 'SPACESHIP', 'UNIVERSE', 'STARSHIP', 'SUPERNOVA',
      'EXPLORER', 'MAGNETIC', 'SPECTRUM', 'WORMHOLE', 'STARDUST',
      'LIGHTYEAR', 'BLACKHOLE', 'CRESCENT', 'SOLSTICE',
    ],
    4: [
      'CONSTELLATION', 'INTERSTELLAR', 'GRAVITYWARP',
      'SPACESTATION', 'STARCRUISER', 'LIGHTSTORM',
      'GALAXYQUEST', 'SUPERCLUSTER', 'COSMICSTORM',
      'HYPERSTREAM', 'STARCOMMAND', 'NEBULAFORGE',
    ],
  },
  'de': {
    1: [
      'MARS', 'MOND', 'KERN', 'BAHN', 'STERN',
      'WARP', 'ERDE', 'LICHT', 'CREW', 'PULS',
      'DOCK', 'FUNK', 'RUMPF', 'STRAHL', 'GLUT',
    ],
    2: [
      'RAKETE', 'SATURN', 'KOMET', 'PLANET', 'SIGNAL',
      'PLASMA', 'SCHILD', 'METEOR', 'FUSION', 'GALAXIS',
      'PHOTON', 'QUASAR', 'PULSAR', 'ASTRAL', 'NEBULA',
    ],
    3: [
      'ASTEROID', 'RAUMSCHIFF', 'STARTKLAR', 'SUPERNOVA',
      'MAGNETFELD', 'STERNENTOR', 'WELTRAUMGUT',
      'LICHTJAHR', 'SONNENSTURM', 'MONDSTAUB',
    ],
    4: [
      'RAUMSTATION', 'STERNENKREUZER', 'GRAVITATIONSFELD',
      'WELTRAUMFAHRT', 'STERNENHIMMEL', 'GALAXIENSTAUB',
      'LICHTGESCHWINDIGKEIT', 'KOSMISCHERSTAUB',
    ],
  },
};
