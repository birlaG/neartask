import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient client;
  AuthService(this.client);

  Future<String> register({
    required String phone,
    required String name,
    required String password,
    String? email,
  }) async {
    final res = await client.post('/auth/register', body: {
      'phone': phone,
      'name': name,
      'password': password,
      if (email != null && email.isNotEmpty) 'email': email,
    });
    return res['accessToken'];
  }

  Future<String> login({required String phone, required String password}) async {
    final res = await client.post('/auth/login', body: {'phone': phone, 'password': password});
    return res['accessToken'];
  }

  Future<AppUser> me() async {
    final res = await client.get('/users/me');
    return AppUser.fromJson(res);
  }

  Future<AppUser> updateProfile(Map<String, dynamic> fields) async {
    final res = await client.patch('/users/me', body: fields);
    return AppUser.fromJson(res);
  }
}
