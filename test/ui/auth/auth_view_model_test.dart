import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/application/chat/message_service_notifier.dart';
import 'package:flutter_rust_demo/data/repositories/auth_repository.dart';
import 'package:flutter_rust_demo/data/services/login_storage.dart';
import 'package:flutter_rust_demo/domain/models/auth.dart';
import 'package:flutter_rust_demo/providers/current_user_provider.dart';
import 'package:flutter_rust_demo/ui/auth/providers/auth_provider.dart';
import 'package:flutter_rust_demo/ui/auth/view_models/auth_view_model.dart';
import 'package:flutter_rust_demo/ui/chat/providers/message_service_provider.dart';

/// 记录 initialize/logout 调用，避免真实初始化 SDK。
class FakeMessageServiceNotifier extends MessageServiceNotifier {
  final List<Map<String, String?>> initializeCalls = [];
  int logoutCount = 0;

  @override
  MessageServiceState build() => MessageServiceState();

  @override
  Future<void> initialize({
    String? wsUrl,
    String? apiBaseUrl,
    String? userId,
    String? imToken,
  }) async {
    initializeCalls.add({
      'wsUrl': wsUrl,
      'apiBaseUrl': apiBaseUrl,
      'userId': userId,
      'imToken': imToken,
    });
  }

  @override
  Future<void> logout() async {
    logoutCount++;
  }
}

class FakeAuthRepository implements AuthRepository {
  bool failSendCode = false;
  bool failLogin = false;
  bool failRegister = false;
  AuthSession? loginSession = const AuthSession(userId: 'u1', imToken: 't1');
  AuthSession? registerSession = const AuthSession(
    userId: 'u2',
    imToken: 't2',
  );
  LoginCredentials? storedCredentials;
  final List<VerificationCodeUsage> sendCodeUsages = [];
  final List<Map<String, String?>> savedCredentials = [];
  int clearCount = 0;

  @override
  String get authBaseUrl => 'http://auth.test';

  @override
  Future<void> sendVerificationCode({
    required String areaCode,
    required String phoneNumber,
    required VerificationCodeUsage usedFor,
  }) async {
    sendCodeUsages.add(usedFor);
    if (failSendCode) throw Exception('发送失败');
  }

  @override
  Future<AuthSession> loginWithPassword({
    required String areaCode,
    required String phoneNumber,
    required String password,
    required int platform,
  }) async {
    if (failLogin) throw Exception('密码错误');
    return loginSession!;
  }

  @override
  Future<AuthSession> loginWithVerifyCode({
    required String areaCode,
    required String phoneNumber,
    required String verifyCode,
    required int platform,
  }) async {
    if (failLogin) throw Exception('验证码错误');
    return loginSession!;
  }

  @override
  Future<AuthSession> registerWithVerifyCode({
    required String areaCode,
    required String phoneNumber,
    required String nickname,
    required String verifyCode,
    required int platform,
  }) async {
    if (failRegister) throw Exception('注册失败');
    return registerSession!;
  }

  @override
  Future<void> saveCredentials({
    required String userId,
    required String imToken,
    String areaCode = '+86',
    String phoneNumber = '',
  }) async {
    savedCredentials.add({
      'userId': userId,
      'imToken': imToken,
      'areaCode': areaCode,
      'phoneNumber': phoneNumber,
    });
  }

  @override
  Future<LoginCredentials?> loadCredentials() async => storedCredentials;

  @override
  Future<void> clearCredentials() async {
    clearCount++;
  }
}

void main() {
  late ProviderContainer container;
  late FakeAuthRepository repository;
  late FakeMessageServiceNotifier messageService;

  setUp(() {
    repository = FakeAuthRepository();
    messageService = FakeMessageServiceNotifier();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        messageServiceProvider.overrideWith(() => messageService),
      ],
    );
    addTearDown(container.dispose);
  });

  AuthViewModel viewModel() => container.read(authViewModelProvider.notifier);
  AuthState state() => container.read(authViewModelProvider);

  group('sendCode', () {
    test('手机号为空时直接报错且不请求', () async {
      await viewModel().sendCode(
        areaCode: '+86',
        phoneNumber: '',
        usedFor: VerificationCodeUsage.login,
      );
      expect(state().errorText, '请先输入手机号');
      expect(repository.sendCodeUsages, isEmpty);
    });

    test('成功发送验证码后进入倒计时', () async {
      await viewModel().sendCode(
        areaCode: '+86',
        phoneNumber: '13800000000',
        usedFor: VerificationCodeUsage.login,
      );
      expect(state().countdown, 60);
      expect(state().errorText, isNull);
      expect(repository.sendCodeUsages, [VerificationCodeUsage.login]);
    });

    test('发送失败时清除倒计时并写入错误', () async {
      repository.failSendCode = true;
      await viewModel().sendCode(
        areaCode: '+86',
        phoneNumber: '13800000000',
        usedFor: VerificationCodeUsage.register,
      );
      expect(state().countdown, 0);
      expect(state().errorText, '发送失败');
    });
  });

  group('login', () {
    test('密码登录成功保存凭证并初始化 SDK', () async {
      final ok = await viewModel().loginWithPassword(
        areaCode: '+86',
        phoneNumber: '13800000000',
        password: '123456',
        wsUrl: 'ws://x',
        apiBaseUrl: 'http://x',
      );
      expect(ok, isTrue);
      expect(state().isLoading, isFalse);
      expect(repository.savedCredentials.single['userId'], 'u1');
      expect(repository.savedCredentials.single['imToken'], 't1');
      expect(
        messageService.initializeCalls.single,
        containsPair('userId', 'u1'),
      );
    });

    test('密码登录失败写入带请求地址的错误', () async {
      repository.failLogin = true;
      final ok = await viewModel().loginWithPassword(
        areaCode: '+86',
        phoneNumber: '13800000000',
        password: 'wrong',
        wsUrl: 'ws://x',
        apiBaseUrl: 'http://x',
      );
      expect(ok, isFalse);
      expect(state().isLoading, isFalse);
      expect(state().errorText, contains('密码错误'));
      expect(state().errorText, contains('http://auth.test'));
    });

    test('手机号或密码为空时直接返回 false', () async {
      final ok = await viewModel().loginWithPassword(
        areaCode: '+86',
        phoneNumber: '',
        password: '',
        wsUrl: 'ws://x',
        apiBaseUrl: 'http://x',
      );
      expect(ok, isFalse);
      expect(state().errorText, '请输入手机号和密码');
    });

    test('验证码登录成功返回 true', () async {
      final ok = await viewModel().loginWithVerifyCode(
        areaCode: '+86',
        phoneNumber: '13800000000',
        verifyCode: '666666',
        wsUrl: 'ws://x',
        apiBaseUrl: 'http://x',
      );
      expect(ok, isTrue);
      expect(messageService.initializeCalls.single['userId'], 'u1');
    });
  });

  group('register', () {
    test('注册成功保存凭证并初始化 SDK', () async {
      final ok = await viewModel().register(
        areaCode: '+86',
        phoneNumber: '13800000000',
        nickname: '张三',
        verifyCode: '666666',
        wsUrl: 'ws://x',
        apiBaseUrl: 'http://x',
      );
      expect(ok, isTrue);
      expect(repository.savedCredentials.single['userId'], 'u2');
      expect(messageService.initializeCalls.single['userId'], 'u2');
    });

    test('注册失败返回 false 并写入错误', () async {
      repository.failRegister = true;
      final ok = await viewModel().register(
        areaCode: '+86',
        phoneNumber: '13800000000',
        nickname: '张三',
        verifyCode: '666666',
        wsUrl: 'ws://x',
        apiBaseUrl: 'http://x',
      );
      expect(ok, isFalse);
      expect(state().errorText, '注册失败');
    });
  });

  group('autoLogin / logout', () {
    test('无本地凭证时返回 false', () async {
      final ok = await viewModel().autoLogin(
        wsUrl: 'ws://x',
        apiBaseUrl: 'http://x',
      );
      expect(ok, isFalse);
      expect(messageService.initializeCalls, isEmpty);
    });

    test('有本地凭证时初始化 SDK 并设置当前用户', () async {
      repository.storedCredentials = LoginCredentials(
        userId: 'u1',
        imToken: 't1',
        areaCode: '+86',
        phoneNumber: '13800000000',
      );
      final ok = await viewModel().autoLogin(
        wsUrl: 'ws://x',
        apiBaseUrl: 'http://x',
      );
      expect(ok, isTrue);
      expect(messageService.initializeCalls.single['userId'], 'u1');
      expect(container.read(currentUserIdProvider), 'u1');
    });

    test('logout 清除凭证与当前用户', () async {
      repository.storedCredentials = LoginCredentials(
        userId: 'u1',
        imToken: 't1',
      );
      await viewModel().autoLogin(wsUrl: 'ws://x', apiBaseUrl: 'http://x');
      await viewModel().logout();
      expect(messageService.logoutCount, 1);
      expect(repository.clearCount, 1);
      expect(container.read(currentUserIdProvider), '');
    });
  });
}
