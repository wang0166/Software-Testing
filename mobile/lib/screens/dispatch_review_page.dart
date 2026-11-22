import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../widgets/business.dart';
import '../widgets/ui.dart';

class DispatchReviewPage extends StatefulWidget {
  final AppState app;
  const DispatchReviewPage({super.key, required this.app});

  @override
  State<DispatchReviewPage> createState() => _DispatchReviewPageState();
}

class _DispatchReviewPageState extends State<DispatchReviewPage> {
  late Future<List<DispatchReview>> _requests;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _requests = widget.app.repo.dispatchReviewInbox();
  }

  Future<void> _refresh() async {
    setState(() => _requests = widget.app.repo.dispatchReviewInbox());
    try {
      await _requests;
    } catch (_) {
      // FutureBuilder shows the error and offers retry.
    }
  }

  Future<void> _review(DispatchReview item, {required bool approve}) async {
    if (_busy) return;
    final decision = approve ? '通过' : '驳回';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$decision' '此派发申请？'),
        content: Text(item.request.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(decision)),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.app.repo.reviewDispatchRequest(item.request.id, approve: approve);
      if (!mounted) return;
      toast(context, approve ? '审核通过，任务已发布' : '申请已驳回');
      await _refresh();
    } catch (error) {
      if (mounted) toast(context, '审核失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('派发审核')),
    body: FutureBuilder<List<DispatchReview>>(
      future: _requests,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('派发审核暂不可用：${snapshot.error}'),
              TextButton(onPressed: _refresh, child: const Text('重试')),
            ]),
          ));
        }
        final rows = snapshot.data ?? [];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (rows.isEmpty) const BusinessEmpty('当前没有待审核的派发申请'),
              for (final item in rows) Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BusinessPanel(
                  title: item.request.name,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('申请人：${item.requesterName}'),
                      Text('接收人：${item.assigneeNames.isEmpty
                        ? item.request.assigneeIds.join('、') : item.assigneeNames.join('、')}'),
                      Text('开始：${item.request.startDate.replaceFirst('T', ' ')}'),
                      Text('截止：${item.request.deadline.replaceFirst('T', ' ')}'),
                      const SizedBox(height: 7),
                      Text(item.request.details),
                      Align(alignment: Alignment.centerRight, child: Wrap(spacing: 8, children: [
                        TextButton(onPressed: _busy ? null : () => _review(item, approve: false),
                          child: const Text('驳回')),
                        FilledButton(onPressed: _busy ? null : () => _review(item, approve: true),
                          child: const Text('通过')),
                      ])),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
