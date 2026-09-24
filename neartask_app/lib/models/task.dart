class TaskRating {
  final String fromUserId;
  final String toUserId;
  final int score;
  final String? comment;

  TaskRating({required this.fromUserId, required this.toUserId, required this.score, this.comment});

  factory TaskRating.fromJson(Map<String, dynamic> json) => TaskRating(
        fromUserId: json['fromUserId'],
        toUserId: json['toUserId'],
        score: json['score'],
        comment: json['comment'],
      );
}

class TaskApplication {
  final String id;
  final String applicantId;
  final String? applicantName;
  final String? note;
  final String status;

  TaskApplication({
    required this.id,
    required this.applicantId,
    this.applicantName,
    this.note,
    required this.status,
  });

  factory TaskApplication.fromJson(Map<String, dynamic> json) => TaskApplication(
        id: json['id'],
        applicantId: json['applicantId'],
        applicantName: json['applicant'] != null ? json['applicant']['name'] : null,
        note: json['note'],
        status: json['status'] ?? 'PENDING',
      );
}

class Task {
  final String id;
  final String title;
  final String description;
  final String category; // CHORE | SOCIAL
  final double price;
  final double latitude;
  final double longitude;
  final String status;
  final String? scheduledAt;
  final double? distanceMeters;
  final String? creatorId;
  final List<TaskApplication> applications;
  final List<TaskRating> ratings;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.scheduledAt,
    this.distanceMeters,
    this.creatorId,
    this.applications = const [],
    this.ratings = const [],
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'],
        title: json['title'],
        description: json['description'] ?? '',
        category: json['category'] ?? 'CHORE',
        price: double.tryParse(json['price'].toString()) ?? 0,
        latitude: (json['latitude'] ?? 0).toDouble(),
        longitude: (json['longitude'] ?? 0).toDouble(),
        status: json['status'] ?? 'OPEN',
        scheduledAt: json['scheduledAt'],
        distanceMeters: json['distance_meters'] != null
            ? double.tryParse(json['distance_meters'].toString())
            : null,
        creatorId: json['creatorId'],
        applications: (json['applications'] as List<dynamic>? ?? [])
            .map((a) => TaskApplication.fromJson(a))
            .toList(),
        ratings: (json['ratings'] as List<dynamic>? ?? []).map((r) => TaskRating.fromJson(r)).toList(),
      );
}
