/// China mainland holiday data supplied by the backend, never generated from
/// hard-coded dates on the client. Festival names are independent of days off.
class HolidayDayInfo {
  final String date;
  final String dayType;
  final String holidayName;
  final List<String> festivals;
  final String sourceUrl;

  const HolidayDayInfo({
    required this.date,
    required this.dayType,
    this.holidayName = '',
    this.festivals = const [],
    this.sourceUrl = '',
  });

  factory HolidayDayInfo.fromJson(dynamic value) {
    if (value is! Map) throw const FormatException('节假日日期记录不是对象');
    final json = Map<String, dynamic>.from(value);
    final date = (json['date'] ?? '').toString();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        DateTime.tryParse(date) == null ||
        _dateKey(DateTime.parse(date)) != date) {
      throw FormatException('节假日日期格式错误：$date');
    }
    if (json['dayType'] == null) {
      throw const FormatException('节假日记录缺少 dayType');
    }
    final dayType = json['dayType'].toString();
    if (!const {'normal', 'holiday', 'makeup_workday'}.contains(dayType)) {
      throw FormatException('未知节假日类型：$dayType');
    }
    final rawFestivals = json['festivals'];
    if (rawFestivals != null && rawFestivals is! List) {
      throw const FormatException('festivals 必须是数组');
    }
    return HolidayDayInfo(
      date: date,
      dayType: dayType,
      holidayName: (json['holidayName'] ?? '').toString().trim(),
      festivals: rawFestivals == null
          ? const []
          : List<String>.unmodifiable((rawFestivals as List)
              .whereType<String>()
              .map((String name) => name.trim())
              .where((String name) => name.isNotEmpty)),
      sourceUrl: (json['sourceUrl'] ?? '').toString(),
    );
  }

  bool get isDayOff => dayType == 'holiday';
  bool get isMakeupWorkday => dayType == 'makeup_workday';
  String get dayTypeLabel => isDayOff ? '休' : isMakeupWorkday ? '班' : '';
  String get festivalLabel => festivals.isNotEmpty ? festivals.first : holidayName;

  String get description {
    final labels = <String>[
      if (isDayOff) '放假',
      if (isMakeupWorkday) '调休补班',
      if (holidayName.isNotEmpty) holidayName,
      ...festivals.where((item) => item != holidayName),
    ];
    return labels.join(' · ');
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'dayType': dayType,
        'holidayName': holidayName,
        'festivals': festivals,
        if (sourceUrl.isNotEmpty) 'sourceUrl': sourceUrl,
      };
}

class HolidayYearData {
  final int year;
  final String region;
  final String timezone;
  /// published, partial, not_published, or unavailable.
  final String dataStatus;
  final String lastSyncedAt;
  final List<HolidayDayInfo> days;

  const HolidayYearData({
    required this.year,
    this.region = 'CN',
    this.timezone = 'Asia/Shanghai',
    required this.dataStatus,
    this.lastSyncedAt = '',
    this.days = const [],
  });

  factory HolidayYearData.fromJson(dynamic value) {
    if (value is! Map) throw const FormatException('节假日年度数据不是对象');
    final json = Map<String, dynamic>.from(value);
    final rawYear = json['year'];
    final year = rawYear is int ? rawYear : int.tryParse('$rawYear');
    if (year == null || year < 2000 || year > 2100) {
      throw const FormatException('节假日年度字段无效');
    }
    final region = (json['region'] ?? '').toString();
    final timezone = (json['timezone'] ?? '').toString();
    if (region != 'CN' || timezone != 'Asia/Shanghai') {
      throw const FormatException('节假日地区或时区与中国大陆日历不符');
    }
    final status = (json['dataStatus'] ?? '').toString();
    if (!const {'published', 'partial', 'not_published', 'unavailable'}
        .contains(status)) {
      throw FormatException('未知节假日数据状态：$status');
    }
    final rawDays = json['days'];
    if (rawDays is! List) throw const FormatException('days 必须是数组');
    final days = rawDays.map(HolidayDayInfo.fromJson).toList();
    if (days.any((day) => int.parse(day.date.substring(0, 4)) != year)) {
      throw const FormatException('节假日记录与请求年份不一致');
    }
    if (days.map((day) => day.date).toSet().length != days.length) {
      throw const FormatException('同一日期存在重复节假日记录');
    }
    return HolidayYearData(
      year: year,
      region: region,
      timezone: timezone,
      dataStatus: status,
      lastSyncedAt: (json['lastSyncedAt'] ?? '').toString(),
      days: List.unmodifiable(days),
    );
  }

  Map<String, dynamic> toJson() => {
        'year': year,
        'region': region,
        'timezone': timezone,
        'dataStatus': dataStatus,
        'lastSyncedAt': lastSyncedAt,
        'days': days.map((item) => item.toJson()).toList(),
      };
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class HolidayYearLoad {
  final HolidayYearData? data;
  final bool fromCache;
  final bool stale;
  final String? error;

  const HolidayYearLoad({
    this.data,
    this.fromCache = false,
    this.stale = false,
    this.error,
  });
}

class HolidayCalendarView {
  final Map<int, HolidayYearLoad> years;
  const HolidayCalendarView(this.years);

  HolidayDayInfo? on(DateTime date) {
    final year = years[date.year]?.data;
    if (year == null) return null;
    final key = _dateKey(date);
    for (final day in year.days) {
      if (day.date == key) return day;
    }
    return null;
  }

  String get notice {
    if (years.isEmpty) return '';
    final states = years.values.toList();
    if (states.any((result) => result.data == null)) {
      return '节假日暂不可用，请检查网络或后端接口';
    }
    if (states.any((result) => result.data!.dataStatus == 'unavailable')) {
      return '节假日数据未接入（演示模式不提供真实节日）';
    }
    if (states.any((result) => result.stale)) {
      return '节假日数据来自离线缓存，可能尚未更新';
    }
    if (states.any((result) => result.data!.dataStatus == 'not_published')) {
      return '部分年份的法定放假安排尚未公布';
    }
    if (states.any((result) => result.data!.dataStatus == 'partial')) {
      return '部分年份的节假日安排尚不完整';
    }
    return '';
  }
}
