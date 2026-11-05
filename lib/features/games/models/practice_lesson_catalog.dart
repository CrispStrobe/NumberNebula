import 'practice_lesson.dart';
import 'lessons_numeric.dart';
import 'lessons_spatial.dart';
import 'lessons_action.dart';
export 'practice_lesson.dart';

/// One audited mechanic exercise per registered game; no generic fallback.
const practiceLessons = <String, PracticeLesson>{
  ...numericLessons,
  ...spatialLessons,
  ...actionLessons,
};
