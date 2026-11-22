import 'dart:collection' show IterableExtensions;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/daily_todos.dart';
import '../core/models.dart';
import '../core/holiday_calendar.dart';
import '../core/task_issue_utils.dart';
import 'repository.dart';

class MockRepository implements PandoraRepository {
  static const users=<UserProfile>[
    UserProfile(id:12,username:'demo001',name:'林小满',role:'EMPLOYEE',departmentId:3,teamId:8),
    UserProfile(id:13,username:'demo002',name:'陈星禾',role:'EMPLOYEE',departmentId:3,teamId:8),
    UserProfile(id:8,username:'leader',name:'周知夏',role:'TEAM_LEADER',departmentId:3,teamId:8),
    UserProfile(id:3,username:'manager',name:'苏以安',role:'DEPT_MANAGER',departmentId:3),
    UserProfile(id:21,username:'product01',name:'顾清禾',role:'EMPLOYEE',departmentId:2,teamId:5),
    UserProfile(id:22,username:'productleader',name:'沈嘉宁',role:'TEAM_LEADER',departmentId:2,teamId:5),
    UserProfile(id:2,username:'productmanager',name:'唐予宁',role:'DEPT_MANAGER',departmentId:2),
    UserProfile(id:1,username:'founder',name:'许远山',role:'FOUNDER'),
    UserProfile(id:99,username:'admin',name:'系统管理员',role:'ADMIN'),
  ];
  final Set<int> disabledUserIds;
  MockRepository({this.disabledUserIds = const {}});

  bool _isEnabled(UserProfile user) => user.isActive && !disabledUserIds.contains(user.id);

  static const demoPassword='demo123456';
  UserProfile? _current;
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();
  Future<void> _wait() => Future<void>.delayed(const Duration(milliseconds:220));
  UserProfile get _user {
    final user = _current;
    if (user == null) throw const AppFailure('请先登录');
    if (!_isEnabled(user)) throw const AppFailure('该账号已停用');
    return user;
  }

  @override Future<UserProfile?> restore() async {
    final p=await _prefs;
    final name=p.getString('pandora_mock_user');
    for (final u in users) {if (u.username==name && _isEnabled(u)) { _current=u;return u;}}
    return null;
  }
  @override Future<UserProfile> login(String username,String password) async {
    await _wait();
    for(final u in users) {
      if(u.username==username.trim() && password==demoPassword) {
        if (!_isEnabled(u)) throw const AppFailure('该账号已停用');
        _current=u;
        (await _prefs).setString('pandora_mock_user',u.username);
        return u;
      }
    }
    throw const AppFailure('演示账号或密码不正确');
  }
  @override Future<void> requestPasswordReset(String username) async {
    if (!users.any((e) => e.username == username.trim())) throw const AppFailure('演示账号不存在');
    // Local demo only; no real admin Web service receives this request.
    (await _prefs).setString('pandora_demo_reset_${username.trim()}', 'PENDING');
  }
  @override Future<void> requestPasswordChange() async {
    final pref = await _prefs;
    final key = 'pandora_demo_password_request_${_user.id}';
    if (pref.getString(key) == 'PENDING') throw const AppFailure('申请正在等待管理员审核');
    await pref.setString(key, 'PENDING');
  }
  @override Future<String> passwordChangeStatus() async {
    return (await _prefs).getString('pandora_demo_password_request_${_user.id}') ?? 'NONE';
  }
  @override Future<void> completePasswordChange(String newPassword) async {
    // The demo deliberately cannot approve itself; approval belongs to the Web administrator.
    throw const AppFailure('演示模式无管理员审批服务，请连接后端完成修改');
  }
  @override Future<void> logout() async {_current=null;(await _prefs).remove('pandora_mock_user');}

  List<WorkLog> _seeds() {
    final now=chinaNow;
    const samples=[
      '完成客户需求梳理与模块优先级确认，整理了本周移动端开发清单，并与团队同步接口字段。明天继续完善登录与日志模块。',
      '优化项目首页布局和色彩体系，修复移动端交互问题，完成接口返回结果检查，准备下一轮联调。',
      '今天完成了日报功能测试，并汇总了用户反馈。需要进一步确认统计指标口径。',
      '开展团队例会，协调任务分配，完成了迭代目标拆分和风险排查。',
      '梳理数据库字段与组织权限关系，参与讨论任务审批流程，完成相关设计说明。',
    ];
    final out=<WorkLog>[];
    var id=100;
    for(var d=0;d<9;d++) {
      for(final u in users.where((x)=>x.role!='ADMIN')) {
        if((d+u.id)%5==0) continue;
        final date=dayString(now.subtract(Duration(days:d)));
        out.add(WorkLog(id:id++,authorId:u.id,authorName:u.name,logDate:date,content:samples[(d+u.id)%samples.length],status:d==0 && u.id%3==0?'DRAFT':'SUBMITTED',isImportant:d%4==0&&u.id==13,submittedAt:d==0 && u.id%3==0?null:'${date}T18:10:00+08:00'));
      }
    }
    return out;
  }
  Future<List<WorkLog>> _allLogs() async {
    final p=await _prefs;
    final raw=p.getString('pandora_mock_logs_v1');
    List<WorkLog> logs;
    if(raw==null) {
      logs=_seeds();
    } else {
      try {logs=(jsonDecode(raw) as List).map(WorkLog.fromJson).toList();}
      catch (_) {logs=_seeds();}
    }
    // Business-day cutoff uses Asia/Shanghai, matching the backend contract.
    // Any prior-day draft is past its deadline; today's drafts convert at 22:00.
    final now=chinaNow;
    final date=todayChina;
    var changed=false;
    final result=<WorkLog>[];
    for(final log in logs) {
      final expired=log.logDate==date && now.hour>=22;
      if(log.status=='DRAFT' && expired) {
        result.add(WorkLog(
          id:log.id,authorId:log.authorId,authorName:log.authorName,
          logDate:log.logDate,content:log.content,status:'SUBMITTED',
          isImportant:log.isImportant,
          submittedAt:'${log.logDate}T22:00:00+08:00',
        ));
        changed=true;
      } else {
        result.add(log);
      }
    }
    if(changed) await _setLogs(result);
    return result;
  }
  Future<void> _setLogs(List<WorkLog> logs) async {(await _prefs).setString('pandora_mock_logs_v1',jsonEncode(logs.map((e)=>e.toJson()).toList()));}
  bool _canSee(UserProfile viewer,UserProfile author) {
    switch(viewer.role) {
      case 'FOUNDER': return true;
      case 'ADMIN': return false;
      case 'DEPT_MANAGER': return author.departmentId==viewer.departmentId;
      case 'TEAM_LEADER': return author.teamId==viewer.teamId;
      default: return author.id==viewer.id;
    }
  }
  bool _isDirectManager(UserProfile viewer,UserProfile author) {
    return switch(viewer.role) {
      'TEAM_LEADER' => author.role=='EMPLOYEE' && author.teamId==viewer.teamId,
      'DEPT_MANAGER' => author.role=='TEAM_LEADER' && author.departmentId==viewer.departmentId,
      'FOUNDER' => author.role=='DEPT_MANAGER',
      _ => false,
    };
  }
  UserProfile _findUser(int id)=>users.firstWhere((u)=>u.id==id,orElse:()=>_user);
  bool _canChangeDay(String day) {
    final parsed = DateTime.tryParse(day);
    if (parsed == null) return false;
    final now = chinaNow;
    final today = DateTime(now.year, now.month, now.day);
    final delta = today.difference(DateTime(parsed.year, parsed.month, parsed.day)).inDays;
    return delta >= 0 && delta <= 2;
  }

  @override Future<List<WorkLog>> logs({String? date,String? status}) async {
    await _wait();
    final viewer=_user;
    final all=await _allLogs();
    return all.where((l)=>_canSee(viewer,_findUser(l.authorId)) && (date==null||l.logDate==date) && (status==null||l.status==status)).map((l) {
      final author = _findUser(l.authorId);
      return WorkLog(id:l.id,authorId:l.authorId,authorName:l.authorName,logDate:l.logDate,content:l.content,status:l.status,isImportant:l.isImportant,submittedAt:l.submittedAt,
        departmentId:author.departmentId,teamId:author.teamId,
        departmentName:author.departmentId == 3 ? '技术研发部' : author.departmentId == 2 ? '产品设计部' : '公司管理层',
        teamName:author.teamId == 8 ? '移动研发团队' : author.teamId == 5 ? '产品规划团队' : '部门管理', authorRole: author.role);
    }).toList()..sort((a,b){final r=b.logDate.compareTo(a.logDate);return r!=0?r:b.id.compareTo(a.id);});
  }
  @override Future<WorkLog> saveLog(String content,{int? id,String? date}) async {
    final me=_user;
    if(!me.canWriteLog) throw const AppFailure('管理员没有日志写入权限');
    if(content.trim().isEmpty) throw const AppFailure('日志内容不能为空');
    final day = date ?? todayChina;
    if(!_canChangeDay(day)) throw const AppFailure('只能写入最近三个自然日的日志');
    final all=await _allLogs();
    final today=day;
    final existing=all.where((e)=>e.authorId==me.id && e.logDate==today).toList();
    if(existing.isNotEmpty && (id==null || existing.first.id!=id)) throw const AppFailure('所选日期已有日志，请编辑原有记录');
    if(id!=null && existing.isEmpty) throw const AppFailure('要编辑的日志不存在');
    final log=WorkLog(id:id ?? (all.isEmpty?1:all.map((e)=>e.id).reduce((a,b)=>a>b?a:b)+1),authorId:me.id,authorName:me.name,logDate:today,content:content.trim(),status:existing.isNotEmpty ? existing.first.status : 'DRAFT',submittedAt:existing.isNotEmpty ? existing.first.submittedAt : null);
    all.removeWhere((e)=>e.id==id);
    all.add(log);
    await _setLogs(all);
    return log;
  }
  @override Future<WorkLog> submitLog(int id) async {
    final me=_user;
    final all=await _allLogs();
    final i=all.indexWhere((x)=>x.id==id);
    if(i<0||all[i].authorId!=me.id) throw const AppFailure('无权提交此日志');
    final old=all[i];
    if(old.submitted) return old;
    if(!_canChangeDay(old.logDate)) throw const AppFailure('仅允许提交最近三个自然日的日志');
    final updated=WorkLog(id:old.id,authorId:old.authorId,authorName:old.authorName,logDate:old.logDate,content:old.content,status:'SUBMITTED',isImportant:old.isImportant,submittedAt:DateTime.now().toUtc().toIso8601String());
    all[i]=updated;await _setLogs(all);return updated;
  }
  Future<List<LogComment>> _allComments() async {
    final p=await _prefs;
    final raw=p.getString('pandora_mock_comments_v1');
    if(raw!=null) {try {return (jsonDecode(raw) as List).map(LogComment.fromJson).toList();} catch (_){}}
    return const [];
  }
  @override Future<List<LogComment>> comments(int logId) async {
    final all=await _allLogs();
    final matches=all.where((l)=>l.id==logId);
    if(matches.isEmpty) throw const AppFailure('日志不存在');
    final author=_findUser(matches.first.authorId), viewer=_user;
    if(viewer.id!=author.id && !_isDirectManager(viewer,author)) throw const AppFailure('仅作者及直属上级可查看点评');
    return (await _allComments()).where((e)=>e.logId==logId).toList()..sort((a,b)=>a.id.compareTo(b.id));
  }
  @override Future<LogComment> addComment(int logId,String content,{int? parentId}) async {
    if(content.trim().isEmpty) throw const AppFailure('点评不能为空');
    final logs=await _allLogs();
    final matches=logs.where((l)=>l.id==logId);
    if(matches.isEmpty) throw const AppFailure('日志不存在');
    final author=_findUser(matches.first.authorId),viewer=_user;
    final list=await comments(logId);
    if(viewer.id==author.id) {
      if(parentId==null || !list.any((e)=>e.id==parentId && e.authorId!=author.id)) throw const AppFailure('请回复直属上级的点评');
    } else if(!_isDirectManager(viewer,author)||parentId!=null) {
      throw const AppFailure('只有直属上级可以发起点评');
    }
    final all=await _allComments();
    final comment=LogComment(id:all.isEmpty?1:all.last.id+1,logId:logId,authorId:viewer.id,authorName:viewer.name,content:content.trim(),createdAt:DateTime.now().toIso8601String(),parentId:parentId);
    all.add(comment);
    (await _prefs).setString('pandora_mock_comments_v1',jsonEncode(all.map((e)=>e.toJson()).toList()));
    return comment;
  }
  @override Future<Overview> overview() async {
    final viewer=_user;
    final eligible=users.where((u)=>u.role!='ADMIN' && _canSee(viewer,u)).toList();
    final today=(await _allLogs()).where((l)=>l.logDate==todayChina && l.submitted);
    final count=eligible.where((u)=>today.any((l)=>l.authorId==u.id)).length;
    final expected=eligible.length;
    return Overview(expected:expected,submitted:count,unsubmitted:expected-count,rate:expected==0?0:count/expected*100);
  }
  @override Future<List<String>> unsubmitted() async {
    final viewer=_user,all=await _allLogs();
    return users.where((u)=>u.role!='ADMIN'&&_canSee(viewer,u)&&!all.any((l)=>l.authorId==u.id&&l.logDate==todayChina&&l.submitted)).map((u)=>u.name).toList();
  }
  @override Future<List<TrendPoint>> trend(int days) async {
    final viewer=_user,all=await _allLogs();
    return List.generate(days,(i){final date=dayString(chinaNow.subtract(Duration(days:days-i-1)));return TrendPoint(day:date,count:all.where((l)=>l.logDate==date && l.submitted && _canSee(viewer,_findUser(l.authorId))).length);});
  }
  List<TaskItem> _taskSeeds(int userId)=>[
    TaskItem(id:210,name:'完善本周工作计划',details:'梳理本周目标、风险与时间节点，及时同步团队',status:'IN_PROGRESS',source:'PERSONAL'),
    TaskItem(id:211,name:'整理需求文档',details:'补充本次迭代的验收要求与功能清单',status:'NOT_STARTED',source:'PERSONAL'),
    TaskItem(id:310,progressPercent:60,progressNote:'已完成大部分接口联调，正在修复数据同步问题',name:'完成模块联调',taskType:'DEVELOPMENT',details:'对照接口文档验证主要业务流程',status:'IN_PROGRESS',source:'RECEIVED',urgency:'URGENT',startDate:dayString(chinaNow.subtract(const Duration(days:2))),deadline:dayString(chinaNow.add(const Duration(days:3)))),
    TaskItem(id:311,progressPercent:100,name:'提交迭代周报',taskType:'OPERATION',details:'总结本周成果与下周安排',status:'COMPLETED',source:'RECEIVED',startDate:dayString(chinaNow.subtract(const Duration(days:1))),deadline:dayString(chinaNow.add(const Duration(days:1)))),
    // The following are demo-only assigned tasks so month/week rows can
    // illustrate multi-day overlaps. No production API data is fabricated.
    TaskItem(id:312,name:'检查用例评审',taskType:'TESTING',details:'评审移动端核心功能测试用例',status:'NOT_STARTED',source:'RECEIVED',startDate:dayString(chinaNow.add(const Duration(days:1))),deadline:dayString(chinaNow.add(const Duration(days:4)))),
    TaskItem(id:313,progressPercent:35,name:'移动端界面完善',taskType:'PRODUCT',details:'检查导航、交互状态与视觉一致性',status:'IN_PROGRESS',source:'RECEIVED',startDate:dayString(chinaNow.subtract(const Duration(days:4))),deadline:dayString(chinaNow.add(const Duration(days:2)))),
    TaskItem(id:314,name:'回归测试',taskType:'TESTING',details:'复测已修复问题和关键页面',status:'NOT_STARTED',source:'RECEIVED',startDate:dayString(chinaNow.add(const Duration(days:5))),deadline:dayString(chinaNow.add(const Duration(days:8)))),
  ];
  Future<List<TaskItem>> _myTasks() async => _tasksFor(_user.id);

  // A visible, resolvable example of a subordinate incident, for demo builds
  // only.  It is an actual demo assignment and progress record, NOT a fake
  // badge count.  Two different teams get an example so founder / department /
  // team-level accounts can all verify the red badge without first creating an
  // incident on another account.  Production ApiRepository never uses this.
  TaskItem? _showcaseIssue(int userId) {
    if (userId != 13 && userId != 21) return null;
    return TaskItem(
      id: 399,
      name: '【演示】跨部门接口协作',
      details: '演示任务：下属上报接口鉴权异常，需管理者查看反馈并协助解决。',
      status: 'BLOCKED',
      source: 'RECEIVED',
      urgency: 'URGENT',
      taskType: 'DEVELOPMENT',
      progressPercent: 45,
      progressNote: '【演示异常】接口鉴权失败，等待上级协调权限。',
      startDate: dayString(chinaNow.subtract(const Duration(days: 1))),
      deadline: dayString(chinaNow.add(const Duration(days: 2))),
    );
  }

  Future<List<TaskItem>> _tasksFor(int userId) async {
    final p = await _prefs;
    final key = 'pandora_mock_tasks_$userId';
    final raw = p.getString(key);
    List<TaskItem> items;
    if (raw == null) {
      items = _taskSeeds(userId);
    } else {
      try {
        items = (jsonDecode(raw) as List).map((e) => TaskItem.fromJson(
          e, source: textOf(mapOf(e)['source'], 'PERSONAL'))).toList();
      } catch (_) {
        items = _taskSeeds(userId);
      }
    }

    // V1.10.3 demo-data migration: also works for users who already launched
    // V1.10.2 and have saved their local task list. Never duplicates an issue.
    // Once the assignee resolves the task, its saved status is preserved.
    final example = _showcaseIssue(userId);
    if (example != null && !items.any((t) => t.id == example.id && t.source == 'RECEIVED')) {
      items = [...items, example];
      await _writeTasksFor(userId, items);
      final historyKey = _progressKey(userId, example.id);
      if (p.getString(historyKey) == null) {
        final name = users.firstWhere((u) => u.id == userId).name;
        final event = TaskProgressRecord(
          id: DateTime.now().microsecondsSinceEpoch,
          status: 'BLOCKED',
          note: example.progressNote,
          authorName: name,
          createdAt: DateTime.now().toUtc().toIso8601String(),
          percent: example.progressPercent,
        );
        await p.setString(historyKey, jsonEncode([event.toJson()]));
      }
    }
    final existingIds = items.where((item) => item.source == 'RECEIVED')
      .map((item) => item.id).toSet();
    for (final request in await _approvedDispatches()) {
      final assignmentId = intOf(mapOf(request['assignmentIds'])['$userId']);
      if (assignmentId == 0 || !existingIds.add(assignmentId)) continue;
      items.add(TaskItem(id: assignmentId, taskId: intOf(request['taskId']),
        senderId: intOf(request['requesterId']), name: textOf(request['name']),
        details: textOf(request['details']), startDate: textOf(request['startDate']),
        deadline: textOf(request['deadline']), urgency: textOf(request['urgency']),
        taskType: textOf(request['taskType']), status: 'NOT_STARTED',
        source: 'RECEIVED', reviewStatus: 'NONE'));
    }
    return items;
  }
  Future<void> _writeTasks(List<TaskItem> items) async => _writeTasksFor(_user.id,items);
  Future<void> _writeTasksFor(int id,List<TaskItem> items) async {(await _prefs).setString('pandora_mock_tasks_$id',jsonEncode(items.map((e)=>e.toJson()).toList()));}
  @override Future<List<TaskItem>> tasks({required bool personal}) async {
    if(!_user.canUseTasks) return [];
    return (await _myTasks()).where((e)=>personal?e.source=='PERSONAL':e.source=='RECEIVED').toList();
  }
  @override Future<TaskItem> createPersonalTask(String name,String details) async {
    if(!_user.canUseTasks) throw const AppFailure('当前角色不能创建自建任务');
    if(name.trim().isEmpty||details.trim().isEmpty) throw const AppFailure('任务名称和详情都不能为空');
    final all=await _myTasks();
    final task=TaskItem(id:all.isEmpty?1:all.map((e)=>e.id).reduce((a,b)=>a>b?a:b)+1,name:name.trim(),details:details.trim(),status:'NOT_STARTED',source:'PERSONAL');
    all.add(task);await _writeTasks(all);return task;
  }
  @override Future<void> updateTask(TaskItem item,String status) async {
    if(!_user.canUseTasks) throw const AppFailure('当前角色没有任务权限');
    final all=await _myTasks();
    final i=all.indexWhere((e)=>e.id==item.id&&e.source==item.source);
    if(i<0) throw const AppFailure('任务不存在');
    final old=all[i];
    if(old.source=='RECEIVED' && !(old.status==status || (old.status=='NOT_STARTED'&&status=='IN_PROGRESS') || (old.status=='IN_PROGRESS'&&status=='COMPLETED'))) throw const AppFailure('接收任务进度只能逐步推进');
    all[i]=TaskItem(id:old.id,name:old.name,details:old.details,status:status,source:old.source,deadline:old.deadline,startDate:old.startDate,taskId:old.taskId,senderId:old.senderId,urgency:old.urgency,reviewStatus:old.reviewStatus,taskType:old.taskType,assigneeName:old.assigneeName,progressNote:old.progressNote,progressPercent:old.progressPercent,progressUpdatedAt:old.progressUpdatedAt);
    await _writeTasks(all);
  }
  String _progressKey(int userId,int taskId) => 'pandora_v19_progress_${userId}_$taskId';
  Future<List<TaskProgressRecord>> _progressFor(int userId, int assignmentId) async {
    final raw=(await _prefs).getString(_progressKey(userId,assignmentId));
    if(raw==null) return [];
    try {
      return (jsonDecode(raw) as List).map(TaskProgressRecord.fromJson).toList()
        ..sort((a,b)=>b.createdAt.compareTo(a.createdAt));
    } catch (_) {throw const AppFailure('历史进度记录格式异常');}
  }

  bool _canInspectSubordinate(UserProfile viewer, UserProfile member) {
    if(viewer.id==member.id || member.role=='ADMIN') return false;
    return switch(viewer.role) {
      'FOUNDER' => true,
      'DEPT_MANAGER' => member.departmentId==viewer.departmentId,
      'TEAM_LEADER' => member.teamId==viewer.teamId && member.role=='EMPLOYEE',
      _ => false,
    };
  }

  @override Future<List<TaskProgressRecord>> subordinateTaskProgressHistory(
      int userId, int assignmentId) async {
    if(!users.any((u)=>u.id==userId)) {
      throw const AppFailure('员工不存在或无权限访问');
    }
    final member=_findUser(userId);
    if(!_canInspectSubordinate(_user,member)) {
      throw const AppFailure('无权限查看该员工任务反馈');
    }
    final tasks=await _tasksFor(userId);
    if(!tasks.any((t)=>t.id==assignmentId && t.source=='RECEIVED')) {
      throw const AppFailure('无法查看该员工未授权的任务');
    }
    return _progressFor(userId,assignmentId);
  }

  @override Future<List<TaskProgressRecord>> taskProgressHistory(int assignmentId) async {
    final tasks=await _myTasks();
    if(!tasks.any((e)=>e.id==assignmentId && e.source=='RECEIVED')) {
      throw const AppFailure('只能查看自己接收任务的进度历史');
    }
    return _progressFor(_user.id,assignmentId);
  }
  @override Future<void> updateTaskProgress(TaskItem item,{
    required String status,required int percent,required String note}) async {
    final me=_user;
    final all=await _myTasks();
    final i=all.indexWhere((e)=>e.id==item.id && e.source=='RECEIVED');
    if(i<0) throw const AppFailure('只能更新本人收到的任务');
    final old=all[i];
    final problem=taskProgressValidation(old,status,percent,note);
    if(problem!=null) throw AppFailure(problem);
    final now=DateTime.now().toUtc().toIso8601String();
    final record=TaskProgressRecord(id:DateTime.now().microsecondsSinceEpoch,
      status:status,note:note.trim(),percent:percent,authorName:me.name,
      createdAt:now);
    final previous=await taskProgressHistory(item.id);
    all[i]=TaskItem(id:old.id,name:old.name,details:old.details,status:status,
      source:old.source,urgency:old.urgency,startDate:old.startDate,
      deadline:old.deadline,taskId:old.taskId,senderId:old.senderId,
      reviewStatus:old.reviewStatus,taskType:old.taskType,
      assigneeName:old.assigneeName,progressNote:note.trim(),
      progressPercent:percent,progressUpdatedAt:now);
    await _writeTasks(all);
    await (await _prefs).setString(_progressKey(me.id,item.id),
      jsonEncode([record,...previous].map((e)=>e.toJson()).toList()));
  }
  @override Future<List<CompanyItem>> companyMatters() async => const [
    CompanyItem(id:1,title:'公司年度战略目标评审',content:'战略事项 · 明确部门重点与季度里程碑'),
    CompanyItem(id:2,title:'产品质量专项治理',content:'高优先级 · 建立问题闭环和质量标准'),
    CompanyItem(id:3,title:'重点客户交付保障',content:'客户事项 · 重点跟踪交付和验收节点'),
    CompanyItem(id:4,title:'研发效率改进计划',content:'研发事项 · 优化联调和版本发布流程'),
    CompanyItem(id:5,title:'统一任务审批制度',content:'管理事项 · 任务跨部门派发需审核'),
    CompanyItem(id:6,title:'全员安全培训安排',content:'行政事项 · 覆盖账号安全及数据保护'),
    CompanyItem(id:7,title:'预算执行和成本分析',content:'财务事项 · 定期复核预算使用情况'),
    CompanyItem(id:8,title:'员工发展与人才盘点',content:'组织事项 · 优化能力发展规划'),
    CompanyItem(id:9,title:'企业内部信息协同',content:'运营事项 · 推动信息透明与职责清晰'),
    CompanyItem(id:10,title:'第四季度业务复盘',content:'战略事项 · 汇总目标、偏差和下一步计划'),
  ];
  @override Future<List<CompanyItem>> companyImportantTasks() async => const [
    CompanyItem(id:1,title:'完成潘多拉移动端联调',content:'研发中心 · 整体验收'),
    CompanyItem(id:2,title:'实施公司级重点任务审核',content:'管理办公室 · 流程评审'),
    CompanyItem(id:3,title:'完成组织权限审计',content:'技术平台部 · 访问控制'),
    CompanyItem(id:4,title:'发布本月客户交付清单',content:'客户成功部 · 交付节点'),
    CompanyItem(id:5,title:'完成核心报表数据校验',content:'数据分析组 · 指标核对'),
    CompanyItem(id:6,title:'开展应用安全检查',content:'技术平台部 · 关键操作审计'),
    CompanyItem(id:7,title:'组织年度战略评审会议',content:'管理办公室 · 日程准备'),
    CompanyItem(id:8,title:'完成新员工入职培训',content:'人力资源部 · 完成确认'),
    CompanyItem(id:9,title:'优化任务可视化看板',content:'产品研发部 · 体验优化'),
    CompanyItem(id:10,title:'提交季度成本管理报告',content:'财务管理部 · 审核归档'),
  ];
  @override Future<List<CalendarDay>> calendar(String from,String to) async {
    final all=await logs();
    final start=DateTime.parse(from),end=DateTime.parse(to);
    if(end.difference(start).inDays>31) throw const AppFailure('日期范围不能超过31天');
    final received=await tasks(personal:false);
    return [for(var i=0;i<=end.difference(start).inDays;i++) () {final day=dayString(start.add(Duration(days:i)));final lc=all.where((e)=>e.logDate==day).length;final tc=received.where((e)=>e.deadline!=null && (e.startDate==null?e.deadline!.substring(0,10)==day:(e.startDate!.substring(0,10).compareTo(day)<=0 && e.deadline!.substring(0,10).compareTo(day)>=0))).length;return CalendarDay(date:day,mark:tc>0?'GREEN':lc>0?'RED':'NONE',logCount:lc,taskCount:tc);}()];
  }
  @override Future<HolidayYearData> holidayYear(int year) async =>
    HolidayYearData(year: year, dataStatus: 'unavailable');
  @override Future<List<TaskItem>> taskMap() async =>
    await tasks(personal:false);

  @override Future<AiAnalysis> aiMapAnalysis({bool refresh=false}) async {
    throw const AppFailure('当前为演示数据模式，未连接后端，无法调用 DeepSeek 分析');
  }

  @override Future<List<UserProfile>> companyMembers() async {
    final viewer = _user;
    if (!viewer.canUseTasks) {
      throw const AppFailure('当前账号无法申请派发任务');
    }
    return users.where((user) => user.canUseTasks && _isEnabled(user)).toList();
  }

  UserProfile? _directReviewer(UserProfile requester) =>
    users.where((candidate) => _isDirectManager(candidate, requester)).firstOrNull;

  @override Future<String> submitDispatchRequest({required String name, required String details,
    required String startDate, required String deadline, required String urgency,
    required String taskType, required List<int> assigneeIds}) async {
    _checkIssueChange(name, details, startDate, deadline, assigneeIds);
    final requester = _user;
    final reviewer = _directReviewer(requester);
    if (reviewer == null || !_isEnabled(reviewer)) {
      throw const AppFailure('当前账号没有可用的直属上级，请联系管理员配置组织关系');
    }
    return _mutateDispatch(() async {
      final saved = await _requestsFor(requester.id);
      saved.add({
        'id': DateTime.now().microsecondsSinceEpoch,
        'name': name.trim(), 'details': details.trim(), 'urgency': urgency,
        'taskType': taskType, 'assigneeIds': assigneeIds, 'startDate': startDate,
        'deadline': deadline, 'status': 'PENDING', 'reviewerName': reviewer.name,
      });
      await _writeRequestsFor(requester.id, saved);
      return 'PENDING';
    });
  }

  String get _issuedChangesKey => 'pandora_mock_issued_changes_${_user.id}';

  Future<List<Map<String,dynamic>>> _requestsFor(int userId) async {
    return _readRequests(await _prefs, userId);
  }

  List<Map<String, dynamic>> _readRequests(SharedPreferences prefs, int userId) {
    final raw = prefs.getStringList('pandora_mock_dispatch_requests_$userId') ?? [];
    final rows = raw.map((value) => mapOf(jsonDecode(value))).toList();
    for (var index = 0; index < rows.length; index++) {
      // Early demo versions stored requests without an ID.
      rows[index]['id'] ??= -(userId * 100000 + index + 1);
    }
    return rows;
  }

  Future<void> _writeRequestsFor(int userId, List<Map<String,dynamic>> items) async {
    final ok = await (await _prefs).setStringList('pandora_mock_dispatch_requests_$userId',
      items.map(jsonEncode).toList());
    if (!ok) throw const AppFailure('保存派发申请失败');
  }

  Future<List<Map<String,dynamic>>> _myRequests() => _requestsFor(_user.id);

  Future<void> _writeRequests(List<Map<String,dynamic>> items) =>
    _writeRequestsFor(_user.id, items);

  Future<List<Map<String,dynamic>>> _approvedDispatches() async {
    final prefs = await _prefs;
    return [
      for (final user in users)
        for (final request in _readRequests(prefs, user.id))
          if (request['status'] == 'APPROVED' && request['assignmentIds'] is Map)
            {...request, 'requesterId': user.id},
    ];
  }

  @override Future<List<DispatchReview>> dispatchReviewInbox() async {
    final viewer = _user;
    final byId = {for (final user in users) user.id: user.name};
    final prefs = await _prefs;
    return [
      for (final requester in users.where((user) => _directReviewer(user)?.id == viewer.id))
        for (final request in _readRequests(prefs, requester.id))
          if (request['status'] == 'PENDING')
            DispatchReview(request: IssuedTask.fromJson(request, request: true),
              requesterName: requester.name,
              assigneeNames: listOf(request['assigneeIds']).map((id) =>
                byId[intOf(id)] ?? '成员 $id').toList()),
    ];
  }

  static Future<void> _dispatchWrites = Future<void>.value();

  Future<T> _mutateDispatch<T>(Future<T> Function() mutate) {
    final result = _dispatchWrites.then((_) => mutate());
    _dispatchWrites = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  @override Future<void> reviewDispatchRequest(int requestId, {required bool approve}) =>
    _mutateDispatch(() => _reviewRequest(requestId, approve: approve));

  Future<void> _reviewRequest(int requestId, {required bool approve}) async {
    final viewer = _user;
    for (final requester in users.where((user) => _directReviewer(user)?.id == viewer.id)) {
      final rows = await _requestsFor(requester.id);
      final request = rows.where((row) =>
        row['id'] == requestId && row['status'] == 'PENDING').firstOrNull;
      if (request == null) continue;
      if (approve) {
        final ids = listOf(request['assigneeIds']).map((id) => intOf(id)).toSet();
        final allowed = users.where((user) => user.canUseTasks && _isEnabled(user))
          .map((user) => user.id).toSet();
        if (!_isEnabled(requester) || ids.isEmpty || !allowed.containsAll(ids)) {
          throw const AppFailure('申请人或接收人已不可用，请驳回申请');
        }
        // Publish the task and all its assignments with a single storage write.
        var publicationId = DateTime.now().microsecondsSinceEpoch;
        for (final published in await _approvedDispatches()) {
          final previous = intOf(published['taskId']);
          if (publicationId <= previous + 100) publicationId = previous + 101;
        }
        request['taskId'] = publicationId;
        request['assignmentIds'] = {
          for (final id in ids) '$id': publicationId + id,
        };
      }
      request['status'] = approve ? 'APPROVED' : 'REJECTED';
      request['reviewerName'] = viewer.name;
      await _writeRequestsFor(requester.id, rows);
      return;
    }
    throw const AppFailure('申请已处理或不在您的直属审核范围');
  }

  Future<List<Map<String,dynamic>>> _myChanges() async {
    final raw=(await _prefs).getStringList(_issuedChangesKey) ?? [];
    return raw.map((e)=>mapOf(jsonDecode(e))).toList();
  }
  Future<void> _writeChanges(List<Map<String,dynamic>> changes) async =>
    (await _prefs).setStringList(_issuedChangesKey,changes.map(jsonEncode).toList());

  @override Future<IssuedTasksResult> issuedTasks() async {
    final changes=await _myChanges();
    final active=await _myDispatched();
    final requestItems=(await _myRequests()).where((j)=>j['status']!='APPROVED').map((j)=>
      IssuedTask.fromJson(j,request:true)).toList().reversed;
    final activeItems=active.reversed.map((t)=>IssuedTask(
      id:t.id,name:t.name,details:t.details,urgency:t.urgency,taskType:t.taskType,
      startDate:t.startDate,deadline:t.deadline,assigneeCount:t.assigneeCount,
      changePending:changes.any((j)=>intOf(j['taskId'])==t.id && j['status']=='PENDING'),
    )).toList();
    // Recipient IDs are resolved only for tasks issued by the current user.
    final withRecipients=<IssuedTask>[];
    for(final t in activeItems) {
      final ids=(await dispatchedAssignments(t.id)).map((a)=>a.assigneeId).toList();
      withRecipients.add(IssuedTask(id:t.id,name:t.name,details:t.details,
        urgency:t.urgency,taskType:t.taskType,startDate:t.startDate,deadline:t.deadline,
        assigneeCount:ids.length,assigneeIds:ids,changePending:t.changePending));
    }
    return IssuedTasksResult([...requestItems,...withRecipients]);
  }

  void _checkIssueChange(String name, String details, String startDate,
    String deadline, List<int> assigneeIds, {Set<int> existingAssignees = const {}}) {
    if(name.trim().isEmpty || details.trim().isEmpty || assigneeIds.isEmpty) {
      throw const AppFailure('任务标题、内容及接收人不能为空');
    }
    if(startDate.compareTo(deadline)>=0) throw const AppFailure('截止时间必须晚于开始时间');
    final viewer = _user;
    if (!viewer.canUseTasks) {
      throw const AppFailure('当前账号无法申请派发任务');
    }
    if (assigneeIds.toSet().length != assigneeIds.length ||
        assigneeIds.any((id) => !existingAssignees.contains(id) &&
          !users.any((user) => user.id == id && user.canUseTasks && _isEnabled(user)))) {
      throw const AppFailure('接收人不属于可派发成员范围');
    }
  }

  @override Future<String> requestIssuedTaskEdit(IssuedTask original, {
    required String name, required String details, required String startDate,
    required String deadline, required String urgency, required String taskType,
    required List<int> assigneeIds}) => _mutateDispatch(() async {
    final existing = original.isRequest ? const <int>{} :
      (await dispatchedAssignments(original.id)).map((item) => item.assigneeId).toSet();
    _checkIssueChange(name, details, startDate, deadline, assigneeIds,
      existingAssignees: existing);
    final data={'name':name.trim(),'details':details.trim(),
      'startDate':startDate,'deadline':deadline,'urgency':urgency,
      'taskType':taskType,'assigneeIds':assigneeIds,'status':'PENDING'};
    if(original.isRequest) {
      final all=await _myRequests();
      final index=all.indexWhere((j)=>intOf(j['id'])==original.id);
      if(index<0 || all[index]['status']!='PENDING') {
        throw const AppFailure('只有本人待审核的派发申请允许修改');
      }
      all[index]={...all[index],...data};
      await _writeRequests(all);
      return 'PENDING';
    }
    final all=await _myDispatched();
    if(!all.any((t)=>t.id==original.id)) throw const AppFailure('无权修改他人发布的任务');
    final changes=await _myChanges();
    if(changes.any((j)=>intOf(j['taskId'])==original.id && j['status']=='PENDING')) {
      throw const AppFailure('已有待审核变更申请，不能重复提交');
    }
    changes.add({...data,'action':'UPDATE','taskId':original.id});
    await _writeChanges(changes);
    // Active task remains unchanged pending approval.
    return 'PENDING';
  });

  @override Future<String> requestIssuedTaskDelete(IssuedTask original) =>
    _mutateDispatch(() async {
    if(original.isRequest) {
      final all=await _myRequests();
      final before=all.length;
      all.removeWhere((j)=>intOf(j['id'])==original.id && j['status']=='PENDING');
      if(all.length==before) throw const AppFailure('无法撤回该派发申请');
      await _writeRequests(all);
      return 'WITHDRAWN';
    }
    final active=await _myDispatched();
    if(!active.any((t)=>t.id==original.id)) throw const AppFailure('无权删除他人发布的任务');
    final changes=await _myChanges();
    if(changes.any((j)=>intOf(j['taskId'])==original.id && j['status']=='PENDING')) {
      throw const AppFailure('已有待审核变更，不能重复提交');
    }
    changes.add({'taskId':original.id,'action':'DELETE','status':'PENDING'});
    await _writeChanges(changes);
    // Only administrator approval may remove the published task.
    return 'PENDING';
  });


  static const String _handoverStorageKey = 'pandora_mock_handovers_v1';
  Future<List<TaskHandover>> _savedHandovers() async {
    final raw = (await _prefs).getString(_handoverStorageKey);
    if (raw == null) return [];
    try {
      return listOf(jsonDecode(raw)).map(TaskHandover.fromJson).toList();
    } catch (_) {
      throw const AppFailure('本地交接记录格式异常，已保留数据，请检查备份');
    }
  }
  Future<void> _saveHandovers(List<TaskHandover> rows) async {
    await (await _prefs).setString(_handoverStorageKey,
      jsonEncode(rows.map((h) => h.toJson()).toList()));
  }

  /// In the demonstration, detection happens on listing after account status
  /// changes. Production MUST create pending records transactionally on server
  /// deactivation, even if nobody opens the task list.
  @override Future<List<TaskHandover>> taskHandovers() async {
    final manager = _user;
    if (!const ['TEAM_LEADER', 'DEPT_MANAGER', 'FOUNDER'].contains(manager.role)) {
      return [];
    }
    final all = await _savedHandovers();
    var changed = false;
    for (final former in users) {
      if (_isEnabled(former) || !_isDirectManager(manager, former)) continue;
      final tasks = await _tasksFor(former.id);
      for (final task in tasks) {
        if (task.source != 'RECEIVED' || task.status == 'COMPLETED' ||
            task.handoverStatus == 'COMPLETED') {
          continue;
        }
        final id = '${former.id}_${task.id}';
        if (all.any((h) => h.id == id)) continue;
        all.add(TaskHandover(id: id,
          originalUserId: former.id, originalUserName: former.name,
          originalAssignmentId: task.id,
          taskName: task.name, taskDetails: task.details,
          executionStatus: task.status, status: 'PENDING',
          taskType: task.taskType, urgency: task.urgency,
          progressNote: task.progressNote,
          progressPercent: task.progressPercent ?? 0,
          deadline: task.deadline));
        changed = true;
      }
    }
    if (changed) await _saveHandovers(all);
    // Managers only see their own direct subordinates' records, including
    // completed handovers; histories of other departments remain private.
    return all.where((h) {
      final former = users.where((u) => u.id == h.originalUserId);
      return former.isNotEmpty && _isDirectManager(manager, former.first);
    }).toList()..sort((a,b) => a.pending == b.pending
        ? a.originalUserName.compareTo(b.originalUserName)
        : a.pending ? -1 : 1);
  }

  @override Future<List<UserProfile>> handoverCandidates(String handoverId) async {
    final row = (await taskHandovers()).where((h) => h.id == handoverId);
    if (row.isEmpty) throw const AppFailure('交接记录不存在或无权查看');
    if (!row.first.pending) return [];
    return users.where((u) => u.id != row.first.originalUserId &&
      _isEnabled(u) && _isDirectManager(_user, u)).toList();
  }

  @override Future<TaskHandover> confirmTaskHandover(String handoverId, {
    required int newAssigneeId, required String note, String? deadline}) async {
    if (note.trim().isEmpty) throw const AppFailure('请填写交接说明');
    final available = await taskHandovers();
    final matched = available.where((h) => h.id == handoverId).toList();
    if (matched.isEmpty) throw const AppFailure('交接记录不存在或无权办理');
    final handover = matched.single;
    if (!handover.pending) throw const AppFailure('该任务已交接，不能重复办理');
    final candidates = await handoverCandidates(handoverId);
    if (!candidates.any((u) => u.id == newAssigneeId)) {
      throw const AppFailure('接手人不存在、已停用或不属于可交接范围');
    }
    final successor = candidates.firstWhere((u) => u.id == newAssigneeId);
    final formerTasks = await _tasksFor(handover.originalUserId);
    final originalIndex = formerTasks.indexWhere((t) => t.source == 'RECEIVED'
        && t.id == handover.originalAssignmentId);
    if (originalIndex < 0) throw const AppFailure('原任务已不存在，交接已停止');
    final original = formerTasks[originalIndex];
    if (original.status == 'COMPLETED') throw const AppFailure('任务已完成，无需交接');
    final newDeadline = deadline == null || deadline.isEmpty
        ? original.deadline : deadline;
    if (newDeadline != null && DateTime.tryParse(newDeadline) == null) {
      throw const AppFailure('截止日期格式无效');
    }

    // Demo-only persistent state. The production backend must make all writes
    // below an atomic transaction and enforce uniqueness / idempotency.
    final pref = await _prefs;
    final next = (pref.getInt('pandora_mock_handover_next_assignment') ?? 900000) + 1;
    final successorsTasks = await _tasksFor(successor.id);
    if (successorsTasks.any((t) => t.id == next && t.source == 'RECEIVED')) {
      throw const AppFailure('交接任务编号冲突');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final newTask = TaskItem.fromJson({
      ...original.toJson(), 'id': next, 'assignmentId': next,
      'deadline': newDeadline,
      'assigneeName': successor.name, 'handoverStatus': 'NONE',
      'handoverToName': '',
    }, source: 'RECEIVED');
    formerTasks[originalIndex] = TaskItem.fromJson({
      ...original.toJson(), 'handoverStatus': 'COMPLETED',
      'handoverToName': successor.name,
    }, source: 'RECEIVED');
    final previous = await _progressFor(handover.originalUserId, original.id);
    final transferEvent = TaskProgressRecord(
      id: DateTime.now().microsecondsSinceEpoch, status: original.status,
      percent: original.progressPercent,
      note: '从${handover.originalUserName}交接给${successor.name}：${note.trim()}',
      authorName: _user.name, createdAt: now);
    await _writeTasksFor(successor.id, [...successorsTasks, newTask]);
    await _writeTasksFor(handover.originalUserId, formerTasks);
    await pref.setString(_progressKey(successor.id, next),
      jsonEncode([transferEvent, ...previous].map((e) => e.toJson()).toList()));
    await pref.setInt('pandora_mock_handover_next_assignment', next);
    final confirmed = TaskHandover.fromJson({
      ...handover.toJson(), 'status': 'COMPLETED',
      'newAssigneeId': successor.id, 'newAssigneeName': successor.name,
      'newAssignmentId': next, 'note': note.trim(),
      'deadline': newDeadline, 'completedAt': now,
    });
    final stored = await _savedHandovers();
    final index = stored.indexWhere((h) => h.id == handoverId);
    if (index < 0 || !stored[index].pending) {
      throw const AppFailure('交接状态发生变化，请刷新');
    }
    stored[index] = confirmed;
    await _saveHandovers(stored);
    return confirmed;
  }

  @override Future<List<SubordinateTaskSummary>> subordinatesTaskOverview() async {
    final me = _user;
    if (!(const ['TEAM_LEADER','DEPT_MANAGER','FOUNDER']).contains(me.role)) return [];
    final list = <SubordinateTaskSummary>[];
    for (final member in users) {
      if (member.id == me.id || member.role == 'ADMIN') continue;
      final allowed = _canInspectSubordinate(me,member);
      if (!allowed) continue;
      final originals = (await _tasksFor(member.id))
        .where((t) => t.source == 'RECEIVED').toList();
      final tasks = <TaskItem>[];
      for(final t in originals) {
        final history = await _progressFor(member.id,t.id);
        final issueCount = unresolvedIssueEvents(t,history);
        tasks.add(TaskItem.fromJson({
          ...t.toJson(), 'openIssueCount': issueCount,
        },source:'RECEIVED'));
      }
      list.add(SubordinateTaskSummary(userId:member.id, name:member.name,
        departmentName:'${member.roleLabel} · ${member.departmentId ?? '公司级'}',
        role: member.role, teamName: member.teamId == null ? '部门直属' : '团队 ${member.teamId}',
        username: member.username, isActive: _isEnabled(member),
        total:tasks.length, inProgress:tasks.where((t)=>t.status=='IN_PROGRESS' &&
          t.handoverStatus!='COMPLETED').length,
        completed:tasks.where((t)=>t.status=='COMPLETED').length,
        openIssueCount:tasks.fold<int>(0,(total,t)=>total+t.visibleIssueCount), tasks:tasks));
    }
    return list;
  }

  @override Future<List<UserProfile>> recipients() async {
    final me=_user;
    if (const ['TEAM_LEADER', 'DEPT_MANAGER', 'FOUNDER'].contains(me.role) && _isEnabled(me)) {
      return users.where((user) => _isEnabled(user) && _isDirectManager(me, user)).toList();
    }
    throw const AppFailure('当前角色不可派发任务');
  }
  Future<List<DispatchedTask>> _myDispatched() async {
    final raw=(await _prefs).getString('pandora_mock_dispatched_${_user.id}');
    final saved = <DispatchedTask>[];
    if (raw != null) {
      try {
        saved.addAll(listOf(jsonDecode(raw)).map(DispatchedTask.fromJson));
      } on FormatException {
        // Unreadable legacy records must not prevent access to new requests.
      }
    }
    return [
      ...saved,
      for (final request in await _myRequests())
        if (request['status'] == 'APPROVED')
          DispatchedTask.fromJson({...request, 'id': request['taskId'],
            'assigneeCount': listOf(request['assigneeIds']).length}),
    ];
  }
  @override Future<List<DispatchedTask>> dispatchedTasks() async {
    final existing=await _myDispatched();
    final result=<DispatchedTask>[];
    for(final item in existing){
      final assignments=await dispatchedAssignments(item.id);
      result.add(DispatchedTask(id:item.id,name:item.name,details:item.details,urgency:item.urgency,startDate:item.startDate,deadline:item.deadline,taskType:item.taskType,assigneeCount:assignments.length,completedCount:assignments.where((a)=>a.status=='COMPLETED').length,pendingReviewCount:assignments.where((a)=>a.reviewStatus=='PENDING').length));
    }
    return result.reversed.toList();
  }
  @override Future<List<TaskAssignment>> dispatchedAssignments(int taskId) async {
    final sender=_user;
    final all=await _myDispatched();
    if(!all.any((e)=>e.id==taskId)) throw const AppFailure('只能查看自己派发的任务');
    final result=<TaskAssignment>[];
    for(final u in users){
      for(final t in await _tasksFor(u.id)){
        if(t.source=='RECEIVED'&&t.taskId==taskId&&t.senderId==sender.id) {
          result.add(TaskAssignment(id:t.id,assigneeId:u.id,assigneeName:u.name,status:t.status,reviewStatus:t.reviewStatus,progressPercent:t.progressPercent,progressNote:t.progressNote));
        }
      }
    }
    return result;
  }
  Future<List<DailyTodo>> _loadDaily() async {
    final raw=(await _prefs).getString('pandora_mock_daily_${_user.id}');
    if(raw==null) return [];
    try{return (jsonDecode(raw) as List).map(DailyTodo.fromJson).toList();}catch(_){return [];}
  }
  Future<void> _saveDaily(List<DailyTodo> items) async {
    final ok = await (await _prefs).setString('pandora_mock_daily_${_user.id}',
      jsonEncode(items.map((e) => e.toJson()).toList()));
    if (!ok) throw const AppFailure('保存事项失败');
  }
  @override Future<List<DailyTodo>> dailyItems({String? from,String? to}) async {
    final all=await _loadDaily();
    return all.where((e) => e.overlaps(from: from, to: to)).toList();
  }
  @override Future<DailyTodo> createDailyItem({required String date,
    required String title, String note = '', bool completed = false,
    int colorValue = DailyTodoColors.defaultColor, int sortOrder = 0,
    String? endDate, String? startTime, String? endTime}) async {
    if(title.trim().isEmpty) throw const AppFailure('请填写事项名称');
    final all=await _loadDaily();
    final item=DailyTodo(id:'${DateTime.now().microsecondsSinceEpoch}',
      date: date, endDate: endDate, title: title.trim(), note: note.trim(),
      completed: completed, colorValue: colorValue, sortOrder: sortOrder,
      startTime: startTime, endTime: endTime);
    if (!item.hasValidRange) throw const AppFailure('事项起止日期或时间无效');
    all.add(item); await _saveDaily(all); return item;
  }
  @override Future<DailyTodo> updateDailyItem(DailyTodo item) async {
    if (!item.hasValidRange || item.title.trim().isEmpty) {
      throw const AppFailure('事项名称、起止日期或时间无效');
    }
    final all=await _loadDaily();
    final index=all.indexWhere((e)=>e.id==item.id);
    if(index<0) throw const AppFailure('事项不存在或无权修改');
    all[index]=item; await _saveDaily(all); return item;
  }
  @override Future<void> deleteDailyItem(String id) async {
    final all=await _loadDaily();
    await _saveDaily(all.where((e)=>e.id!=id).toList());
  }
  @override Future<void> dispatchTask({required String name,required String details,required String startDate,required String deadline,required String urgency,required List<int> assigneeIds}) async {
    if(name.trim().isEmpty||details.trim().isEmpty||assigneeIds.isEmpty) throw const AppFailure('请填写任务信息并选择接收人');
    if(startDate.compareTo(deadline)>0) throw const AppFailure('截止时间不能早于开始日期');
    final legal=(await recipients()).map((e)=>e.id).toSet();
    if(assigneeIds.toSet().length!=assigneeIds.length||assigneeIds.any((e)=>!legal.contains(e)))throw const AppFailure('存在无权派发的接收人');
    final me=_user,items=await _myDispatched();
    final id=DateTime.now().microsecondsSinceEpoch;
    final task=DispatchedTask(id:id,name:name.trim(),details:details.trim(),startDate:startDate,deadline:deadline,urgency:urgency,assigneeCount:assigneeIds.length);
    items.add(task);
    (await _prefs).setString('pandora_mock_dispatched_${me.id}',jsonEncode(items.map((e)=>e.toJson()).toList()));
    for(final receiverId in assigneeIds){
      final inbox=await _tasksFor(receiverId);
      inbox.add(TaskItem(id:id+receiverId,taskId:id,senderId:me.id,name:name.trim(),details:details.trim(),status:'NOT_STARTED',reviewStatus:'NONE',source:'RECEIVED',startDate:startDate,deadline:deadline,urgency:urgency));
      await _writeTasksFor(receiverId,inbox);
    }
  }
  @override Future<void> inviteReview(int assignmentId) async {
    final inbox=await _myTasks();
    final index=inbox.indexWhere((e)=>e.id==assignmentId && e.source=='RECEIVED');
    if(index<0)throw const AppFailure('未找到本人接收的任务');
    final old=inbox[index];
    if(old.status!='COMPLETED'||old.reviewStatus=='PENDING'||old.reviewStatus=='APPROVED')throw const AppFailure('仅完成且未待检的任务可以邀请检查');
    inbox[index]=_copyTask(old,reviewStatus:'PENDING');
    await _writeTasks(inbox);
  }
  @override Future<void> reviewAssignment(int assignmentId,String result,String comment) async {
    final me=_user;
    if(result!='APPROVED'&&result!='RETURNED')throw const AppFailure('检查结果无效');
    for(final receiver in users){
      final inbox=await _tasksFor(receiver.id);
      final index=inbox.indexWhere((e)=>e.id==assignmentId&&e.senderId==me.id);
      if(index<0)continue;
      final old=inbox[index];
      if(old.reviewStatus!='PENDING')throw const AppFailure('仅待检查的任务可审核');
      final resetPercent = result=='RETURNED' && old.progressPercent==100 ? 95 : old.progressPercent;
      inbox[index]=TaskItem(id:old.id,name:old.name,details:old.details,
        status:result=='RETURNED'?'IN_PROGRESS':old.status,source:old.source,
        deadline:old.deadline,startDate:old.startDate,taskId:old.taskId,
        senderId:old.senderId,urgency:old.urgency,reviewStatus:result,
        taskType:old.taskType,assigneeName:old.assigneeName,
        progressNote:old.progressNote,progressPercent:resetPercent,
        progressUpdatedAt:DateTime.now().toUtc().toIso8601String());
      await _writeTasksFor(receiver.id,inbox);
      final key=_progressKey(receiver.id,old.id);
      final prefs=await _prefs;
      final raw=prefs.getString(key);
      final existing=raw==null?<dynamic>[]:listOf(jsonDecode(raw));
      final event=TaskProgressRecord(id:DateTime.now().microsecondsSinceEpoch,
        status:result,note:comment,authorName:me.name,
        createdAt:DateTime.now().toUtc().toIso8601String(),percent:resetPercent);
      await prefs.setString(key,jsonEncode([event.toJson(),...existing]));
      return;
    }
    throw const AppFailure('无权检查此任务');
  }
  TaskItem _copyTask(TaskItem old,{String? status,String? reviewStatus})=>TaskItem(id:old.id,name:old.name,details:old.details,status:status??old.status,source:old.source,deadline:old.deadline,startDate:old.startDate,taskId:old.taskId,senderId:old.senderId,urgency:old.urgency,reviewStatus:reviewStatus??old.reviewStatus,taskType:old.taskType,assigneeName:old.assigneeName,progressNote:old.progressNote,progressPercent:old.progressPercent,progressUpdatedAt:old.progressUpdatedAt);

}
