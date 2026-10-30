import 'models.dart';

/// 仅在服务器已经授权返回的日志内进行视图筛选。
/// 下属名单必须来自单独的服务端授权查询，不能通过同部门推断。
List<WorkLog> filterWorkLogs({
  required List<WorkLog> authorized,
  required int viewerId,
  required String mode,
  Set<int> subordinateIds = const <int>{},
  int? selectedSubordinateId,
  String? selectedDepartment,
  String search = '',
}) {
  final query = search.trim();
  return authorized.where((log) {
    if (mode == '我的日志' && log.authorId != viewerId) return false;
    if (mode == '我的下属') {
      if (!subordinateIds.contains(log.authorId)) return false;
      if (selectedSubordinateId != null && log.authorId != selectedSubordinateId) {
        return false;
      }
    }
    if (mode == '部门日志' && selectedDepartment != null) {
      final name = log.departmentName.isNotEmpty ? log.departmentName
          : log.departmentId == null ? '未标注部门' : '部门 ${log.departmentId}';
      if (name != selectedDepartment) return false;
    }
    return query.isEmpty || log.authorName.contains(query) || log.content.contains(query);
  }).toList();
}
