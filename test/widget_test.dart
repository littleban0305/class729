import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_729/app_state.dart';
import 'package:class_729/firebase_options.dart';
import 'package:class_729/main.dart';
import 'package:class_729/models.dart';
import 'package:class_729/services/cloud_sync_service.dart';

void main() {
  testWidgets('729 app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('729'), findsWidgets);
    expect(find.text('這台裝置要作為什麼用途？'), findsOneWidget);
  });

  test('a reminder can be active during any configured time range', () {
    final reminder = ReminderData(
      title: '課間提醒',
      content: '請準備下一節課',
      date: '',
      startTime: '08:00',
      endTime: '08:10',
      timeRanges: [
        ReminderTimeRange(startTime: '08:00', endTime: '08:10'),
        ReminderTimeRange(startTime: '12:00', endTime: '12:30'),
      ],
    );

    expect(reminder.isActiveAt(DateTime(2026, 9, 17, 8, 5)), isTrue);
    expect(reminder.isActiveAt(DateTime(2026, 9, 17, 12, 15)), isTrue);
    expect(reminder.isActiveAt(DateTime(2026, 9, 17, 10, 0)), isFalse);
  });

  test('each time range applies its own weekday or calendar rule', () {
    final reminder = ReminderData(
      title: '分段規則',
      content: '',
      date: '',
      startTime: '08:00',
      endTime: '09:00',
      timeRanges: [
        ReminderTimeRange(
          startTime: '08:00',
          endTime: '09:00',
          repeatType: 'weekly',
          weekdays: [1, 3],
        ),
        ReminderTimeRange(
          startTime: '12:00',
          endTime: '13:00',
          repeatType: 'specific',
          dates: ['2026-09-17'],
        ),
      ],
    );

    expect(reminder.isActiveAt(DateTime(2026, 9, 14, 8, 30)), isTrue);
    expect(reminder.isActiveAt(DateTime(2026, 9, 15, 8, 30)), isFalse);
    expect(reminder.isActiveAt(DateTime(2026, 9, 17, 12, 30)), isTrue);
    expect(reminder.isActiveAt(DateTime(2026, 9, 18, 12, 30)), isFalse);
  });

  test('class reminders trigger auto evaluation when the end time is reached', () {
    final reminder = ReminderData(
      title: '數學課',
      content: '分數與圖形',
      date: '',
      startTime: '08:00',
      endTime: '08:40',
      lessonType: 'class',
      autoEvaluationEnabled: true,
    );

    expect(reminder.shouldAutoEvaluateAt(DateTime(2026, 9, 17, 8, 30)), isFalse);
    expect(reminder.shouldAutoEvaluateAt(DateTime(2026, 9, 17, 8, 40)), isTrue);
    expect(reminder.shouldAutoEvaluateAt(DateTime(2026, 9, 17, 8, 41)), isTrue);
  });

  test('teacher password remains intact when private snapshot merges across devices', () {
    final merged = CloudSyncService.mergePrivateState(
      existing: {
        'teacherPassword': 'OldSecret123',
        'reminders': [
          {'title': 'existing'},
        ],
      },
      incoming: {
        'reminders': [
          {'title': 'new'},
        ],
      },
    );

    expect(merged['teacherPassword'], 'OldSecret123');
    expect(merged['reminders'], isA<List>());
    expect(merged['reminders'][0]['title'], 'new');
  });

  test('firebase options are available for macOS so cloud sync can initialize', () {
    final options = DefaultFirebaseOptions.forPlatform(TargetPlatform.macOS);

    expect(options.projectId, 'class-729-app');
    expect(options.appId, isNotEmpty);
    expect(options.apiKey, isNotEmpty);
  });

  test('public cloud data applies the preview test time across devices', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final state = AppState();
    state.testNow = null;

    await state.applyPublicCloudData({
      'testNow': '2026-09-17T12:30:00.000',
      'reminders': <Map<String, dynamic>>[],
      'seats': <Map<String, dynamic>>[],
      'diaryEntries': <Map<String, dynamic>>[],
      'scheduleEntries': <Map<String, dynamic>>[],
      'attendanceToday': <Map<String, dynamic>>[],
    });

    expect(state.testNow, isNotNull);
    expect(state.testNow!.toIso8601String(), '2026-09-17T12:30:00.000');
  });

  test('public attendance snapshots keep the exact sign-in time', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final state = AppState();
    await state.applyPublicCloudData({
      'testNow': null,
      'reminders': <Map<String, dynamic>>[],
      'seats': <Map<String, dynamic>>[],
      'diaryEntries': <Map<String, dynamic>>[],
      'scheduleEntries': <Map<String, dynamic>>[],
      'attendanceToday': [
        {
          'studentNumber': '1',
          'studentName': '小明',
          'date': '2026-09-20',
          'time': '07:42:15',
          'late': false,
        }
      ],
    });

    expect(state.attendanceRecords, isNotEmpty);
    expect(state.attendanceRecords.first.time, '07:42:15');
    expect(state.attendanceRecords.first.late, isFalse);
  });

  test('seat score can be adjusted by adding and subtracting points', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final state = AppState();
    state.seats = [
      SeatData(number: '1', name: '小明', row: 0, slot: 0, score: 3),
    ];

    await state.adjustSeatScore(0, 5);
    expect(state.seats[0].score, 8);

    await state.adjustSeatScore(0, -3);
    expect(state.seats[0].score, 5);
  });

  test('seat score still updates even when cloud sync fails', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final state = AppState();
    state.classId = '729';
    state.deviceRole = 'teacher';
    state.cloudSyncEnabled = true;
    state.seats = [
      SeatData(number: '1', name: '小明', row: 0, slot: 0, score: 3),
    ];

    await state.adjustSeatScore(0, 4);

    expect(state.seats[0].score, 7);
    expect(state.cloudSyncError, isNotNull);
  });

  test('seat score imported from JSON or Firebase accepts numeric strings', () {
    final seat = SeatData.fromJson({
      'number': '1',
      'name': '小明',
      'row': 0,
      'slot': 0,
      'score': '8',
    });

    expect(seat.score, 8);
  });

  test('on-time attendance gives a bonus and discipline records deduct points', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final state = AppState();
    state.seats = [
      SeatData(number: '1', name: '小明', row: 0, slot: 0, score: 0),
    ];

    await state.recordAttendance(state.seats[0], at: DateTime(2026, 9, 23, 7, 15), late: false);
    expect(state.seats[0].score, 1);
    expect(state.studentRecords.first.type, '不遲到加分');

    await state.addStudentRecord(student: state.seats[0], type: '被記扣分', note: '吵鬧');
    expect(state.seats[0].score, 0);
    expect(state.studentRecords.first.type, '被記扣分');
  });

  test('row slides through empty slots when shifted left or right', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final leftState = AppState();
    leftState.seats = [
      SeatData(number: '1', name: 'A', row: 1, slot: 0),
      SeatData(number: '2', name: 'B', row: 3, slot: 0),
    ];

    await leftState.rotateSeats(-1);
    expect(leftState.seats.firstWhere((seat) => seat.name == 'A').row, 0);
    expect(leftState.seats.firstWhere((seat) => seat.name == 'B').row, 2);
    expect(leftState.seats.firstWhere((seat) => seat.name == 'A').slot, 0);
    expect(leftState.seats.firstWhere((seat) => seat.name == 'B').slot, 0);

    final rightState = AppState();
    rightState.seats = [
      SeatData(number: '1', name: 'A', row: 0, slot: 1),
      SeatData(number: '2', name: 'B', row: 2, slot: 1),
    ];

    await rightState.rotateSeats(1);
    expect(rightState.seats.firstWhere((seat) => seat.name == 'A').row, 1);
    expect(rightState.seats.firstWhere((seat) => seat.name == 'B').row, 3);
    expect(rightState.seats.firstWhere((seat) => seat.name == 'A').slot, 1);
    expect(rightState.seats.firstWhere((seat) => seat.name == 'B').slot, 1);
  });

  test('row movement wraps horizontally at both ends', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final rightState = AppState();
    rightState.seats = [
      for (var row = 0; row < 6; row++) SeatData(number: '${row + 1}-1', name: 'S$row', row: row, slot: 0),
    ];

    await rightState.rotateSeats(1);
    expect(rightState.seats.firstWhere((seat) => seat.name == 'S5').row, 0);
    expect(rightState.seats.firstWhere((seat) => seat.name == 'S0').row, 1);
    expect(rightState.seats.firstWhere((seat) => seat.name == 'S5').slot, 0);
    expect(rightState.seats.firstWhere((seat) => seat.name == 'S0').slot, 0);

    await rightState.rotateSeats(-1);
    expect(rightState.seats.firstWhere((seat) => seat.name == 'S0').row, 0);
    expect(rightState.seats.firstWhere((seat) => seat.name == 'S5').row, 5);
    expect(rightState.seats.firstWhere((seat) => seat.name == 'S0').slot, 0);
    expect(rightState.seats.firstWhere((seat) => seat.name == 'S5').slot, 0);
  });

  test('drag seat swap exchanges students and positions', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final state = AppState();
    state.seats = [
      SeatData(number: '1-1', name: 'A', row: 0, slot: 0, gender: '男', score: 3),
      SeatData(number: '2-1', name: 'B', row: 1, slot: 0, gender: '女', score: 5),
    ];

    await state.swapSeats(0, 1);

    expect(state.seats[0].name, 'A');
    expect(state.seats[0].number, '1-1');
    expect(state.seats[0].row, 1);
    expect(state.seats[0].slot, 0);
    expect(state.seats[0].gender, '男');
    expect(state.seats[0].score, 3);
    expect(state.seats[1].name, 'B');
    expect(state.seats[1].number, '2-1');
    expect(state.seats[1].row, 0);
    expect(state.seats[1].slot, 0);
    expect(state.seats[1].gender, '女');
    expect(state.seats[1].score, 5);
  });

  testWidgets('seat board drag swaps visible cards', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final state = AppState();
    state.seats = [
      SeatData(number: '1-1', name: 'A', row: 0, slot: 0),
      SeatData(number: '2-1', name: 'B', row: 1, slot: 0),
    ];
    await tester.pumpWidget(MaterialApp(home: SeatPage(state: state)));
    await tester.pump();

    final source = tester.getCenter(find.text('A'));
    final target = tester.getCenter(find.text('B'));
    await tester.dragFrom(source, target - source);
    await tester.pumpAndSettle();

    expect(state.seats.firstWhere((seat) => seat.name == 'A').row, 1);
    expect(state.seats.firstWhere((seat) => seat.name == 'B').row, 0);
  });

  test('moving a seat to an empty slot preserves its seat number', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final state = AppState();
    state.seats = [
      SeatData(number: '1-1', name: 'A', row: 0, slot: 0),
    ];

    await state.moveSeatTo(0, row: 2, slot: 1);

    expect(state.seats[0].number, '1-1');
    expect(state.seats[0].row, 2);
    expect(state.seats[0].slot, 1);
  });

  test('reminder element rotation is preserved through copy and JSON conversion', () {
    final element = ReminderElementData(
      id: 'rotated-text',
      type: 'text',
      text: '轉啊轉',
      x: 120,
      y: 80,
      width: 220,
      height: 70,
      rotation: 32,
    );

    final recreated = ReminderElementData.fromJson(element.toJson());

    expect(element.rotation, 32);
    expect(recreated.rotation, 32);
    expect(element.copyWith(rotation: 90).rotation, 90);
  });

  test('text element preserves line breaks in the stored content', () {
    final element = ReminderElementData(
      id: 'multiline-text',
      type: 'text',
      text: '第一行\n第二行\n第三行',
      x: 50,
      y: 50,
      width: 200,
      height: 80,
    );

    final roundTrip = ReminderElementData.fromJson(element.toJson());

    expect(roundTrip.text, '第一行\n第二行\n第三行');
    expect(element.copyWith(text: 'A\nB').text, 'A\nB');
  });
}
