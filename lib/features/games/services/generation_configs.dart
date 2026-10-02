import 'algorithm_path.dart';

class StarForgeGenerationConfig {
  final int grade, level;
  const StarForgeGenerationConfig(this.grade, this.level);
  int getStarPoints() {
    final grade = this.grade;
    if (grade <= 2) return 5;
    if (grade == 3) return 6;
    return 7;
  }

  int getClueCount() {
    final level = this.level;
    final grade = this.grade;
    final points = getStarPoints();
    final nodeCount = points * 2;

    // Grade 1, level 1: reveal 80% (only 2 empty nodes on a 10-node star)
    // Progressively remove clues as grade and level increase
    double clueRatio;
    if (grade <= 1) {
      clueRatio = 0.80 - (level - 1) * 0.03; // 80% -> 62% over 6 levels
    } else if (grade <= 2) {
      clueRatio = 0.70 - (level - 1) * 0.03; // 70% -> 52%
    } else {
      clueRatio = 0.60 - (level - 1) * 0.02; // 60% -> 42%
    }
    final count = (nodeCount * clueRatio).round();
    return count.clamp(2, nodeCount - 2);
  }
}

class NebulaMatrixGenerationConfig {
  final int grade, level;
  const NebulaMatrixGenerationConfig(this.grade, this.level);
  int getGridSize() {
    final grade = this.grade;
    if (grade <= 1) return 3;
    if (grade <= 2) return 4;
    if (grade <= 3) return 5;
    return 5;
  }

  int getClueCount() {
    final level = this.level;
    final size = getGridSize();
    final totalCells = size * size;
    // More clues at low levels, fewer at high levels
    final base = (totalCells * 0.6).round();
    final reduction = (level / 4).floor();
    final advanced =
        algorithmPath == AlgorithmPath.legacy ? 0 : (grade - 4).clamp(0, 2);
    return (base - reduction - advanced).clamp(size, totalCells - 1);
  }
}

class OrbitalTowersGenerationConfig {
  final int grade, level;
  const OrbitalTowersGenerationConfig(this.grade, this.level);
  int getGridSize() {
    final grade = this.grade;
    if (grade <= 1) return 3;
    if (grade <= 2) return 4;
    return 5;
  }

  int getEdgeClueCount() {
    final level = this.level;
    final size = getGridSize();
    final maxClues = size * 4;
    final base = (maxClues * 0.75).round();
    final reduction = (level / 4).floor();
    final advanced =
        algorithmPath == AlgorithmPath.legacy ? 0 : (grade - 4).clamp(0, 2);
    return (base - reduction - advanced).clamp(size, maxClues);
  }

  int getCellClueCount() {
    final level = this.level;
    if (level <= 3) return 2;
    if (level <= 6) return 1;
    return 0;
  }
}

class HiveStationGenerationConfig {
  final int grade, level;
  const HiveStationGenerationConfig(this.grade, this.level);
  int getRadius() {
    final grade = this.grade;
    final level = this.level;
    if (grade <= 1) return 2; // 19 cells — enough for a real puzzle
    if (grade <= 2) return level >= 10 ? 3 : 2;
    if (grade <= 3) return 3; // 37 cells
    return level >= 8 ? 4 : 3; // grade 4: up to 61 cells
  }

  double getEnergyFraction() {
    final grade = this.grade;
    final level = this.level;
    // Grade 1: 25%→30%, Grade 2: 28%→33%, Grade 3: 30%→35%, Grade 4: 30%→38%
    final base = [0, 0.25, 0.28, 0.30, 0.30][grade.clamp(0, 4)];
    final max = [0, 0.30, 0.33, 0.35, 0.38][grade.clamp(0, 4)];
    return base + (level - 1) * (max - base) / 19;
  }

  double getHintFraction() {
    final grade = this.grade;
    final level = this.level;
    // Grade determines range, level slides within it:
    //   Grade 1: 0.75 → 0.60  (most hints visible, some deduction)
    //   Grade 2: 0.65 → 0.50  (moderate deduction)
    //   Grade 3: 0.55 → 0.40  (significant deduction)
    //   Grade 4: 0.50 → 0.30  (expert: many hidden cells)
    final start = [1.0, 0.75, 0.65, 0.55, 0.50][grade.clamp(0, 4)];
    final end = [1.0, 0.60, 0.50, 0.40, 0.30][grade.clamp(0, 4)];
    return start - (level - 1) * (start - end) / 19;
  }

  int getMaxAttempts() {
    final grade = this.grade;
    return grade <= 2 ? 3 : 2;
  }
}

class RelicAssemblyGenerationConfig {
  final int grade, level;
  const RelicAssemblyGenerationConfig(this.grade, this.level);
  int getRows() {
    final grade = this.grade;
    if (grade <= 1) return 2;
    if (grade <= 2) return 2;
    return 3;
  }

  int getCols() {
    final grade = this.grade;
    if (grade <= 1) return 2;
    if (grade <= 2) return 3;
    return 3;
  }

  int getEdgeValueCount() {
    final level = this.level;
    // More edge values = harder
    const base = 3;
    final bonus = (level / 5).floor();
    return (base + bonus).clamp(3, 7);
  }
}
