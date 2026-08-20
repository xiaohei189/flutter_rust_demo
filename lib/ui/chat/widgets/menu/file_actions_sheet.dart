import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

Future<String?> showFileActionsSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: context.appColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: const Text('打开文件'),
            onTap: () => Navigator.of(sheetContext).pop('open'),
          ),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: const Text('保存/另存为'),
            onTap: () => Navigator.of(sheetContext).pop('save'),
          ),
        ],
      ),
    ),
  );
}