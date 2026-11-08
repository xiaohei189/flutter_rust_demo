import 'topic.dart';

const String kTopicLinkScheme = 'flutterrustdemo';

String buildTopicLink({required String groupId, required String topicId}) {
  final group = Uri.encodeQueryComponent(groupId);
  final topic = Uri.encodeComponent(topicId);
  return '$kTopicLinkScheme:///topic/$topic?groupID=$group';
}

({String groupId, String topicId})? parseTopicLink(Uri uri) {
  if (uri.scheme != kTopicLinkScheme) return null;
  final segments = uri.pathSegments;
  if (segments.length < 2 || segments.first != 'topic') return null;
  final topicId = segments[1];
  final groupId = uri.queryParameters['groupID'] ?? '';
  if (topicId.isEmpty || groupId.isEmpty) return null;
  return (groupId: groupId, topicId: topicId);
}

TopicShareCard buildTopicShareCard({
  required Topic topic,
  required String groupName,
  String? title,
  List<TopicShareReply> replies = const [],
  bool snapshotComplete = true,
}) {
  return TopicShareCard(
    groupId: topic.groupId,
    topicId: topic.topicId,
    groupName: groupName,
    title: title ?? topic.rootPreview,
    creatorName: topic.creatorNickname,
    replyCount: topic.replyCount,
    link: buildTopicLink(groupId: topic.groupId, topicId: topic.topicId),
    replies: replies,
    snapshotComplete: snapshotComplete,
  );
}
