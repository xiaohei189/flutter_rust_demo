// 临时调试脚本：检查运行中 VM 加载的 Dart 源码是否为最新版。
// 用法: dart run scripts/vm_check_source.dart <wsUri> <源文件关键词>
import 'dart:io';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

Future<void> main(List<String> args) async {
  final uri = args.isNotEmpty ? args[0] : 'ws://127.0.0.1:59524/ws';
  final keyword = args.length > 1 ? args[1] : 'group_info_view_model.dart';
  final service = await vmServiceConnectUri(uri);
  final vm = await service.getVM();
  for (final iso in vm.isolates ?? <IsolateRef>[]) {
    if (!(iso.name?.contains('main') ?? false)) continue;
    final scripts = await service.getScripts(iso.id!);
    for (final s in scripts.scripts ?? <ScriptRef>[]) {
      if (!(s.uri?.contains(keyword) ?? false)) continue;
      stdout.writeln('script: ${s.uri}');
      final src = await service.getObject(iso.id!, s.id!) as Script;
      final source = src.source ?? '';
      stdout.writeln('--- source length: ${source.length}');
      for (final probe in ['localAvatarUrl', '_addCacheBuster', 'showGroupAvatarPickerSheet', 'uploadAvatar']) {
        stdout.writeln('contains[$probe]: ${source.contains(probe)}');
      }
    }
  }
  await service.dispose();
}
