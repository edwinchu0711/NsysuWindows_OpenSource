import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/course_service.dart';

final courseServiceProvider = Provider<CourseService>((ref) {
  return CourseService.instance;
});