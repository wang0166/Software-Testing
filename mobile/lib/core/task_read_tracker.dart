import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// 本机未查看任务标记。仅依赖当前账号可访问的任务，不扩展权限。
/// 真正的跨设备未读状态需要后端提供 assignment 级的已读记录。
class TaskReadTracker {
  final int userId;
  TaskReadTracker(this.userId);

  String get storageKey => 'pandora_received_viewed_v112_$userId';
  Set<int> _viewedIds = <int>{};
  Future<void>? _loading;

  Future<void> _ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _viewedIds = (prefs.getStringList(storageKey) ?? const <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
  }

  Future<Set<int>> unreadIds(List<TaskItem> receivedTasks) async {
    await _ensureLoaded();
    // TaskItem.id is the received assignment ID, not the common task ID.
    return receivedTasks
        .where((task) => task.source == 'RECEIVED' && task.id > 0 && !_viewedIds.contains(task.id))
        .map((task) => task.id)
        .toSet();
  }

  Future<void> markViewed(int assignmentId) async {
    if (assignmentId <= 0) return;
    await _ensureLoaded();
    if (!_viewedIds.add(assignmentId)) return;
    final prefs = await SharedPreferences.getInstance();
    final sorted = _viewedIds.map((id) => id.toString()).toList()..sort();
    await prefs.setStringList(storageKey, sorted);
  }
}
