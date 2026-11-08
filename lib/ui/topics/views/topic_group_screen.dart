import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/group.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/topic.dart';
import '../../../application/chat/topic_event_revision_provider.dart';
import '../../../application/topics/topic_notification_controller.dart';
import '../../../router/app_router.dart';
import '../../chat/providers/conversation_provider.dart';
import '../../chat/providers/message_provider.dart';
import '../../chat/providers/message_service_provider.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/topic_group_theme.dart';
import '../../groups/providers/group_provider.dart';
import '../providers/topic_provider.dart';
import '../view_models/topic_group_view_model.dart';
import '../widgets/topic_chat_composer.dart';
import '../widgets/topic_common_dialogs.dart';
import '../widgets/topic_share_sheet.dart';

class TopicGroupScreen extends ConsumerStatefulWidget {
  const TopicGroupScreen({super.key, required this.conversationId, this.group});

  final String conversationId;
  final Group? group;

  @override
  ConsumerState<TopicGroupScreen> createState() => _TopicGroupScreenState();
}

class _TopicGroupScreenState extends ConsumerState<TopicGroupScreen> {
  String? _lastMessageId;
  String? _inlineReplyTopicId;

  String get _groupId => conversationId.startsWith('sg_')
      ? widget.conversationId.substring(3)
      : widget.conversationId;

  String get conversationId => widget.conversationId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadNotificationPolicy();
      ref.read(groupMemberProvider(_groupId).notifier).loadMembers();
    });
    ref.listenManual(messagesProvider(conversationId), (_, messages) {
      if (messages.isEmpty) return;
      final latest = messages.reduce(
        (left, right) => left.seq >= right.seq ? left : right,
      );
      if (latest.clientMsgId == _lastMessageId) return;
      _lastMessageId = latest.clientMsgId;
      ref.read(topicGroupProvider(_groupId).notifier).refresh();
    });
    ref.listenManual(topicEventRevisionProvider, (_, __) {
      ref.read(topicGroupProvider(_groupId).notifier).refresh();
    });
    ref.listenManual(topicReadRevisionProvider, (_, __) {
      ref.read(topicGroupProvider(_groupId).notifier).refresh();
    });
  }

  Future<void> _loadNotificationPolicy() async {
    try {
      final profile = await ref
          .read(topicRepositoryProvider)
          .getGroupSettings(_groupId);
      ref
          .read(topicNotificationsProvider.notifier)
          .updateGroupSettings(_groupId, profile.settings);
    } catch (_) {
      // 通知策略加载失败时沿用默认策略，不阻塞话题列表。
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final conversation = ref.watch(conversationByIdProvider(conversationId));
    final state = ref.watch(topicGroupProvider(_groupId));
    final memberState = ref.watch(groupMemberProvider(_groupId));
    final currentUserId = ref.watch(
      messageServiceProvider.select((service) => service.currentUserId),
    );
    final group = widget.group;
    final groupName = group?.groupName.isNotEmpty == true
        ? group!.groupName
        : conversation?.showName.isNotEmpty == true
        ? conversation!.showName
        : '话题群';
    final groupAvatar = group?.faceUrl.isNotEmpty == true
        ? group!.faceUrl
        : conversation?.faceUrl ?? '';
    final memberCount = group?.memberCount ?? memberState.members.length;
    final visualTheme = TopicGroupVisualTheme.forGroup(
      groupId: _groupId,
      groupEx: group?.ex ?? '',
      brightness: Theme.of(context).brightness,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          (visualTheme.useLightStatusBar
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: colors.surface,
                systemNavigationBarIconBrightness:
                    Theme.of(context).brightness == Brightness.dark
                    ? Brightness.light
                    : Brightness.dark,
              ),
      child: Scaffold(
        backgroundColor: visualTheme.headerColor,
        floatingActionButton: _inlineReplyTopicId != null
            ? null
            : FloatingActionButton(
                onPressed: () => _publish(context),
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 4,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, size: 30),
              ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopicGroupHeader(
                groupName: groupName,
                groupAvatar: groupAvatar,
                memberCount: memberCount,
                theme: visualTheme,
                onBack: () => Navigator.of(context).maybePop(),
                onPinned: () => _search(
                  context,
                  initialFilter: const TopicSearchFilter(pinnedOnly: true),
                ),
                onShare: () => _shareGroup(context, groupName),
                onMenuSelected: (value) =>
                    _handleGroupAction(context, value, groupName: groupName),
              ),
              Expanded(
                child: ColoredBox(
                  color: visualTheme.headerColor,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppTheme.radiusSheet),
                      ),
                    ),
                    child: Column(
                      children: [
                        _TopicTabs(
                          tab: state.tab,
                          onChanged: (tab) => ref
                              .read(topicGroupProvider(_groupId).notifier)
                              .setTab(tab),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () => ref
                                .read(topicGroupProvider(_groupId).notifier)
                                .refresh(),
                            child: _body(
                              context,
                              state,
                              currentUserId: currentUserId,
                              members: memberState.members,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    TopicGroupState state, {
    required String currentUserId,
    required List<GroupMember> members,
  }) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(child: Text(state.error!)),
        ],
      );
    }
    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: Text('还没有话题，发布第一个话题')),
        ],
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle &&
            _inlineReplyTopicId != null) {
          _setInlineReplyTopicId(null);
        }
        if (notification.metrics.extentAfter < 240) {
          ref.read(topicGroupProvider(_groupId).notifier).loadMore();
        }
        return false;
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: state.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = state.items[index];
          if (item.type == TopicFeedItemType.system) {
            return Container(
              width: double.infinity,
              color: context.appColors.surfaceMuted,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                item.systemEventText,
                style: TextStyle(
                  color: context.appColors.textSecondary,
                  fontSize: AppTheme.fontSizeSmall,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }
          final topic = item.topic;
          if (topic == null) return const SizedBox.shrink();
          return _TopicCard(
            topic: topic,
            conversationId: conversationId,
            groupId: _groupId,
            currentUserId: currentUserId,
            members: members,
            replyOpen: _inlineReplyTopicId == topic.topicId,
            onChanged: () =>
                ref.read(topicGroupProvider(_groupId).notifier).refresh(),
            onReplySent: _refreshAfterReply,
            onReplyStateChanged: (open) =>
                _setInlineReplyTopicId(open ? topic.topicId : null),
          );
        },
      ),
    );
  }

  void _setInlineReplyTopicId(String? topicId) {
    if (_inlineReplyTopicId == topicId) return;
    setState(() => _inlineReplyTopicId = topicId);
  }

  void _refreshAfterReply() {
    final notifier = ref.read(topicGroupProvider(_groupId).notifier);
    unawaited(notifier.refresh());
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (mounted) unawaited(notifier.refresh());
      }),
    );
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) unawaited(notifier.refresh());
      }),
    );
  }

  Future<void> _publish(BuildContext context) async {
    final published = await AppRouter.goToTopicCompose(
      context,
      groupId: _groupId,
    );
    if (published == true) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      ref.read(topicGroupProvider(_groupId).notifier).refresh();
    }
  }

  Future<void> _search(
    BuildContext context, {
    TopicSearchFilter initialFilter = const TopicSearchFilter(),
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appColors.surface,
      builder: (_) => _TopicSearchSheet(
        groupId: _groupId,
        hostContext: context,
        initialFilter: initialFilter,
      ),
    );
  }

  void _handleGroupAction(
    BuildContext context,
    String value, {
    required String groupName,
  }) {
    switch (value) {
      case 'settings':
        AppRouter.goToTopicSettings(context, groupId: _groupId);
      case 'notifications':
        AppRouter.goToTopicNotifications(context);
      case 'search':
        _search(context);
      case 'closed':
        _search(
          context,
          initialFilter: const TopicSearchFilter(
            state: TopicSearchState.closed,
          ),
        );
      case 'pinned':
        _search(
          context,
          initialFilter: const TopicSearchFilter(pinnedOnly: true),
        );
      case 'groupPinned':
        _search(
          context,
          initialFilter: const TopicSearchFilter(groupPinnedOnly: true),
        );
      case 'history':
        AppRouter.goToChatHistory(context, conversationId);
      case 'refresh':
        ref.read(topicGroupProvider(_groupId).notifier).refresh();
      case 'groupInfo':
        AppRouter.goToGroupInfoById(context, conversationId);
    }
  }

  Future<void> _shareGroup(BuildContext context, String groupName) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.appColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                groupName,
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link_rounded),
                title: const Text('复制群号'),
                subtitle: Text('群号 $_groupId'),
                onTap: () => Navigator.of(sheetContext).pop('copy'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('查看群资料'),
                onTap: () => Navigator.of(sheetContext).pop('info'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: _groupId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('群号已复制')));
    } else if (action == 'info') {
      AppRouter.goToGroupInfoById(context, conversationId);
    }
  }
}

class _TopicMetaBadge extends StatelessWidget {
  const _TopicMetaBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6, top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: AppTheme.fontSizeCaption,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _TopicFeedAction extends StatelessWidget {
  const _TopicFeedAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.label = '',
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 46,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 21, color: color),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: AppTheme.fontSizeSmall,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _formatTopicFeedTime(int milliseconds) {
  if (milliseconds <= 0) return '';
  final time = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  final clock =
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  final days = today.difference(day).inDays;
  if (days == 0) return clock;
  if (days == 1) return '昨天 $clock';
  if (time.year == now.year) return '${time.month}月${time.day}日 $clock';
  return '${time.year}年${time.month}月${time.day}日';
}

class _TopicSearchSheet extends ConsumerStatefulWidget {
  const _TopicSearchSheet({
    required this.groupId,
    required this.hostContext,
    this.initialFilter = const TopicSearchFilter(),
  });

  final String groupId;
  final BuildContext hostContext;
  final TopicSearchFilter initialFilter;

  @override
  ConsumerState<_TopicSearchSheet> createState() => _TopicSearchSheetState();
}

class _TopicSearchSheetState extends ConsumerState<_TopicSearchSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  List<Topic> _results = const [];
  late TopicSearchFilter _filter;
  TopicTab _tab = TopicTab.all;
  String _cursor = '';
  bool _hasMore = false;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _tab = ref.read(topicGroupProvider(widget.groupId)).tab;
    _filter = widget.initialFilter;
    _scrollController.addListener(_onScroll);
    Future.microtask(
      () =>
          ref.read(groupMemberProvider(widget.groupId).notifier).loadMembers(),
    );
    if (_filter.isActive) {
      Future.microtask(() => _search(reset: true));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final keyword = value.trim();
    if (keyword.isEmpty && !_filter.isActive) {
      setState(() {
        _results = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(reset: true);
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 180) {
      _search(reset: false);
    }
  }

  Future<void> _search({required bool reset}) async {
    if (!reset && (_loading || _loadingMore || !_hasMore)) return;
    final keyword = _controller.text.trim();
    if (keyword.isEmpty && !_filter.isActive) {
      setState(() {
        _results = const [];
        _cursor = '';
        _hasMore = false;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
      return;
    }
    final requestVersion = reset ? ++_requestVersion : _requestVersion;
    setState(() {
      _loading = reset;
      _loadingMore = !reset;
      _error = null;
    });
    try {
      final page = await ref
          .read(topicRepositoryProvider)
          .searchTopics(
            groupId: widget.groupId,
            keyword: keyword,
            tab: _tab,
            filter: _filter,
            cursor: reset ? '' : _cursor,
          );
      if (!mounted ||
          requestVersion != _requestVersion ||
          _controller.text.trim() != keyword) {
        return;
      }
      final seen = reset
          ? <String>{}
          : _results.map((item) => item.topicId).toSet();
      setState(() {
        _results = [
          if (!reset) ..._results,
          ...page.topics.where((item) => seen.add(item.topicId)),
        ];
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = '搜索失败: $e';
      });
    }
  }

  Future<void> _showFilters() async {
    final members = ref.read(groupMemberProvider(widget.groupId)).members;
    final selected = await showModalBottomSheet<TopicSearchFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appColors.surface,
      builder: (sheetContext) =>
          _TopicSearchFilterSheet(initial: _filter, members: members),
    );
    if (selected == null || !mounted) return;
    setState(() => _filter = selected);
    await _search(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final members = ref.watch(groupMemberProvider(widget.groupId)).members;
    final activeAuthor = members
        .where((member) => member.userId == _filter.authorId)
        .firstOrNull;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _onChanged,
                      decoration: const InputDecoration(
                        hintText: '搜索话题内容',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '筛选',
                    onPressed: _showFilters,
                    icon: Badge(
                      isLabelVisible: _filter.isActive,
                      child: const Icon(Icons.tune),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<TopicTab>(
                  segments: const [
                    ButtonSegment(value: TopicTab.all, label: Text('全部')),
                    ButtonSegment(
                      value: TopicTab.subscribed,
                      label: Text('我订阅的'),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (selection) {
                    setState(() => _tab = selection.first);
                    _search(reset: true);
                  },
                ),
              ),
              if (_filter.isActive) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (_filter.state != TopicSearchState.any)
                        InputChip(
                          label: Text(
                            _filter.state == TopicSearchState.open
                                ? '开放'
                                : '已关闭',
                          ),
                          onDeleted: () {
                            setState(
                              () => _filter = _filter.copyWith(
                                state: TopicSearchState.any,
                              ),
                            );
                            _search(reset: true);
                          },
                        ),
                      if (activeAuthor != null)
                        InputChip(
                          label: Text(
                            activeAuthor.nickname.isEmpty
                                ? activeAuthor.userId
                                : activeAuthor.nickname,
                          ),
                          onDeleted: () {
                            setState(
                              () =>
                                  _filter = _filter.copyWith(clearAuthor: true),
                            );
                            _search(reset: true);
                          },
                        ),
                      if (_filter.createdAfter > 0)
                        InputChip(
                          label: Text(_timeRangeLabel(_filter.createdAfter)),
                          onDeleted: () {
                            setState(
                              () => _filter = _filter.copyWith(
                                clearCreatedAfter: true,
                              ),
                            );
                            _search(reset: true);
                          },
                        ),
                      if (_filter.hasAttachments)
                        InputChip(
                          label: const Text('有附件'),
                          onDeleted: () {
                            setState(
                              () => _filter = _filter.copyWith(
                                hasAttachments: false,
                              ),
                            );
                            _search(reset: true);
                          },
                        ),
                      if (_filter.hasTasks)
                        InputChip(
                          label: const Text('有任务'),
                          onDeleted: () {
                            setState(
                              () => _filter = _filter.copyWith(hasTasks: false),
                            );
                            _search(reset: true);
                          },
                        ),
                      if (_filter.pinnedOnly)
                        InputChip(
                          label: const Text('仅 Pin'),
                          onDeleted: () {
                            setState(
                              () =>
                                  _filter = _filter.copyWith(pinnedOnly: false),
                            );
                            _search(reset: true);
                          },
                        ),
                      if (_filter.groupPinnedOnly)
                        InputChip(
                          label: const Text('仅置顶'),
                          onDeleted: () {
                            setState(
                              () => _filter = _filter.copyWith(
                                groupPinnedOnly: false,
                              ),
                            );
                            _search(reset: true);
                          },
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(child: Text(_error!))
                    : _results.isEmpty
                    ? Center(
                        child: Text(
                          _controller.text.trim().isEmpty && !_filter.isActive
                              ? '输入关键字或选择筛选条件'
                              : '没有找到匹配话题',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        itemCount: _results.length + (_loadingMore ? 1 : 0),
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          if (index >= _results.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final topic = _results[index];
                          return ListTile(
                            title: Text(
                              topic.rootPreview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${topic.creatorNickname.isEmpty ? '成员' : topic.creatorNickname}'
                              ' · ${topic.replyCount} 回复',
                            ),
                            trailing: topic.state == TopicState.closed
                                ? Text(
                                    '已关闭',
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                    ),
                                  )
                                : null,
                            onTap: () {
                              Navigator.of(context).pop();
                              AppRouter.goToTopicDetail(
                                widget.hostContext,
                                groupId: widget.groupId,
                                topicId: topic.topicId,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeRangeLabel(int createdAfter) {
    final age = DateTime.now().millisecondsSinceEpoch - createdAfter;
    if (age <= const Duration(days: 1).inMilliseconds) return '今天';
    if (age <= const Duration(days: 7).inMilliseconds) return '近 7 天';
    return '近 30 天';
  }
}

class _TopicSearchFilterSheet extends StatefulWidget {
  const _TopicSearchFilterSheet({required this.initial, required this.members});

  final TopicSearchFilter initial;
  final List<GroupMember> members;

  @override
  State<_TopicSearchFilterSheet> createState() =>
      _TopicSearchFilterSheetState();
}

class _TopicSearchFilterSheetState extends State<_TopicSearchFilterSheet> {
  late TopicSearchFilter _draft = widget.initial;

  int get _timeRangeDays {
    if (_draft.createdAfter <= 0) return 0;
    final age = DateTime.now().millisecondsSinceEpoch - _draft.createdAfter;
    if (age <= const Duration(days: 1).inMilliseconds) return 1;
    if (age <= const Duration(days: 7).inMilliseconds) return 7;
    return 30;
  }

  void _setTimeRange(int days) {
    setState(() {
      _draft = days == 0
          ? _draft.copyWith(clearCreatedAfter: true)
          : _draft.copyWith(
              createdAfter: DateTime.now()
                  .subtract(Duration(days: days))
                  .millisecondsSinceEpoch,
            );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '筛选话题',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _draft = const TopicSearchFilter()),
                    child: const Text('重置'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('状态', style: TextStyle(color: colors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('全部'),
                    selected: _draft.state == TopicSearchState.any,
                    onSelected: (_) => setState(
                      () =>
                          _draft = _draft.copyWith(state: TopicSearchState.any),
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('开放'),
                    selected: _draft.state == TopicSearchState.open,
                    onSelected: (_) => setState(
                      () => _draft = _draft.copyWith(
                        state: TopicSearchState.open,
                      ),
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('已关闭'),
                    selected: _draft.state == TopicSearchState.closed,
                    onSelected: (_) => setState(
                      () => _draft = _draft.copyWith(
                        state: TopicSearchState.closed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('作者', style: TextStyle(color: colors.textSecondary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _draft.authorId,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('全部作者')),
                  for (final member in widget.members)
                    DropdownMenuItem(
                      value: member.userId,
                      child: Text(
                        '${member.nickname.isEmpty ? member.userId : member.nickname} (${member.userId})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(
                  () => _draft = value == null || value.isEmpty
                      ? _draft.copyWith(clearAuthor: true)
                      : _draft.copyWith(authorId: value),
                ),
              ),
              const SizedBox(height: 18),
              Text('创建时间', style: TextStyle(color: colors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final item in const [
                    (0, '不限'),
                    (1, '今天'),
                    (7, '近 7 天'),
                    (30, '近 30 天'),
                  ])
                    ChoiceChip(
                      label: Text(item.$2),
                      selected: _timeRangeDays == item.$1,
                      onSelected: (_) => _setTimeRange(item.$1),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              FilterChip(
                label: const Text('有附件'),
                selected: _draft.hasAttachments,
                onSelected: (value) => setState(
                  () => _draft = _draft.copyWith(hasAttachments: value),
                ),
              ),
              const SizedBox(height: 8),
              FilterChip(
                label: const Text('有任务'),
                selected: _draft.hasTasks,
                onSelected: (value) =>
                    setState(() => _draft = _draft.copyWith(hasTasks: value)),
              ),
              const SizedBox(height: 8),
              FilterChip(
                label: const Text('仅 Pin'),
                selected: _draft.pinnedOnly,
                onSelected: (value) =>
                    setState(() => _draft = _draft.copyWith(pinnedOnly: value)),
              ),
              const SizedBox(height: 8),
              FilterChip(
                label: const Text('仅置顶'),
                selected: _draft.groupPinnedOnly,
                onSelected: (value) => setState(
                  () => _draft = _draft.copyWith(groupPinnedOnly: value),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_draft),
                  child: const Text('应用筛选'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicGroupHeader extends StatelessWidget {
  const _TopicGroupHeader({
    required this.groupName,
    required this.groupAvatar,
    required this.memberCount,
    required this.theme,
    required this.onBack,
    required this.onPinned,
    required this.onShare,
    required this.onMenuSelected,
  });

  final String groupName;
  final String groupAvatar;
  final int memberCount;
  final TopicGroupVisualTheme theme;
  final VoidCallback onBack;
  final VoidCallback onPinned;
  final VoidCallback onShare;
  final ValueChanged<String> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 18),
      child: Column(
        children: [
          Row(
            children: [
              _TopicHeaderIconButton(
                tooltip: '返回',
                icon: Icons.arrow_back_ios_new_rounded,
                foregroundColor: theme.foregroundColor,
                onPressed: onBack,
              ),
              const Spacer(),
              _TopicHeaderIconButton(
                tooltip: 'Pin 管理',
                icon: Icons.bookmarks_outlined,
                foregroundColor: theme.foregroundColor,
                onPressed: onPinned,
              ),
              _TopicHeaderMenuButton(
                foregroundColor: theme.foregroundColor,
                onSelected: onMenuSelected,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _TopicGroupHeroAvatar(
                groupAvatar: groupAvatar,
                groupName: groupName,
                theme: theme,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.foregroundColor,
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.group_outlined,
                          size: 17,
                          color: theme.foregroundColor.withValues(alpha: 0.88),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$memberCount',
                          style: TextStyle(
                            color: theme.foregroundColor.withValues(
                              alpha: 0.88,
                            ),
                            fontSize: AppTheme.fontSizeSmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onShare,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.foregroundColor,
                  side: BorderSide(
                    color: theme.foregroundColor.withValues(alpha: 0.72),
                  ),
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('分享'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopicGroupHeroAvatar extends StatelessWidget {
  const _TopicGroupHeroAvatar({
    required this.groupAvatar,
    required this.groupName,
    required this.theme,
  });

  final String groupAvatar;
  final String groupName;
  final TopicGroupVisualTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.foregroundColor.withValues(alpha: 0.72),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: groupAvatar.isNotEmpty
            ? UserAvatar(
                avatarUrl: groupAvatar,
                cacheKey: groupName,
                fallbackName: groupName,
                radius: 27,
              )
            : ColoredBox(
                color: theme.foregroundColor.withValues(alpha: 0.14),
                child: Icon(
                  Icons.groups_rounded,
                  size: 30,
                  color: theme.foregroundColor,
                ),
              ),
      ),
    );
  }
}

class _TopicHeaderIconButton extends StatelessWidget {
  const _TopicHeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.foregroundColor,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color foregroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Icon(icon, size: 24, color: foregroundColor);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: foregroundColor.withValues(alpha: 0.1),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(width: 42, height: 42, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}

class _TopicHeaderMenuButton extends StatelessWidget {
  const _TopicHeaderMenuButton({
    required this.foregroundColor,
    required this.onSelected,
  });

  final Color foregroundColor;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: foregroundColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: PopupMenuButton<String>(
          tooltip: '话题群管理',
          onSelected: onSelected,
          icon: Icon(Icons.more_horiz_rounded, color: foregroundColor),
          padding: EdgeInsets.zero,
          color: colors.surface,
          surfaceTintColor: colors.surface,
          shadowColor: colors.shadow,
          elevation: 12,
          offset: const Offset(0, 8),
          position: PopupMenuPosition.under,
          constraints: const BoxConstraints(minWidth: 228, maxWidth: 240),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: BorderSide(color: colors.divider, width: 0.5),
          ),
          itemBuilder: (_) => [
            _menuItem(
              context,
              value: 'settings',
              icon: Icons.tune_rounded,
              label: '话题群设置',
            ),
            _menuItem(
              context,
              value: 'groupInfo',
              icon: Icons.info_outline_rounded,
              label: '查看群资料',
            ),
            _menuItem(
              context,
              value: 'search',
              icon: Icons.search_rounded,
              label: '搜索话题',
            ),
            _menuItem(
              context,
              value: 'notifications',
              icon: Icons.notifications_none_rounded,
              label: '话题通知',
            ),
            PopupMenuDivider(height: 9, thickness: 0.5, color: colors.divider),
            _menuItem(
              context,
              value: 'closed',
              icon: Icons.lock_outline_rounded,
              label: '已关闭话题',
            ),
            _menuItem(
              context,
              value: 'pinned',
              icon: Icons.push_pin_outlined,
              label: 'Pin 管理',
            ),
            _menuItem(
              context,
              value: 'groupPinned',
              icon: Icons.vertical_align_top_rounded,
              label: '置顶话题',
            ),
            _menuItem(
              context,
              value: 'history',
              icon: Icons.history_rounded,
              label: '历史消息',
            ),
            PopupMenuDivider(height: 9, thickness: 0.5, color: colors.divider),
            _menuItem(
              context,
              value: 'refresh',
              icon: Icons.refresh_rounded,
              label: '刷新话题',
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    BuildContext context, {
    required String value,
    required IconData icon,
    required String label,
  }) {
    final colors = context.appColors;
    return PopupMenuItem<String>(
      value: value,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(icon, size: 19, color: colors.textSecondary),
          const SizedBox(width: 11),
          Text(
            label,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: AppTheme.fontSizeBody,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicTabs extends StatelessWidget {
  const _TopicTabs({required this.tab, required this.onChanged});

  final TopicTab tab;
  final ValueChanged<TopicTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.appColors.surface,
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        children: [
          _tab(context, TopicTab.all, '全部'),
          _tab(context, TopicTab.subscribed, '我订阅的'),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, TopicTab value, String label) {
    final selected = value == tab;
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? context.appColors.primary
                    : context.appColors.textSecondary,
                fontSize: AppTheme.fontSizeBody,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 24,
              height: 3,
              decoration: BoxDecoration(
                color: selected
                    ? context.appColors.primary
                    : context.appColors.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicCard extends ConsumerStatefulWidget {
  const _TopicCard({
    required this.topic,
    required this.conversationId,
    required this.groupId,
    required this.currentUserId,
    required this.members,
    required this.replyOpen,
    required this.onChanged,
    required this.onReplySent,
    required this.onReplyStateChanged,
  });

  final Topic topic;
  final String conversationId;
  final String groupId;
  final String currentUserId;
  final List<GroupMember> members;
  final bool replyOpen;
  final VoidCallback onChanged;
  final VoidCallback onReplySent;
  final ValueChanged<bool> onReplyStateChanged;

  @override
  ConsumerState<_TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends ConsumerState<_TopicCard> {
  Topic get topic => widget.topic;
  String get conversationId => widget.conversationId;
  String get groupId => widget.groupId;
  VoidCallback get onChanged => widget.onChanged;
  bool get _replying => widget.replyOpen;

  void _setReplying(bool value) {
    widget.onReplyStateChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final conversation = ref.watch(conversationByIdProvider(conversationId));
    final creator = topic.creatorNickname.isEmpty
        ? '成员'
        : topic.creatorNickname;
    final thumbCount =
        topic.reactions.counts
            .where((reaction) => reaction.emoji == '👍')
            .firstOrNull
            ?.count ??
        0;
    return Material(
      color: colors.surface,
      child: InkWell(
        onTap: () {
          if (_replying) {
            _setReplying(false);
            return;
          }
          AppRouter.goToTopicDetail(
            context,
            groupId: groupId,
            topicId: topic.topicId,
          ).then((_) => onChanged());
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserAvatar(
                        avatarUrl: topic.creatorFaceUrl,
                        cacheKey: topic.creatorId,
                        fallbackName: creator,
                        radius: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              creator,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: AppTheme.fontSizeBody,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  _formatTopicFeedTime(topic.createdAt),
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: AppTheme.fontSizeSmall,
                                  ),
                                ),
                                if (topic.edited) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '已编辑',
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: AppTheme.fontSizeSmall,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (topic.hasUnread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 7, right: 2),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (topic.hasMention)
                        _TopicMetaBadge(label: '@我', color: colors.danger),
                      if (topic.pinned)
                        _TopicMetaBadge(label: 'Pin', color: colors.primary),
                      if (topic.groupPinned)
                        _TopicMetaBadge(label: '置顶', color: colors.primary),
                      if (topic.state == TopicState.closed)
                        _TopicMetaBadge(
                          label: '已关闭',
                          color: colors.textSecondary,
                        ),
                      PopupMenuButton<String>(
                        tooltip: '话题操作',
                        padding: EdgeInsets.zero,
                        iconSize: 22,
                        color: colors.surface,
                        surfaceTintColor: colors.surface,
                        shadowColor: colors.shadow,
                        elevation: 12,
                        position: PopupMenuPosition.under,
                        constraints: const BoxConstraints(
                          minWidth: 158,
                          maxWidth: 172,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLg,
                          ),
                          side: BorderSide(color: colors.divider, width: 0.5),
                        ),
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          color: colors.textSecondary,
                        ),
                        onSelected: (action) =>
                            _handleAction(context, ref, action),
                        itemBuilder: (_) => [
                          _topicMenuItem(
                            context,
                            value: 'pin',
                            icon: Icons.push_pin_outlined,
                            label: topic.pinned ? '取消 Pin' : 'Pin',
                          ),
                          _topicMenuItem(
                            context,
                            value: 'groupPin',
                            icon: Icons.vertical_align_top_rounded,
                            label: topic.groupPinned ? '取消置顶' : '置顶话题',
                          ),
                          _topicMenuItem(
                            context,
                            value: 'task',
                            icon: Icons.done_all_rounded,
                            label: '添加任务',
                          ),
                          _topicMenuItem(
                            context,
                            value: 'state',
                            icon: Icons.remove_circle_outline_rounded,
                            label: topic.state == TopicState.closed
                                ? '重新打开话题'
                                : '关闭话题',
                          ),
                          _topicMenuItem(
                            context,
                            value: 'revoke',
                            icon: Icons.undo_rounded,
                            label: '撤回话题',
                          ),
                          if (topic.creatorId == widget.currentUserId &&
                              const {
                                101,
                                106,
                                117,
                                118,
                              }.contains(topic.rootContentType))
                            _topicMenuItem(
                              context,
                              value: 'edit',
                              icon: Icons.edit_outlined,
                              label: '编辑话题',
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    topic.rootPreview,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 17,
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (topic.recentReplies.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (topic.replyCount >
                              topic.recentReplies.length) ...[
                            Text(
                              '查看更早 ${topic.replyCount - topic.recentReplies.length} 条回复',
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: AppTheme.fontSizeSmall,
                              ),
                            ),
                            const SizedBox(height: 7),
                          ],
                          for (final reply in topic.recentReplies)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text:
                                          '${reply.senderNickname.isEmpty ? '成员' : reply.senderNickname}：',
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    TextSpan(
                                      text: reply.content,
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: AppTheme.fontSizeSmall,
                                  height: 1.4,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Divider(height: 1, thickness: 0.5, color: colors.divider),
            Row(
              children: [
                Expanded(
                  child: _TopicFeedAction(
                    tooltip: '点赞',
                    icon: topic.reactions.hasReaction('👍')
                        ? Icons.thumb_up_rounded
                        : Icons.thumb_up_outlined,
                    label: thumbCount > 0 ? '$thumbCount' : '',
                    color: topic.reactions.hasReaction('👍')
                        ? colors.primary
                        : colors.textSecondary,
                    onPressed: () => _toggleReaction(context, ref, '👍'),
                  ),
                ),
                Expanded(
                  child: _TopicFeedAction(
                    tooltip: _replying ? '收起回复' : '回复话题',
                    icon: Icons.mode_comment_outlined,
                    label: topic.replyCount > 0 ? '${topic.replyCount}' : '',
                    color: _replying ? colors.primary : colors.textSecondary,
                    onPressed: () => _setReplying(!_replying),
                  ),
                ),
                Expanded(
                  child: _TopicFeedAction(
                    tooltip: '转发话题',
                    icon: Icons.shortcut_rounded,
                    color: colors.textSecondary,
                    onPressed: () => showTopicShareSheet(
                      context: context,
                      ref: ref,
                      topic: topic,
                      groupName: conversation?.showName ?? '话题群',
                    ),
                  ),
                ),
                Expanded(
                  child: _TopicFeedAction(
                    tooltip: topic.subscribed ? '取消订阅' : '订阅',
                    icon: topic.subscribed
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_add_outlined,
                    color: topic.subscribed
                        ? colors.primary
                        : colors.textSecondary,
                    onPressed: () async {
                      await ref
                          .read(topicRepositoryProvider)
                          .setSubscription(
                            topicId: topic.topicId,
                            subscribed: !topic.subscribed,
                          );
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _replying
                  ? Container(
                      key: ValueKey('topic-inline-reply-${topic.topicId}'),
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        border: Border(
                          top: BorderSide(color: colors.divider, width: 0.5),
                        ),
                      ),
                      child: TopicChatComposer(
                        groupId: groupId,
                        conversationId: conversationId,
                        topicId: topic.topicId,
                        sendToLabel: '回复话题',
                        onSent: (_) {
                          if (mounted) _setReplying(false);
                          widget.onReplySent();
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    try {
      final repository = ref.read(topicRepositoryProvider);
      switch (action) {
        case 'pin':
          await repository.setPinned(
            topicId: topic.topicId,
            pinned: !topic.pinned,
            expectedVersion: topic.version,
          );
        case 'groupPin':
          await repository.setGroupPinned(
            topicId: topic.topicId,
            pinned: !topic.groupPinned,
            expectedVersion: topic.version,
          );
        case 'state':
          await repository.changeState(
            topicId: topic.topicId,
            state: topic.state == TopicState.closed
                ? TopicState.open
                : TopicState.closed,
            expectedVersion: topic.version,
          );
        case 'revoke':
          await repository.changeState(
            topicId: topic.topicId,
            state: TopicState.revoked,
            expectedVersion: topic.version,
          );
        case 'edit':
          final text = await showEditTopicDialog(
            context: context,
            initialText: topic.rootPreview,
          );
          if (text == null || !context.mounted) return;
          await repository.editTopic(
            topicId: topic.topicId,
            text: text,
            expectedVersion: topic.version,
          );
        case 'task':
          final memberProvider = groupMemberProvider(groupId);
          if (widget.members.isEmpty) {
            await ref.read(memberProvider.notifier).loadMembers();
          }
          if (!context.mounted) return;
          final members = widget.members.isNotEmpty
              ? widget.members
              : ref.read(memberProvider).members;
          if (members.isEmpty) {
            throw StateError('暂无可分配的群成员');
          }
          final draft = await showCreateTopicTaskDialog(
            context: context,
            members: members,
          );
          if (draft == null || !context.mounted) return;
          await repository.createTopicTask(
            topicId: topic.topicId,
            title: draft.title,
            description: draft.description,
            assigneeId: draft.assigneeId,
            dueAt: draft.dueAt,
            priority: draft.priority,
          );
      }
      onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  PopupMenuItem<String> _topicMenuItem(
    BuildContext context, {
    required String value,
    required IconData icon,
    required String label,
  }) {
    final colors = context.appColors;
    return PopupMenuItem<String>(
      value: value,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: AppTheme.fontSizeBody,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleReaction(
    BuildContext context,
    WidgetRef ref,
    String emoji,
  ) async {
    try {
      await ref
          .read(topicRepositoryProvider)
          .setReaction(
            topicId: topic.topicId,
            emoji: emoji,
            active: !topic.reactions.hasReaction(emoji),
          );
      onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('表情操作失败: $e')));
      }
    }
  }
}
