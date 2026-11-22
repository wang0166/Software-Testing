import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/api_repository.dart';
import 'package:mobile/data/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('后端必须明确确认交接，不能把普通成功响应误判成已交接', () async {
    final sent = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/tasks/handovers/12_310/confirm')) {
        sent.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(jsonEncode({'code': 0, 'message': 'ok',
          'data': {'id': '12_310', 'status': 'PENDING'}}), 200,
          headers: {'content-type': 'application/json'});
      }
      return http.Response(jsonEncode({'code': 0,
        'data': {'items': <dynamic>[], 'total': 0}}), 200,
        headers: {'content-type': 'application/json'});
    });
    final repo = ApiRepository(baseUrl: 'https://example.test/api', client: client);
    await expectLater(repo.confirmTaskHandover('12_310',
      newAssigneeId: 13, note: '交接说明', deadline: '2026-12-02'),
      throwsA(isA<AppFailure>()));
    expect(sent.single['newAssigneeId'], 13);
    expect(sent.single['deadline'], '2026-12-02');
  });
}
