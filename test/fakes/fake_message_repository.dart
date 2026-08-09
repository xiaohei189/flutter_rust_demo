import 'package:flutter_rust_demo/data/repositories/message_repository.dart';

class FakeMessageRepository implements MessageRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
