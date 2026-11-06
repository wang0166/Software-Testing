import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pandora AI 地图分析组件。
///
/// 真实接口：POST /api/ai/map/analysis
/// 请求：{"refresh": false}，手动刷新时传 true。
///
/// 优先复用传入的 readAccessToken；未传入时，尝试从常见的本地登录
/// Token 存储键读取。若项目有统一 API 客户端，推荐改为复用它的鉴权方式。
class PandoraAiAnalysisPanel extends StatefulWidget {
  const PandoraAiAnalysisPanel({
    super.key,
    this.readAccessToken,
  });

  final Future<String?> Function()? readAccessToken;

  @override
  State<PandoraAiAnalysisPanel> createState() => _PandoraAiAnalysisPanelState();
}

class _PandoraAiAnalysisPanelState extends State<PandoraAiAnalysisPanel> {
  static const bool _demoMode =
      bool.fromEnvironment('PANDORA_DEMO', defaultValue: false);
  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080/api',
  );

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _analysis;

  @override
  void initState() {
    super.initState();
    if (!_demoMode) {
      _loadAnalysis(refresh: false);
    }
  }

  Future<void> _loadAnalysis({required bool refresh}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _requestAnalysis(refresh: refresh);
      if (!mounted) return;
      setState(() => _analysis = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<Map<String, dynamic>> _requestAnalysis({required bool refresh}) async {
    final token = await (widget.readAccessToken?.call() ?? _readSavedToken());
    if (token == null || token.trim().isEmpty) {
      throw Exception(
        '未找到登录凭证。请先在真实接口模式登录；若仍出现此提示，'
        '需把此组件的 readAccessToken 接到项目现有的登录状态或 API 客户端。',
      );
    }

    final baseUrl = _apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse('$baseUrl/ai/map/analysis');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);

    try {
      final request = await client.postUrl(uri).timeout(const Duration(seconds: 15));
      request.headers.contentType = ContentType.json;
      final authValue = token.trim().replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authValue');
      request.write(jsonEncode({'refresh': refresh}));

      // AI 分析可能涉及模型调用，超时阈值应高于普通业务 API。
      final response = await request.close().timeout(const Duration(seconds: 90));
      final responseText = await response.transform(utf8.decoder).join()
          .timeout(const Duration(seconds: 90));

      dynamic decoded;
      try {
        decoded = jsonDecode(responseText);
      } on FormatException {
        throw Exception('AI 接口返回的不是有效 JSON（HTTP ${response.statusCode}）。');
      }

      if (decoded is! Map) {
        throw Exception('AI 接口数据格式不正确。');
      }
      final envelope = Map<String, dynamic>.from(decoded);
      final message = envelope['message']?.toString() ??
          envelope['msg']?.toString() ?? '服务暂时不可用';

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('AI 接口鉴权失败（HTTP ${response.statusCode}）。请重新登录，'
            '或让此组件与项目现有的 API 客户端共用 Token。');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('AI 分析请求失败（HTTP ${response.statusCode}）：$message');
      }

      // 后端 ApiResponse.success(data)：优先读取 data，同时容忍直接返回 DTO。
      final rawData = envelope.containsKey('data') ? envelope['data'] : envelope;
      if (rawData is! Map) {
        throw Exception('AI 接口未返回分析结果：$message');
      }
      final data = Map<String, dynamic>.from(rawData);
      if ((data['summary']?.toString() ?? '').trim().isEmpty) {
        throw Exception('AI 接口未返回 summary，请核对后端返回字段。');
      }
      return data;
    } on SocketException {
      throw Exception('无法连接后端。请确认 Spring Boot 已启动、手机已执行 adb reverse，'
          '并使用 PANDORA_DEMO=false。');
    } on HandshakeException {
      throw Exception('连接后端时 TLS 握手失败，请检查 API_BASE_URL。');
    } finally {
      client.close(force: true);
    }
  }

  static String _normalizedKey(String key) =>
      key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static const List<String> _tokenKeys = [
    'accessToken',
    'access_token',
    'pandoraAccessToken',
    'authToken',
    'auth_token',
    'jwtToken',
    'jwt',
    'token',
    'loginToken',
  ];

  static String? _readCandidate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();
    // 兼容少数项目把登录信息序列化为 JSON 字符串的情况。
    if (value.startsWith('{')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          for (final key in _tokenKeys) {
            final candidate = decoded[key];
            if (candidate is String && candidate.trim().isNotEmpty) {
              return candidate.trim();
            }
          }
        }
      } catch (_) {
        return null;
      }
      return null;
    }
    return value;
  }

  static String? _selectSavedToken(Map<String, String> values) {
    for (final expected in _tokenKeys) {
      final normalized = _normalizedKey(expected);
      for (final entry in values.entries) {
        if (_normalizedKey(entry.key) == normalized) {
          final token = _readCandidate(entry.value);
          if (token != null) return token;
        }
      }
    }
    return null;
  }

  static Future<String?> _readSavedToken() async {
    try {
      const storage = FlutterSecureStorage();
      final fromSecure = _selectSavedToken(await storage.readAll());
      if (fromSecure != null) return fromSecure;
    } catch (_) {
      // 继续尝试 SharedPreferences；不在日志中打印任何密钥。
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      final values = <String, String>{};
      for (final key in preferences.getKeys()) {
        final value = preferences.get(key);
        if (value is String) values[key] = value;
      }
      return _selectSavedToken(values);
    } catch (_) {
      return null;
    }
  }

  static List<String> _asStringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD6DEE0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, color: Color(0xFF087A80)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('AI 数据分析', style: TextStyle(
                  color: Color(0xFF123247),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                )),
              ),
              if (!_demoMode)
                TextButton.icon(
                  onPressed: _loading ? null : () => _loadAnalysis(refresh: true),
                  icon: const Icon(Icons.refresh, size: 17),
                  label: const Text('重新分析'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_demoMode)
            _notice('当前运行的是演示模式，无法调用真实 DeepSeek 分析。请使用 '
                'PANDORA_DEMO=false 启动 Flutter，并确保后端数据库连接、'
                'DEEPSEEK_API_KEY 和登录状态正常。')
          else ...[
            if (_loading) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 10),
              const Text('正在汇总授权范围内的任务与日志并生成分析…'),
              const SizedBox(height: 12),
            ],
            if (_error != null) ...[
              _notice(_error!, isError: true),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _loading ? null : () => _loadAnalysis(refresh: false),
                icon: const Icon(Icons.replay),
                label: const Text('重试'),
              ),
            ],
            if (_analysis != null) _analysisBody(_analysis!),
            if (!_loading && _analysis == null && _error == null)
              _notice('暂无分析结果，点击“重新分析”开始。'),
          ],
        ],
      ),
    );
  }

  Widget _notice(String message, {bool isError = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFF2F0) : const Color(0xFFF2F6F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: TextStyle(
        fontSize: 13,
        height: 1.5,
        color: isError ? const Color(0xFF9B3227) : const Color(0xFF435D67),
      )),
    );
  }

  Widget _analysisBody(Map<String, dynamic> data) {
    final highlights = _asStringList(data['highlights']);
    final risks = _asStringList(data['risks']);
    final suggestions = _asStringList(data['suggestions']);
    final model = data['model']?.toString();
    final generatedAt = data['generatedAt']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('分析摘要', Icons.summarize_outlined),
        const SizedBox(height: 7),
        Text(data['summary']?.toString() ?? '',
            style: const TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF123247))),
        _bullets('亮点与规律', Icons.trending_up, highlights),
        _bullets('风险与提醒', Icons.warning_amber_outlined, risks,
            empty: '本次分析未指出明确风险。'),
        _bullets('下一步建议', Icons.lightbulb_outline, suggestions),
        if ((model != null && model.isNotEmpty) ||
            (generatedAt != null && generatedAt.isNotEmpty)) ...[
          const Divider(height: 28),
          Text(
            [if (model != null && model.isNotEmpty) '模型：$model',
             if (generatedAt != null && generatedAt.isNotEmpty) '生成时间：$generatedAt'].join('  ·  '),
            style: const TextStyle(color: Color(0xFF6C7E86), fontSize: 11),
          ),
        ],
        const SizedBox(height: 8),
        const Text('仅分析当前账号获授权的数据；内容供工作参考。',
            style: TextStyle(fontSize: 11, color: Color(0xFF6C7E86))),
      ],
    );
  }

  Widget _heading(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 19, color: const Color(0xFF087A80)),
      const SizedBox(width: 6),
      Expanded(child: Text(title, style: const TextStyle(
          color: Color(0xFF123247), fontWeight: FontWeight.w800, fontSize: 15))),
    ]);
  }

  Widget _bullets(String title, IconData icon, List<String> items, {String? empty}) {
    if (items.isEmpty && empty == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(title, icon),
          const SizedBox(height: 7),
          if (items.isEmpty)
            Text(empty!, style: const TextStyle(fontSize: 13, color: Color(0xFF667780)))
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(color: Color(0xFF087A80), fontSize: 15)),
                    Expanded(child: Text(item, style: const TextStyle(
                        color: Color(0xFF123247), fontSize: 13, height: 1.45))),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
