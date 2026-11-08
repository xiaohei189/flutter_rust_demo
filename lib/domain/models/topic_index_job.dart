class TopicIndexJob {
  final String jobId;
  final String groupId;
  final String clientMsgId;
  final String status;
  final int attempts;
  final String lastError;
  final int nextRetryAt;
  final int createdAt;
  final int updatedAt;

  const TopicIndexJob({
    required this.jobId,
    required this.groupId,
    required this.clientMsgId,
    required this.status,
    required this.attempts,
    required this.lastError,
    required this.nextRetryAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TopicIndexJob.fromJson(Map<String, dynamic> json) {
    return TopicIndexJob(
      jobId: json['jobID']?.toString() ?? '',
      groupId: json['groupID']?.toString() ?? '',
      clientMsgId: json['clientMsgID']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      lastError: json['lastError']?.toString() ?? '',
      nextRetryAt: (json['nextRetryAt'] as num?)?.toInt() ?? 0,
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

class TopicIndexJobPage {
  final List<TopicIndexJob> jobs;
  final String nextCursor;
  final bool hasMore;

  const TopicIndexJobPage({
    required this.jobs,
    this.nextCursor = '',
    this.hasMore = false,
  });
}
