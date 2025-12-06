import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if user is currently authenticated
  Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    final currentUser = _auth.currentUser;
    print("Firebase currentUser: ${FirebaseAuth.instance.currentUser}");
    print("SharedPrefs loggedIn: $isLoggedIn");

    // Both SharedPreferences and Firebase must agree
    return isLoggedIn && currentUser != null;
  }

  /// Get the current user ID from SharedPreferences
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  /// Get the current user email from SharedPreferences
  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  /// Save login state after successful authentication
  Future<void> saveLoginState(String userId, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyUserEmail, email);
  }

  /// Clear login state on logout
  Future<void> clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
    await _auth.signOut();
  }

  /// Get current Firebase user
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
