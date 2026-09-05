// 临时调试脚本：连接正在运行的 Flutter 应用 VM Service，
// dump widget 摘要树并扫描头像相关节点，验证群头像更新是否已渲染。
// 用法: dart run scripts/vm_probe.dart [wsUri]  默认 ws://127.0.0.1:59524/ws
import 'dart:convert';
import 'dart:io';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

Future<void> main(List<String> args) async {
  final uri = args.isNotEmpty ? args[0] : 'ws://127.0.0.1:59524/ws';
  final service = await vmServiceConnectUri(uri);
  final vm = await service.getVM();
  stdout.writeln('VM: ${vm.name} | isolates: ${vm.isolates?.length}');
  for (final iso in vm.isolates ?? <IsolateRef>[]) {
    stdout.writeln('isolate: ${iso.id} | ${iso.name}');
    if (!(iso.name?.contains('main') ?? false)) continue;
    final tree = await service.callServiceExtension(
      'ext.flutter.inspector.getRootWidgetSummaryTree',
      isolateId: iso.id,
      args: {'objectGroup': 'root'},
    );
    final outFile = File('logs/vm_widget_tree.json');
    outFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(tree.json));
    stdout.writeln('tree saved: ${outFile.path}');
    // 完整树（含属性描述），用于查看 URL 等详情
    try {
      final full = await service.callServiceExtension(
        'ext.flutter.inspector.getRootWidgetTree',
        isolateId: iso.id,
        args: {
          'groupName': 'root',
          'isSummaryTree': 'false',
          'withPreviews': 'false',
        },
      );
      final fullFile = File('logs/vm_widget_full_tree.json');
      fullFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(full.json));
      stdout.writeln('full tree saved: ${fullFile.path}');
    } catch (e) {
      stdout.writeln('full tree failed: $e');
    }
    final text = JsonEncoder().convert(tree.json);
    for (final k in ['UserAvatar', 'NetworkImage', '_t=', 'faceUrl', 'avatar']) {
      stdout.writeln('key[$k]: ${text.split(k).length - 1}');
    }
  }
  await service.dispose();
}
