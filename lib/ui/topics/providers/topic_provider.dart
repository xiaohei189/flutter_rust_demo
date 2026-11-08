import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/topic_repository.dart';
import '../../../data/services/topic_api.dart';
import '../../../data/services/topic_draft_store.dart';
import '../../../domain/models/topic.dart';
import '../view_models/topic_detail_view_model.dart';
import '../view_models/topic_group_view_model.dart';

final topicApiProvider = Provider<TopicApi>((ref) {
  final api = TopicApi();
  ref.onDispose(api.close);
  return api;
});

final topicRepositoryProvider = Provider<TopicRepository>((ref) {
  return TopicRepositoryImpl(api: ref.watch(topicApiProvider));
});

final topicDraftStoreProvider = Provider<TopicDraftStore>((ref) {
  return const TopicDraftStore();
});

final topicGroupProvider =
    NotifierProvider.family<TopicGroupViewModel, TopicGroupState, String>(
      TopicGroupViewModel.new,
    );

typedef TopicDetailArgs = ({String groupId, String topicId});
typedef TopicGroupSummaryArgs = ({String groupId, int revision});

final topicDetailProvider =
    NotifierProvider.family<
      TopicDetailViewModel,
      TopicDetailState,
      TopicDetailArgs
    >(TopicDetailViewModel.new);

final topicGroupSummaryProvider = FutureProvider.autoDispose
    .family<TopicGroupSummary?, TopicGroupSummaryArgs>((ref, args) {
      return ref.watch(topicRepositoryProvider).getGroupSummary(args.groupId);
    });
