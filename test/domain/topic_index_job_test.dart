import 'package:flutter_rust_demo/domain/models/topic_index_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('话题索引任务解析死信重试字段', () {
    final job = TopicIndexJob.fromJson({
      'jobID': 'group_1:message_1',
      'groupID': 'group_1',
      'clientMsgID': 'message_1',
      'status': 'dead',
      'attempts': 10,
      'lastError': 'mongo unavailable',
      'createdAt': 100,
      'updatedAt': 200,
    });

    expect(job.jobId, 'group_1:message_1');
    expect(job.status, 'dead');
    expect(job.attempts, 10);
    expect(job.lastError, 'mongo unavailable');
  });
}
