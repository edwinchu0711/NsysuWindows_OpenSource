import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_course_service.dart';

final localCourseServiceProvider = Provider<LocalCourseService>((ref) {
  return LocalCourseService.instance;
});