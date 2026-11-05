import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'log_detail_page.dart';
import 'logs_page.dart';
import 'personal_board_editor.dart';

/// 导图固定为一屏四块拼图；只有拼图内部滚动，页本身不滚动。
/// 保留 onTab 以兼容现有导航调用。
class HomePage extends StatefulWidget {
  final AppState app;
  final ValueChanged<int> onTab;
  const HomePage({super.key, required this.app, required this.onTab});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<_HomeData> _future;
  // null = the user has never customized the personal panel;
  // an empty list is a deliberate user choice.
  List<PersonalBoardEntry>? _personalEntries;

  Future<void> _loadPersonalEntries() async {
    final userId = widget.app.user?.id;
    if (userId == null) return;
    final entries = await PersonalBoardStorage.read(userId);
    if (mounted) setState(() => _personalEntries = entries);
  }

  List<PersonalBoardEntry> _initialPersonalEntries(_HomeData? data) {
    if (_personalEntries != null) return List.of(_personalEntries!);
    return (data?.receivedTasks ?? <TaskItem>[]).take(10).map((task) =>
      PersonalBoardEntry(title: task.name, detail: task.details),
    ).toList();
  }

  Future<void> _editPersonalBoard(_HomeData? data) async {
    final userId = widget.app.user?.id;
    if (userId == null) return;
    final saved = await Navigator.push<bool>(context, MaterialPageRoute<bool>(
      builder: (_) => PersonalBoardEditorPage(
        userId: userId,
        initial: _initialPersonalEntries(data),
      ),
    ));
    if (saved == true) await _loadPersonalEntries();
  }

  /// Bottom-right panel edits the real current user's work logs, not notes.
  /// The backend remains the authority on the 3-day editing window.
  Future<void> _editMyLog() async {
    final now = chinaNow;
    final today = DateTime(now.year, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today.subtract(const Duration(days: 2)),
      lastDate: today,
      helpText: '选择要新增或修改的个人日志日期',
    );
    if (date == null || !mounted) return;
    final day = dayString(date);
    try {
      final logs = await widget.app.repo.logs(date: day);
      if (!mounted) return;
      final mine = logs.where((log) => log.authorId == widget.app.user?.id).toList();
      final saved = await Navigator.push<bool>(context, MaterialPageRoute<bool>(
        builder: (_) => LogEditorPage(
          app: widget.app,
          date: day,
          draft: mine.isEmpty ? null : mine.first,
        ),
      ));
      if (mounted && saved == true) setState(_refresh);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开个人日志失败：$error')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadPersonalEntries();
  }

  void _refresh() {
    _future = _load();
  }

  Future<_HomeData> _load() async {
    Future<List<T>?> safe<T>(Future<List<T>> Function() action) async {
      try {
        return await action();
      } catch (_) {
        return null;
      }
    }

    final values = await Future.wait<dynamic>([
      safe(widget.app.repo.companyMatters),
      safe(widget.app.repo.companyImportantTasks),
      safe(widget.app.repo.logs),
      safe(() => widget.app.repo.tasks(personal: false)),
    ]);
    return _HomeData(
      values[0] as List<CompanyItem>?,
      values[1] as List<CompanyItem>?,
      values[2] as List<WorkLog>?,
      values[3] as List<TaskItem>?,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snap) {
          final data = snap.data;
          final logs = data?.logs;
          final me = widget.app.user;
          final mine = logs == null || me == null
              ? null
              : logs.where((log) => log.authorId == me.id).take(10).toList();
          final personalTop10 = _initialPersonalEntries(data);
          // Personal logs are visible to the author. Do not turn the edit
          // action into a local-only annotation of other people's logs.
          final loading = snap.connectionState != ConnectionState.done;
          return LayoutBuilder(
            builder: (context, bounds) => Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                children: [
                  // 标题和副标题的实际高度随字体、系统缩放和测试环境变化。
                  // 不要固定 44 像素，否则两行文字可能出现 RenderFlex overflow。
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('信息导图', style: TextStyle(
                                fontSize: 21, fontWeight: FontWeight.w900,
                                color: Palette.deep,
                              )),
                              Text('四大信息拼图 · 面板内部滑动查看完整内容',
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 10, color: Palette.muted)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: loading ? null : () => setState(_refresh),
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: const Text('刷新', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _tile(
                            '公司10大重要事项', '01', data?.matters == null
                                ? null
                                : data!.matters!.take(10).map((e) =>
                                    _TileRecord(e.title, e.content)).toList(),
                            loading: loading,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _tile(
                            '公司10大任务派发', '02', data?.tasks == null
                                ? null
                                : data!.tasks!.take(10).map((e) =>
                                    _TileRecord(e.title, e.content)).toList(),
                            loading: loading,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _tile(
                            '个人10大信息', '03',
                            personalTop10.map((entry) => _TileRecord(
                              entry.title,
                              entry.detail,
                              onTap: () => _editPersonalBoard(data),
                            )).toList(),
                            loading: loading,
                            onEdit: () => _editPersonalBoard(data),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _tile(
                            '日志展示', '04',
                            mine?.map((log) => _TileRecord(
                              log.content.replaceAll('\n', ' '),
                              '个人日志 · ${log.logDate} · ${log.status == 'SUBMITTED' ? '已提交' : '草稿'}',
                              onTap: () => _openLog(log),
                            )).toList(),
                            loading: loading,
                            onEdit: _editMyLog,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

  Widget _tile(String title, String order, List<_TileRecord>? items,
      {required bool loading, VoidCallback? onEdit}) => _HomeTile(
        key: ValueKey(order), title: title, order: order, records: items,
        loading: loading, onEdit: onEdit,
      );

  void _openLog(WorkLog log) {
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => LogDetailPage(app: widget.app, log: log),
    ));
  }
}

class _TileRecord {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _TileRecord(this.title, this.subtitle, {this.onTap});
}

class _HomeTile extends StatefulWidget {
  final String title;
  final String order;
  final List<_TileRecord>? records;
  final bool loading;
  final VoidCallback? onEdit;
  const _HomeTile({super.key, required this.title, required this.order,
    required this.records, required this.loading, this.onEdit});

  @override State<_HomeTile> createState() => _HomeTileState();
}

class _HomeTileState extends State<_HomeTile> {
  final ScrollController _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.records;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Palette.divider),
      ),
      child: Column(
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 57),
            padding: const EdgeInsets.fromLTRB(10, 9, 9, 9),
            color: Palette.deep,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.order, style: const TextStyle(
                color: Color(0xFF65D2C4), fontSize: 12, fontWeight: FontWeight.w800,
              )),
              const SizedBox(width: 5),
              Expanded(child: Text(widget.title, maxLines: 2,
                overflow: TextOverflow.ellipsis, style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800,
                  fontSize: 12, height: 1.3,
                ))),
              if (widget.onEdit != null) IconButton(
                key: ValueKey('home_edit_${widget.order}'), tooltip: '编辑${widget.title}',
                onPressed: widget.onEdit, icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 17),
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                padding: EdgeInsets.zero, visualDensity: VisualDensity.compact,
              ),
              if (records != null) Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Text('${records.length}/10', style: const TextStyle(
                  color: Color(0xFF9ADCD4), fontSize: 10,
                )),
              ),
            ]),
          ),
          Expanded(
            child: widget.loading && records == null
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : records == null || records.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(11),
                        child: Align(alignment: Alignment.topLeft,
                          child: Text(records == null ? '数据加载失败，请刷新' : '暂无可查看的信息',
                            style: const TextStyle(fontSize: 12, color: Palette.muted))),
                      )
                    : Scrollbar(
                        controller: _scroll,
                        thumbVisibility: true,
                        thickness: 2.5,
                        radius: const Radius.circular(3),
                        child: ListView.separated(
                          key: PageStorageKey('home_tile_${widget.order}'),
                          controller: _scroll,
                          primary: false,
                          padding: const EdgeInsets.fromLTRB(9, 4, 8, 4),
                          itemCount: records.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1, color: Palette.divider,
                          ),
                          itemBuilder: (context, index) {
                            final row = records[index];
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: row.onTap,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${index + 1}'.padLeft(2, '0'),
                                        style: const TextStyle(color: Palette.primary,
                                          fontSize: 10, fontWeight: FontWeight.w900)),
                                      const SizedBox(width: 6),
                                      Expanded(child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(row.title, maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12,
                                              height: 1.3, fontWeight: FontWeight.w700,
                                              color: Palette.deep)),
                                          if (row.subtitle.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(row.subtitle, maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 10,
                                                color: Palette.muted)),
                                          ],
                                        ],
                                      )),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _HomeData {
  final List<CompanyItem>? matters, tasks;
  final List<WorkLog>? logs;
  final List<TaskItem>? receivedTasks;
  const _HomeData(this.matters, this.tasks, this.logs, this.receivedTasks);
}
