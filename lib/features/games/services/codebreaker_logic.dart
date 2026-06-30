// ignore_for_file: constant_identifier_names, unused_element, unused_field
import 'dart:math' as math;

import 'package:dart_csp/dart_csp.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../constants/difficulty_manager.dart';

// DEVELOPMENT CONSTANT: Switch between generation approaches
const bool USE_CSP_GENERATION = false; // Set to false to use original algorithm

//##############################################################################
// ADVANCED PUZZLE GENERATION SYSTEM (Both Original and CSP approaches)
//##############################################################################

/// Represents a single equation with term1 op term2 = result
class PuzzleEquation {
  final dynamic term1; // String or int
  final String op;
  final dynamic term2; // String or int  
  final dynamic result; // String or int

  PuzzleEquation({
    required this.term1,
    required this.op,
    required this.term2,
    required this.result,
  });

  @override
  String toString() {
    return "$term1 $op $term2 = $result";
  }

  List<String> getSymbols() {
    final symbols = <String>[];
    if (term1 is String) symbols.add(term1 as String);
    if (term2 is String) symbols.add(term2 as String);
    if (result is String) symbols.add(result as String);
    return symbols.toSet().toList();
  }

  /// Returns true if this equation has both operands as visible numbers
  bool hasBothOperandsAsNumbers() {
    return term1 is int && term2 is int;
  }
}

/// Solves puzzles using iterative substitution (Original Algorithm)
class PuzzleSolver {
  bool verbose;
  
  PuzzleSolver({this.verbose = false});

  Map<String, int>? solve(List<PuzzleEquation> equations, List<String> allSymbols) {
    if (verbose) debugPrint("🧠 [SOLVER] Starting to solve puzzle with ${equations.length} equations and ${allSymbols.length} symbols");
    
    final knownValues = <String, int>{};
    
    if (verbose) {
      if (kDebugMode) debugPrint("🧠 [SOLVER] Equations to solve:");
      for (int i = 0; i < equations.length; i++) {
        debugPrint("🧠 [SOLVER]   Eq$i: ${equations[i]}");
      }
    }

    for (int iteration = 0; iteration < allSymbols.length + 1; iteration++) {
      if (verbose) debugPrint("🧠 [SOLVER] === Iteration ${iteration + 1} ===");
      
      bool newValuesFound = false;
      
      for (int eqIndex = 0; eqIndex < equations.length; eqIndex++) {
        final eq = equations[eqIndex];
        final unknowns = eq.getSymbols().where((s) => !knownValues.containsKey(s)).toList();
        
        if (verbose) debugPrint("🧠 [SOLVER] Eq$eqIndex: $eq -> unknowns: $unknowns");
        
        if (unknowns.length == 1) {
          final unknownSymbol = unknowns.first;
          if (knownValues.containsKey(unknownSymbol)) continue;
          
          try {
            final value = _solveFor(unknownSymbol, eq, knownValues);
            if (value != null && (value - value.round()).abs() < 1e-9) {
              final intValue = value.round();
              knownValues[unknownSymbol] = intValue;
              newValuesFound = true;
              if (verbose) debugPrint("🧠 [SOLVER] ✓ Solved: $unknownSymbol = $intValue");
            } else {
              if (verbose) debugPrint("🧠 [SOLVER] ✗ Could not solve for $unknownSymbol (value: $value)");
            }
          } catch (e) {
            if (verbose) debugPrint("🧠 [SOLVER] ✗ Error solving for $unknownSymbol: $e");
            return null;
          }
        }
      }
      
      if (knownValues.length == allSymbols.length) {
        if (verbose) debugPrint("🧠 [SOLVER] 🎉 All symbols solved! Final solution: $knownValues");
        return knownValues;
      }
      
      if (!newValuesFound) {
        if (verbose) debugPrint("🧠 [SOLVER] ❌ No new values found, terminating");
        break;
      }
    }
    
    if (verbose) debugPrint("🧠 [SOLVER] ❌ Failed to solve all symbols. Final known: $knownValues");
    return knownValues.length < allSymbols.length ? null : knownValues;
  }

  double? _solveFor(String symbol, PuzzleEquation eq, Map<String, int> known) {
    // Handle special cases where same symbol appears twice
    if (eq.term1 == symbol && eq.term2 == symbol) {
      final resVal = _getValue(eq.result, known);
      if (resVal != null) {
        switch (eq.op) {
          case '+': return resVal / 2;
          case '*': return resVal >= 0 ? math.sqrt(resVal) : null;
          default: return null;
        }
      }
      return null;
    }

    final t1 = _getValue(eq.term1, known);
    final t2 = _getValue(eq.term2, known);
    final res = _getValue(eq.result, known);
    
    // Check if we have non-symbol values that aren't our target
    if (eq.term1 != symbol && t1 == null) return null;
    if (eq.term2 != symbol && t2 == null) return null;
    if (eq.result != symbol && res == null) return null;
    
    if (symbol == eq.result) {
      if (t1 != null && t2 != null) {
        return _calculate(t1, t2, eq.op);
      }
    }
    
    if (symbol == eq.term1) {
      if (t2 != null && res != null) {
        switch (eq.op) {
          case '+': return res - t2;
          case '-': return res + t2;
          case '*': return t2 != 0 ? res / t2 : null;
          case '/': return res * t2;
          default: return null;
        }
      }
    }
    
    if (symbol == eq.term2) {
      if (t1 != null && res != null) {
        switch (eq.op) {
          case '+': return res - t1;
          case '-': return t1 - res;
          case '*': return t1 != 0 ? res / t1 : null;
          case '/': return res != 0 ? t1 / res : null;
          default: return null;
        }
      }
    }
    
    return null;
  }

  double? _getValue(dynamic term, Map<String, int> known) {
    if (term is int) return term.toDouble();
    if (term is String) return known[term]?.toDouble();
    return null;
  }

  double? _calculate(double v1, double v2, String op) {
    switch (op) {
      case '+': return v1 + v2;
      case '-': return v1 - v2;
      case '*': return v1 * v2;
      case '/': return v2 != 0 ? v1 / v2 : null;
      default: return null;
    }
  }
}

/// Advanced puzzle generator using both original and CSP approaches
class AdvancedPuzzleGenerator {
  final DifficultyConfig difficulty;
  final bool verbose;
  final bool useCSP;
  final Map<String, dynamic>? customSettings;
  final math.Random _random = math.Random();
  
  late Map<String, dynamic> params;
  List<String> symbols = [];
  Map<String, int> solution = {};
  late final PuzzleSolver solver;

  static const List<String> availableSymbols = [
    'nebula', 'star', 'galaxy', 'planet', 'rocket', 'satellite', 'comet', 
    'asteroid', 'sun', 'moon', 'supernova', 'blackhole', 'spaceship', 'alien', 'meteor'
  ];

  AdvancedPuzzleGenerator({
    required this.difficulty, 
    this.verbose = false,
    this.useCSP = USE_CSP_GENERATION,
    this.customSettings,
  }) {
    solver = PuzzleSolver(verbose: verbose);
    params = _getParams();
    if (verbose) debugPrint("🗂️ [GENERATOR] Initialized with difficulty ${difficulty.grade}, using ${useCSP ? 'CSP' : 'ORIGINAL'} approach, params: $params");
  }

  Map<String, dynamic> _getParams() {
    List<String> operatorStrings;
    List<int> valueRange;
    
    // Check if custom settings should be used
    if (customSettings != null && customSettings!['useCustomSettings'] == true) {
      // Use custom operations if provided
      final customOps = customSettings!['customOps'] as List<MathOperation>? ?? [];
      operatorStrings = customOps.map((op) {
        switch (op) {
          case MathOperation.addition: return '+';
          case MathOperation.subtraction: return '-';
          case MathOperation.multiplication: return '*';
          case MathOperation.division: return '/';
        }
      }).toList();
      
      // Use custom range if provided
      valueRange = [
        customSettings!['customMin'] as int? ?? difficulty.numberRange['min']!,
        customSettings!['customMax'] as int? ?? difficulty.numberRange['max']!,
      ];
    } else {
      // Use difficulty config
      operatorStrings = difficulty.operationTypes.map((op) {
        switch (op) {
          case MathOperation.addition: return '+';
          case MathOperation.subtraction: return '-';
          case MathOperation.multiplication: return '*';
          case MathOperation.division: return '/';
        }
      }).toList();
      
      valueRange = [
        difficulty.numberRange['min']!,
        difficulty.numberRange['max']!,
      ];
    }

    final int numSymbols, numEquations;
    final grade = difficulty.grade;

    if (grade >= 3) {
        numSymbols = 4;
        numEquations = 4;
    } else if (grade == 2) {
        numSymbols = 4;
        numEquations = 4;
    } else {
        numSymbols = 3;
        numEquations = 3;
    }

    return {
      'numSymbols': numSymbols,
      'valueRange': valueRange,
      'operators': operatorStrings.isNotEmpty ? operatorStrings : ['+'],
      'numEquations': numEquations,
    };
  }

  Future<List<PuzzleEquation>> generate() async {
    if (useCSP) {
      return _generateWithCSP();
    } else {
      return _generateOriginal(); // Call the correct method
    }
  }

  /// CSP-based generation approach
  Future<List<PuzzleEquation>> _generateWithCSP() async {
    const maxMainTries = 10;
    
    for (int attempt = 1; attempt <= maxMainTries; attempt++) {
      if (verbose) debugPrint("🗂️ [CSP GENERATOR] === Main generation attempt $attempt ===");
      
      try {
        // Step 1: Generate a valid solution (same as original)
        _generateSolutionKey();
        
        // Step 2: Create equations using the original proven logic
        final candidateEquations = _generatePuzzleCandidate();
        
        if (candidateEquations != null) {
          if (verbose) debugPrint("🗂️ [CSP GENERATOR] Testing candidate puzzle with CSP solver...");
          
          // Step 3: Verify with CSP solver (instead of iterative solver)
          final cspResult = await _validateWithCSP(candidateEquations);
          
          if (cspResult != null) {
            bool matches = true;
            for (final symbol in symbols) {
              if (cspResult[symbol] != solution[symbol]) {
                matches = false;
                break;
              }
            }
            
            if (matches) {
              if (verbose) debugPrint("🗂️ [CSP GENERATOR] 🎉 SUCCESS! Generated valid puzzle");
              return candidateEquations;
            } else {
              if (verbose) debugPrint("🗂️ [CSP GENERATOR] ❌ REJECTED: CSP result $cspResult doesn't match key $solution");
            }
          } else {
            if (verbose) debugPrint("🗂️ [CSP GENERATOR] ❌ REJECTED: CSP could not solve the puzzle");
          }
        } else {
          if (verbose) debugPrint("🗂️ [CSP GENERATOR] ❌ REJECTED: Could not generate candidate puzzle");
        }
        
      } catch (e) {
        if (verbose) debugPrint("🗂️ [CSP GENERATOR] ❌ Attempt $attempt failed: $e");
      }
    }
    
    throw Exception("CSP generation failed to generate a valid puzzle after $maxMainTries attempts");
  }

  List<PuzzleEquation>? _createKnownValidEquations() {
    final equations = <PuzzleEquation>[];
    final operators = params['operators'] as List<String>;
    final numEquations = params['numEquations'] as int;
    final valueRange = params['valueRange'] as List<int>;
    
    if (verbose) debugPrint("🗂️ [CSP GENERATOR] Creating equations for solution: $solution");
    
    // Strategy: Create equations that naturally work with mathematical relationships
    final symbolsList = symbols.toList();
    
    // First, try to create some basic relationships
    for (int attempt = 0; attempt < 50 && equations.length < numEquations; attempt++) {
      final s1 = symbolsList[_random.nextInt(symbolsList.length)];
      final s2 = symbolsList[_random.nextInt(symbolsList.length)];
      final s3 = symbolsList[_random.nextInt(symbolsList.length)];
      
      if (s1 == s2 || s1 == s3 || s2 == s3) continue;
      
      // Check if this combination already exists
      final existingEq = equations.any((eq) => 
        {eq.term1, eq.term2, eq.result}.containsAll({s1, s2, s3}));
      if (existingEq) continue;
      
      final v1 = solution[s1]!;
      final v2 = solution[s2]!;
      final v3 = solution[s3]!;
      
      // Try different arrangements and operators
      final arrangements = [
        [s1, s2, s3, v1, v2, v3], // s1 op s2 = s3
        [s1, s3, s2, v1, v3, v2], // s1 op s3 = s2  
        [s2, s1, s3, v2, v1, v3], // s2 op s1 = s3
        [s2, s3, s1, v2, v3, v1], // s2 op s3 = s1
        [s3, s1, s2, v3, v1, v2], // s3 op s1 = s2
        [s3, s2, s1, v3, v2, v1], // s3 op s2 = s1
      ];
      
      bool foundValid = false;
      for (final arr in arrangements) {
        final sym1 = arr[0] as String;
        final sym2 = arr[1] as String; 
        final symResult = arr[2] as String;
        final val1 = arr[3] as int;
        final val2 = arr[4] as int;
        final valResult = arr[5] as int;
        
        for (final op in operators) {
          bool isValid = false;
          switch (op) {
            case '+':
              isValid = (val1 + val2) == valResult;
              break;
            case '-':
              isValid = (val1 - val2) == valResult && val1 > val2;
              break;
            case '*':
              isValid = (val1 * val2) == valResult;
              break;
            case '/':
              isValid = val2 != 0 && val1 % val2 == 0 && (val1 ~/ val2) == valResult;
              break;
          }
          
          if (isValid) {
            equations.add(PuzzleEquation(
              term1: sym1,
              op: op,
              term2: sym2,
              result: symResult,
            ));
            if (verbose) debugPrint("🗂️ [CSP GENERATOR] Found valid equation: $sym1 $op $sym2 = $symResult ($val1 $op $val2 = $valResult)");
            foundValid = true;
            break;
          }
        }
        if (foundValid) break;
      }
      if (foundValid) break;
    }
    
    // If we still don't have enough equations, create some mixed number-symbol equations
    while (equations.length < numEquations) {
      const attempts = 20;
      bool found = false;
      
      for (int i = 0; i < attempts; i++) {
        final s1 = symbolsList[_random.nextInt(symbolsList.length)];
        final s2 = symbolsList[_random.nextInt(symbolsList.length)];
        if (s1 == s2) continue;
        
        final v1 = solution[s1]!;
        final v2 = solution[s2]!;
        
        // Try number op symbol = symbol  
        for (int num = valueRange[0]; num <= math.min(valueRange[1], 20); num++) {
          for (final op in operators) {
            int? result;
            switch (op) {
              case '+':
                result = num + v1;
                break;
              case '-':
                if (num > v1) result = num - v1;
                break;
              case '*':
                result = num * v1;
                break;
              case '/':
                if (v1 != 0 && num % v1 == 0) result = num ~/ v1;
                break;
            }
            
            if (result != null && result == v2 && result >= valueRange[0] && result <= valueRange[1]) {
              equations.add(PuzzleEquation(
                term1: num,
                op: op,
                term2: s1,
                result: s2,
              ));
              if (verbose) debugPrint("🗂️ [CSP GENERATOR] Found mixed equation: $num $op $s1 = $s2");
              found = true;
              break;
            }
          }
          if (found) break;
        }
        if (found) break;
      }
      
      if (!found) {
        if (verbose) debugPrint("🗂️ [CSP GENERATOR] Could not find enough valid equations");
        break;
      }
    }
    
    if (verbose) debugPrint("🗂️ [CSP GENERATOR] Created ${equations.length} equations");
    return equations.length >= math.min(numEquations, 2) ? equations : null; // Accept at least 2 equations
  }

  Future<Map<String, int>?> _validateWithCSP(List<PuzzleEquation> equations) async {
    final p = Problem();
    final valueRange = params['valueRange'] as List<int>;
    final domain = List<int>.generate(valueRange[1] - valueRange[0] + 1, (i) => i + valueRange[0]);
    
    // Add variables for symbols only
    for (final symbol in symbols) {
      p.addVariable(symbol, domain);
    }
    
    // Add equation constraints - handle mixed types
    for (final eq in equations) {
      // Collect only symbol variables for this constraint
      final symbolVars = <String>[];
      if (eq.term1 is String) symbolVars.add(eq.term1 as String);
      if (eq.term2 is String) symbolVars.add(eq.term2 as String);
      if (eq.result is String) symbolVars.add(eq.result as String);
      
      // Skip equations with no symbols (shouldn't happen, but safety check)
      if (symbolVars.isEmpty) continue;
      
      p.addConstraint(symbolVars, (assignment) {
        // Get actual values (symbols from assignment, numbers directly)
        final val1 = eq.term1 is String ? assignment[eq.term1] : (eq.term1 as int);
        final val2 = eq.term2 is String ? assignment[eq.term2] : (eq.term2 as int);
        final valResult = eq.result is String ? assignment[eq.result] : (eq.result as int);
        
        if (val1 == null || val2 == null || valResult == null) return false;
        
        switch (eq.op) {
          case '+': return (val1 + val2) == valResult;
          case '-': return (val1 - val2) == valResult;
          case '*': return (val1 * val2) == valResult;
          case '/': return val2 != 0 && val1 % val2 == 0 && (val1 ~/ val2) == valResult;
          default: return false;
        }
      });
    }
    
    // Add uniqueness constraints for symbols only
    for (int i = 0; i < symbols.length; i++) {
      for (int j = i + 1; j < symbols.length; j++) {
        p.addConstraint([symbols[i], symbols[j]], (a, b) => a != b);
      }
    }
    
    try {
      final result = await p.getSolution();
      if (result is Map<String, dynamic>) {
        return result.cast<String, int>();
      }
    } catch (e) {
      if (verbose) debugPrint("🗂️ [CSP] Validation error: $e");
    }

    return null;
  }

  bool _solutionsMatch(Map<String, int> cspSolution, Map<String, int> originalSolution) {
    for (final symbol in symbols) {
      if (cspSolution[symbol] != originalSolution[symbol]) {
        return false;
      }
    }
    return true;
  }

  List<PuzzleEquation>? _createEquationStructuresCSP(int numEquations) {
    final equations = <PuzzleEquation>[];
    final operators = params['operators'] as List<String>;
    final valueRange = params['valueRange'] as List<int>;
    final maxVal = valueRange[1];
    final minVal = valueRange[0];
    
    // Create equations using symbols strategically to ensure good interconnection
    final usedSymbols = <String>{};
    
    for (int i = 0; i < numEquations; i++) {
      // FILTER OPERATORS based on domain constraints
      final validOps = operators.where((op) {
        switch (op) {
          case '-':
            // For subtraction, ensure we can have meaningful differences within range
            return maxVal - minVal >= 1;
          case '/':
            // For division, ensure we have reasonable divisors
            return maxVal >= 2;
          case '*':
            // For multiplication, ensure products don't exceed range too quickly  
            return maxVal >= 4;
          default:
            return true;
        }
      }).toList();
      
      if (validOps.isEmpty) validOps.add('+'); // Fallback to addition
      
      final op = validOps[_random.nextInt(validOps.length)];
      
      String term1, term2, result;
      
      if (i == 0) {
        // First equation: use fresh symbols
        term1 = symbols[0];
        term2 = symbols[1]; 
        result = symbols[2];
      } else {
        // Subsequent equations: ensure at least one connection to previous equations
        final availableSymbols = symbols.where(usedSymbols.contains).toList();
        if (availableSymbols.isEmpty) {
          return null; // Cannot create connected equations
        }
        
        term1 = availableSymbols[_random.nextInt(availableSymbols.length)];
        
        // Choose term2 and result from unused symbols when possible
        final unusedSymbols = symbols.where((s) => !usedSymbols.contains(s)).toList();
        if (unusedSymbols.length >= 2) {
          term2 = unusedSymbols[0];
          result = unusedSymbols[1];
        } else if (unusedSymbols.length == 1) {
          term2 = unusedSymbols[0];
          result = symbols.where((s) => s != term1 && s != term2).first;
        } else {
          // All symbols used, create interconnected equations
          final otherSymbols = symbols.where((s) => s != term1).toList();
          otherSymbols.shuffle(_random);
          term2 = otherSymbols[0];
          result = otherSymbols[1];
        }
      }
      
      usedSymbols.addAll([term1, term2, result]);
      
      equations.add(PuzzleEquation(
        term1: term1,
        op: op,
        term2: term2,
        result: result,
      ));
    }
    
    return equations;
  }

  Future<Map<String, int>?> _solveWithCSPConstraints(List<PuzzleEquation> equations) async {
    final p = Problem();
    final valueRange = params['valueRange'] as List<int>;
    final domain = List<int>.generate(valueRange[1] - valueRange[0] + 1, (i) => i + valueRange[0]);
    
    // Add variables for each symbol
    for (final symbol in symbols) {
      p.addVariable(symbol, domain);
    }
    
    // Add equation constraints (3 variables - use Map signature)
    for (final eq in equations) {
      p.addConstraint([eq.term1 as String, eq.term2 as String, eq.result as String], (assignment) {
        final a = assignment[eq.term1];
        final b = assignment[eq.term2];
        final c = assignment[eq.result];
        if (a == null || b == null || c == null) return false;
        
        int calculatedResult;
        switch (eq.op) {
          case '+':
            calculatedResult = a + b;
            break;
          case '-':
            calculatedResult = a - b;
            break;
          case '*':
            calculatedResult = a * b;
            break;
          case '/':
            if (b == 0 || a % b != 0) return false;
            calculatedResult = a ~/ b;
            break;
          default:
            return false;
        }
        
        // Ensure the calculated result is within domain AND matches the result variable
        return calculatedResult >= valueRange[0] && 
              calculatedResult <= valueRange[1] && 
              calculatedResult == c;
      });
    }
    
    // FIX: Add pairwise constraints using direct function signature for 2 variables
    for (int i = 0; i < symbols.length; i++) {
      for (int j = i + 1; j < symbols.length; j++) {
        p.addConstraint([symbols[i], symbols[j]], (a, b) => a != b);
      }
    }
    
    // Solve with CSP
    try {
      final result = await p.getSolution();
      if (result is Map<String, dynamic>) {
        return result.cast<String, int>();
      }
    } catch (e) {
      if (verbose) debugPrint("🗂️ [CSP] Error solving: $e");
    }

    return null;
  }

  /// ORIGINAL generation approach (kept for comparison)
  List<PuzzleEquation> _generateOriginal() {
    const maxMainTries = 100;
    
    for (int attempt = 1; attempt <= maxMainTries; attempt++) {
      if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] === Main generation attempt $attempt ===");
      
      _generateSolutionKey();
      final candidateEquations = _generatePuzzleCandidate();
      
      if (candidateEquations != null) {
        if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Testing candidate puzzle with solver...");
        
        final solverResult = solver.solve(candidateEquations, symbols);
        
        if (solverResult != null) {
          bool matches = true;
          for (final symbol in symbols) {
            if (solverResult[symbol] != solution[symbol]) {
              matches = false;
              break;
            }
          }
          
          if (matches) {
            if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] 🎉 SUCCESS! Generated valid puzzle");
            return candidateEquations;
          } else {
            if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] ❌ REJECTED: Solver result $solverResult doesn't match key $solution");
          }
        } else {
          if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] ❌ REJECTED: Solver could not solve the puzzle");
        }
      } else {
        if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] ❌ REJECTED: Could not generate candidate puzzle");
      }
    }
    
    throw Exception("Original generation failed to generate a valid puzzle after $maxMainTries attempts");
  }

  void _generateSolutionKey() {
    final numSymbols = params['numSymbols'] as int;
    final valueRange = params['valueRange'] as List<int>;
    
    // For CSP, use smaller values that are more likely to have relationships
    final effectiveMin = useCSP ? math.max(valueRange[0], 1) : valueRange[0];
    final effectiveMax = useCSP ? math.min(valueRange[1], 30) : valueRange[1]; // Limit to 30 for CSP
    
    symbols = List.from(availableSymbols)..shuffle(_random);
    symbols = symbols.take(numSymbols).toList();
    
    final values = <int>[];
    for (int i = effectiveMin; i <= effectiveMax; i++) {
      values.add(i);
    }
    values.shuffle(_random);
    
    solution = {};
    for (int i = 0; i < numSymbols; i++) {
      solution[symbols[i]] = values[i];
    }
    
    if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Generated solution key: $solution");
  }

  List<PuzzleEquation> _createEquationPool() {
    if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Creating equation pool...");
    
    final pool = <PuzzleEquation>[];
    final eqStrings = <String>{};
    final valueToSymbol = <int, String>{};
    
    for (final entry in solution.entries) {
      valueToSymbol[entry.value] = entry.key;
    }
    
    final operators = params['operators'] as List<String>;
    
    // Generate ALL types of equations: symbol-symbol with ANY result
    for (final s1 in symbols) {
      for (final s2 in symbols) {
        for (final op in operators) {
          final v1 = solution[s1]!;
          final v2 = solution[s2]!;
          
          if (op == '-' && v1 < v2) continue;
          if (op == '/' && (v2 == 0 || v1 % v2 != 0)) continue;
          
          final resVal = _calculateInt(v1, v2, op);
          
          // Result can be either a symbol OR a number - both are fine!
          final result = valueToSymbol[resVal] ?? resVal;
          
          final eq = PuzzleEquation(term1: s1, op: op, term2: s2, result: result);
          final eqStr = eq.toString();
          
          if (!eqStrings.contains(eqStr)) {
            pool.add(eq);
            eqStrings.add(eqStr);
            if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Added symbol-symbol: $eq");
          }
        }
      }
    }
    
    if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Created equation pool with ${pool.length} equations");
    return pool;
  }

  List<PuzzleEquation>? _generatePuzzleCandidate() {
    if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Assembling puzzle candidate with connectivity...");
    
    final pool = _createEquationPool();
    
    // Categorize equations by quality
    // Best: Both operands are symbols (result can be anything)
    final bestEquations = pool.where((eq) => 
      eq.term1 is String && eq.term2 is String
    ).toList();
    
    if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Available equations with symbol operands: ${bestEquations.length}");
    
    if (bestEquations.length < 4) {
      if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Not enough good equations available");
      return null;
    }
    
    bestEquations.shuffle(_random);
    
    final puzzle = <PuzzleEquation>[];
    final knownSymbols = <String>{};
    
    // Find entry points with at most 2 unknown symbols
    final entryPoints = bestEquations.where((eq) {
      final symbolCount = eq.getSymbols().length;
      return symbolCount <= 2;
    }).toList();
    
    if (entryPoints.isEmpty) {
      if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] No valid entry points");
      return null;
    }
    
    final firstEq = entryPoints[_random.nextInt(entryPoints.length)];
    puzzle.add(firstEq);
    bestEquations.remove(firstEq);
    knownSymbols.addAll(firstEq.getSymbols());
    
    if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Starting with: $firstEq, known symbols: $knownSymbols");
    
    // Build the chain
    final numSymbols = params['numSymbols'] as int;
    while (knownSymbols.length < numSymbols) {
      PuzzleEquation? nextLink;
      
      for (final eq in bestEquations) {
        final eqSymbols = eq.getSymbols().toSet();
        final newSymbols = eqSymbols.difference(knownSymbols.toSet());
        final connectingSymbols = eqSymbols.intersection(knownSymbols.toSet());
        
        if (newSymbols.length == 1 && connectingSymbols.isNotEmpty) {
          nextLink = eq;
          break;
        }
      }
      
      if (nextLink != null) {
        puzzle.add(nextLink);
        bestEquations.remove(nextLink);
        knownSymbols.addAll(nextLink.getSymbols());
        if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Added: $nextLink, known symbols: $knownSymbols");
      } else {
        if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Could not find connecting equation");
        return null;
      }
    }
    
    // Add filler equations
    final numEquations = params['numEquations'] as int;
    while (puzzle.length < numEquations) {
      PuzzleEquation? filler;
      
      for (final eq in bestEquations) {
        final eqSymbols = eq.getSymbols().toSet();
        if (eqSymbols.difference(knownSymbols.toSet()).isEmpty) {
          filler = eq;
          break;
        }
      }
      
      if (filler != null) {
        puzzle.add(filler);
        bestEquations.remove(filler);
        if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Added filler: $filler");
      } else {
        break;
      }
    }
    
    puzzle.shuffle(_random);
    if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Final puzzle candidate: ${puzzle.map((e) => e.toString()).toList()}");
    
    return puzzle;
  }

  int _calculateInt(int v1, int v2, String op) {
    switch (op) {
      case '+': return v1 + v2;
      case '-': return v1 - v2;
      case '*': return v1 * v2;
      case '/': return v1 ~/ v2;
      default: throw Exception("Unknown operator: $op");
    }
  }
}

/// Main puzzle data structure (unchanged)
/// Main puzzle data structure - MODIFIED to track visible positions
class AdvancedCodebreakerPuzzle {
  final Map<String, int> knownSymbolValues; // Keep for backward compatibility but won't use much
  final List<PuzzleEquation> equations;
  final Set<String> hiddenSymbols;
  final List<int> numberPool;
  final List<String> hiddenPositions;
  final Map<String, int> _fullSolution;
  final Set<String> visiblePositions; // NEW: Track specific visible positions

  AdvancedCodebreakerPuzzle({
    required this.knownSymbolValues,
    required this.equations,
    required this.hiddenSymbols,
    required this.numberPool,
    required this.hiddenPositions,
    required Map<String, int> fullSolution,
    required this.visiblePositions, // NEW parameter
  }) : _fullSolution = fullSolution;

  Map<String, int> get fullSolution => _fullSolution;

  static Future<AdvancedCodebreakerPuzzle> generate(Map<String, dynamic> args) async {
    if (kDebugMode) debugPrint("🎯 [PUZZLE FACTORY] Starting puzzle generation with args: $args");
    
    final difficultyConfig = args['difficulty'] as DifficultyConfig;
    final useCSP = args['useCSP'] as bool;
    
    if (kDebugMode) debugPrint("🎯 [PUZZLE FACTORY] Using ${useCSP ? 'CSP' : 'ORIGINAL'} generation approach");
    
    // FIX: Handle the enum conversion properly
    final customOpsRaw = args['customOps'] as List<dynamic>;
    final customOps = customOpsRaw.map((op) {
      if (op is MathOperation) return op;
      // Handle string conversion from compute serialization
      if (op is String) {
        switch (op) {
          case 'addition': return MathOperation.addition;
          case 'subtraction': return MathOperation.subtraction;
          case 'multiplication': return MathOperation.multiplication;
          case 'division': return MathOperation.division;
          default: return MathOperation.addition;
        }
      }
      return MathOperation.addition; // fallback
    }).toList();
    
    final customSettings = {
      'useCustomSettings': args['useCustomSettings'] as bool,
      'customOps': customOps,
      'customMin': args['customMin'] as int,
      'customMax': args['customMax'] as int,
    };

    final generator = AdvancedPuzzleGenerator(
      difficulty: difficultyConfig, 
      verbose: true,
      useCSP: useCSP,
      customSettings: customSettings,
    );

    final puzzleEquations = await generator.generate();

    // VALIDATE that the generated solution actually works
    final testSolver = PuzzleSolver(verbose: true);
    final validationResult = testSolver.solve(puzzleEquations, generator.symbols);
    
    if (validationResult == null) {
      throw Exception("Generated puzzle has no valid solution");
    }
    
    // Verify the validation matches the generator's solution
    for (final symbol in generator.symbols) {
      if (validationResult[symbol] != generator.solution[symbol]) {
        throw Exception("Solution mismatch for symbol $symbol: expected ${generator.solution[symbol]}, got ${validationResult[symbol]}");
      }
    }
    
    if (kDebugMode) debugPrint("🎯 [PUZZLE FACTORY] Solution validation passed ✓");
    debugPrint("🎯 [PUZZLE FACTORY] Generated ${puzzleEquations.length} equations");
    
    final allSymbols = generator.symbols;
    
    // NEW: Select visible positions (not symbols)
    final visiblePositions = _selectVisiblePositions(puzzleEquations, allSymbols);
    
    if (kDebugMode) debugPrint("🎯 [PUZZLE FACTORY] Visible positions: $visiblePositions");
    
    // Build known values map only for visible positions
    final knownValues = <String, int>{};
    for (final pos in visiblePositions) {
      final symbol = _getSymbolFromPosition(puzzleEquations, pos);
      if (symbol != null) {
        knownValues[pos] = generator.solution[symbol]!; // Store by position, not symbol
      }
    }
    
    // Determine which symbols are completely hidden (no visible positions)
    final symbolsWithVisiblePositions = <String>{};
    for (final pos in visiblePositions) {
      final symbol = _getSymbolFromPosition(puzzleEquations, pos);
      if (symbol != null) symbolsWithVisiblePositions.add(symbol);
    }
    final hiddenSymbols = allSymbols.toSet().difference(symbolsWithVisiblePositions);

    // Collect ALL hidden positions (even for symbols that have some visible
    // positions elsewhere). The player needs the value in the pool for every
    // position they must fill.
    final allSymbolPositions = <String>{};
    for (int i = 0; i < puzzleEquations.length; i++) {
      final eq = puzzleEquations[i];
      if (eq.term1 is String) allSymbolPositions.add('eq${i}_term1');
      if (eq.term2 is String) allSymbolPositions.add('eq${i}_term2');
      if (eq.result is String) allSymbolPositions.add('eq${i}_result');
    }
    final hiddenPositionIds = allSymbolPositions.difference(visiblePositions);

    // Build the correct numbers list from hidden positions (not symbols).
    // Use a Set for the pool so each distinct value appears once, but ensure
    // every needed value is present.
    final correctNumbersList = <int>[];
    for (final pos in hiddenPositionIds) {
      final symbol = _getSymbolFromPosition(puzzleEquations, pos);
      if (symbol != null) {
        correctNumbersList.add(generator.solution[symbol]!);
      }
    }
    final correctNumbersSet = correctNumbersList.toSet();
    final decoys = <int>{};
    final numberRange = generator.params['valueRange'] as List<int>;
    final maxVal = numberRange[1];

    if (kDebugMode) debugPrint("🎯 [PUZZLE FACTORY] Correct numbers needed: ${correctNumbersList.join(', ')}");

    // Generate strategic decoys
    for (final correct in correctNumbersSet) {
      for (int i = 1; i <= 2; i++) {
        if (correct - i > 0) decoys.add(correct - i);
        if (correct + i <= maxVal) decoys.add(correct + i);
      }
    }
    decoys.removeAll(correctNumbersSet);

    final random = math.Random();
    const targetPoolSize = 8;
    final requiredDecoys = targetPoolSize - correctNumbersList.length;

    while (decoys.length < requiredDecoys) {
      final randomDecoy = random.nextInt(maxVal) + 1;
      if (!correctNumbersSet.contains(randomDecoy)) {
        decoys.add(randomDecoy);
      }
    }

    final numberPool = <int>[];
    numberPool.addAll(correctNumbersList);
    numberPool.addAll(decoys.take(targetPoolSize - correctNumbersList.length));

    numberPool.shuffle();
    final finalPool = numberPool;

    if (kDebugMode) debugPrint("🎯 [PUZZLE FACTORY] Final number pool: ${finalPool.join(', ')}");
    
    // Build hidden positions (all symbol positions except visible ones)
    final hiddenPositions = <String>[];
    for (int i = 0; i < puzzleEquations.length; i++) {
      final eq = puzzleEquations[i];
      
      final pos1 = 'eq${i}_term1';
      final pos2 = 'eq${i}_term2';
      final posR = 'eq${i}_result';
      
      if (eq.term1 is String && !visiblePositions.contains(pos1)) {
        hiddenPositions.add(pos1);
      }
      if (eq.term2 is String && !visiblePositions.contains(pos2)) {
        hiddenPositions.add(pos2);
      }
      if (eq.result is String && !visiblePositions.contains(posR)) {
        hiddenPositions.add(posR);
      }
    }
    
    if (kDebugMode) debugPrint("🎯 [PUZZLE FACTORY] Hidden positions: $hiddenPositions");
    debugPrint("🎯 [PUZZLE FACTORY] Puzzle generation complete!");
    
    return AdvancedCodebreakerPuzzle(
      knownSymbolValues: knownValues,
      equations: puzzleEquations,
      hiddenSymbols: hiddenSymbols,
      numberPool: finalPool,
      hiddenPositions: hiddenPositions,
      fullSolution: generator.solution,
      visiblePositions: visiblePositions,
    );
  }

  /// Select which specific positions should be visible (max 1 per equation)
  /// Never reveal symbols in equations that already have number literals
  static Set<String> _selectVisiblePositions(List<PuzzleEquation> equations, List<String> allSymbols) {
    final visiblePositions = <String>{};
    final random = math.Random();
    
    // Find equations that are "pure" (all terms are symbols, no number literals)
    final pureEquations = <int>[];
    for (int i = 0; i < equations.length; i++) {
      final eq = equations[i];
      final hasNoNumbers = (eq.term1 is String) && (eq.term2 is String) && (eq.result is String);
      if (hasNoNumbers) {
        pureEquations.add(i);
      }
    }
    
    if (kDebugMode) debugPrint("🎯 [CLUE SELECTION] Pure symbol equations: $pureEquations out of ${equations.length}");
    
    // Only reveal from pure equations, max 1 position total
    if (pureEquations.isNotEmpty) {
      final selectedEq = pureEquations[random.nextInt(pureEquations.length)];
      final eq = equations[selectedEq];
      
      final symbolPositions = <String>[];
      if (eq.term1 is String) symbolPositions.add('eq${selectedEq}_term1');
      if (eq.term2 is String) symbolPositions.add('eq${selectedEq}_term2');
      if (eq.result is String) symbolPositions.add('eq${selectedEq}_result');
      
      if (symbolPositions.isNotEmpty) {
        final posToReveal = symbolPositions[random.nextInt(symbolPositions.length)];
        visiblePositions.add(posToReveal);
        if (kDebugMode) debugPrint("🎯 [CLUE SELECTION] Revealing position: $posToReveal");
      }
    } else {
      debugPrint("🎯 [CLUE SELECTION] No pure equations available, puzzle will be harder!");
    }
    
    return visiblePositions;
  }

  static String? _getSymbolFromPosition(List<PuzzleEquation> equations, String positionId) {
    final parts = positionId.split('_');
    final eqIndex = int.parse(parts[0].substring(2));
    final termType = parts[1];
    
    if (eqIndex >= equations.length) return null;
    final equation = equations[eqIndex];
    
    switch (termType) {
      case 'term1':
        return equation.term1 is String ? equation.term1 as String : null;
      case 'term2':
        return equation.term2 is String ? equation.term2 as String : null;
      case 'result':
        return equation.result is String ? equation.result as String : null;
      default:
        return null;
    }
  }

  bool validateSolution(Map<String, int> userSolution) {
    if (kDebugMode) debugPrint("✅ [VALIDATION] Starting solution validation");
    debugPrint("✅ [VALIDATION] User solution: $userSolution");
    debugPrint("✅ [VALIDATION] Full solution: $_fullSolution");
    
    for (final entry in userSolution.entries) {
      final symbol = getSymbolFromPosition(entry.key);
      final expectedValue = _fullSolution[symbol];
      final userValue = entry.value;
      
      if (kDebugMode) debugPrint("✅ [VALIDATION] Position ${entry.key}: symbol=$symbol, user=$userValue, expected=$expectedValue");
      
      if (userValue != expectedValue) {
        debugPrint("✅ [VALIDATION] ❌ Validation failed: $symbol should be $expectedValue but user provided $userValue");
        return false;
      }
    }
    
    // Check all hidden positions are filled
    for (final pos in hiddenPositions) {
      if (!userSolution.containsKey(pos)) {
        if (kDebugMode) debugPrint("✅ [VALIDATION] ❌ Missing value for position $pos");
        return false;
      }
    }
    
    if (kDebugMode) debugPrint("✅ [VALIDATION] ✓ Solution is valid!");
    return true;
  }

  String getSymbolFromPosition(String positionId) {
    final parts = positionId.split('_');
    final eqIndex = int.parse(parts[0].substring(2));
    final termType = parts[1];
    
    final equation = equations[eqIndex];
    
    switch (termType) {
      case 'term1':
        return equation.term1 as String;
      case 'term2':
        return equation.term2 as String;
      case 'result':
        return equation.result as String;
      default:
        throw Exception("Invalid position ID: $positionId");
    }
  }
  
  // NEW: Check if a specific position is visible
  bool isPositionVisible(String positionId) {
    return visiblePositions.contains(positionId);
  }
  
  // NEW: Get value for a visible position
  int? getVisibleValue(String positionId) {
    if (!isPositionVisible(positionId)) return null;
    final symbol = getSymbolFromPosition(positionId);
    return _fullSolution[symbol];
  }
}
