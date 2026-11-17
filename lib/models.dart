int _coerceInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) return parsed;
    final decimal = double.tryParse(value.trim());
    if (decimal != null) return decimal.toInt();
  }
  return fallback;
}

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
  /// 國文課分組：0 = 未分組，1 以上是第幾組
  int group;
  /// 國文課分數（國文課時在詳細資料卡片加減）
  int chineseScore;
  SeatData({
    required this.number,
    required this.name,
    this.row = 0,
    this.slot = -1,
    this.gender = '',
    this.label = '',
    this.note = '',
    this.score = 0,
    this.group = 0,
    this.chineseScore = 0,
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
        'group': group,
        'chineseScore': chineseScore,
      };
  factory SeatData.fromJson(Map<String, dynamic> json) => SeatData(
        number: json['number'] as String? ?? '',
        name: json['name'] as String? ?? '',
        row: _coerceInt(json['row'], fallback: 0),
        slot: _coerceInt(json['slot'], fallback: -1),
        gender: json['gender'] as String? ?? '',
        label: json['label'] as String? ?? '',
        note: json['note'] as String? ?? '',
        score: _coerceInt(json['score'], fallback: 0),
        group: _coerceInt(json['group'], fallback: 0),
        chineseScore: _coerceInt(json['chineseScore'], fallback: 0),
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

/// 特殊顯示時段（非上課）：開始、結束（HH:mm）與大屏要顯示的文字。
/// 上課時段一律由課表決定；[overrideLesson] 勾選時，這段時間會蓋過上課（段考、朝會、活動用）。
class TimePeriod {
  String start;
  String end;
  String text;
  bool overrideLesson;
  /// 這段時間大屏首頁黃色按鈕要做什麼（見 [TimePeriod.actions]）
  String action;

  TimePeriod({
    required this.start,
    required this.end,
    required this.text,
    this.overrideLesson = false,
    this.action = 'minimize',
  });

  /// 黃色按鈕可以設定的動作：值 → (選單名稱, 按鈕文字)
  static const actions = <String, (String, String)>{
    'minimize': ('最小化（開始上課）', '開始上課'),
    'attendance': ('打開簽到頁', '簽到'),
    'stamp': ('打開蓋章頁（管理者專用）', '蓋章（管理者專用）'),
    'diary': ('打開聯絡簿', '聯絡簿'),
    'schedule': ('打開課表', '課表'),
    'pick': ('開始選號', '選號機'),
    'none': ('不顯示按鈕', ''),
  };

  int get startMinutes => _toMinutes(start);
  int get endMinutes => _toMinutes(end);

  static int _toMinutes(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return -1;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  Map<String, dynamic> toJson() =>
      {'start': start, 'end': end, 'text': text, 'override': overrideLesson, 'action': action};

  factory TimePeriod.fromJson(Map<String, dynamic> json) => TimePeriod(
        start: json['start'] as String? ?? '',
        end: json['end'] as String? ?? '',
        text: json['text'] as String? ?? '',
        overrideLesson: json['override'] as bool? ?? false,
        action: json['action'] as String? ?? 'minimize',
      );

  /// 伊洛手寫的 729 作息表（只留非上課時段；上課看課表，課與課之間自動顯示「下課」）
  static List<TimePeriod> defaults() => [
        for (final row in const [
          ['00:00', '07:30', '正常簽到', 'attendance'],
          ['07:30', '08:00', '遲到簽到', 'attendance'],
          ['08:00', '08:15', '早自習'],
          ['11:55', '12:05', '午餐下課'],
          ['12:05', '12:25', '吃飯'],
          ['12:25', '12:35', '中午下課'],
          ['12:35', '13:05', '午休'],
          ['14:55', '15:15', '打掃時間'],
          ['16:00', '23:59', '放學'],
        ])
          TimePeriod(start: row[0], end: row[1], text: row[2], action: row.length > 3 ? row[3] : 'minimize'),
      ];
}

/// 一段文字的格式（大小、粗體、斜體、底線、顏色）
class NoticeStyle {
  final double size;
  final bool bold;
  final bool italic;
  final bool underline;
  final int color;

  const NoticeStyle({
    this.size = 64,
    this.bold = true,
    this.italic = false,
    this.underline = false,
    this.color = 0xFF272343,
  });

  NoticeStyle copyWith({double? size, bool? bold, bool? italic, bool? underline, int? color}) => NoticeStyle(
        size: size ?? this.size,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        color: color ?? this.color,
      );

  @override
  bool operator ==(Object other) =>
      other is NoticeStyle &&
      other.size == size &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline &&
      other.color == color;

  @override
  int get hashCode => Object.hash(size, bold, italic, underline, color);

  Map<String, dynamic> toJson() => {
        'size': size,
        'bold': bold,
        'italic': italic,
        'underline': underline,
        'color': color,
      };

  factory NoticeStyle.fromJson(Map<String, dynamic> json) => NoticeStyle(
        size: (json['size'] as num?)?.toDouble() ?? 64,
        bold: json['bold'] as bool? ?? true,
        italic: json['italic'] as bool? ?? false,
        underline: json['underline'] as bool? ?? false,
        color: (json['color'] as num?)?.toInt() ?? 0xFF272343,
      );
}

/// 同一種格式的一段連續文字
class NoticeSpan {
  final String text;
  final NoticeStyle style;
  const NoticeSpan(this.text, this.style);

  Map<String, dynamic> toJson() => {'text': text, ...style.toJson()};

  factory NoticeSpan.fromJson(Map<String, dynamic> json) =>
      NoticeSpan(json['text'] as String? ?? '', NoticeStyle.fromJson(json));
}

/// 教師即時通知：一大段文字，每一段字可以有自己的格式；對齊是整段一起。
class TeacherNotice {
  String id;
  List<NoticeSpan> spans;
  /// 'left' / 'center' / 'right'
  String align;

  TeacherNotice({required this.id, List<NoticeSpan>? spans, this.align = 'center'}) : spans = spans ?? [];

  String get text => spans.map((s) => s.text).join();

  TeacherNotice copy() => TeacherNotice.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'spans': spans.map((s) => s.toJson()).toList(),
        'align': align,
      };

  factory TeacherNotice.fromJson(Map<String, dynamic> json) {
    final raw = json['spans'];
    List<NoticeSpan> spans;
    if (raw is List) {
      spans = raw.whereType<Map>().map((e) => NoticeSpan.fromJson(Map<String, dynamic>.from(e))).toList();
    } else {
      // 舊版（整段同一格式）
      final text = json['text'] as String? ?? '';
      spans = text.isEmpty
          ? []
          : [
              NoticeSpan(
                text,
                NoticeStyle(
                  size: (json['fontSize'] as num?)?.toDouble() ?? 64,
                  bold: json['bold'] as bool? ?? true,
                  italic: json['italic'] as bool? ?? false,
                  underline: json['underline'] as bool? ?? false,
                  color: (json['color'] as num?)?.toInt() ?? 0xFF272343,
                ),
              )
            ];
    }
    return TeacherNotice(id: json['id'] as String? ?? '', spans: spans, align: json['align'] as String? ?? 'center');
  }

  static TeacherNotice? tryParse(Object? raw) =>
      raw is Map ? TeacherNotice.fromJson(Map<String, dynamic>.from(raw)) : null;
}

/// 兌換獎勵的項目：名稱＋要花幾個章
class RewardItem {
  String name;
  int cost;
  RewardItem({required this.name, this.cost = 1});

  Map<String, dynamic> toJson() => {'name': name, 'cost': cost};

  factory RewardItem.fromJson(Map<String, dynamic> json) =>
      RewardItem(name: json['name'] as String? ?? '', cost: (json['cost'] as num?)?.toInt() ?? 1);
}

/// 教材資料夾：課表科目名稱裡有 keywords 其中一個字，就打開 path
class MaterialFolder {
  String name;
  /// 用逗號分開的關鍵字，例如「英語,英文」
  String keywords;
  String path;
  MaterialFolder({required this.name, required this.keywords, required this.path});

  List<String> get keywordList =>
      keywords.split(RegExp(r'[,，、\s]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  bool matches(String subject) => keywordList.any((k) => subject.contains(k));

  Map<String, dynamic> toJson() => {'name': name, 'keywords': keywords, 'path': path};

  factory MaterialFolder.fromJson(Map<String, dynamic> json) => MaterialFolder(
        name: json['name'] as String? ?? '',
        keywords: json['keywords'] as String? ?? '',
        path: json['path'] as String? ?? '',
      );

  /// 預設：學校 \\10.194.4.249\media 的各科教材
  static List<MaterialFolder> defaults() {
    const root = r'\\10.194.4.249\media';
    const ebook = '$root\\@各科電子書、題庫';
    return [
      for (final r in const [
        ['本土語', '本土語,閩南語,台語', '$root\\14 本土語-閩南語\\114學年 育達版本\\01-1 國中台語文(甲版)第1冊-教學簡報(OK)'],
        ['健教', '健教,健康', '$root\\07健體領域\\亞群\\115學年度'],
        ['家政', '家政', '$root\\08綜合領域\\01家政\\楊雅荃'],
        ['論語播講', '論語', '$root\\115學年度論語播講'],
        ['LiveABC', 'LiveABC', '$root\\@Video\\LiveABC'],
        ['輔導', '輔導', '$root\\07健體領域\\錦怡\\輔導\\七'],
        ['美術', '美術,視覺藝術', '$root\\06藝術領域\\02美術\\昱馨'],
        ['國文', '國文', '$ebook\\康軒\\康軒115上學期ISO\\01.國文\\01_115國中國文1上電子書_0812更新'],
        ['數學', '數學', '$ebook\\翰林\\115上\\03數學ok\\電子書ok'],
        ['英語', '英語,英文,世界節慶萬花筒', '$ebook\\翰林\\115上\\02英文ok\\電子書ok'],
        ['公民', '公民', '$ebook\\康軒\\康軒115上學期ISO\\07.公民'],
        ['地理', '地理,全球與鄉土', '$ebook\\康軒\\康軒115上學期ISO\\05.地理'],
        ['歷史', '歷史', '$ebook\\康軒\\康軒115上學期ISO\\06.歷史'],
        ['生物', '生物,自然', '$ebook\\康軒\\康軒115上學期ISO\\04.自然'],
        ['康軒主目錄', '', '$ebook\\康軒\\康軒115上學期ISO'],
        ['翰林主目錄', '', '$ebook\\翰林\\115上'],
      ])
        MaterialFolder(name: r[0], keywords: r[1], path: r[2]),
    ];
  }
}

/// Chrome 使用者：用指定的使用者（設定檔資料夾）打開 Chrome，可以順便開網址；
/// 填了課表科目的話，跟教材一起在下課後自動打開
class ChromeProfile {
  String name;
  /// Chrome 內部的設定檔資料夾名稱，例如 Default、Profile 1
  String profileDir;
  String url;
  String keywords;
  ChromeProfile({required this.name, required this.profileDir, this.url = '', this.keywords = ''});

  List<String> get keywordList =>
      keywords.split(RegExp(r'[,，、\s]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  bool matches(String subject) => keywordList.any((k) => subject.contains(k));

  Map<String, dynamic> toJson() => {'name': name, 'profileDir': profileDir, 'url': url, 'keywords': keywords};

  factory ChromeProfile.fromJson(Map<String, dynamic> json) => ChromeProfile(
        name: json['name'] as String? ?? '',
        profileDir: json['profileDir'] as String? ?? '',
        url: json['url'] as String? ?? '',
        keywords: json['keywords'] as String? ?? '',
      );
}

