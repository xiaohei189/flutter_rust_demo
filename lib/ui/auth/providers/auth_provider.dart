import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/auth_view_model.dart';

/// 登录/注册 ViewModel Provider
final authViewModelProvider = NotifierProvider<AuthViewModel, AuthState>(
  AuthViewModel.new,
);
