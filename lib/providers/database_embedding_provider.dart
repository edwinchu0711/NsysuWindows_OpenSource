import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_embedding_service.dart';

final databaseEmbeddingServiceProvider = Provider<DatabaseEmbeddingService>((ref) {
  return DatabaseEmbeddingService.instance;
});