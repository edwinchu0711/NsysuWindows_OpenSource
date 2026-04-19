import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai/ai_service.dart';
import '../models/ai_config_model.dart';
import 'storage_provider.dart';

final aiServiceProvider = Provider.family<AiService, AiConfig>((ref, config) {
  return AiService(config: config);
});

// Current AI config — read from storage, defaults to empty
final aiConfigProvider = FutureProvider<List<AiConfig>>((ref) async {
  final storage = ref.watch(storageServiceProvider);
  final configsJson = await storage.read('ai_configs');
  if (configsJson == null || configsJson.isEmpty) return [];
  return AiConfig.decode(configsJson);
});