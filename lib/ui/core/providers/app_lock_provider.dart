import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/app_lock_view_model.dart';

/// 应用锁 ViewModel Provider
final appLockViewModelProvider =
    NotifierProvider<AppLockViewModel, AppLockState>(AppLockViewModel.new);
