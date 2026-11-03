import 'dart:convert';
import 'package:flutter/material.dart' show Color;

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
  final String mbtiType;
  final int? departmentId, teamId;
  final List<String> permissions;
  const UserProfile({required this.id, required this.username, required this.name, required this.role, this.departmentId, this.teamId, this.permissions = const [],this.mbtiType=''});
  factory UserProfile.fromJson(dynamic obj) {
    final j=mapOf(obj);
    return UserProfile(id:intOf(j['id']),username:textOf(j['username']),name:textOf(j['realName'],textOf(j['name'], '用户')),role:textOf(j['role'],'EMPLOYEE'),mbtiType:textOf(j['mbtiType'],textOf(j['mbti'])),departmentId:j['departmentId']==null?null:intOf(j['departmentId']),teamId:j['teamId']==null?null:intOf(j['teamId']),permissions:listOf(j['permissions']).map((e)=>e.toString()).toList());
  }
  Map<String,dynamic> toJson()=>{'id':id,'username':username,'realName':name,'role':role,'departmentId':departmentId,'teamId':teamId,'permissions':permissions,'mbtiType':mbtiType};
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
  final String name, details, status, source, urgency, reviewStatus, taskType;
  final String? deadline, startDate;
  final int? taskId, senderId;
  final String assigneeName, progressNote;
  final int? progressPercent;
  final String? progressUpdatedAt;
  /// Server-calculated unresolved issues when available; null means unsupported.
  final int? openIssueCount;
  int get visibleIssueCount => openIssueCount ?? (status == 'BLOCKED' ? 1 : 0);
  const TaskItem({required this.id,required this.name,required this.details,required this.status,required this.source,this.urgency='NOT_URGENT',this.deadline,this.startDate,this.taskId,this.senderId,this.reviewStatus='NONE',this.taskType='GENERAL',this.assigneeName='',this.progressNote='',this.progressPercent,this.progressUpdatedAt,this.openIssueCount});
  factory TaskItem.fromJson(dynamic obj,{String source='PERSONAL'}) {
    final j=mapOf(obj);
    return TaskItem(id:intOf(j[source=='RECEIVED'?'assignmentId':'id'],intOf(j['id'],intOf(j['personalTaskId']))),name:textOf(j['name']),details:textOf(j['details']),status:textOf(j['executionStatus'],textOf(j['status'],'NOT_STARTED')),source:source,urgency:textOf(j['urgency'],'NOT_URGENT'),deadline:j['deadline']?.toString(),startDate:j['startDate']?.toString(),taskId:j['taskId']==null?null:intOf(j['taskId']),senderId:j['senderId']==null?intOf(mapOf(j['sender'])['id'],0):intOf(j['senderId']),reviewStatus:textOf(j['reviewStatus'],'NONE'),taskType:textOf(j['taskType'],textOf(j['category'],textOf(j['type'],'GENERAL'))),assigneeName:textOf(j['assigneeName'],textOf(j['receiverName'],textOf(mapOf(j['assignee'])['realName']))),progressNote:textOf(j['progressNote'],textOf(j['progressRemark'],textOf(j['remarks']))),progressPercent:j['progressPercent']==null && j['completionRate']==null ? null : intOf(j['progressPercent'],intOf(j['completionRate'])).clamp(0,100).toInt(),progressUpdatedAt:j['progressUpdatedAt']?.toString(),openIssueCount:j['openIssueCount']==null && j['unresolvedIssueCount']==null?null:intOf(j['openIssueCount'],intOf(j['unresolvedIssueCount'])).clamp(0,999).toInt());
  }
  String get statusLabel=>const {'NOT_STARTED':'待开始','IN_PROGRESS':'进行中','COMPLETED':'已完成','BLOCKED':'受阻'}[status]??status;
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'details':details,'status':status,'source':source,'urgency':urgency,'deadline':deadline,'startDate':startDate,'taskId':taskId,'senderId':senderId,'reviewStatus':reviewStatus,'taskType':taskType,'assigneeName':assigneeName,'progressNote':progressNote,'progressPercent':progressPercent,'progressUpdatedAt':progressUpdatedAt,'openIssueCount':openIssueCount};
  bool get isOverdue {
    if (status=='COMPLETED' || deadline==null || deadline!.isEmpty) return false;
    final end=DateTime.tryParse(deadline!.replaceFirst(' ', 'T'));
    return end!=null && end.isBefore(DateTime.now());
  }
}

/// Immutable server/auditable record for a received assignment's progress.
class TaskProgressRecord {
  final int id;
  final String status, note, authorName, createdAt;
  final int? percent;
  const TaskProgressRecord({required this.id,required this.status,required this.note,
    required this.authorName,required this.createdAt,this.percent});
  factory TaskProgressRecord.fromJson(dynamic value) {
    final j=mapOf(value);
    return TaskProgressRecord(id:intOf(j['id']),
      status:textOf(j['status'],textOf(j['executionStatus'],'IN_PROGRESS')),
      note:textOf(j['note'],textOf(j['progressNote'])),
      authorName:textOf(j['authorName'],textOf(mapOf(j['author'])['realName'],'执行人')),
      createdAt:textOf(j['createdAt'],textOf(j['updatedAt'])),
      percent:j['progressPercent']==null && j['percent']==null ? null
        :intOf(j['progressPercent'],intOf(j['percent'])).clamp(0,100).toInt());
  }
  Map<String,dynamic> toJson()=>{'id':id,'status':status,'note':note,
    'authorName':authorName,'createdAt':createdAt,'progressPercent':percent};
}

/// Validate client input; backend separately enforces assignment ownership.
String? taskProgressValidation(TaskItem task,String status,int percent,String note) {
  if (task.source != 'RECEIVED') { return '仅可更新本人收到的任务'; }
  if (!['NOT_STARTED','IN_PROGRESS','BLOCKED','COMPLETED'].contains(status)) { return '任务状态无效'; }
  if (percent < 0 || percent > 100) { return '完成率必须在0%到100%之间'; }
  if (status == 'COMPLETED' && percent != 100) { return '标记完成时完成率必须为100%'; }
  if (status == 'BLOCKED' && note.trim().isEmpty) { return '受阻状态必须填写原因'; }
  if (status == 'IN_PROGRESS' && percent == 100) { return '进行中不能填100%，请标记完成'; }
  if (status == 'NOT_STARTED' && percent != 0) { return '待开始状态的完成率应为0%'; }
  if (status == 'BLOCKED' && percent == 100) { return '受阻状态不能填100%'; }
  if (task.status == 'COMPLETED') { return '已完成任务请通过审核/退回流程继续处理'; }
  if (task.progressPercent != null && percent < task.progressPercent!) { return '完成率不可倒退'; }
  if (note.trim().length > 1000) { return '进度备注不能超过1000字'; }
  if (status == 'NOT_STARTED' && task.status != 'NOT_STARTED') { return '已开始的任务不能退回待开始'; }
  return null;
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

/// A task submitted by this user. CREATE_REQUEST records are approval requests,
/// not tasks visible in the recipient's inbox until an administrator approves.
class IssuedTask {
  final int id;
  final String name, details, urgency, taskType, startDate, deadline;
  final String reviewStatus, recordType;
  final bool changePending;
  final List<int> assigneeIds;
  final int assigneeCount;
  const IssuedTask({required this.id, required this.name, required this.details,
    required this.startDate, required this.deadline,
    this.urgency='NOT_URGENT', this.taskType='GENERAL',
    this.reviewStatus='APPROVED', this.recordType='ACTIVE',
    this.changePending=false, this.assigneeIds=const [], this.assigneeCount=0});
  bool get isRequest => recordType == 'CREATE_REQUEST';
  bool get isWaiting => isRequest && reviewStatus == 'PENDING';
  String get stateLabel {
    if (changePending) return '变更审核中';
    if (isRequest) {
      return const {'PENDING':'派发待审核','REJECTED':'申请被驳回',
        'APPROVED':'审核已通过', 'WITHDRAWN':'已撤回'}[reviewStatus] ?? reviewStatus;
    }
    return '已发布';
  }
  factory IssuedTask.fromJson(dynamic obj, {bool request=false}) {
    final j=mapOf(obj);
    final ids=listOf(j['assigneeIds']).map((e)=>intOf(e)).where((e)=>e>0).toList();
    return IssuedTask(
      id:intOf(request ? j['requestId'] : j['id'],intOf(j['id'])),
      name:textOf(j['name'],textOf(j['title'])),
      details:textOf(j['details']), urgency:textOf(j['urgency'],'NOT_URGENT'),
      taskType:textOf(j['taskType'],'GENERAL'),
      startDate:textOf(j['startDate']),deadline:textOf(j['deadline']),
      assigneeIds:ids,assigneeCount:intOf(j['assigneeCount'],ids.length),
      reviewStatus:textOf(j['status'],textOf(j['reviewStatus'],request?'PENDING':'APPROVED')),
      recordType:request?'CREATE_REQUEST':'ACTIVE',
      changePending:j['changePending']==true || textOf(j['changeRequestStatus'])=='PENDING',
    );
  }
}

class IssuedTasksResult {
  final List<IssuedTask> items;
  /// Non-null if an older backend cannot list pending requests yet.
  final String? notice;
  const IssuedTasksResult(this.items, {this.notice});
}

class TaskAssignment {
  final int id, assigneeId;
  final String assigneeName, status, reviewStatus, progressNote;
  final int? progressPercent;
  const TaskAssignment({required this.id,required this.assigneeId,required this.assigneeName,required this.status,required this.reviewStatus,this.progressPercent,this.progressNote=''});
  factory TaskAssignment.fromJson(dynamic obj) {final j=mapOf(obj);final a=mapOf(j['assignee']);return TaskAssignment(id:intOf(j['assignmentId']),assigneeId:intOf(a['id'],intOf(j['assigneeId'])),assigneeName:textOf(a['realName'],textOf(j['assigneeName'],'成员')),status:textOf(j['executionStatus'],'NOT_STARTED'),reviewStatus:textOf(j['reviewStatus'],'NONE'),progressPercent:j['progressPercent']==null?null:intOf(j['progressPercent']).clamp(0,100).toInt(),progressNote:textOf(j['progressNote']));}
}

class CalendarDay {
  final String date, mark;
  final int logCount,taskCount;
  const CalendarDay({required this.date,required this.mark,required this.logCount,required this.taskCount});
  factory CalendarDay.fromJson(dynamic obj) {final j=mapOf(obj);return CalendarDay(date:textOf(j['date']),mark:textOf(j['mark'],'NONE'),logCount:intOf(j['logCount']),taskCount:intOf(j['taskCount']));}
}

String encodeJson(dynamic input)=>jsonEncode(input);

/// New task-type tags. Unknown types remain visible as supplied by the server.
String taskTypeLabel(String type) => const {
  'GENERAL':'综合', 'DEVELOPMENT':'开发', 'PRODUCT':'产品', 'TESTING':'测试',
  'OPERATION':'运营', 'SALES':'销售', 'ADMINISTRATIVE':'行政', 'OTHER':'其他',
}[type] ?? (type.isEmpty ? '综合' : type);

Color taskTypeColor(String type) {
  switch (type) {
    case 'DEVELOPMENT': return const Color(0xFF2175B5);
    case 'PRODUCT': return const Color(0xFF8156BD);
    case 'TESTING': return const Color(0xFF1B8B7C);
    case 'OPERATION': return const Color(0xFFBB7A20);
    case 'SALES': return const Color(0xFFB34E4E);
    case 'ADMINISTRATIVE': return const Color(0xFF64758B);
    default: return const Color(0xFF3E677D);
  }
}

class SubordinateTaskSummary {
  final int userId, total, inProgress, completed;
  final String name, departmentName;
  final String role, teamName, username, mbtiType;
  final List<TaskItem> tasks;
  final int? openIssueCount;
  int get visibleIssueCount => openIssueCount ?? tasks.fold<int>(0,(sum,t)=>sum+t.visibleIssueCount);
  const SubordinateTaskSummary({required this.userId, required this.name,
    required this.departmentName, required this.total, required this.inProgress,
    required this.completed, required this.tasks,
    this.role = '', this.teamName = '', this.username = '',this.mbtiType='',this.openIssueCount});
  factory SubordinateTaskSummary.fromJson(dynamic obj) {
    final j = mapOf(obj);
    final items = listOf(j['tasks']).map((e) => TaskItem.fromJson(e, source: 'RECEIVED')).toList();
    return SubordinateTaskSummary(
      userId: intOf(j['userId'], intOf(j['id'])), name: textOf(j['name'], textOf(j['realName'], '成员')),
      departmentName: textOf(j['departmentName']),
      role: textOf(j['role']),
      teamName: textOf(j['teamName']),
      username: textOf(j['username']),
      mbtiType: textOf(j['mbtiType'],textOf(j['mbti'])),
      openIssueCount:j['openIssueCount']==null && j['unresolvedIssueCount']==null?null:intOf(j['openIssueCount'],intOf(j['unresolvedIssueCount'])).clamp(0,999).toInt(),
      total: intOf(j['total'], items.length),
      inProgress: intOf(j['inProgress'], items.where((t) => t.status == 'IN_PROGRESS').length),
      completed: intOf(j['completed'], items.where((t) => t.status == 'COMPLETED').length),
      tasks: items,
    );
  }
}
