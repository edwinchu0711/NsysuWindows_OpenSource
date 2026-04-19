import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/graduation_service.dart';

final graduationServiceProvider = Provider<GraduationService>((ref) {
  return GraduationService.instance;
});