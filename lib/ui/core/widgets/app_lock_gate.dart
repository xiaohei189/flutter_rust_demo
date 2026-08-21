import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/im_providers.dart';
import '../providers/app_lock_provider.dart';
import '../theme/app_theme.dart';
import '../view_models/app_lock_view_model.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  final TextEditingController _pinController = TextEditingController();
  late final AppLockViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ref.read(appLockViewModelProvider.notifier);
    ref
        .read(appLifecycleServiceProvider)
        .isBackground
        .addListener(_onLifecycleChanged);
    unawaited(_viewModel.load());
  }

  @override
  void dispose() {
    ref
        .read(appLifecycleServiceProvider)
        .isBackground
        .removeListener(_onLifecycleChanged);
    _pinController.dispose();
    super.dispose();
  }

  void _onLifecycleChanged() {
    if (ref.read(appLifecycleServiceProvider).isBackground.value) {
      _viewModel.lock();
    } else if (_viewModel.currentState.enabled == true) {
      _viewModel.lock();
    }
  }

  Future<void> _unlockWithPin() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;
    final ok = await _viewModel.unlockWithPin(pin);
    if (ok && mounted) {
      _pinController.clear();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_viewModel.currentState.error ?? 'PIN 不正确')),
      );
    }
  }

  Future<void> _unlockWithBiometrics() async {
    await _viewModel.unlockWithBiometrics();
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockViewModelProvider);
    if (!lockState.shouldShowLock) {
      return widget.child;
    }

    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 72, color: colors.primary),
                const SizedBox(height: 16),
                const Text(
                  '输入 PIN 解锁',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _pinController,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '4-6 位数字',
                    filled: true,
                    fillColor: colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _unlockWithPin(),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _unlockWithPin,
                  child: const Text('解锁'),
                ),
                if (lockState.biometricEnabled)
                  TextButton.icon(
                    onPressed: _unlockWithBiometrics,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('使用生物识别'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
