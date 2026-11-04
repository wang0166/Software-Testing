import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../core/models.dart';
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
  Future<Map<String,dynamic>> _request(String method,String path,{Map<String,String>? query,Object? body,bool authenticated=true,bool retry=true}) async {
    Future<http.Response> send() async {
      final headers=<String,String>{'Content-Type':'application/json; charset=utf-8'};
      if(authenticated&&_accessToken!=null) headers['Authorization']='Bearer $_accessToken';
      final uri=_uri(path,query);
      final payload=body==null?null:jsonEncode(body);
      switch(method) {
        case 'POST':return client.post(uri,headers:headers,body:payload).timeout(const Duration(seconds:15));
        case 'PUT':return client.put(uri,headers:headers,body:payload).timeout(const Duration(seconds:15));
        case 'PATCH':return client.patch(uri,headers:headers,body:payload).timeout(const Duration(seconds:15));
        default:return client.get(uri,headers:headers).timeout(const Duration(seconds:15));
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
  Future<List<dynamic>> _allPages(String path,{Map<String,String>? query}) async {
    const pageSize=50;
    final out=<dynamic>[];
    for(var page=1;page<=10;page++) {
      final data=_data(await _request('GET',path,query:{...?query,'page':'$page','size':'$pageSize'}));
      final items=_items(data);
      out.addAll(items);
      if(items.length<pageSize || (mapOf(data)['total']!=null && out.length>=intOf(mapOf(data)['total']))) break;
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
    try {return UserProfile.fromJson(_data(await _request('GET','/auth/me')));}catch(_){await _clearTokens();return null;}
  }
  @override Future<UserProfile> login(String username,String password) async {
    final data=mapOf(_data(await _request('POST','/auth/login',authenticated:false,body:{'username':username,'password':password})));
    final access=textOf(data['accessToken']),refresh=textOf(data['refreshToken']);
    if(access.isEmpty||refresh.isEmpty) throw const AppFailure('服务端没有返回完整令牌');
    final user=UserProfile.fromJson(data['user']);
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
  @override Future<WorkLog> saveLog(String content,{int? id}) async {
    final result=_data(await _request(id==null?'POST':'PUT',id==null?'/logs':'/logs/$id',body:{'content':content.trim()}));
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
  @override Future<List<CompanyItem>> companyMatters() async =>
    (await _allPages('/company-matters')).map(CompanyItem.fromJson).toList();
  @override Future<List<CompanyItem>> companyImportantTasks() async =>
    (await _allPages('/company-important-tasks')).map(CompanyItem.fromJson).toList();
  @override Future<List<CalendarDay>> calendar(String from,String to) async {
    final data=_data(await _request('GET','/calendar',query:{'from':from,'to':to}));
    return listOf(mapOf(data)['days']).map(CalendarDay.fromJson).toList();
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
  @override Future<List<UserProfile>> recipients() async {
    final data=_data(await _request('GET','/tasks/recipients'));
    return _items(data).map(UserProfile.fromJson).toList();
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
