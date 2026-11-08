import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;

import '../../core/utils/app_logger.dart';
import '../../domain/models/group_mode.dart';
import '../../domain/models/topic.dart';
import '../../domain/models/topic_index_job.dart';
import '../../domain/models/topic_notification.dart';
import '../config/host_config.dart';
import '../mappers/topic_mapper.dart';
import 'login_storage.dart';
import 'topic_read_cache.dart';

String get kTopicApiBaseUrl => 'http://${getHostAddress()}:10002';

@visibleForTesting
String? debugTopicApiBaseUrlOverride;

class TopicTransportException implements Exception {
  const TopicTransportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TopicApi {
  TopicApi({http.Client? client, TopicReadCache? readCache})
    : _client = client ?? http.Client(),
      _readCache = readCache ?? const TopicReadCache();

  final http.Client _client;
  final TopicReadCache _readCache;

  String get _baseUrl => debugTopicApiBaseUrlOverride ?? kTopicApiBaseUrl;

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final credentials = await LoginStorage.loadCredentials();
    if (credentials == null || credentials.imToken.isEmpty) {
      throw StateError('登录凭证不存在');
    }
    late final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {
              'Content-Type': 'application/json',
              'token': credentials.imToken,
              'operationID': _operationId(),
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException catch (error) {
      throw TopicTransportException('话题服务请求超时: $error');
    } on SocketException catch (error) {
      throw TopicTransportException('话题服务不可达: $error');
    } on http.ClientException catch (error) {
      throw TopicTransportException('话题服务连接失败: $error');
    }
    if (response.statusCode != 200) {
      if (response.statusCode >= 500) {
        throw TopicTransportException(
          '话题服务暂时不可用: HTTP ${response.statusCode} ($path)',
        );
      }
      throw Exception('话题服务请求失败: HTTP ${response.statusCode} ($path)');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw Exception('话题服务响应格式错误');
    final envelope = Map<String, dynamic>.from(decoded);
    final errCode = (envelope['errCode'] as num?)?.toInt() ?? -1;
    if (errCode != 0) {
      throw Exception(envelope['errMsg']?.toString() ?? '话题服务请求失败');
    }
    final data = envelope['data'];
    return data is Map<Object?, Object?>
        ? Map<String, dynamic>.from(data)
        : const {};
  }

  Future<Map<String, dynamic>> _postRead(
    String path,
    Map<String, dynamic> body, {
    required String cacheKey,
  }) async {
    final credentials = await LoginStorage.loadCredentials();
    try {
      final data = await _post(path, body);
      if (credentials != null) {
        await _readCache.write(
          userId: credentials.userId,
          key: cacheKey,
          data: data,
        );
      }
      return data;
    } on TopicTransportException {
      if (credentials != null) {
        final cached = await _readCache.read(
          userId: credentials.userId,
          key: cacheKey,
        );
        if (cached != null) {
          appLog.d('[TopicAPI] 使用本地话题缓存: $cacheKey');
          return cached;
        }
      }
      rethrow;
    }
  }

  Future<TopicFeedPage> getTopics({
    required String groupId,
    required TopicTab tab,
    String cursor = '',
    int count = 30,
  }) async {
    final data = await _postRead(
      '/topic/get_topics',
      {
        'groupID': groupId,
        'tab': tab.wireValue,
        'cursor': cursor,
        'count': count,
      },
      cacheKey: 'topics:$groupId:${tab.wireValue}:$cursor:$count',
    );
    return _feedPage(data);
  }

  Future<TopicGroupSummary?> getGroupSummary(String groupId) async {
    final data = await _postRead('/topic/get_group_topic_summaries', {
      'groupIDs': [groupId],
    }, cacheKey: 'group_summary:$groupId');
    final raw = data['summaries'];
    if (raw is! List) return null;
    final summaries = raw.whereType<Map<Object?, Object?>>().map(
      (item) => TopicGroupSummary.fromJson(Map<String, dynamic>.from(item)),
    );
    for (final summary in summaries) {
      if (summary.groupId == groupId) return summary;
    }
    return null;
  }

  Future<TopicDetail> getTopic({
    required String groupId,
    required String topicId,
  }) async {
    final data = await _postRead('/topic/get_topic', {
      'groupID': groupId,
      'topicID': topicId,
    }, cacheKey: 'topic:$groupId:$topicId');
    return topicDetailFromJson(data);
  }

  Future<TopicReplyPage> getReplies({
    required String topicId,
    required int beforeSeq,
    int count = 30,
  }) async {
    final data = await _postRead('/topic/get_topic_replies', {
      'topicID': topicId,
      'beforeSeq': beforeSeq,
      'count': count,
    }, cacheKey: 'replies:$topicId:$beforeSeq:$count');
    return topicReplyPageFromJson(data);
  }

  Future<bool> setSubscription({
    required String topicId,
    required bool subscribed,
  }) async {
    final data = await _post('/topic/set_topic_subscription', {
      'topicID': topicId,
      'subscribed': subscribed,
    });
    return data['subscribed'] == true;
  }

  Future<int> markRead({
    required String topicId,
    required int lastReadSeq,
  }) async {
    final data = await _post('/topic/mark_topic_read', {
      'topicID': topicId,
      'lastReadSeq': lastReadSeq,
    });
    return (data['lastReadSeq'] as num?)?.toInt() ?? lastReadSeq;
  }

  Future<int> markUnread(String topicId) async {
    final data = await _post('/topic/mark_topic_unread', {'topicID': topicId});
    return (data['lastReadSeq'] as num?)?.toInt() ?? 0;
  }

  Future<int> markGroupRead(String groupId) async {
    final data = await _post('/topic/mark_group_topics_read', {
      'groupID': groupId,
    });
    return (data['updatedCount'] as num?)?.toInt() ?? 0;
  }

  Future<Topic> setPinned({
    required String topicId,
    required bool pinned,
    required int expectedVersion,
  }) async {
    final data = await _post('/topic/set_topic_pinned', {
      'topicID': topicId,
      'pinned': pinned,
      'expectedVersion': expectedVersion,
    });
    return Topic.fromJson(Map<String, dynamic>.from(data['topic'] as Map));
  }

  Future<Topic> setGroupPinned({
    required String topicId,
    required bool pinned,
    required int expectedVersion,
  }) async {
    final data = await _post('/topic/set_topic_group_pinned', {
      'topicID': topicId,
      'pinned': pinned,
      'expectedVersion': expectedVersion,
    });
    return Topic.fromJson(Map<String, dynamic>.from(data['topic'] as Map));
  }

  Future<Topic> changeState({
    required String topicId,
    required TopicState state,
    required int expectedVersion,
  }) async {
    final data = await _post('/topic/change_topic_state', {
      'topicID': topicId,
      'state': state.wireValue,
      'expectedVersion': expectedVersion,
    });
    return Topic.fromJson(Map<String, dynamic>.from(data['topic'] as Map));
  }

  Future<Topic> editTopic({
    required String topicId,
    required String text,
    required int expectedVersion,
  }) async {
    final data = await _post('/topic/edit_topic', {
      'topicID': topicId,
      'text': text,
      'expectedVersion': expectedVersion,
    });
    return Topic.fromJson(Map<String, dynamic>.from(data['topic'] as Map));
  }

  Future<TopicReactionState> setReaction({
    required String topicId,
    required String emoji,
    required bool active,
  }) async {
    final data = await _post('/topic/set_topic_reaction', {
      'topicID': topicId,
      'emoji': emoji,
      'active': active,
    });
    final raw = data['reactions'];
    if (raw is! Map<Object?, Object?>) {
      return const TopicReactionState();
    }
    return TopicReactionState.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<TopicGroupModeProfile> setGroupMode({
    required String groupId,
    required GroupMode mode,
    int expectedVersion = 0,
  }) async {
    final data = await _post('/topic/set_group_mode', {
      'groupID': groupId,
      'mode': mode == GroupMode.topic ? 2 : 1,
      'expectedVersion': expectedVersion,
    });
    final profile = data['profile'];
    if (profile is! Map) throw Exception('群模式响应为空');
    return TopicGroupModeProfile.fromJson(Map<String, dynamic>.from(profile));
  }

  Future<TopicGroupSettingsProfile> getGroupSettings(String groupId) async {
    final data = await _postRead('/topic/get_topic_group_settings', {
      'groupID': groupId,
    }, cacheKey: 'group_settings:$groupId');
    return TopicGroupSettingsProfile.fromJson(data);
  }

  Future<TopicGroupSettingsProfile> setGroupSettings({
    required String groupId,
    required TopicGroupSettings settings,
    required int expectedVersion,
  }) async {
    final data = await _post('/topic/set_topic_group_settings', {
      'groupID': groupId,
      'settings': {
        'allowMemberPublish': settings.allowMemberPublish,
        'allowMemberReply': settings.allowMemberReply,
        'defaultSubscribe': settings.defaultSubscribe,
        'notifyNewTopic': settings.notifyNewTopic,
        'notifyReplies': settings.notifyReplies,
        'allowMemberPin': settings.allowMemberPin,
        'allowMemberGroupPin': settings.allowMemberGroupPin,
      },
      'expectedVersion': expectedVersion,
    });
    return TopicGroupSettingsProfile.fromJson(data);
  }

  Future<TopicNotificationPage> getNotifications({
    String groupId = '',
    String cursor = '',
    int count = 50,
  }) async {
    final data = await _post('/topic/get_topic_notifications', {
      'groupID': groupId,
      'cursor': cursor,
      'count': count,
    });
    final raw = data['notifications'];
    return TopicNotificationPage(
      notifications: raw is List
          ? raw
                .whereType<Map<Object?, Object?>>()
                .map(
                  (item) => TopicNotification.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
      nextCursor: data['nextCursor']?.toString() ?? '',
      hasMore: data['hasMore'] == true,
      unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<int> markNotificationsRead(List<String> notificationIds) async {
    final data = await _post('/topic/mark_topic_notifications_read', {
      'notificationIDs': notificationIds,
    });
    return (data['updatedCount'] as num?)?.toInt() ?? 0;
  }

  Future<TopicIndexJobPage> getIndexJobs({
    String groupId = '',
    String status = '',
    String cursor = '',
    int count = 50,
  }) async {
    final data = await _post('/topic/get_topic_index_jobs', {
      'groupID': groupId,
      'status': status,
      'cursor': cursor,
      'count': count,
    });
    final raw = data['jobs'];
    return TopicIndexJobPage(
      jobs: raw is List
          ? raw
                .whereType<Map<Object?, Object?>>()
                .map(
                  (item) =>
                      TopicIndexJob.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const [],
      nextCursor: data['nextCursor']?.toString() ?? '',
      hasMore: data['hasMore'] == true,
    );
  }

  Future<TopicIndexJob> retryIndexJob(String jobId) async {
    final data = await _post('/topic/retry_topic_index_job', {'jobID': jobId});
    final raw = data['job'];
    if (raw is! Map) throw Exception('索引任务重试响应为空');
    return TopicIndexJob.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<bool> deleteIndexJob(String jobId) async {
    final data = await _post('/topic/delete_topic_index_job', {'jobID': jobId});
    return data['deleted'] == true;
  }

  Future<TopicSearchPage> searchTopics({
    required String groupId,
    required String keyword,
    TopicTab tab = TopicTab.all,
    TopicSearchFilter filter = const TopicSearchFilter(),
    String cursor = '',
    int count = 30,
  }) async {
    final body = {
      'groupID': groupId,
      'keyword': keyword,
      'tab': tab.wireValue,
      'cursor': cursor,
      'count': count,
      'authorID': filter.authorId,
      'createdAfter': filter.createdAfter,
      'createdBefore': filter.createdBefore,
      'state': filter.stateWireValue,
      'hasAttachments': filter.hasAttachments,
      'hasTasks': filter.hasTasks,
      'pinnedOnly': filter.pinnedOnly,
      'groupPinnedOnly': filter.groupPinnedOnly,
    };
    final searchCacheKey =
        'search:$groupId:${tab.wireValue}:$cursor:$count:'
        '${filter.authorId}:${filter.createdAfter}:${filter.createdBefore}:'
        '${filter.stateWireValue}:${filter.hasAttachments}:${filter.hasTasks}:'
        '${filter.pinnedOnly}:${filter.groupPinnedOnly}:'
        '${Uri.encodeQueryComponent(keyword)}';
    final data = await _postRead(
      '/topic/search_topics',
      body,
      cacheKey: searchCacheKey,
    );
    final raw = data['topics'];
    if (raw is! List) return const TopicSearchPage(topics: []);
    return TopicSearchPage(
      topics: raw
          .whereType<Map<Object?, Object?>>()
          .map((item) => Topic.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      nextCursor: data['nextCursor']?.toString() ?? '',
      hasMore: data['hasMore'] == true,
    );
  }

  Future<List<TopicTask>> getTopicTasks(String topicId) async {
    final data = await _postRead('/topic/get_topic_tasks', {
      'topicID': topicId,
    }, cacheKey: 'tasks:$topicId');
    final raw = data['tasks'];
    if (raw is! List) return const [];
    final tasks = raw
        .whereType<Map<Object?, Object?>>()
        .map((item) => TopicTask.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    appLog.d('[TopicAPI] 话题任务加载成功: topicID=$topicId count=${tasks.length}');
    return tasks;
  }

  Future<TopicTask> createTopicTask({
    required String topicId,
    required String title,
    required String description,
    required String assigneeId,
    required int dueAt,
    required TopicTaskPriority priority,
  }) async {
    final data = await _post('/topic/create_topic_task', {
      'topicID': topicId,
      'title': title,
      'description': description,
      'assigneeID': assigneeId,
      'dueAt': dueAt,
      'priority': priority.wireValue,
    });
    final raw = data['task'];
    if (raw is! Map) throw Exception('任务创建响应为空');
    return TopicTask.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<TopicTask> changeTopicTaskStatus({
    required String taskId,
    required TopicTaskStatus status,
    required int expectedVersion,
  }) async {
    final data = await _post('/topic/change_topic_task_status', {
      'taskID': taskId,
      'status': status.wireValue,
      'expectedVersion': expectedVersion,
    });
    final raw = data['task'];
    if (raw is! Map) throw Exception('任务更新响应为空');
    return TopicTask.fromJson(Map<String, dynamic>.from(raw));
  }

  void close() => _client.close();

  String _operationId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

TopicFeedPage _feedPage(Map<String, dynamic> data) {
  try {
    return topicFeedPageFromJson(data);
  } catch (e) {
    appLog.e('[TopicAPI] Feed 解析失败: $e');
    rethrow;
  }
}
