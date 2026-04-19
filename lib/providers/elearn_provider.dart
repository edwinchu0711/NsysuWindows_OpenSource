import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/exam_task/elearn_task_HW_service.dart';
import '../services/elearn_bulletin_service.dart';

final elearnServiceProvider = Provider<ElearnService>((ref) {
  return ElearnService.instance;
});

final elearnBulletinServiceProvider = Provider<ElearnBulletinService>((ref) {
  return ElearnBulletinService.instance;
});