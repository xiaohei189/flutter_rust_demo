import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/auth_repository.dart';
import '../view_models/auth_view_model.dart';

/// 认证仓库 Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return const AuthRepositoryImpl();
});

/// 登录/注册 ViewModel Provider
final authViewModelProvider = NotifierProvider<AuthViewModel, AuthState>(
  AuthViewModel.new,
);
