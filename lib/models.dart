class ActionButtonData {
  String text;
  String url;

  ActionButtonData({required this.text, required this.url});

  Map<String, dynamic> toJson() => {'text': text, 'url': url};

  factory ActionButtonData.fromJson(Map<String, dynamic> json) {
    return ActionButtonData(
      text: json['text'] as String? ?? '開啟',
      url: json['url'] as String? ?? '',
    );
  }
}

class ReminderBlockData {
  double x;
  double y;
  double width;
  double height;

  ReminderBlockData({required this.x, required this.y, required this.width, required this.height});

  ReminderBlockData copyWith({double? x, double? y, double? width, double? height}) => ReminderBlockData(
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
      );

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'width': width, 'height': height};

  factory ReminderBlockData.fromJson(Map<String, dynamic> json, ReminderBlockData fallback) => ReminderBlockData(
        x: (json['x'] as num?)?.toDouble() ?? fallback.x,
        y: (json['y'] as num?)?.toDouble() ?? fallback.y,
        width: (json['width'] as num?)?.toDouble() ?? fallback.width,
        height: (json['height'] as num?)?.toDouble() ?? fallback.height,
      );
}

class ReminderElementData {
  String id;
  String type;
  String text;
  String url;
  double x;
  double y;
  double width;
  double height;
  double rotation;
  double fontSize;
  bool bold;
  bool italic;
  bool underline;
  String alignment;
  int color;
  int backgroundColor;

  ReminderElementData({
    required this.id,
    required this.type,
    this.text = '',
    this.url = '',
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.fontSize = 28,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.alignment = 'left',
    this.color = 0xff171a24,
    this.backgroundColor = 0x00000000,
  });

  ReminderElementData copyWith({
    String? text,
    String? url,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? fontSize,
    bool? bold,
    bool? italic,
    bool? underline,
    String? alignment,
    int? color,
    int? backgroundColor,
  }) =>
      ReminderElementData(
        id: id,
        type: type,
        text: text ?? this.text,
        url: url ?? this.url,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotation: rotation ?? this.rotation,
        fontSize: fontSize ?? this.fontSize,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        alignment: alignment ?? this.alignment,
        color: color ?? this.color,
        backgroundColor: backgroundColor ?? this.backgroundColor,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'text': text,
        'url': url,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'rotation': rotation,
        'fontSize': fontSize,
        'bold': bold,
        'italic': italic,
        'underline': underline,
        'alignment': alignment,
        'color': color,
        'backgroundColor': backgroundColor,
      };

  factory ReminderElementData.fromJson(Map<String, dynamic> json) => ReminderElementData(
        id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        type: json['type'] as String? ?? 'text',
        text: json['text'] as String? ?? '',
        url: json['url'] as String? ?? '',
        x: (json['x'] as num?)?.toDouble() ?? 80,
        y: (json['y'] as num?)?.toDouble() ?? 80,
        width: (json['width'] as num?)?.toDouble() ?? 400,
        height: (json['height'] as num?)?.toDouble() ?? 100,
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 28,
        bold: json['bold'] as bool? ?? false,
        italic: json['italic'] as bool? ?? false,
        underline: json['underline'] as bool? ?? false,
        alignment: json['alignment'] as String? ?? 'left',
        color: (json['color'] as num?)?.toInt() ?? 0xff171a24,
        backgroundColor: (json['backgroundColor'] as num?)?.toInt() ?? 0x00000000,
      );
}

class ReminderTimeRange {
  String startTime;
  String endTime;
  String repeatType;
  List<int> weekdays;
  List<String> dates;

  ReminderTimeRange({
    required this.startTime,
    required this.endTime,
    this.repeatType = 'none',
    List<int>? weekdays,
    List<String>? dates,
  })  : weekdays = weekdays ?? [],
        dates = dates ?? [];

  Map<String, dynamic> toJson() => {
        'startTime': startTime,
        'endTime': endTime,
        'repeatType': repeatType,
        'weekdays': weekdays,
        'dates': dates,
      };

  factory ReminderTimeRange.fromJson(Map<String, dynamic> json) => ReminderTimeRange(
        startTime: json['startTime'] as String? ?? '08:00',
        endTime: json['endTime'] as String? ?? '18:00',
        repeatType: json['repeatType'] as String? ?? 'none',
        weekdays: (json['weekdays'] as List?)?.whereType<num>().map((e) => e.toInt()).toList(),
        dates: (json['dates'] as List?)?.whereType<String>().toList(),
      );

  ReminderTimeRange copyWith({
    String? startTime,
    String? endTime,
    String? repeatType,
    List<int>? weekdays,
    List<String>? dates,
  }) =>
      ReminderTimeRange(
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        repeatType: repeatType ?? this.repeatType,
        weekdays: weekdays ?? List<int>.from(this.weekdays),
        dates: dates ?? List<String>.from(this.dates),
      );
}

class LessonEvaluationRecord {
  String id;
  int score;
  String note;
  String createdAt;
  String lessonType;

  LessonEvaluationRecord({
    required this.id,
    required this.score,
    required this.note,
    DateTime? createdAt,
    this.lessonType = 'class',
  }) : createdAt = (createdAt ?? DateTime.now()).toIso8601String();

  String get dateKey => DateTime.tryParse(createdAt)?.toIso8601String().substring(0, 10) ?? '';

  Map<String, dynamic> toJson() => {
        'id': id,
        'score': score,
        'note': note,
        'createdAt': createdAt,
        'lessonType': lessonType,
      };

  factory LessonEvaluationRecord.fromJson(Map<String, dynamic> json) => LessonEvaluationRecord(
        id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        score: (json['score'] as num?)?.toInt() ?? 0,
        note: json['note'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        lessonType: json['lessonType'] as String? ?? 'class',
      );
}

class ReminderData {
  String title;
  String content;
  String date;
  String startTime;
  String endTime;
  String lessonType;
  bool autoEvaluationEnabled;
  List<LessonEvaluationRecord> evaluations;
  List<ReminderTimeRange> timeRanges;
  String repeatType;
  List<String> repeatDates;
  List<ActionButtonData> buttons;
  List<String> layout;
  Map<String, ReminderBlockData> blocks;
  List<ReminderElementData> elements;

  ReminderData({
    required this.title,
    required this.content,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.lessonType = 'other',
    this.autoEvaluationEnabled = false,
    List<LessonEvaluationRecord>? evaluations,
    List<ReminderTimeRange>? timeRanges,
    this.repeatType = 'none',
    List<String>? repeatDates,
    List<ActionButtonData>? buttons,
    List<String>? layout,
    Map<String, ReminderBlockData>? blocks,
    List<ReminderElementData>? elements,
  })  : buttons = buttons ?? [],
        layout = layout ?? const ['title', 'content', 'buttons'],
        blocks = blocks ?? defaultBlockLayouts(),
        elements = elements ?? [],
        repeatDates = repeatDates ?? [],
        evaluations = evaluations ?? [],
        timeRanges = timeRanges ??
            [
              ReminderTimeRange(
                startTime: startTime,
                endTime: endTime,
                repeatType: repeatType,
                weekdays: repeatType == 'weekly' && date.isNotEmpty ? [DateTime.tryParse(date)?.weekday ?? 0] : [],
                dates: repeatType == 'specific'
                    ? List<String>.from(repeatDates ?? [])
                    : (repeatType == 'none' && date.isNotEmpty ? [date] : []),
              ),
            ];

  static Map<String, ReminderBlockData> defaultBlockLayouts() => {
        'title': ReminderBlockData(x: 70, y: 70, width: 860, height: 110),
        'content': ReminderBlockData(x: 70, y: 220, width: 860, height: 180),
        'buttons': ReminderBlockData(x: 70, y: 440, width: 860, height: 80),
      };

  bool get isActive => isActiveAt(DateTime.now());

  String get lessonLabel {
    switch (lessonType) {
      case 'class':
        return '上課';
      case 'break':
        return '下課';
      default:
        return '其他';
    }
  }

  bool hasEvaluationForDate(DateTime date) {
    final dateKey =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return evaluations.any((entry) => entry.lessonType == lessonType && entry.dateKey == dateKey);
  }

  bool shouldAutoEvaluateAt(DateTime now) {
    if (lessonType != 'class' || !autoEvaluationEnabled) {
      return false;
    }
    if (hasEvaluationForDate(now)) {
      return false;
    }
    final endMinutes = _timeToMinutes(endTime);
    final nowMinutes = now.hour * 60 + now.minute;
    return endMinutes >= 0 && nowMinutes >= endMinutes;
  }

  int _timeToMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return -1;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return -1;
    }
    return hour * 60 + minute;
  }

  bool isActiveAt(DateTime now) {
    final todayKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    int minutes(String value) {
      final p = value.split(':');
      if (p.length != 2) return 0;
      final hour = int.tryParse(p[0]);
      final minute = int.tryParse(p[1]);
      if (hour == null || minute == null) return -1;
      return hour * 60 + minute;
    }

    final current = now.hour * 60 + now.minute;
    return timeRanges.any((range) {
      if (range.repeatType == 'weekly' && !range.weekdays.contains(now.weekday)) {
        return false;
      }
      if (range.repeatType == 'specific' && !range.dates.contains(todayKey)) {
        return false;
      }
      if (range.repeatType == 'none' && range.dates.isNotEmpty && !range.dates.contains(todayKey)) {
        return false;
      }
      final start = minutes(range.startTime);
      final end = minutes(range.endTime);
      return start >= 0 && end >= 0 && current >= start && current <= end;
    });
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'lessonType': lessonType,
        'autoEvaluationEnabled': autoEvaluationEnabled,
        'evaluations': evaluations.map((e) => e.toJson()).toList(),
        'timeRanges': timeRanges.map((range) => range.toJson()).toList(),
        'repeatType': repeatType,
        'repeatDates': repeatDates,
        'buttons': buttons.map((e) => e.toJson()).toList(),
        'layout': layout,
        'blocks': blocks.map((key, value) => MapEntry(key, value.toJson())),
        'elements': elements.map((e) => e.toJson()).toList(),
      };

  factory ReminderData.fromJson(Map<String, dynamic> json) {
    final rawButtons = (json['buttons'] as List?) ?? [];
    final rawLayout = (json['layout'] as List?)?.whereType<String>().toList();
    final defaults = defaultBlockLayouts();
    final rawBlocks = json['blocks'] as Map?;
    final rawElements = (json['elements'] as List?) ?? [];
    final rawTimeRanges = (json['timeRanges'] as List?) ?? [];
    final rawEvaluations = (json['evaluations'] as List?) ?? [];
    var parsedTimeRanges =
        rawTimeRanges.whereType<Map>().map((e) => ReminderTimeRange.fromJson(Map<String, dynamic>.from(e))).toList();
    final legacyRepeatType = json['repeatType'] as String? ?? 'none';
    final legacyRepeatDates = (json['repeatDates'] as List?)?.whereType<String>().toList() ?? [];
    if (parsedTimeRanges.isNotEmpty &&
        legacyRepeatType != 'none' &&
        parsedTimeRanges.every((range) => range.repeatType == 'none' && range.dates.isEmpty)) {
      final legacyWeekday = legacyRepeatType == 'weekly' && (json['date'] as String? ?? '').isNotEmpty
          ? DateTime.tryParse(json['date'] as String)?.weekday
          : null;
      parsedTimeRanges = parsedTimeRanges
          .map((range) => range.copyWith(
                repeatType: legacyRepeatType,
                weekdays: legacyWeekday == null ? [] : [legacyWeekday],
                dates: legacyRepeatType == 'specific' ? legacyRepeatDates : [],
              ))
          .toList();
    }
    final parsedBlocks = <String, ReminderBlockData>{};
    for (final entry in defaults.entries) {
      final rawBlock = rawBlocks?[entry.key];
      parsedBlocks[entry.key] =
          rawBlock is Map ? ReminderBlockData.fromJson(Map<String, dynamic>.from(rawBlock), entry.value) : entry.value;
    }
    return ReminderData(
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      date: json['date'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '08:00',
      endTime: json['endTime'] as String? ?? '18:00',
      lessonType: json['lessonType'] as String? ?? 'other',
      autoEvaluationEnabled: json['autoEvaluationEnabled'] as bool? ?? false,
      evaluations: rawEvaluations
          .whereType<Map>()
          .map((e) => LessonEvaluationRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      timeRanges: parsedTimeRanges.isEmpty ? null : parsedTimeRanges,
      repeatType: legacyRepeatType,
      repeatDates: legacyRepeatDates,
      buttons: rawButtons.whereType<Map>().map((e) => ActionButtonData.fromJson(Map<String, dynamic>.from(e))).toList(),
      layout: rawLayout,
      blocks: parsedBlocks,
      elements:
          rawElements.whereType<Map>().map((e) => ReminderElementData.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
  }
}

class SeatData {
  String number;
  String name;
  int row;
  int slot;
  String gender;
  String label;
  String note;
  int score;
  SeatData({
    required this.number,
    required this.name,
    this.row = 0,
    this.slot = -1,
    this.gender = '',
    this.label = '',
    this.note = '',
    this.score = 0,
  });
  Map<String, dynamic> toJson() => {
        'number': number,
        'name': name,
        'row': row,
        'slot': slot,
        'gender': gender,
        'label': label,
        'note': note,
        'score': score,
      };
  factory SeatData.fromJson(Map<String, dynamic> json) => SeatData(
        number: json['number'] as String? ?? '',
        name: json['name'] as String? ?? '',
        row: (json['row'] as num?)?.toInt() ?? 0,
        slot: (json['slot'] as num?)?.toInt() ?? -1,
        gender: json['gender'] as String? ?? '',
        label: json['label'] as String? ?? '',
        note: json['note'] as String? ?? '',
        score: (json['score'] as num?)?.toInt() ?? 0,
      );
}

class ScheduleEntry {
  int weekday;
  int lesson;
  String subject;
  String teacher;
  String startTime;
  String endTime;

  ScheduleEntry(
      {required this.weekday,
      required this.lesson,
      required this.subject,
      this.teacher = '',
      this.startTime = '',
      this.endTime = ''});

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'lesson': lesson,
        'subject': subject,
        'teacher': teacher,
        'startTime': startTime,
        'endTime': endTime,
      };

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) => ScheduleEntry(
        weekday: (json['weekday'] as num?)?.toInt() ?? 0,
        lesson: (json['lesson'] as num?)?.toInt() ?? 0,
        subject: json['subject'] as String? ?? '',
        teacher: json['teacher'] as String? ?? '',
        startTime: json['startTime'] as String? ?? '',
        endTime: json['endTime'] as String? ?? '',
      );
}

class DiaryEntry {
  String date;
  String tag;
  String content;

  DiaryEntry({required this.date, required this.tag, required this.content});

  Map<String, dynamic> toJson() => {'date': date, 'tag': tag, 'content': content};

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
        date: json['date'] as String? ?? '',
        tag: json['tag'] as String? ?? '一般',
        content: json['content'] as String? ?? '',
      );
}
