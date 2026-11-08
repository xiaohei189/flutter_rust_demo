import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/topics/topic_notification_controller.dart';
import '../../../domain/models/topic.dart';
import '../../core/theme/app_theme.dart';
import '../providers/topic_provider.dart';

class TopicGroupSettingsScreen extends ConsumerStatefulWidget {
  const TopicGroupSettingsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<TopicGroupSettingsScreen> createState() =>
      _TopicGroupSettingsScreenState();
}

class _TopicGroupSettingsScreenState
    extends ConsumerState<TopicGroupSettingsScreen> {
  TopicGroupSettings _settings = const TopicGroupSettings();
  int _version = 0;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await ref
          .read(topicRepositoryProvider)
          .getGroupSettings(widget.groupId);
      if (!mounted) return;
      setState(() {
        _settings = profile.settings;
        _version = profile.version;
        _loading = false;
        _error = null;
      });
      ref
          .read(topicNotificationsProvider.notifier)
          .updateGroupSettings(widget.groupId, profile.settings);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载话题群设置失败: $e';
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profile = await ref
          .read(topicRepositoryProvider)
          .setGroupSettings(
            groupId: widget.groupId,
            settings: _settings,
            expectedVersion: _version,
          );
      if (!mounted) return;
      setState(() {
        _settings = profile.settings;
        _version = profile.version;
        _saving = false;
      });
      ref
          .read(topicNotificationsProvider.notifier)
          .updateGroupSettings(widget.groupId, profile.settings);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('话题群设置已保存')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('话题群设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _version == 0
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('重试')),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                SwitchListTile(
                  title: const Text('成员可以发布话题'),
                  subtitle: const Text('关闭后仅群主和管理员可以发布'),
                  value: _settings.allowMemberPublish,
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                          () => _settings = _settings.copyWith(
                            allowMemberPublish: value,
                          ),
                        ),
                ),
                SwitchListTile(
                  title: const Text('成员可以回复话题'),
                  subtitle: const Text('关闭后仅群主和管理员可以回复'),
                  value: _settings.allowMemberReply,
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                          () => _settings = _settings.copyWith(
                            allowMemberReply: value,
                          ),
                        ),
                ),
                SwitchListTile(
                  title: const Text('首次查看自动订阅'),
                  subtitle: const Text('成员第一次打开话题时自动订阅'),
                  value: _settings.defaultSubscribe,
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                          () => _settings = _settings.copyWith(
                            defaultSubscribe: value,
                          ),
                        ),
                ),
                SwitchListTile(
                  title: const Text('成员可以 Pin 话题'),
                  subtitle: const Text('关闭后仅群主和管理员可以 Pin'),
                  value: _settings.allowMemberPin,
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                          () => _settings = _settings.copyWith(
                            allowMemberPin: value,
                          ),
                        ),
                ),
                SwitchListTile(
                  title: const Text('成员可以置顶话题'),
                  subtitle: const Text('关闭后成员只能取消自己客户端中的置顶展示'),
                  value: _settings.allowMemberGroupPin,
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                          () => _settings = _settings.copyWith(
                            allowMemberGroupPin: value,
                          ),
                        ),
                ),
                SwitchListTile(
                  title: const Text('通知新话题'),
                  subtitle: const Text('有新话题时写入话题通知中心'),
                  value: _settings.notifyNewTopic,
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                          () => _settings = _settings.copyWith(
                            notifyNewTopic: value,
                          ),
                        ),
                ),
                SwitchListTile(
                  title: const Text('通知话题回复'),
                  subtitle: const Text('有回复时写入话题通知中心'),
                  value: _settings.notifyReplies,
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                          () => _settings = _settings.copyWith(
                            notifyReplies: value,
                          ),
                        ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: TextStyle(color: context.appColors.danger),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? '保存中…' : '保存设置'),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '设置保存由服务端校验群主/管理员权限。通知策略仅影响话题通知中心，不绕过系统免打扰。',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }
}
