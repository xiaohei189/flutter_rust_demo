import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/topic_index_job.dart';
import '../providers/topic_provider.dart';

class TopicIndexOpsScreen extends ConsumerStatefulWidget {
  const TopicIndexOpsScreen({super.key});

  @override
  ConsumerState<TopicIndexOpsScreen> createState() =>
      _TopicIndexOpsScreenState();
}

class _TopicIndexOpsScreenState extends ConsumerState<TopicIndexOpsScreen> {
  List<TopicIndexJob> _jobs = const [];
  String _status = 'dead';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(topicRepositoryProvider)
          .getIndexJobs(status: _status);
      if (!mounted) return;
      setState(() {
        _jobs = page.jobs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载索引任务失败: $e';
      });
    }
  }

  Future<void> _retry(TopicIndexJob job) async {
    try {
      await ref.read(topicRepositoryProvider).retryIndexJob(job.jobId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('重试失败: $e')));
    }
  }

  Future<void> _delete(TopicIndexJob job) async {
    try {
      await ref.read(topicRepositoryProvider).deleteIndexJob(job.jobId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('话题索引运维'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _status,
            onSelected: (value) {
              setState(() => _status = value);
              _load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'dead', child: Text('死信')),
              PopupMenuItem(value: 'pending', child: Text('待重试')),
              PopupMenuItem(value: 'processing', child: Text('处理中')),
              PopupMenuItem(value: '', child: Text('全部')),
            ],
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('重试')),
                  ],
                ),
              ),
            )
          : _jobs.isEmpty
          ? const Center(child: Text('当前筛选下没有索引任务'))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _jobs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final job = _jobs[index];
                return ListTile(
                  title: Text('${job.status} · ${job.attempts} 次'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('群 ${job.groupId} · 消息 ${job.clientMsgId}'),
                      if (job.lastError.isNotEmpty)
                        Text(
                          job.lastError,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        '创建 ${DateFormat('MM-dd HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(job.createdAt))}',
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'retry') _retry(job);
                      if (value == 'delete') _delete(job);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'retry', child: Text('立即重试')),
                      PopupMenuItem(value: 'delete', child: Text('删除任务')),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
