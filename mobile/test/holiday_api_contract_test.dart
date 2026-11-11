import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/api_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('接口固定为 GET /api/calendar/holidays?year=YYYY', () async {
    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(jsonEncode({
        'code': 0, 'message': 'ok',
        'data': {
          'year': 2027, 'region': 'CN', 'timezone': 'Asia/Shanghai',
          'dataStatus': 'not_published', 'lastSyncedAt': '', 'days': [],
        },
      }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final repo = ApiRepository(
      baseUrl: 'http://10.0.2.2:8080/api', client: client);
    final result = await repo.holidayYear(2027);
    expect(requested.path, '/api/calendar/holidays');
    expect(requested.queryParameters['year'], '2027');
    expect(result.dataStatus, 'not_published');
    client.close();
  });
}
