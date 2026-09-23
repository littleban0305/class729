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

class AttendanceRecord {
  final String studentNumber;
  final String studentName;
  final String date;
  final String time;
  final bool late;

  AttendanceRecord({
    required this.studentNumber,
    required this.studentName,
    required this.date,
    required this.time,
    this.late = false,
  });

  Map<String, dynamic> toJson() => {
        'studentNumber': studentNumber,
        'studentName': studentName,
        'date': date,
        'time': time,
        'late': late,
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
        studentNumber: json['studentNumber'] as String? ?? '',
        studentName: json['studentName'] as String? ?? '',
        date: json['date'] as String? ?? '',
        time: json['time'] as String? ?? '',
        late: json['late'] as bool? ?? false,
      );
}

class StudentRecord {
  final String id;
  final String studentNumber;
  final String studentName;
  final String date;
  final String time;
  final String type;
  final String note;

  StudentRecord({
    required this.id,
    required this.studentNumber,
    required this.studentName,
    required this.date,
    required this.time,
    required this.type,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentNumber': studentNumber,
        'studentName': studentName,
        'date': date,
        'time': time,
        'type': type,
        'note': note,
      };

  factory StudentRecord.fromJson(Map<String, dynamic> json) => StudentRecord(
        id: json['id'] as String? ?? '',
        studentNumber: json['studentNumber'] as String? ?? '',
        studentName: json['studentName'] as String? ?? '',
        date: json['date'] as String? ?? '',
        time: json['time'] as String? ?? '',
        type: (json['type'] as String? ?? '秩序不佳') == '秩序' ? '秩序不佳' : (json['type'] as String? ?? '秩序不佳'),
        note: json['note'] as String? ?? '',
      );
}

class CleanlinessRecord {
  final String id;
  final String date;
  final String area;
  final String evaluator;
  final int score;
  final String studentNumber;
  final String studentName;
  final String result;
  final String note;

  CleanlinessRecord({
    required this.id,
    required this.date,
    required this.area,
    required this.evaluator,
    required this.score,
    this.studentNumber = '',
    this.studentName = '',
    this.result = '一般',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'area': area,
        'evaluator': evaluator,
        'score': score,
        'studentNumber': studentNumber,
        'studentName': studentName,
        'result': result,
        'note': note,
      };

  factory CleanlinessRecord.fromJson(Map<String, dynamic> json) => CleanlinessRecord(
        id: json['id'] as String? ?? '',
        date: json['date'] as String? ?? '',
        area: json['area'] as String? ?? '教室',
        evaluator: json['evaluator'] as String? ?? '',
        score: _coerceInt(json['score'], fallback: 0),
        studentNumber: json['studentNumber'] as String? ?? '',
        studentName: json['studentName'] as String? ?? '',
        result: json['result'] as String? ?? '一般',
        note: json['note'] as String? ?? '',
      );
}

/// One class's cleanliness "vote of the week": up to 3 excellent + 3 needs-work
/// student numbers, locked in explicitly by whoever runs the weekly review.
class WeeklySelection {
  final String weekStart;
  final List<String> excellentNumbers;
  final List<String> needsWorkNumbers;
  final bool locked;

  WeeklySelection({
    required this.weekStart,
    this.excellentNumbers = const [],
    this.needsWorkNumbers = const [],
    this.locked = false,
  });

  WeeklySelection copyWith({List<String>? excellentNumbers, List<String>? needsWorkNumbers, bool? locked}) =>
      WeeklySelection(
        weekStart: weekStart,
        excellentNumbers: excellentNumbers ?? this.excellentNumbers,
        needsWorkNumbers: needsWorkNumbers ?? this.needsWorkNumbers,
        locked: locked ?? this.locked,
      );

  Map<String, dynamic> toJson() => {
        'weekStart': weekStart,
        'excellentNumbers': excellentNumbers,
        'needsWorkNumbers': needsWorkNumbers,
        'locked': locked,
      };

  factory WeeklySelection.fromJson(Map<String, dynamic> json) => WeeklySelection(
        weekStart: json['weekStart'] as String? ?? '',
        excellentNumbers: (json['excellentNumbers'] as List?)?.whereType<String>().toList() ?? [],
        needsWorkNumbers: (json['needsWorkNumbers'] as List?)?.whereType<String>().toList() ?? [],
        locked: json['locked'] as bool? ?? false,
      );
}

class ClassPhoto {
  final String id;
  final String path;
  final String date;
  final String title;
  final String note;

  ClassPhoto({
    required this.id,
    required this.path,
    required this.date,
    this.title = '',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'date': date,
        'title': title,
        'note': note,
      };

  factory ClassPhoto.fromJson(Map<String, dynamic> json) => ClassPhoto(
        id: json['id'] as String? ?? '',
        path: json['path'] as String? ?? '',
        date: json['date'] as String? ?? '',
        title: json['title'] as String? ?? '',
        note: json['note'] as String? ?? '',
      );
}
