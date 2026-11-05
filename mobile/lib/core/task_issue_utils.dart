import 'models.dart';

/// In the absence of a server issue count, an unresolved blocker is identified
/// from BLOCKED progress updates since the last non-blocked update. Only
/// explicitly blocked entries are treated as issues; ordinary notes are not.
/// A seeded BLOCKED task with no history is one unresolved blocked task.
int unresolvedIssueEvents(TaskItem task, List<TaskProgressRecord> history) {
  if (task.openIssueCount != null) return task.openIssueCount!;
  if (task.status != 'BLOCKED') return 0;
  final sorted = [...history]..sort((a,b)=>b.createdAt.compareTo(a.createdAt));
  var total=0;
  for (final record in sorted) {
    if(record.status != 'BLOCKED') break;
    if(record.note.trim().isNotEmpty) total++;
  }
  return total==0 ? 1 : total;
}
