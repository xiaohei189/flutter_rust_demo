import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../ui/chat/mappers/message_display.dart';
import '../../../../domain/models/user.dart';
import '../../../../domain/models/message_search_result.dart'
    show MessageSearchResult;
import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';
import '../providers/chat_detail_provider.dart';
import 'message_search_filter.dart';

/// 会话内消息搜索底部面板
class ChatMessageSearchSheet extends ConsumerStatefulWidget {
  const ChatMessageSearchSheet({
    super.key,
    required this.conversationId,
    this.onMessageTap,
    this.initialFilter = ChatMessageSearchFilter.all,
  });

  final String conversationId;
  final ValueChanged<MessageSearchResult>? onMessageTap;
  final ChatMessageSearchFilter initialFilter;

  @override
  ConsumerState<ChatMessageSearchSheet> createState() =>
      _ChatMessageSearchSheetState();
}

class _ChatMessageSearchSheetState
    extends ConsumerState<ChatMessageSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<MessageSearchResult> _results = const [];
  bool _searching = false;
  String? _error;
  late ChatMessageSearchFilter _filter = widget.initialFilter;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String keyword) {
    _debounce?.cancel();
    if (keyword.trim().isEmpty && _filter == ChatMessageSearchFilter.all) {
      setState(() {
        _results = const [];
        _error = null;
        _searching = false;
      });
      return;
    }
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(keyword);
    });
  }

  void _onFilterChanged(ChatMessageSearchFilter filter) {
    if (filter == _filter) return;
    _debounce?.cancel();
    setState(() => _filter = filter);
    _search(_controller.text);
  }

  Future<void> _search(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty && _filter == ChatMessageSearchFilter.all) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _error = null;
        _searching = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final raw = await ref
          .read(chatDetailViewModelProvider(widget.conversationId).notifier)
          .searchLocalMessages(
            trimmed,
            messageTypes: _filter.messageTypes,
            // 纯类型浏览页多取一些，避免只看到最近的几条
            count: _filter == ChatMessageSearchFilter.all ? 50 : 200,
          );
      final results = _filter.needsLocalMatch
          ? raw.where(_filter.matches).toList(growable: false)
          : raw;
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
                  hintText: _filter.hint,
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
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final filter in ChatMessageSearchFilter.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(filter.label),
                        selected: filter == _filter,
                        showCheckmark: false,
                        onSelected: (_) => _onFilterChanged(filter),
                      ),
                    ),
                ],
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
      final idle =
          _filter == ChatMessageSearchFilter.all &&
          _controller.text.trim().isEmpty;
      return Center(child: Text(idle ? '输入关键字搜索聊天记录' : '没有找到相关消息'));
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
          leading: UserAvatar.fromUser(
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
