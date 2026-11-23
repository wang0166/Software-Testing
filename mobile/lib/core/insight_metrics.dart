import 'models.dart';

/// Explicit, reproducible work-information statistics. Not an AI prediction.
class KeywordScore {
  final String term;
  final int occurrences;
  final int score;
  const KeywordScore(this.term, this.occurrences, this.score);
}

/// Keyword candidates are openly maintained business vocabulary. Counting
/// uses *only authorized text* fetched for the current logged-in user.
/// The score is a simple weighting rule: log matches=1, received task matches=2,
/// urgent received task matches=3. It must not be labeled an AI judgement.
List<KeywordScore> extractWorkKeywords({
  required List<WorkLog> logs,
  required List<TaskItem> tasks,
  int limit = 8,
}) {
  const keywords = [
    '联调', '测试', '开发', '需求', '进度', '计划', '任务', '日志', '项目',
    '交付', '客户', '审核', '设计', '风险', '质量', '发布', '协作',
    '会议', '评审', '验收', '预算', '目标', '文档', '优化', '问题',
    '培训', '统计', '数据', '成本', '汇报', '运营', '销售', '安全',
  ];
  final scored = <KeywordScore>[];
  int occurrences(String text, String term) {
    if (text.isEmpty) return 0;
    return term.allMatches(text.toLowerCase()).length;
  }

  for (final term in keywords) {
    var count = 0;
    var weighted = 0;
    for (final log in logs) {
      final n = occurrences(log.content, term);
      count += n;
      weighted += n;
    }
    for (final task in tasks) {
      final n = occurrences('${task.name} ${task.details}', term);
      count += n;
      weighted += n * (task.urgency == 'URGENT' ? 3 : 2);
    }
    if (count > 0) scored.add(KeywordScore(term, count, weighted));
  }
  scored.sort((a, b) {
    final scoreOrder = b.score.compareTo(a.score);
    return scoreOrder != 0 ? scoreOrder : a.term.compareTo(b.term);
  });
  return scored.take(limit).toList();
}

class TaskStatusCounts {
  final int notStarted;
  final int inProgress;
  final int completed;
  const TaskStatusCounts(this.notStarted, this.inProgress, this.completed);
  int get total => notStarted + inProgress + completed;
}

TaskStatusCounts countTaskStatuses(List<TaskItem> tasks) => TaskStatusCounts(
  tasks.where((t) => t.status == 'NOT_STARTED').length,
  tasks.where((t) => t.status == 'IN_PROGRESS').length,
  tasks.where((t) => t.status == 'COMPLETED').length,
);

int urgentTaskCount(List<TaskItem> tasks) =>
    tasks.where((task) => task.urgency == 'URGENT').length;

/// Completion ratio for dispatched tasks can be calculated from assignee
/// completion counts. 0 assignees means unknown, rather than false 0%.
double? completionRatio(DispatchedTask task) {
  if (task.assigneeCount == 0) return null;
  return (task.completedCount / task.assigneeCount).clamp(0.0, 1.0).toDouble();
}
