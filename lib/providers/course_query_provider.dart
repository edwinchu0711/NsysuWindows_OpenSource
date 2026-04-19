import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/course_query_service.dart';

final courseQueryServiceProvider = Provider<CourseQueryService>((ref) {
  return CourseQueryService.instance;
});