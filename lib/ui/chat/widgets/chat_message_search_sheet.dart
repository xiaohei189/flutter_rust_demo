import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/extensions/message_ext.dart';
import '../../../../domain/models/user.dart';
import '../../../../generated/rust/model/local.dart' show LocalChatLog;
import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';
import '../providers/chat_detail_provider.dart';

/// 会话内消息搜索底部面板
class ChatMessageSearchSheet extends ConsumerStatefulWidget {
  const ChatMessageSearchSheet({
    super.key,
    required this.conversationId,
    this.onMessageTap,
  });

  final String conversationId;
  final ValueChanged<LocalChatLog>? onMessageTap;

  @override
  ConsumerState<ChatMessageSearchSheet> createState() =>
      _ChatMessageSearchSheetState();
}

class _ChatMessageSearchSheetState
    extends ConsumerState<ChatMessageSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<LocalChatLog> _results = const [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String keyword) {
    _debounce?.cancel();
    if (keyword.trim().isEmpty) {
      setState(() {
        _results = const [];
        _error = null;
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(keyword);
    });
  }

  Future<void> _search(String keyword) async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await ref
          .read(chatDetailViewModelProvider(widget.conversationId).notifier)
          .searchLocalMessages(keyword);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '搜索失败: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: '搜索聊天记录',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _controller.clear();
                            _onChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: colors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final colors = context.appColors;
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, style: TextStyle(color: colors.danger)),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(child: Text('没有找到相关消息'));
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
      itemBuilder: (_, i) {
        final log = _results[i];
        final rawTime = log.sendTime.toInt();
        final time = DateTime.fromMillisecondsSinceEpoch(
          rawTime > 0 && rawTime < 946684800000 ? rawTime * 1000 : rawTime,
        ).toLocal();
        return ListTile(
          leading: UserAvatar(
            user: User(
              id: log.sendId,
              name: log.senderNickName,
              avatar: log.senderFaceUrl.isNotEmpty ? log.senderFaceUrl : null,
            ),
            radius: 18,
          ),
          title: Text(
            log.displayText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${log.senderNickName.isNotEmpty ? log.senderNickName : log.sendId}  '
            '${time.toString().substring(0, 16)}',
            style: const TextStyle(fontSize: 12),
          ),
          onTap: () {
            Navigator.of(context).pop();
            widget.onMessageTap?.call(log);
          },
        );
      },
    );
  }
}
