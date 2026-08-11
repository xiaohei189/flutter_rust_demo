import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/search_view_model.dart';

/// 搜索数据源 Provider
final searchGatewayProvider = Provider<SearchGateway>((ref) {
  return RiverpodSearchGateway(ref);
});

/// 搜索 ViewModel Provider
final searchViewModelProvider = NotifierProvider<SearchViewModel, SearchState>(
  SearchViewModel.new,
);
