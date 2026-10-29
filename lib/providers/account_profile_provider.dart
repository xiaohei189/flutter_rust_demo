import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/repositories/account_profile_repository.dart';
import '../data/services/account_profile_api.dart';

final accountProfileApiProvider = Provider<AccountProfileApi>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return AccountProfileApi(client: client);
});

final accountProfileRepositoryProvider = Provider<AccountProfileRepository>((
  ref,
) {
  return AccountProfileRepositoryImpl(
    api: ref.watch(accountProfileApiProvider),
  );
});
