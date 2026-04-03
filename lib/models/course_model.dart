class Course {
  final String name;
  final String code;
  final String professor;
  final String location;
  final String timeString;
  final String credits;
  final String required;
  final String detailUrl;
  final List<CourseTime> parsedTimes;
  
  // 新增詳細欄位
  final bool english;
  final int restrict;
  final int select;
  final int selected;
  final int remaining;
  final List<String> tags;
  final String department;
  final String description;

  Course({
    required this.name,
    required this.code,
    required this.professor,
    required this.location,
    required this.timeString,
    required this.credits,
    required this.required,
    required this.detailUrl,
    required this.parsedTimes,
    this.english = false,
    this.restrict = 0,
    this.select = 0,
    this.selected = 0,
    this.remaining = 0,
    this.tags = const [],
    this.department = "",
    this.description = "",
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      name: json['name'] ?? "",
      code: json['code'] ?? "",
      professor: json['professor'] ?? "",
      location: json['location'] ?? "",
      timeString: json['timeString'] ?? "",
      credits: json['credits'] ?? "",
      required: json['required'] ?? "",
      detailUrl: json['detailUrl'] ?? "",
      parsedTimes: (json['parsedTimes'] as List?)
              ?.map((t) => CourseTime.fromJson(t))
              .toList() ??
          [],
      english: json['english'] ?? false,
      restrict: json['restrict'] ?? 0,
      select: json['select'] ?? 0,
      selected: json['selected'] ?? 0,
      remaining: json['remaining'] ?? 0,
      tags: List<String>.from(json['tags'] ?? []),
      department: json['department'] ?? "",
      description: json['description'] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'professor': professor,
      'location': location,
      'timeString': timeString,
      'credits': credits,
      'required': required,
      'detailUrl': detailUrl,
      'parsedTimes': parsedTimes.map((t) => t.toJson()).toList(),
      'english': english,
      'restrict': restrict,
      'select': select,
      'selected': selected,
      'remaining': remaining,
      'tags': tags,
      'department': department,
      'description': description,
    };
  }
}

class CourseTime {
  final int day;    // 1-7
  final String period; // '1', '2', 'A', 'B'...

  CourseTime(this.day, this.period);

  factory CourseTime.fromJson(Map<String, dynamic> json) {
    return CourseTime(
      json['day'] as int,
      json['period'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'period': period,
    };
  }
}