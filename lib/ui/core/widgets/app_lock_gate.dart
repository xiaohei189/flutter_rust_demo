import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/app_lifecycle_service.dart';
import '../../../providers/providers.dart';
import '../theme/app_theme.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  final TextEditingController _pinController = TextEditingController();
  bool? _enabled;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    AppLifecycleService.instance.isBackground.addListener(_onLifecycleChanged);
    _load();
  }

  @override
  void dispose() {
    AppLifecycleService.instance.isBackground.removeListener(
      _onLifecycleChanged,
    );
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final enabled = await ref.read(settingsRepositoryProvider).isAppLockEnabled();
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _unlocked = !enabled;
      });
    }
  }

  void _onLifecycleChanged() {
    if (AppLifecycleService.instance.isBackground.value) {
      _unlocked = false;
    } else if (_enabled == true) {
      _unlocked = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _unlockWithPin() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;
    final ok = await ref.read(settingsRepositoryProvider).verifyPin(pin);
    if (ok && mounted) {
      _pinController.clear();
      setState(() => _unlocked = true);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PIN 不正确')));
    }
  }

  Future<void> _unlockWithBiometrics() async {
    final ok = await ref
        .read(settingsRepositoryProvider)
        .authenticateWithBiometrics();
    if (ok && mounted) {
      setState(() => _unlocked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_enabled != true || _unlocked) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 72,
                  color: AppTheme.primaryColor,
                ),
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
                    fillColor: Colors.white,
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
                FutureBuilder<bool>(
                  future: ref
                      .read(settingsRepositoryProvider)
                      .isBiometricEnabled(),
                  builder: (context, snapshot) {
                    final enabled = snapshot.data ?? false;
                    if (!enabled) return const SizedBox.shrink();
                    return TextButton.icon(
                      onPressed: _unlockWithBiometrics,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('使用生物识别'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
