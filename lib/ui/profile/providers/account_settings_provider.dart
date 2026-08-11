import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/account_settings_view_model.dart';

/// 账号设置 ViewModel Provider
final accountSettingsViewModelProvider =
    NotifierProvider<AccountSettingsViewModel, AccountSettingsState>(
      AccountSettingsViewModel.new,
    );
