import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/group_info_view_model.dart';

/// 群信息 ViewModel Provider（按会话 ID）
final groupInfoViewModelProvider =
    NotifierProvider.family<GroupInfoViewModel, GroupInfoState, String>(
      GroupInfoViewModel.new,
    );
