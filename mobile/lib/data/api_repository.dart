import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../core/daily_todos.dart';
import '../core/models.dart';
import '../core/holiday_calendar.dart';
import 'repository.dart';

/// 与 documents/后端接口文档.md 的统一响应 {code,message,data} 对齐。
/// 真正的数据权限和角色校验始终由服务端执行。
class ApiRepository implements PandoraRepository {
  final String baseUrl;
  final http.Client client;
  final FlutterSecureStorage _store = const FlutterSecureStorage();
  String? _accessToken, _refreshToken;
  ApiRepository({required this.baseUrl, http.Client? client}):client=client??http.Client();

  Uri _uri(String path,[Map<String,String>? query]) {
    final normalized=baseUrl.endsWith('/')?baseUrl.substring(0,baseUrl.length-1):baseUrl;
    return Uri.parse('$normalized$path').replace(queryParameters:query);
  }
  Future<Map<String,dynamic>> _request(String method,String path,{Map<String,String>? query,Object? body,bool authenticated=true,bool retry=true,Duration timeout=const Duration(seconds:15)}) async {
    Future<http.Response> send() async {
      final headers=<String,String>{'Content-Type':'application/json; charset=utf-8'};
      if(authenticated&&_accessToken!=null) headers['Authorization']='Bearer $_accessToken';
      final uri=_uri(path,query);
      final payload=body==null?null:jsonEncode(body);
      switch(method) {
        case 'POST':return client.post(uri,headers:headers,body:payload).timeout(timeout);
        case 'PUT':return client.put(uri,headers:headers,body:payload).timeout(timeout);
        case 'PATCH':return client.patch(uri,headers:headers,body:payload).timeout(timeout);
        case 'DELETE':return client.delete(uri,headers:headers,body:payload).timeout(timeout);
        default:return client.get(uri,headers:headers).timeout(timeout);
      }
    }
    try {
      var response=await send();
      if(response.statusCode==401&&retry&&authenticated&&_refreshToken!=null) {
        try {await _refresh();response=await send();}catch(_){await _clearTokens();throw const AppFailure('登录已过期，请重新登录');}
      }
      final json=mapOf(jsonDecode(utf8.decode(response.bodyBytes)));
      if(response.statusCode<200||response.statusCode>=300||intOf(json['code'],-1)!=0) {
        throw AppFailure(textOf(json['message'],'请求失败（HTTP ${response.statusCode}）'));
      }
      return json;
    } on AppFailure {rethrow;}
      on TimeoutException {throw const AppFailure('请求超时，请检查网络或服务器');}
      on FormatException {throw const AppFailure('服务器返回格式不正确，请联系后端');}
      on http.ClientException {throw const AppFailure('无法连接服务器，请检查接口地址和网络');}
      catch(e){throw AppFailure('连接失败：$e');}
  }
  dynamic _data(Map<String,dynamic> response)=>response['data'];
  List<dynamic> _items(dynamic data) { if(data is List) return data; final j=mapOf(data);return listOf(j['items']); }
  Future<List<dynamic>> _allPages(String path, {Map<String,String>? query,
    bool fetchAll = false}) async {
    const pageSize=50;
    final out=<dynamic>[];
    String? previousPage;
    for (var page = 1; page <= (fetchAll ? 100 : 10); page++) {
      final data=_data(await _request('GET',path,query:{...?query,'page':'$page','size':'$pageSize'}));
      final items=_items(data);
      if (fetchAll) {
        final signature = jsonEncode(items);
        if (signature == previousPage) break;
        previousPage = signature;
      }
      out.addAll(items);
      final total = mapOf(data)['total'];
      if (items.isEmpty || (total == null
        ? items.length < pageSize : out.length >= intOf(total))) {
        break;
      }
    }
    return out;
  }
  Future<void> _saveTokens(String access,String refresh) async {
    _accessToken=access;_refreshToken=refresh;
    await _store.write(key:'pandora_access_token',value:access);
    await _store.write(key:'pandora_refresh_token',value:refresh);
  }
  Future<void> _clearTokens() async {
    _accessToken=null;_refreshToken=null;
    await _store.delete(key:'pandora_access_token');
    await _store.delete(key:'pandora_refresh_token');
  }
  Future<void> _refresh() async {
    final refresh=_refreshToken;
    if(refresh==null) throw const AppFailure('登录已过期');
    final data=mapOf(_data(await _request('POST','/auth/refresh',body:{'refreshToken':refresh},authenticated:false,retry:false)));
    final access=textOf(data['accessToken']);
    if(access.isEmpty) throw const AppFailure('服务器未返回新的访问令牌');
    await _saveTokens(access,textOf(data['refreshToken'],refresh));
  }
  @override Future<UserProfile?> restore() async {
    _accessToken=await _store.read(key:'pandora_access_token');
    _refreshToken=await _store.read(key:'pandora_refresh_token');
    if(_accessToken==null||_accessToken!.isEmpty) return null;
    try {
      final user = UserProfile.fromJson(_data(await _request('GET', '/auth/me')));
      if (user.isActive) return user;
    } catch (_) {
      // An expired or disabled session cannot be restored.
    }
    await _clearTokens();
    return null;
  }
  @override Future<UserProfile> login(String username,String password) async {
    final data=mapOf(_data(await _request('POST','/auth/login',authenticated:false,body:{'username':username,'password':password})));
    final access=textOf(data['accessToken']),refresh=textOf(data['refreshToken']);
    if(access.isEmpty||refresh.isEmpty) throw const AppFailure('服务端没有返回完整令牌');
    final user=UserProfile.fromJson(data['user']);
    if (!user.isActive) throw const AppFailure('该账号已停用');
    await _saveTokens(access,refresh);
    return user;
  }
  // The following endpoints require backend implementation and Web-admin approval.
  // Never treat HTTP 404/500 as a successful password change.
  @override Future<void> requestPasswordReset(String username) async {
    await _request('POST','/auth/password-reset-requests',authenticated:false,body:{'username':username.trim()});
  }
  @override Future<void> requestPasswordChange() async {
    await _request('POST','/account/password-change-requests',body:{});
  }
  @override Future<String> passwordChangeStatus() async {
    final data=mapOf(_data(await _request('GET','/account/password-change-requests/me')));
    return textOf(data['status'],'NONE');
  }
  @override Future<void> completePasswordChange(String newPassword) async {
    await _request('POST','/account/password-change',body:{'newPassword':newPassword});
  }
  @override Future<void> logout() async {
    try {
      if(_refreshToken!=null) await _request('POST','/auth/logout',body:{'refreshToken':_refreshToken});
    } finally {await _clearTokens();}
  }
  @override Future<List<WorkLog>> logs({String? date,String? status}) async {
    final query=<String,String>{};if(date!=null)query['date']=date;if(status!=null)query['status']=status;
    return (await _allPages('/logs',query:query)).map(WorkLog.fromJson).toList();
  }
  @override Future<WorkLog> saveLog(String content,{int? id,String? date}) async {
    final result=_data(await _request(id==null?'POST':'PUT',id==null?'/logs':'/logs/$id',body:{'content':content.trim(),if(date!=null)'logDate':date}));
    return WorkLog.fromJson(result);
  }
  @override Future<WorkLog> submitLog(int id) async {
    final data=_data(await _request('POST','/logs/$id/submit',body:{}));
    final j=mapOf(data);
    if(j.isNotEmpty&&j['id']!=null) return WorkLog.fromJson(data);
    final result=_data(await _request('GET','/logs/$id'));
    return WorkLog.fromJson(result);
  }
  @override Future<List<LogComment>> comments(int logId) async {
    final data=_data(await _request('GET','/logs/$logId/comments'));
    return (data is List?data:_items(data)).map(LogComment.fromJson).toList();
  }
  @override Future<LogComment> addComment(int logId,String content,{int? parentId}) async {
    final result=_data(await _request('POST','/logs/$logId/comments',body:{'content':content.trim(),'parentId':parentId}));
    return LogComment.fromJson(result);
  }
  @override Future<Overview> overview() async=>Overview.fromJson(_data(await _request('GET','/stats/overview')));
  @override Future<List<TrendPoint>> trend(int days) async {
    final data=_data(await _request('GET','/stats/trend',query:{'days':'$days'}));
    final j=mapOf(data);
    final points=data is List?data:(j['days'] is List?j['days']:(j['items'] is List?j['items']:(j['trend'] is List?j['trend']:[])));
    return listOf(points).map(TrendPoint.fromJson).toList();
  }
  @override Future<List<String>> unsubmitted() async {
    final data=_data(await _request('GET','/stats/unsubmitted'));
    return _items(data).map((e){if(e is String)return e;final j=mapOf(e);return textOf(j['realName'],textOf(j['name']));}).toList();
  }
  @override Future<List<TaskItem>> tasks({required bool personal}) async=>
    (await _allPages(personal?'/personal-tasks':'/tasks/received')).map((e)=>TaskItem.fromJson(e,source:personal?'PERSONAL':'RECEIVED')).toList();
  @override Future<TaskItem> createPersonalTask(String name,String details) async {
    final data=_data(await _request('POST','/personal-tasks',body:{'name':name.trim(),'details':details.trim(),'status':'NOT_STARTED'}));
    return TaskItem.fromJson(data);
  }
  @override Future<void> updateTask(TaskItem item,String status) async {
    if(item.source=='PERSONAL') {
      await _request('PUT','/personal-tasks/${item.id}',body:{'name':item.name,'details':item.details,'status':status});
    } else {
      await _request('PATCH','/tasks/assignments/${item.id}/progress',body:{'status':status});
    }
  }
  // New backend contract. Do not silently fall back to status-only PATCH:
  // an old backend might acknowledge a status but discard percent/note.
  @override Future<void> updateTaskProgress(TaskItem item,{
    required String status,required int percent,required String note}) async {
    final issue=taskProgressValidation(item,status,percent,note);
    if(issue!=null) throw AppFailure(issue);
    final result=mapOf(_data(await _request('POST',
      '/tasks/assignments/${item.id}/progress-updates',body:{
      'status':status,'progressPercent':percent,'note':note.trim(),
    })));
    if(intOf(result['id'])<=0 && textOf(result['createdAt']).isEmpty) {
      throw const AppFailure('服务器未确认进度记录已保存，请与后端核对接口');
    }
  }
  @override Future<List<TaskProgressRecord>> taskProgressHistory(int assignmentId) async {
    final data=_data(await _request('GET',
      '/tasks/assignments/$assignmentId/progress-updates'));
    return _items(data).map(TaskProgressRecord.fromJson).toList()
      ..sort((a,b)=>b.createdAt.compareTo(a.createdAt));
  }
  @override Future<List<TaskProgressRecord>> subordinateTaskProgressHistory(
      int userId, int assignmentId) async {
    // Backend MUST enforce viewer's organization hierarchy AND assignment ownership.
    // This route is not supported by the previous Spring Boot version.
    final data=_data(await _request('GET',
      '/tasks/subordinates/$userId/assignments/$assignmentId/progress-updates'));
    return _items(data).map(TaskProgressRecord.fromJson).toList()
      ..sort((a,b)=>b.createdAt.compareTo(a.createdAt));
  }
  @override Future<List<CompanyItem>> companyMatters() async =>
    (await _allPages('/company-matters')).map(CompanyItem.fromJson).toList();
  @override Future<List<CompanyItem>> companyImportantTasks() async =>
    (await _allPages('/company-important-tasks')).map(CompanyItem.fromJson).toList();
  @override Future<List<CalendarDay>> calendar(String from,String to) async {
    final data=_data(await _request('GET','/calendar',query:{'from':from,'to':to}));
    return listOf(mapOf(data)['days']).map(CalendarDay.fromJson).toList();
  }
  @override Future<HolidayYearData> holidayYear(int year) async {
    final data = _data(await _request('GET', '/calendar/holidays',
      query: {'year': '$year'}));
    final parsed = HolidayYearData.fromJson(data);
    if (parsed.year != year) {
      throw const AppFailure('节假日年份与请求不匹配');
    }
    return parsed;
  }
  @override Future<List<TaskItem>> taskMap() async {
    final data=await _allPages('/task-map');
    return data.where((e)=>textOf(mapOf(e)['source'])!='PERSONAL').map((e){final j=mapOf(e);return TaskItem.fromJson({
      ...j,
      'id':j['assignmentId'],
      'assignmentId':j['assignmentId'],
      'executionStatus':j['executionStatus'],
      'details':textOf(j['details']),
    },source:'RECEIVED');}).toList();
  }
  @override Future<AiAnalysis> aiMapAnalysis({bool refresh=false}) async {
    final data=await _request('POST','/ai/map/analysis',
      body:{'refresh':refresh}, timeout:const Duration(seconds:90));
    return AiAnalysis.fromJson(_data(data));
  }
  // 每日待办：云端为准，服务端按登录用户隔离，客户端不再自行编造 AI/统计数据。
  @override Future<List<DailyTodo>> dailyItems({String? from,String? to}) async {
    final rows = await _allPages('/daily-items', fetchAll: true, query: {
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    return rows.map(DailyTodo.fromJson)
      .where((item) => item.id.isNotEmpty && item.overlaps(from: from, to: to)).toList();
  }
  @override Future<DailyTodo> createDailyItem({required String date,
    required String title, String note = '', bool completed = false,
    int colorValue = DailyTodoColors.defaultColor, int sortOrder = 0,
    String? endDate, String? startTime, String? endTime}) =>
    _saveDailyItem(DailyTodo(id: '', date: date, endDate: endDate,
      title: title, note: note, completed: completed, colorValue: colorValue,
      sortOrder: sortOrder, startTime: startTime, endTime: endTime));

  @override Future<DailyTodo> updateDailyItem(DailyTodo item) => _saveDailyItem(item);

  Future<DailyTodo> _saveDailyItem(DailyTodo item) async {
    if (!item.hasValidRange) throw const AppFailure('事项起止日期或时间无效');
    final creating = item.id.isEmpty;
    final body = item.toJson()..remove('id');
    final data = _data(await _request(creating ? 'POST' : 'PUT',
      creating ? '/daily-items' : '/daily-items/${item.id}', body: body));
    final saved = DailyTodo.fromJson(data);
    if (saved.id.isEmpty) throw const AppFailure('服务器未返回每日事项编号');
    if (saved.date != item.date || saved.endDate != item.endDate ||
        saved.startTime != item.startTime || saved.endTime != item.endTime) {
      throw const AppFailure('服务器返回的事项日期或时间与所选范围不一致，请刷新确认');
    }
    return saved;
  }
  @override Future<void> deleteDailyItem(String id) async {
    await _request('DELETE','/daily-items/$id');
  }
  @override Future<List<UserProfile>> recipients() async {
    final data=_data(await _request('GET','/tasks/recipients'));
    return _items(data).map(UserProfile.fromJson).toList();
  }
  @override Future<List<UserProfile>> companyMembers() async =>
    (await _allPages('/tasks/recipients/all', fetchAll: true))
        .map(UserProfile.fromJson).where((user) => user.id > 0 && user.canUseTasks).toList();
  @override Future<String> submitDispatchRequest({required String name,required String details,
    required String startDate, required String deadline, required String urgency,
    required String taskType, required List<int> assigneeIds}) async {
    final data=mapOf(_data(await _request('POST','/tasks/dispatch-requests',body:{
      'name':name, 'details':details, 'startDate':startDate, 'deadline':deadline,
      'urgency':urgency, 'taskType':taskType, 'assigneeIds':assigneeIds,
    })));
    final status=textOf(data['status']);
    if(status!='PENDING' && status!='APPROVED') throw const AppFailure('服务器未确认任务审核状态');
    return status;
  }
  @override Future<List<DispatchReview>> dispatchReviewInbox() async =>
    (await _allPages('/tasks/dispatch-requests/inbox', fetchAll: true))
      .map(DispatchReview.fromJson).where((item) => item.request.isWaiting).toList();

  @override Future<void> reviewDispatchRequest(int requestId, {required bool approve}) async {
    final result = approve ? 'APPROVED' : 'REJECTED';
    final data = mapOf(_data(await _request('POST', '/tasks/dispatch-requests/$requestId/review',
      body: {'result': result})));
    if (textOf(data['status']) != result) {
      throw const AppFailure('服务器未确认审核结果，请刷新后核对');
    }
  }


  // Backend endpoints described in HANDOVER_BACKEND_CONTRACT.md. Requests never
  // change ownership locally; success requires an explicit completed record.
  @override Future<List<TaskHandover>> taskHandovers() async =>
    (await _allPages('/tasks/handovers', fetchAll: true))
        .map(TaskHandover.fromJson).toList();

  @override Future<List<UserProfile>> handoverCandidates(String handoverId) async =>
    (await _allPages('/tasks/handovers/${Uri.encodeComponent(handoverId)}/candidates',
      fetchAll: true)).map(UserProfile.fromJson)
      .where((u) => u.id > 0 && u.isActive).toList();

  @override Future<TaskHandover> confirmTaskHandover(String handoverId, {
    required int newAssigneeId, required String note, String? deadline}) async {
    if (note.trim().isEmpty) throw const AppFailure('请填写交接说明');
    final data = _data(await _request('POST',
      '/tasks/handovers/${Uri.encodeComponent(handoverId)}/confirm', body: {
        'newAssigneeId': newAssigneeId,
        'note': note.trim(),
        if (deadline != null && deadline.isNotEmpty) 'deadline': deadline,
      }));
    final confirmed = TaskHandover.fromJson(data);
    if (confirmed.id != handoverId || confirmed.status != 'COMPLETED' ||
        confirmed.newAssigneeId != newAssigneeId ||
        confirmed.newAssignmentId == null || confirmed.newAssignmentId! <= 0) {
      throw const AppFailure('服务器未确认任务交接成功，请刷新交接清单核对');
    }
    return confirmed;
  }

  @override Future<List<SubordinateTaskSummary>> subordinatesTaskOverview() async =>
    (await _allPages('/tasks/subordinates/overview', fetchAll: true)).map(SubordinateTaskSummary.fromJson).toList();
  @override Future<IssuedTasksResult> issuedTasks() async {
    // Existing API supplies live tasks. The request-history endpoint is a new
    // backend contract; report unsupported history rather than inventing it.
    final active=(await _allPages('/tasks/dispatched'))
        .map((e)=>IssuedTask.fromJson(e)).toList();
    try {
      final pending=(await _allPages('/tasks/dispatch-requests/mine'))
          .map((e)=>IssuedTask.fromJson(e,request:true)).toList();
      return IssuedTasksResult([...pending, ...active]);
    } on AppFailure catch (e) {
      return IssuedTasksResult(active, notice:'派发申请记录尚不可用：${e.message}。已发布任务仍可查看。');
    }
  }

  @override Future<String> requestIssuedTaskEdit(IssuedTask original, {
    required String name, required String details, required String startDate,
    required String deadline, required String urgency, required String taskType,
    required List<int> assigneeIds}) async {
    if(original.changePending) throw const AppFailure('该任务已有待审核变更，请等待审核完成');
    final body={'name':name.trim(),'details':details.trim(),'startDate':startDate,
      'deadline':deadline,'urgency':urgency,'taskType':taskType,'assigneeIds':assigneeIds};
    final data=mapOf(_data(await _request(original.isRequest?'PUT':'POST',
      original.isRequest?'/tasks/dispatch-requests/${original.id}':'/tasks/${original.id}/change-requests',
      body:original.isRequest?body:{...body,'action':'UPDATE'})));
    final status=textOf(data['status']);
    if(status!='PENDING') throw const AppFailure('服务器未确认修改申请为待审核，未视为成功');
    return status;
  }

  @override Future<String> requestIssuedTaskDelete(IssuedTask original) async {
    if(original.changePending) throw const AppFailure('该任务有待审核变更，不能重复申请');
    final data=mapOf(_data(await _request(original.isRequest?'DELETE':'POST',
      original.isRequest?'/tasks/dispatch-requests/${original.id}':'/tasks/${original.id}/change-requests',
      body:original.isRequest?null:{'action':'DELETE'})));
    final status=textOf(data['status']);
    if(original.isRequest && status=='WITHDRAWN') return status;
    if(!original.isRequest && status=='PENDING') return status;
    throw const AppFailure('服务器未确认撤回或删除审核状态，未视为成功');
  }

  @override Future<List<DispatchedTask>> dispatchedTasks() async =>
      (await _allPages('/tasks/dispatched')).map(DispatchedTask.fromJson).toList();
  @override Future<List<TaskAssignment>> dispatchedAssignments(int taskId) async {
    final data=mapOf(_data(await _request('GET','/tasks/$taskId')));
    return listOf(data['assignments']).map(TaskAssignment.fromJson).toList();
  }
  @override Future<void> dispatchTask({required String name,required String details,required String startDate,required String deadline,required String urgency,required List<int> assigneeIds}) async {
    await _request('POST','/tasks',body:{'name':name,'details':details,'startDate':startDate,'deadline':deadline,'urgency':urgency,'assigneeIds':assigneeIds});
  }
  @override Future<void> inviteReview(int assignmentId) async {
    await _request('POST','/tasks/assignments/$assignmentId/review-invitations',body:{});
  }
  @override Future<void> reviewAssignment(int assignmentId,String result,String comment) async {
    await _request('POST','/tasks/assignments/$assignmentId/review',body:{'result':result,'comment':comment});
  }

}
