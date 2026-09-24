import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class AuthState extends ChangeNotifier {
  final ApiClient client = ApiClient();
  late final AuthService authService = AuthService(client);

  String? token;
  AppUser? currentUser;
  bool loading = true;

  bool get isLoggedIn => token != null && currentUser != null;

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('neartask_token');
    if (saved != null) {
      token = saved;
      client.setToken(saved);
      try {
        currentUser = await authService.me();
      } catch (_) {
        await logout();
      }
    }
    loading = false;
    notifyListeners();
  }

  Future<void> login(String phone, String password) async {
    final t = await authService.login(phone: phone, password: password);
    await _persistToken(t);
    currentUser = await authService.me();
    notifyListeners();
  }

  Future<void> register({
    required String phone,
    required String name,
    required String password,
    String? email,
  }) async {
    final t = await authService.register(phone: phone, name: name, password: password, email: email);
    await _persistToken(t);
    currentUser = await authService.me();
    notifyListeners();
  }

  Future<void> refreshUser() async {
    currentUser = await authService.me();
    notifyListeners();
  }

  Future<void> _persistToken(String t) async {
    token = t;
    client.setToken(t);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('neartask_token', t);
  }

  Future<void> logout() async {
    token = null;
    currentUser = null;
    client.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('neartask_token');
    notifyListeners();
  }
}
