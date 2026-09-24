import '../models/task.dart';
import 'api_client.dart';

class TaskService {
  final ApiClient client;
  TaskService(this.client);

  Future<List<Task>> nearby({
    required double lat,
    required double lng,
    int radius = 5000,
    String? category,
  }) async {
    final res = await client.get('/tasks/nearby', query: {
      'lat': lat,
      'lng': lng,
      'radius': radius,
      if (category != null) 'category': category,
    });
    return (res as List).map((t) => Task.fromJson(t)).toList();
  }

  Future<Task> getTask(String id) async {
    final res = await client.get('/tasks/$id');
    return Task.fromJson(res);
  }

  Future<Task> createTask({
    required String category,
    required String title,
    required String description,
    required double price,
    required double latitude,
    required double longitude,
    int? radiusMeters,
    String? scheduledAt,
    String? genderPreference,
    int? minAge,
    int? maxAge,
  }) async {
    final res = await client.post('/tasks', body: {
      'category': category,
      'title': title,
      'description': description,
      'price': price,
      'latitude': latitude,
      'longitude': longitude,
      if (radiusMeters != null) 'radiusMeters': radiusMeters,
      if (scheduledAt != null) 'scheduledAt': scheduledAt,
      if (genderPreference != null) 'genderPreference': genderPreference,
      if (minAge != null) 'minAge': minAge,
      if (maxAge != null) 'maxAge': maxAge,
    });
    return Task.fromJson(res);
  }

  Future<void> apply(String taskId, {String? note}) =>
      client.post('/tasks/$taskId/apply', body: {if (note != null && note.isNotEmpty) 'note': note});

  Future<void> selectApplicant(String taskId, String applicationId) =>
      client.post('/tasks/$taskId/select/$applicationId');

  Future<void> complete(String taskId) => client.post('/tasks/$taskId/complete');

  Future<void> cancel(String taskId) => client.post('/tasks/$taskId/cancel');

  Future<void> reportNoShow(String taskId) => client.post('/tasks/$taskId/no-show');

  Future<void> rateTask(String taskId, {required String toUserId, required int score, String? comment}) =>
      client.post('/tasks/$taskId/rate', body: {
        'toUserId': toUserId,
        'score': score,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      });

  Future<void> raiseDispute(String taskId, String reason) =>
      client.post('/tasks/$taskId/dispute', body: {'reason': reason});
}
