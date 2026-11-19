import 'package:flutter_test/flutter_test.dart';
import 'package:foodz/data/models/app_settings.dart';

AppSettings _shop({bool accepting = true, Map<int, DayHours> hours = const {}}) => AppSettings(
      restaurantName: 'Dar Ennakhla',
      deliveryFee: 200,
      minOrder: 1000,
      defaultPrepMinutes: 20,
      acceptingOrders: accepting,
      contactPhone: '',
      contactEmail: '',
      hours: hours,
    );

void main() {
  // 16 November 2026 is a Monday.
  final monday = DateTime(2026, 11, 16);
  DateTime at(int dayOffset, int hour, int minute) =>
      DateTime(monday.year, monday.month, monday.day + dayOffset, hour, minute);

  test('without a schedule the shop is open whenever the switch is on', () {
    expect(_shop().openNow(at(0, 3, 0)), isTrue);
    expect(_shop(accepting: false).openNow(at(0, 12, 0)), isFalse);
  });

  test('inside and outside the daily window', () {
    final s = _shop(hours: {1: const DayHours(open: 660, close: 1380)}); // Monday 11:00-23:00
    expect(s.openNow(at(0, 12, 0)), isTrue);
    expect(s.openNow(at(0, 10, 59)), isFalse);
    expect(s.openNow(at(0, 23, 0)), isFalse);
    expect(s.openNow(at(1, 12, 0)), isFalse); // Tuesday has no hours
  });

  test('a closed day stays closed', () {
    final s = _shop(hours: {1: const DayHours(closed: true)});
    expect(s.openNow(at(0, 12, 0)), isFalse);
  });

  test('a window that passes midnight stays open into the next morning', () {
    final s = _shop(hours: {5: const DayHours(open: 1080, close: 120)}); // Friday 18:00-02:00
    expect(s.openNow(at(4, 23, 0)), isTrue); // Friday night
    expect(s.openNow(at(5, 1, 0)), isTrue); // Saturday 01:00
    expect(s.openNow(at(5, 3, 0)), isFalse);
  });

  test('hours are saved and read back unchanged', () {
    final s = _shop(hours: {2: const DayHours(open: 600, close: 1320)});
    final back = AppSettings.fromMap({
      'restaurantName': 'Dar Ennakhla',
      'hours': s.hoursToMap(),
    });
    expect(back.hours[2]?.open, 600);
    expect(back.hours[2]?.close, 1320);
    expect(back.hours[3], isNull);
  });
}
