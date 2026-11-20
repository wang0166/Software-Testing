import 'package:flutter/material.dart';

import '../core/holiday_calendar.dart';
import '../core/theme.dart';

/// Small Chinese "休 / 班" tag, common to the home and work calendars.
class HolidayDayBadge extends StatelessWidget {
  final HolidayDayInfo? day;
  const HolidayDayBadge({super.key, this.day});

  @override
  Widget build(BuildContext context) {
    final holiday = day;
    if (holiday == null || holiday.dayTypeLabel.isEmpty) {
      return const SizedBox.shrink();
    }
    final workday = holiday.isMakeupWorkday;
    return Tooltip(
      message: holiday.description,
      child: Semantics(
        label: holiday.description,
        child: Container(
          key: Key('holiday_badge_${holiday.date}'),
          width: 14,
          height: 14,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: workday ? const Color(0xFFFFE7D3) : const Color(0xFFFFE6E3),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(workday ? '班' : '休',
              style: TextStyle(
                fontSize: 9,
                height: 1.0,
                color: workday ? const Color(0xFF9A571B) : Palette.coral,
                fontWeight: FontWeight.w900,
              )),
        ),
      ),
    );
  }
}

/// The festival label is separate from the legal day-off/workday status.
class HolidayFestivalLabel extends StatelessWidget {
  final HolidayDayInfo? day;
  const HolidayFestivalLabel({super.key, this.day});

  @override
  Widget build(BuildContext context) {
    final name = day?.festivalLabel ?? '';
    if (name.isEmpty) return const SizedBox.shrink();
    return Tooltip(
      message: day!.description,
      child: Text(
        name,
        key: Key('holiday_festival_${day!.date}'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Palette.coral,
          fontSize: 9,
          height: 1.15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class SelectedHolidayInfo extends StatelessWidget {
  final HolidayDayInfo? day;
  const SelectedHolidayInfo({super.key, this.day});

  @override
  Widget build(BuildContext context) {
    final info = day;
    if (info == null || info.description.isEmpty) return const SizedBox.shrink();
    return Row(
      key: const Key('selected_holiday_info'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (info.dayTypeLabel.isNotEmpty) ...[
          HolidayDayBadge(day: info),
          const SizedBox(width: 5),
        ],
        Flexible(child: Text(info.description,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11, color: Palette.coral, fontWeight: FontWeight.w700,
          ))),
      ],
    );
  }
}

class HolidaySyncNotice extends StatelessWidget {
  final HolidayCalendarView? view;
  final VoidCallback? retry;
  const HolidaySyncNotice({super.key, this.view, this.retry});

  @override
  Widget build(BuildContext context) {
    final message = view?.notice ?? '';
    if (message.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        const Icon(Icons.info_outline, color: Palette.muted, size: 15),
        const SizedBox(width: 6),
        Expanded(child: Text(message,
          key: const Key('holiday_sync_notice'),
          style: const TextStyle(fontSize: 11, color: Palette.muted))),
        if (retry != null)
          TextButton(
            onPressed: retry,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('重试', style: TextStyle(fontSize: 11)),
          ),
      ]),
    );
  }
}
