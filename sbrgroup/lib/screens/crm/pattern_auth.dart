import 'package:shared_preferences/shared_preferences.dart';

class PatternAuth {
  static const String _patternKey = "user_pattern";

  Future<void> savePattern(String pattern) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_patternKey, pattern);
  }

  Future<String?> getPattern() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_patternKey);
  }

  Future<bool> verifyPattern(String enteredPattern) async {
    final storedPattern = await getPattern();
    return storedPattern == enteredPattern;
  }
}
