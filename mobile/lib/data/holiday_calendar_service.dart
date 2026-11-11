import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/holiday_calendar.dart';

/// Shared client-side service for both calendars. Only the backend supplies
/// holiday dates; the local store is a last-successful-response cache.
class HolidayCalendarService {
  final Future<HolidayYearData> Function(int year) fetchYear;
  final Duration refreshInterval;
  final DateTime Function() now;
  final Map<int, Future<HolidayYearLoad>> _inFlight = {};

  HolidayCalendarService({
    required this.fetchYear,
    this.refreshInterval = const Duration(hours: 12),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  String _cacheKey(int year) => 'pandora_cn_holidays_v1_$year';

  Future<HolidayYearLoad> loadYear(int year, {bool forceRefresh = false}) {
    final previous = _inFlight[year];
    if (previous != null) return previous;
    // Complete cleanup before the returned Future completes, so a second
    // sequential load can correctly read the just-saved cache.
    late final Future<HolidayYearLoad> request;
    request = _loadYear(year, forceRefresh: forceRefresh).whenComplete(() {
      if (identical(_inFlight[year], request)) _inFlight.remove(year);
    });
    _inFlight[year] = request;
    return request;
  }

  Future<HolidayYearLoad> _loadYear(int year, {required bool forceRefresh}) async {
    HolidayYearData? cached;
    DateTime? savedAt;
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(year));
      if (raw != null) {
        final saved = jsonDecode(raw);
        if (saved is Map) {
          final record = Map<String, dynamic>.from(saved);
          cached = HolidayYearData.fromJson(record['data']);
          if (cached.year != year) cached = null;
          savedAt = DateTime.tryParse('${record['savedAt']}');
        }
      }
    } catch (_) {
      // Invalid or inaccessible cache never becomes a fabricated holiday.
      cached = null;
      savedAt = null;
    }

    if (!forceRefresh && cached != null && savedAt != null &&
        !now().isBefore(savedAt) &&
        now().difference(savedAt) < refreshInterval) {
      return HolidayYearLoad(data: cached, fromCache: true);
    }

    try {
      final incoming = await fetchYear(year);
      if (incoming.year != year || incoming.region != 'CN' ||
          incoming.timezone != 'Asia/Shanghai') {
        throw const FormatException('后端返回的节假日地区或年份不一致');
      }
      // "unavailable" means no real holiday source. Never cache a demo stub.
      if (incoming.dataStatus != 'unavailable' && prefs != null) {
        try {
          await prefs.setString(_cacheKey(year), jsonEncode({
            'savedAt': now().toIso8601String(),
            'data': incoming.toJson(),
          }));
        } catch (_) {
          // Display the successful network result even if persistence fails.
        }
      }
      return HolidayYearLoad(data: incoming);
    } catch (error) {
      if (cached != null) {
        return HolidayYearLoad(
          data: cached, fromCache: true, stale: true, error: '$error');
      }
      return HolidayYearLoad(error: '$error');
    }
  }

  Future<HolidayCalendarView> loadRange(DateTime start, DateTime end,
      {bool forceRefresh = false}) async {
    if (end.isBefore(start)) throw ArgumentError('日期区间不可倒置');
    final years = <int>{for (var y = start.year; y <= end.year; y++) y};
    final results = await Future.wait([
      for (final year in years) loadYear(year, forceRefresh: forceRefresh),
    ]);
    return HolidayCalendarView({
      for (var i = 0; i < results.length; i++) years.elementAt(i): results[i],
    });
  }
}
