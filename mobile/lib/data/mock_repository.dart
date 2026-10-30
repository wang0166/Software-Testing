import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models.dart';
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
  static const demoPassword='demo123456';
  UserProfile? _current;
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();
  Future<void> _wait() => Future<void>.delayed(const Duration(milliseconds:220));
  UserProfile get _user {final u=_current;if(u==null) throw const AppFailure('请先登录');return u;}

  @override Future<UserProfile?> restore() async {
    final p=await _prefs;
    final name=p.getString('pandora_mock_user');
    for (final u in users) {if (u.username==name) { _current=u;return u;}}
    return null;
  }
  @override Future<UserProfile> login(String username,String password) async {
    await _wait();
    for(final u in users) {
      if(u.username==username.trim() && password==demoPassword) {
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
      final expired=log.logDate.compareTo(date)<0 ||
          (log.logDate==date && now.hour>=22);
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
  bool get _canChangeToday {final now=chinaNow;return now.hour<22;}

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
  @override Future<WorkLog> saveLog(String content,{int? id}) async {
    final me=_user;
    if(!me.canWriteLog) throw const AppFailure('管理员没有日志写入权限');
    if(content.trim().isEmpty) throw const AppFailure('日志内容不能为空');
    if(!_canChangeToday) throw const AppFailure('已过今日22:00截止时间，无法编辑');
    final all=await _allLogs();
    final today=todayChina;
    final existing=all.where((e)=>e.authorId==me.id && e.logDate==today).toList();
    if(existing.isNotEmpty && (id==null || existing.first.id!=id)) throw const AppFailure('今天已经有日志，请编辑原有草稿');
    if(id!=null && (existing.isEmpty || existing.first.submitted)) throw const AppFailure('已提交日志不可修改');
    final log=WorkLog(id:id ?? (all.isEmpty?1:all.map((e)=>e.id).reduce((a,b)=>a>b?a:b)+1),authorId:me.id,authorName:me.name,logDate:today,content:content.trim(),status:'DRAFT');
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
    if(!_canChangeToday||old.logDate!=todayChina) throw const AppFailure('今天已截止，无法提交');
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
    TaskItem(id:310,name:'完成模块联调',details:'对照接口文档验证主要业务流程',status:'IN_PROGRESS',source:'RECEIVED',urgency:'URGENT',startDate:dayString(chinaNow.subtract(const Duration(days:2))),deadline:dayString(chinaNow.add(const Duration(days:3)))),
    TaskItem(id:311,name:'提交迭代周报',details:'总结本周成果与下周安排',status:'COMPLETED',source:'RECEIVED',startDate:dayString(chinaNow.subtract(const Duration(days:1))),deadline:dayString(chinaNow.add(const Duration(days:1)))),
    // The following are demo-only assigned tasks so month/week rows can
    // illustrate multi-day overlaps. No production API data is fabricated.
    TaskItem(id:312,name:'检查用例评审',details:'评审移动端核心功能测试用例',status:'NOT_STARTED',source:'RECEIVED',startDate:dayString(chinaNow.add(const Duration(days:1))),deadline:dayString(chinaNow.add(const Duration(days:4)))),
    TaskItem(id:313,name:'移动端界面完善',details:'检查导航、交互状态与视觉一致性',status:'IN_PROGRESS',source:'RECEIVED',startDate:dayString(chinaNow.subtract(const Duration(days:4))),deadline:dayString(chinaNow.add(const Duration(days:2)))),
    TaskItem(id:314,name:'回归测试',details:'复测已修复问题和关键页面',status:'NOT_STARTED',source:'RECEIVED',startDate:dayString(chinaNow.add(const Duration(days:5))),deadline:dayString(chinaNow.add(const Duration(days:8)))),
  ];
  Future<List<TaskItem>> _myTasks() async => _tasksFor(_user.id);
  Future<List<TaskItem>> _tasksFor(int userId) async {
    final p=await _prefs,key='pandora_mock_tasks_$userId';
    final raw=p.getString(key);
    if(raw==null) return _taskSeeds(userId);
    try{return (jsonDecode(raw) as List).map((e)=>TaskItem.fromJson(e,source:textOf(mapOf(e)['source'],'PERSONAL'))).toList();}catch(_){return _taskSeeds(userId);}
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
    all[i]=TaskItem(id:old.id,name:old.name,details:old.details,status:status,source:old.source,deadline:old.deadline,startDate:old.startDate,taskId:old.taskId,senderId:old.senderId,urgency:old.urgency,reviewStatus:old.reviewStatus);
    await _writeTasks(all);
  }
  @override Future<List<CompanyItem>> companyMatters() async =>const [
    CompanyItem(id:1,title:'推动数字化协作升级',content:'让团队信息透明、工作流清晰，持续优化组织协作体验'),
    CompanyItem(id:2,title:'本季度客户体验提升',content:'聚焦需求闭环与交付质量，持续收集反馈'),
    CompanyItem(id:3,title:'强化项目风险管理',content:'建立问题追踪机制，确保关键节点按期完成'),
  ];
  @override Future<List<CompanyItem>> companyImportantTasks() async=>const [
    CompanyItem(id:1,title:'完成潘多拉核心模块',content:'推进日志、点评、统计与移动端联调'),
    CompanyItem(id:2,title:'交付新版项目文档',content:'维护接口契约、测试用例与操作说明'),
  ];
  @override Future<List<CalendarDay>> calendar(String from,String to) async {
    final all=await logs();
    final start=DateTime.parse(from),end=DateTime.parse(to);
    if(end.difference(start).inDays>31) throw const AppFailure('日期范围不能超过31天');
    final received=await tasks(personal:false);
    return [for(var i=0;i<=end.difference(start).inDays;i++) () {final day=dayString(start.add(Duration(days:i)));final lc=all.where((e)=>e.logDate==day).length;final tc=received.where((e)=>e.deadline!=null && (e.startDate==null?e.deadline!.substring(0,10)==day:(e.startDate!.substring(0,10).compareTo(day)<=0 && e.deadline!.substring(0,10).compareTo(day)>=0))).length;return CalendarDay(date:day,mark:tc>0?'GREEN':lc>0?'RED':'NONE',logCount:lc,taskCount:tc);}()];
  }
  @override Future<List<TaskItem>> taskMap() async =>
    await tasks(personal:false);
  @override Future<List<UserProfile>> recipients() async {
    final me=_user;
    if(me.role=='TEAM_LEADER') return users.where((u)=>u.role=='EMPLOYEE' && u.teamId==me.teamId).toList();
    if(me.role=='DEPT_MANAGER') return users.where((u)=>u.role=='TEAM_LEADER' && u.departmentId==me.departmentId).toList();
    if(me.role=='FOUNDER') return users.where((u)=>u.role=='DEPT_MANAGER').toList();
    throw const AppFailure('当前角色不可派发任务');
  }
  Future<List<DispatchedTask>> _myDispatched() async {
    final raw=(await _prefs).getString('pandora_mock_dispatched_${_user.id}');
    if(raw==null) return [];
    try{return (jsonDecode(raw) as List).map(DispatchedTask.fromJson).toList();}catch(_){return [];}
  }
  @override Future<List<DispatchedTask>> dispatchedTasks() async {
    final existing=await _myDispatched();
    final result=<DispatchedTask>[];
    for(final item in existing){
      final assignments=await dispatchedAssignments(item.id);
      result.add(DispatchedTask(id:item.id,name:item.name,details:item.details,urgency:item.urgency,startDate:item.startDate,deadline:item.deadline,assigneeCount:assignments.length,completedCount:assignments.where((a)=>a.status=='COMPLETED').length,pendingReviewCount:assignments.where((a)=>a.reviewStatus=='PENDING').length));
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
          result.add(TaskAssignment(id:t.id,assigneeId:u.id,assigneeName:u.name,status:t.status,reviewStatus:t.reviewStatus));
        }
      }
    }
    return result;
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
      inbox[index]=_copyTask(old,reviewStatus:result,status:result=='RETURNED'?'IN_PROGRESS':old.status);
      await _writeTasksFor(receiver.id,inbox);
      return;
    }
    throw const AppFailure('无权检查此任务');
  }
  TaskItem _copyTask(TaskItem old,{String? status,String? reviewStatus})=>TaskItem(id:old.id,name:old.name,details:old.details,status:status??old.status,source:old.source,deadline:old.deadline,startDate:old.startDate,taskId:old.taskId,senderId:old.senderId,urgency:old.urgency,reviewStatus:reviewStatus??old.reviewStatus);

}
