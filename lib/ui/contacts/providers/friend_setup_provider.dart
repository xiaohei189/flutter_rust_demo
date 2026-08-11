import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/friend_setup_view_model.dart';

/// 好友设置 ViewModel Provider（按用户 ID）
final friendSetupViewModelProvider =
    NotifierProvider.family<FriendSetupViewModel, FriendSetupState, String>(
      FriendSetupViewModel.new,
    );
