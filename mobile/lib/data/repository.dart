import '../core/models.dart';

class AppFailure implements Exception {
  final String message;
  const AppFailure(this.message);
  @override String toString()=>message;
}

abstract class PandoraRepository {
  Future<UserProfile?> restore();
  Future<UserProfile> login(String username,String password);
  Future<void> logout();
  Future<void> requestPasswordReset(String username);
  Future<void> requestPasswordChange();
  Future<String> passwordChangeStatus();
  Future<void> completePasswordChange(String newPassword);
  Future<List<WorkLog>> logs({String? date,String? status});
  Future<WorkLog> saveLog(String content,{int? id});
  Future<WorkLog> submitLog(int id);
  Future<List<LogComment>> comments(int logId);
  Future<LogComment> addComment(int logId,String content,{int? parentId});
  Future<Overview> overview();
  Future<List<TrendPoint>> trend(int days);
  Future<List<String>> unsubmitted();
  Future<List<TaskItem>> tasks({required bool personal});
  Future<TaskItem> createPersonalTask(String name,String details);
  Future<void> updateTask(TaskItem item,String status);
  Future<List<CompanyItem>> companyMatters();
  Future<List<CompanyItem>> companyImportantTasks();
  Future<List<CalendarDay>> calendar(String from,String to);
  Future<List<TaskItem>> taskMap();
  Future<List<UserProfile>> recipients();
  Future<List<DispatchedTask>> dispatchedTasks();
  Future<List<TaskAssignment>> dispatchedAssignments(int taskId);
  Future<void> dispatchTask({required String name,required String details,required String startDate,required String deadline,required String urgency,required List<int> assigneeIds});
  Future<void> inviteReview(int assignmentId);
  Future<void> reviewAssignment(int assignmentId,String result,String comment);
}
