import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/reading_dao.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

final readingDaoProvider = Provider<ReadingDao>((ref) {
  final appDb = ref.watch(appDatabaseProvider);
  return ReadingDao(appDb);
});
