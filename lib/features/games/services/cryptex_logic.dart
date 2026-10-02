import 'generator_random.dart';
import '../models/math_problem.dart';
import '../constants/app_constants.dart';

class CryptexPuzzle {
  /// Exact local-session snapshot, including mutable model state.
  Map<String, dynamic> toJson() => {
        'dialCount': dialCount,
        'equations': equations.map((v0) => v0.toJson()).toList(),
        'solution': solution.map((v0) => v0).toList(),
        'initialValues': initialValues.map((v0) => v0).toList()
      };
  factory CryptexPuzzle.fromJson(Map<String, dynamic> json) => CryptexPuzzle(
      dialCount: json['dialCount'] as int,
      equations: (json['equations'] as List)
          .map((v0) =>
              CryptexEquation.fromJson(Map<String, dynamic>.from(v0 as Map)))
          .toList(),
      solution: (json['solution'] as List).map((v0) => v0 as int).toList(),
      initialValues:
          (json['initialValues'] as List).map((v0) => v0 as int).toList());

  final int dialCount;
  final List<CryptexEquation> equations;
  final List<int> solution;
  final List<int> initialValues;

  CryptexPuzzle({
    required this.dialCount,
    required this.equations,
    required this.solution,
    required this.initialValues,
  });

  static CryptexPuzzle generate(int grade, int level) {
    final complexity = grade + (level / 5.0);
    int dialCount;
    List<String> operators;

    if (complexity <= 2.0) {
      dialCount = 3;
      operators = ['+', '-'];
    } else if (complexity <= 3.5) {
      dialCount = generatorRandom().nextBool() ? 3 : 4;
      operators = ['+', '-', '*'];
    } else if (complexity <= 5.0) {
      dialCount = 4;
      operators = ['+', '-', '*', '/'];
    } else {
      dialCount = generatorRandom().nextBool() ? 4 : 5;
      operators = ['+', '-', '*', '/'];
    }

    return _generateSolvablePuzzle(dialCount, operators, grade);
  }

  static CryptexPuzzle _generateSolvablePuzzle(
      int dialCount, List<String> operators, int grade) {
    final random = generatorRandom();

    // Generate solution values (1-9 to avoid 0 complications)
    final solution = List.generate(dialCount, (_) => random.nextInt(9) + 1);

    // Generate equations that work with the solution
    final equations = <CryptexEquation>[];

    // Simple two-dial equations first
    for (int i = 0; i < dialCount - 1; i++) {
      final op = operators[random.nextInt(operators.length)];
      int result;

      switch (op) {
        case '+':
          result = solution[i] + solution[i + 1];
          break;
        case '-':
          result = (solution[i] - solution[i + 1]).abs();
          break;
        case '*':
          result = solution[i] * solution[i + 1];
          break;
        case '/':
          // Ensure clean division
          if (solution[i + 1] != 0 && solution[i] % solution[i + 1] == 0) {
            result = solution[i] ~/ solution[i + 1];
          } else {
            result = solution[i] + solution[i + 1]; // Fallback to addition
          }
          break;
        default:
          result = solution[i] + solution[i + 1];
      }

      equations.add(CryptexEquation(
        leftOperandIndices: [i, i + 1],
        operator: op == '/' &&
                (solution[i + 1] == 0 || solution[i] % solution[i + 1] != 0)
            ? '+'
            : op,
        rightSide: result,
        resultDialIndex: null,
      ));
    }

    // Add one more complex equation if we have enough dials
    if (dialCount >= 4) {
      final indices = [0, dialCount - 1];
      final op = [
        '+',
        '*'
      ][random.nextInt(2)]; // Simpler operations for complex equations
      final result = op == '+'
          ? solution[0] + solution[dialCount - 1]
          : solution[0] * solution[dialCount - 1];

      equations.add(CryptexEquation(
        leftOperandIndices: indices,
        operator: op,
        rightSide: result,
        resultDialIndex: null,
      ));
    }

    // Generate initial values (different from solution)
    final initialValues = List.generate(dialCount, (i) {
      int value;
      do {
        value = random.nextInt(10);
      } while (value == solution[i]);
      return value;
    });

    return CryptexPuzzle(
      dialCount: dialCount,
      equations: equations,
      solution: solution,
      initialValues: initialValues,
    );
  }
}

class CryptexEquation {
  /// Exact local-session snapshot, including mutable model state.
  Map<String, dynamic> toJson() => {
        'leftOperandIndices': leftOperandIndices.map((v0) => v0).toList(),
        'operator': operator,
        'rightSide': rightSide,
        'resultDialIndex': (resultDialIndex)
      };
  factory CryptexEquation.fromJson(Map<String, dynamic> json) =>
      CryptexEquation(
          leftOperandIndices: (json['leftOperandIndices'] as List)
              .map((v0) => v0 as int)
              .toList(),
          operator: json['operator'] as String,
          rightSide: json['rightSide'] as int,
          resultDialIndex: (json['resultDialIndex'] == null
              ? null
              : json['resultDialIndex'] as int));

  final List<int> leftOperandIndices;
  final String operator;
  final int rightSide;
  final int? resultDialIndex; // null if right side is constant

  CryptexEquation({
    required this.leftOperandIndices,
    required this.operator,
    required this.rightSide,
    this.resultDialIndex,
  });

  bool isSatisfied(List<int> dialValues) {
    final leftResult = _calculateLeftSide(dialValues);
    final rightResult =
        resultDialIndex != null ? dialValues[resultDialIndex!] : rightSide;
    return leftResult == rightResult;
  }

  int getCurrentResult(List<int> dialValues) {
    return _calculateLeftSide(dialValues);
  }

  /// Converts this equation into a standard MathProblem object using the puzzle's solution.
  /// This allows the SRI service to track the underlying math fact mastery.
  MathProblem toMathProblem(List<int> solutionValues) {
    // Ensure we have enough operands to create a valid problem
    if (leftOperandIndices.length < 2) {
      // Return a dummy problem if the equation is malformed
      return MathProblem(
          operandA: 0,
          operandB: 0,
          operation: MathOperation.addition,
          answer: 0,
          expression: 'error',
          difficulty: 1);
    }

    final opA = solutionValues[leftOperandIndices[0]];
    final opB = solutionValues[leftOperandIndices[1]];

    MathOperation op;
    switch (operator) {
      case '+':
        op = MathOperation.addition;
        break;
      case '-':
        op = MathOperation.subtraction;
        break;
      case '*':
        op = MathOperation.multiplication;
        break;
      case '/':
        op = MathOperation.division;
        break;
      default:
        op = MathOperation.addition;
    }

    return MathProblem(
      operandA: opA,
      operandB: opB,
      operation: op,
      answer: rightSide, // The equation's result is the problem's answer
      expression: '$opA $operator $opB',
      // The difficulty can be based on the operator or number size
      difficulty: (operator == '*' || operator == '/') ? 3 : 1,
    );
  }

  int _calculateLeftSide(List<int> dialValues) {
    if (leftOperandIndices.length < 2) return 0;

    final a = dialValues[leftOperandIndices[0]];
    final b = dialValues[leftOperandIndices[1]];

    switch (operator) {
      case '+':
        return a + b;
      case '-':
        return (a - b).abs();
      case '*':
        return a * b;
      case '/':
        return b != 0 ? (a ~/ b) : 0;
      default:
        return a + b;
    }
  }

  String getLeftSideDisplay() {
    final dialLabels =
        leftOperandIndices.map((i) => String.fromCharCode(65 + i)).toList();
    if (dialLabels.length >= 2) {
      return '${dialLabels[0]} $operator ${dialLabels[1]}';
    }
    return dialLabels.isNotEmpty ? dialLabels[0] : '?';
  }

  String getRightSideDisplay() {
    return resultDialIndex != null
        ? String.fromCharCode(65 + resultDialIndex!)
        : rightSide.toString();
  }

  @override
  String toString() {
    return '${getLeftSideDisplay()} = ${getRightSideDisplay()}';
  }
}
