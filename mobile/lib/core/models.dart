import 'dart:convert';

String dayString(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime get chinaNow => DateTime.now().toUtc().add(const Duration(hours: 8));
String get todayChina => dayString(chinaNow);
String friendlyDate(String day) {
  try {
    final dt = DateTime.parse(day);
    return '${dt.month}月${dt.day}日';
  } catch (_) { return day; }
}
Map<String, dynamic> mapOf(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<dynamic> listOf(dynamic value) => value is List ? value : const [];
String textOf(dynamic value, [String fallback = '']) => value == null ? fallback : value.toString();
int intOf(dynamic value, [int fallback = 0]) => value is num ? value.toInt() : int.tryParse(textOf(value)) ?? fallback;
double doubleOf(dynamic value, [double fallback = 0]) => value is num ? value.toDouble() : double.tryParse(textOf(value)) ?? fallback;

class UserProfile {
  final int id;
  final String username, name, role;
  final int? departmentId, teamId;
  final List<String> permissions;
  const UserProfile({required this.id, required this.username, required this.name, required this.role, this.departmentId, this.teamId, this.permissions = const []});
  factory UserProfile.fromJson(dynamic obj) {
    final j=mapOf(obj);
    return UserProfile(id:intOf(j['id']),username:textOf(j['username']),name:textOf(j['realName'],textOf(j['name'], '用户')),role:textOf(j['role'],'EMPLOYEE'),departmentId:j['departmentId']==null?null:intOf(j['departmentId']),teamId:j['teamId']==null?null:intOf(j['teamId']),permissions:listOf(j['permissions']).map((e)=>e.toString()).toList());
  }
  Map<String,dynamic> toJson()=>{'id':id,'username':username,'realName':name,'role':role,'departmentId':departmentId,'teamId':teamId,'permissions':permissions};
  String get roleLabel => const {'EMPLOYEE':'员工','TEAM_LEADER':'团队长','DEPT_MANAGER':'部门老总','FOUNDER':'创始人','ADMIN':'系统管理员'}[role] ?? '员工';
  bool get canWriteLog => role!='ADMIN';
  bool get canUseTasks => role!='ADMIN';
}

class WorkLog {
  final int id, authorId;
  final String authorName, logDate, content, status;
  final bool isImportant;
  final String? submittedAt;
  final int? departmentId, teamId;
  final String departmentName, teamName, authorRole;
  const WorkLog({required this.id,required this.authorId,required this.authorName,required this.logDate,required this.content,required this.status,this.isImportant=false,this.submittedAt,this.departmentId,this.teamId,this.departmentName='',this.teamName='',this.authorRole=''});
  factory WorkLog.fromJson(dynamic obj) {
    final j=mapOf(obj);
    final author=mapOf(j['author']);
    final department=mapOf(j['department']);
    final team=mapOf(j['team']);
    return WorkLog(id:intOf(j['id']),authorId:intOf(j['authorId']),authorName:textOf(j['authorName'],textOf(mapOf(j['author'])['realName'],'同事')),logDate:textOf(j['logDate']),content:textOf(j['content']),status:textOf(j['status'],'DRAFT'),isImportant:j['isImportant']==true,submittedAt:j['submittedAt']?.toString(),departmentId:j['departmentId']==null?(author['departmentId']==null?null:intOf(author['departmentId'])):intOf(j['departmentId']),teamId:j['teamId']==null?(author['teamId']==null?null:intOf(author['teamId'])):intOf(j['teamId']),departmentName:textOf(j['departmentName'],textOf(department['name'],textOf(author['departmentName'],textOf(mapOf(author['department'])['name'])))),teamName:textOf(j['teamName'],textOf(team['name'],textOf(author['teamName'],textOf(mapOf(author['team'])['name'])))),authorRole:textOf(j['authorRole'],textOf(author['role'])));
  }
  Map<String,dynamic> toJson()=>{'id':id,'authorId':authorId,'authorName':authorName,'logDate':logDate,'content':content,'status':status,'isImportant':isImportant,'submittedAt':submittedAt,'departmentId':departmentId,'teamId':teamId,'departmentName':departmentName,'teamName':teamName,'authorRole':authorRole};
  bool get submitted=>status=='SUBMITTED';
}

class LogComment {
  final int id, logId, authorId;
  final String authorName, content, createdAt;
  final int? parentId;
  const LogComment({required this.id,required this.logId,required this.authorId,required this.authorName,required this.content,required this.createdAt,this.parentId});
  factory LogComment.fromJson(dynamic obj) {
    final j=mapOf(obj);
    return LogComment(id:intOf(j['id']),logId:intOf(j['logId']),authorId:intOf(j['authorId'],intOf(j['commenterId'])),authorName:textOf(j['authorName'],textOf(mapOf(j['author'])['realName'],'同事')),content:textOf(j['content']),createdAt:textOf(j['createdAt']),parentId:j['parentId']==null?null:intOf(j['parentId']));
  }
  Map<String,dynamic> toJson()=>{'id':id,'logId':logId,'authorId':authorId,'authorName':authorName,'content':content,'createdAt':createdAt,'parentId':parentId};
}

class TaskItem {
  final int id;
  final String name, details, status, source, urgency, reviewStatus;
  final String? deadline, startDate;
  final int? taskId, senderId;
  const TaskItem({required this.id,required this.name,required this.details,required this.status,required this.source,this.urgency='NOT_URGENT',this.deadline,this.startDate,this.taskId,this.senderId,this.reviewStatus='NONE'});
  factory TaskItem.fromJson(dynamic obj,{String source='PERSONAL'}) {
    final j=mapOf(obj);
    return TaskItem(id:intOf(j[source=='RECEIVED'?'assignmentId':'id'],intOf(j['id'],intOf(j['personalTaskId']))),name:textOf(j['name']),details:textOf(j['details']),status:textOf(j['executionStatus'],textOf(j['status'],'NOT_STARTED')),source:source,urgency:textOf(j['urgency'],'NOT_URGENT'),deadline:j['deadline']?.toString(),startDate:j['startDate']?.toString(),taskId:j['taskId']==null?null:intOf(j['taskId']),senderId:j['senderId']==null?intOf(mapOf(j['sender'])['id'],0):intOf(j['senderId']),reviewStatus:textOf(j['reviewStatus'],'NONE'));
  }
  String get statusLabel=>const {'NOT_STARTED':'待开始','IN_PROGRESS':'进行中','COMPLETED':'已完成'}[status]??status;
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'details':details,'status':status,'source':source,'urgency':urgency,'deadline':deadline,'startDate':startDate,'taskId':taskId,'senderId':senderId,'reviewStatus':reviewStatus};
}

class CompanyItem {
  final int id;
  final String title, content;
  const CompanyItem({required this.id,required this.title,required this.content});
  factory CompanyItem.fromJson(dynamic obj) {final j=mapOf(obj);return CompanyItem(id:intOf(j['id']),title:textOf(j['title']),content:textOf(j['content']));}
}

class Overview {
  final int expected,submitted,unsubmitted;
  final double rate;
  const Overview({required this.expected,required this.submitted,required this.unsubmitted,required this.rate});
  factory Overview.fromJson(dynamic obj) {
    final j=mapOf(obj);
    final e=intOf(j['expected'],intOf(j['expectedCount'],intOf(j['expectedUsers'])));
    final s=intOf(j['submitted'],intOf(j['submittedCount'],intOf(j['submittedUsers'])));
    final u=intOf(j['unsubmitted'],intOf(j['unsubmittedCount'], e-s));
    double r=doubleOf(j['rate'],doubleOf(j['submissionRate'],e==0?0:s/e*100));
    if (r>0 && r<=1) r*=100;
    return Overview(expected:e,submitted:s,unsubmitted:u,rate:r.clamp(0.0,100.0).toDouble());
  }
}

class TrendPoint {
  final String day;
  final int count;
  const TrendPoint({required this.day,required this.count});
  factory TrendPoint.fromJson(dynamic obj) {final j=mapOf(obj);return TrendPoint(day:textOf(j['date'],textOf(j['day'])),count:intOf(j['count'],intOf(j['logCount'])));}
}

class DispatchedTask {
  final int id, assigneeCount, completedCount, pendingReviewCount;
  final String name, details, urgency, startDate, deadline;
  const DispatchedTask({required this.id,required this.name,required this.details,required this.urgency,required this.startDate,required this.deadline,this.assigneeCount=0,this.completedCount=0,this.pendingReviewCount=0});
  factory DispatchedTask.fromJson(dynamic obj) {final j=mapOf(obj);return DispatchedTask(id:intOf(j['id']),name:textOf(j['name']),details:textOf(j['details']),urgency:textOf(j['urgency'],'NOT_URGENT'),startDate:textOf(j['startDate']),deadline:textOf(j['deadline']),assigneeCount:intOf(j['assigneeCount']),completedCount:intOf(j['completedCount']),pendingReviewCount:intOf(j['pendingReviewCount']));}
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'details':details,'urgency':urgency,'startDate':startDate,'deadline':deadline,'assigneeCount':assigneeCount,'completedCount':completedCount,'pendingReviewCount':pendingReviewCount};
}
class TaskAssignment {
  final int id, assigneeId;
  final String assigneeName, status, reviewStatus;
  const TaskAssignment({required this.id,required this.assigneeId,required this.assigneeName,required this.status,required this.reviewStatus});
  factory TaskAssignment.fromJson(dynamic obj) {final j=mapOf(obj);final a=mapOf(j['assignee']);return TaskAssignment(id:intOf(j['assignmentId']),assigneeId:intOf(a['id'],intOf(j['assigneeId'])),assigneeName:textOf(a['realName'],textOf(j['assigneeName'],'成员')),status:textOf(j['executionStatus'],'NOT_STARTED'),reviewStatus:textOf(j['reviewStatus'],'NONE'));}
}

class CalendarDay {
  final String date, mark;
  final int logCount,taskCount;
  const CalendarDay({required this.date,required this.mark,required this.logCount,required this.taskCount});
  factory CalendarDay.fromJson(dynamic obj) {final j=mapOf(obj);return CalendarDay(date:textOf(j['date']),mark:textOf(j['mark'],'NONE'),logCount:intOf(j['logCount']),taskCount:intOf(j['taskCount']));}
}

String encodeJson(dynamic input)=>jsonEncode(input);
