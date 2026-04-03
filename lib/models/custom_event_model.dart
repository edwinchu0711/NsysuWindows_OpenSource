class CustomEvent {
  final String id;
  final String title;
  final String details;
  final String location;
  final int day;
  final List<String> periods;

  CustomEvent({
    required this.id,
    required this.title,
    required this.location,
    required this.details,
    required this.day,
    required this.periods,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'details': details,
        'location': location,
        'day': day,
        'periods': periods,
      };

  factory CustomEvent.fromJson(Map<String, dynamic> json) => CustomEvent(
        id: json['id'],
        title: json['title'],
        details: json['details'],
        location: json['location'] ?? '',
        day: json['day'],
        periods: List<String>.from(json['periods'] ?? []),
      );
}
