import 'package:flutter_rust_demo/data/services/login_storage.dart';
import 'package:flutter_rust_demo/data/services/topic_api.dart';
import 'package:flutter_rust_demo/data/services/topic_read_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _OfflineClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw http.ClientException('offline');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LoginStorage.saveCredentials(userId: 'user_1', imToken: 'token');
  });

  test('网络不可用时话题详情回退本地缓存', () async {
    const cache = TopicReadCache();
    await cache.write(
      userId: 'user_1',
      key: 'topic:group_1:topic_1',
      data: {
        'topic': {
          'topicID': 'topic_1',
          'groupID': 'group_1',
          'rootClientMsgID': 'topic_1',
          'creatorID': 'user_2',
          'creatorNickname': '张三',
          'rootPreview': '缓存话题',
          'state': 1,
          'version': 1,
        },
        'rootMessage': null,
      },
    );
    final api = TopicApi(client: _OfflineClient(), readCache: cache);

    final detail = await api.getTopic(groupId: 'group_1', topicId: 'topic_1');

    expect(detail.topic.topicId, 'topic_1');
    expect(detail.topic.rootPreview, '缓存话题');
  });

  test('缓存按用户隔离', () async {
    const cache = TopicReadCache();
    await cache.write(
      userId: 'user_1',
      key: 'topic:group_1:topic_1',
      data: {'topic': <String, dynamic>{}},
    );

    expect(
      await cache.read(userId: 'user_2', key: 'topic:group_1:topic_1'),
      isNull,
    );
  });
}
