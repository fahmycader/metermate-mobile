import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class BreakService {
  static const String _breakStartTimeKey = 'break_start_time';
  static const String _isOnBreakKey = 'is_on_break';
  static const String _breakTakenDateKey = 'break_taken_date';
  static const int _breakDurationSeconds = 30 * 60; // 30 minutes

  // Check if user is currently on break
  static Future<bool> isOnBreak() async {
    final prefs = await SharedPreferences.getInstance();
    final isOnBreak = prefs.getBool(_isOnBreakKey) ?? false;
    
    if (!isOnBreak) return false;
    
    // Check if break has expired
    final startTimeStr = prefs.getString(_breakStartTimeKey);
    if (startTimeStr == null) {
      await clearBreak();
      return false;
    }
    
    final startTime = DateTime.parse(startTimeStr);
    final now = DateTime.now();
    final elapsed = now.difference(startTime).inSeconds;
    
    if (elapsed >= _breakDurationSeconds) {
      // Break has ended - mark as taken for today
      await _markBreakTaken();
      await clearBreak();
      return false;
    }
    
    return true;
  }

  // Check if break has been taken today
  static Future<bool> hasBreakBeenTakenToday() async {
    final prefs = await SharedPreferences.getInstance();
    final breakTakenDateStr = prefs.getString(_breakTakenDateKey);
    
    if (breakTakenDateStr == null) return false;
    
    // Check if the date matches today
    final breakTakenDate = DateTime.parse(breakTakenDateStr);
    final today = DateTime.now();
    
    return breakTakenDate.year == today.year &&
           breakTakenDate.month == today.month &&
           breakTakenDate.day == today.day;
  }

  // Mark break as taken for today
  static Future<void> _markBreakTaken() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString(_breakTakenDateKey, now.toIso8601String());
  }

  // Mark break as taken (called when break starts)
  static Future<void> markBreakTaken() async {
    await _markBreakTaken();
  }

  // Get remaining break time in seconds
  static Future<int> getRemainingSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final startTimeStr = prefs.getString(_breakStartTimeKey);
    
    if (startTimeStr == null) return 0;
    
    final startTime = DateTime.parse(startTimeStr);
    final now = DateTime.now();
    final elapsed = now.difference(startTime).inSeconds;
    final remaining = _breakDurationSeconds - elapsed;
    
    return remaining > 0 ? remaining : 0;
  }

  // Start break
  static Future<void> startBreak() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString(_breakStartTimeKey, now.toIso8601String());
    await prefs.setBool(_isOnBreakKey, true);
  }

  // Clear break (when break ends or is manually stopped)
  static Future<void> clearBreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_breakStartTimeKey);
    await prefs.remove(_isOnBreakKey);
    // Note: We don't remove _breakTakenDateKey here because we want to track
    // that a break was taken today even after it ends
  }

  // Clear break taken status (for testing or new day)
  static Future<void> clearBreakTakenStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_breakTakenDateKey);
  }

  // Get break start time
  static Future<DateTime?> getBreakStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    final startTimeStr = prefs.getString(_breakStartTimeKey);
    if (startTimeStr == null) return null;
    return DateTime.parse(startTimeStr);
  }
}

