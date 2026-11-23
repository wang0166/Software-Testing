import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/holiday_calendar.dart';
import 'package:mobile/core/models.dart';
import 'package:mobile/core/app_state.dart';
import 'package:mobile/data/holiday_calendar_service.dart';
import 'package:mobile/screens/calendar_page.dart';
import 'package:mobile/screens/daily_todos_calendar.dart';
import 'package:mobile/widgets/holiday_calendar_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

HolidayYearData sampleYear(int year, String day,
    {String status = 'published'}) => HolidayYearData(
  year: year,
  dataStatus: status,
  days: [
    HolidayDayInfo(date: day, dayType: 'holiday',
      holidayName: '放假通知', festivals: const ['传统节日']),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('后端响应区分法定放假、补班和传统节日', () {
    final parsed = HolidayYearData.fromJson({
      'year': 2027,
      'region': 'CN',
      'timezone': 'Asia/Shanghai',
      'dataStatus': 'published',
      'lastSyncedAt': '2026-11-11T08:00:00+08:00',
      'days': [
        {'date': '2027-02-05', 'dayType': 'holiday',
          'holidayName': '春节', 'festivals': ['春节']},
        {'date': '2027-02-14', 'dayType': 'makeup_workday',
          'holidayName': '春节调休', 'festivals': []},
        {'date': '2027-03-01', 'dayType': 'normal',
          'holidayName': '', 'festivals': ['传统节日']},
      ],
    });
    expect(parsed.days[0].isDayOff, isTrue);
    expect(parsed.days[1].dayTypeLabel, '班');
    expect(parsed.days[2].isDayOff, isFalse);
    expect(parsed.days[2].festivalLabel, '传统节日');
    expect(HolidayYearData.fromJson(parsed.toJson()).days, hasLength(3));
    expect(() => HolidayYearData.fromJson({
      ...parsed.toJson(), 'region': 'US',
    }), throwsFormatException);
    expect(() => HolidayYearData.fromJson({
      ...parsed.toJson(), 'days': [
        {'date': '2027-02-30', 'dayType': 'holiday'}
      ],
    }), throwsFormatException);
  });

  test('按年份持久化缓存、12小时内不重复请求、失败回退旧数据', () async {
    var time = DateTime(2026, 11, 11, 8);
    var requests = 0;
    var fail = false;
    final store = HolidayCalendarService(
      now: () => time,
      fetchYear: (year) async {
        requests++;
        if (fail) throw Exception('后端暂不可用');
        return sampleYear(year, '$year-11-11');
      },
    );
    final first = await store.loadYear(2027);
    expect(first.fromCache, isFalse);
    final second = await store.loadYear(2027);
    expect(second.fromCache, isTrue);
    expect(requests, 1);
    time = time.add(const Duration(days: 1));
    fail = true;
    final stale = await store.loadYear(2027);
    expect(stale.stale, isTrue);
    expect(stale.data?.days.single.date, '2027-11-11');
    expect(requests, 2);
    final view = await store.loadRange(DateTime(2027, 11), DateTime(2027, 11, 30));
    expect(view.notice, contains('离线缓存'));
  });

  test('没有后端数据时不生成假节日；未公布安排与普通日期区分', () async {
    final missing = HolidayCalendarService(fetchYear: (_) async =>
        throw Exception('404'));
    final unavailable = await missing.loadRange(DateTime(2031), DateTime(2031, 12));
    expect(unavailable.on(DateTime(2031, 1)), isNull);
    expect(unavailable.notice, contains('暂不可用'));

    final pending = HolidayCalendarService(fetchYear: (year) async =>
        HolidayYearData(year: year, dataStatus: 'not_published'));
    final notPublished = await pending.loadRange(
        DateTime(2032), DateTime(2032, 12));
    expect(notPublished.notice, contains('尚未公布'));
  });

  testWidgets('共享节日徽标以及传统节日描述', (tester) async {
    const day = HolidayDayInfo(
      date: '2027-02-05', dayType: 'holiday',
      holidayName: '春节', festivals: ['春节'],
    );
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: Column(children: [
        HolidayDayBadge(day: day),
        HolidayFestivalLabel(day: day),
        SelectedHolidayInfo(day: day),
      ]),
    )));
    expect(find.byKey(const Key('holiday_badge_2027-02-05')), findsWidgets);
    expect(find.byKey(const Key('holiday_festival_2027-02-05')), findsOneWidget);
    expect(find.text('春节'), findsOneWidget);
  });

  testWidgets('公司日历读取真实数据模型但不改变任务接口', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 840));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final app = AppState();
    await tester.runAsync(() => app.login('demo001', 'demo123456'));
    final date = chinaNow;
    final store = HolidayCalendarService(fetchYear: (year) async =>
        sampleYear(year, year == date.year
            ? dayString(date) : '$year-01-01'));
    await tester.pumpWidget(MaterialApp(home: CalendarPage(
      app: app, initialDate: date, holidayService: store,
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('holiday_badge_${dayString(date)}')), findsWidgets);
    expect(find.byKey(const Key('selected_holiday_info')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('首页小屏月历的日期和节日标签不发生溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(340, 550));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final date = chinaNow;
    final service = HolidayCalendarService(fetchYear: (year) async =>
        sampleYear(year, year == date.year
            ? dayString(date) : '$year-01-01'));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(
      height: 310, child: DailyTodosCalendar(
        userId: 108, holidayService: service),
    ))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('首页仍能保存个人Todo，节假日数据不会创建任务', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final date = chinaNow;
    final store = HolidayCalendarService(fetchYear: (year) async =>
        sampleYear(year, year == date.year
            ? dayString(date) : '$year-01-01'));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(
      height: 675,
      child: DailyTodosCalendar(userId: 107, holidayService: store),
    ))));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('holiday_badge_${dayString(date)}')), findsWidgets);
    await tester.tap(find.byKey(const Key('daily_todo_add_day')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('daily_todo_title_input')), '个人看书');
    await tester.tap(find.byKey(const Key('daily_todo_save_button')));
    await tester.pumpAndSettle();
    expect(find.text('个人看书'), findsWidgets);
    expect(find.byKey(Key('holiday_badge_${dayString(date)}')), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
