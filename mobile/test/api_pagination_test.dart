import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/api_repository.dart';
import 'package:mobile/data/repository.dart';

void main() {
  test('日志分页可以读取第 501 条', () async {
    final client = MockClient((request) async {
      final page = int.parse(request.url.queryParameters['page']!);
      final start = (page - 1) * 50;
      final count = page <= 10 ? 50 : page == 11 ? 1 : 0;
      final items = List.generate(count, (index) {
        final id = start + index + 1;
        return {
          'id': id,
          'authorId': 1,
          'authorName': '测试员工',
          'logDate': '2026-11-27',
          'content': '日志 $id',
          'status': 'SUBMITTED',
        };
      });
      return http.Response(jsonEncode({
        'code': 0,
        'message': 'ok',
        'data': {'total': 501, 'page': page, 'size': 50, 'items': items},
      }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final repo = ApiRepository(baseUrl: 'https://example.test/api', client: client);

    final logs = await repo.logs();

    expect(logs, hasLength(501));
    expect(logs.last.id, 501);
  });

  test('分页成功响应缺少 items 时报告格式异常', () async {
    final client = MockClient((request) async => http.Response(jsonEncode({
      'code': 0,
      'message': 'ok',
      'data': {'total': 1, 'page': 1, 'size': 50},
    }), 200, headers: {'content-type': 'application/json; charset=utf-8'}));
    final repo = ApiRepository(baseUrl: 'https://example.test/api', client: client);

    await expectLater(repo.logs(), throwsA(isA<AppFailure>()
      .having((error) => error.message, 'message', contains('分页响应格式异常'))));
  });
}
