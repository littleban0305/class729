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
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 28,
        bold: json['bold'] as bool? ?? false,
        italic: json['italic'] as bool? ?? false,
        underline: json['underline'] as bool? ?? false,
        alignment: json['alignment'] as String? ?? 'left',
        color: (json['color'] as num?)?.toInt() ?? 0xff171a24,
        backgroundColor: (json['backgroundColor'] as num?)?.toInt() ?? 0x00000000,
      );
}

class ReminderData {
  String title;
  String content;
  String date;
  String startTime;
  String endTime;
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
        repeatDates = repeatDates ?? [];

  static Map<String, ReminderBlockData> defaultBlockLayouts() => {
        'title': ReminderBlockData(x: 70, y: 70, width: 860, height: 110),
        'content': ReminderBlockData(x: 70, y: 220, width: 860, height: 180),
        'buttons': ReminderBlockData(x: 70, y: 440, width: 860, height: 80),
      };

  bool get isActive => isActiveAt(DateTime.now());

  bool isActiveAt(DateTime now) {
    final todayKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (repeatType == 'daily') {
      // Daily reminders are active every calendar day.
    } else if (repeatType == 'weekly') {
      if (date.isNotEmpty) {
        final parts = date.split('-');
        final anchor = parts.length == 3 ? DateTime.tryParse(date) : null;
        if (anchor == null || anchor.weekday != now.weekday) return false;
      }
    } else if (repeatType == 'specific') {
      if (!repeatDates.contains(todayKey)) return false;
    } else if (date.isNotEmpty) {
      final parts = date.split('-');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        if (year == null || month == null || day == null) return false;
        final target = DateTime(year, month, day);
        final today = DateTime(now.year, now.month, now.day);
        if (target != today) return false;
      }
    }
    int minutes(String value) {
      final p = value.split(':');
      if (p.length != 2) return 0;
      final hour = int.tryParse(p[0]);
      final minute = int.tryParse(p[1]);
      if (hour == null || minute == null) return -1;
      return hour * 60 + minute;
    }

    final current = now.hour * 60 + now.minute;
    return current >= minutes(startTime) && current <= minutes(endTime);
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
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
      repeatType: json['repeatType'] as String? ?? 'none',
      repeatDates: (json['repeatDates'] as List?)?.whereType<String>().toList(),
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
  SeatData({required this.number, required this.name, this.row = 0, this.slot = -1, this.gender = ''});
  Map<String, dynamic> toJson() => {'number': number, 'name': name, 'row': row, 'slot': slot, 'gender': gender};
  factory SeatData.fromJson(Map<String, dynamic> json) => SeatData(
        number: json['number'] as String? ?? '',
        name: json['name'] as String? ?? '',
        row: (json['row'] as num?)?.toInt() ?? 0,
        slot: (json['slot'] as num?)?.toInt() ?? -1,
        gender: json['gender'] as String? ?? '',
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
