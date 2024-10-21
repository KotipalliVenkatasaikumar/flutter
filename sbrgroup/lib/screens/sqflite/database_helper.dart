import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:ajna/screens/sqflite/schedule.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static const _databaseName = 'ajna.db';
  static const _databaseVersion = 1;

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    return await openDatabase(
      join(await getDatabasesPath(), _databaseName),
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE scan_schedules (
        scheduleId INTEGER,
        scheduleTimeId INTEGER,
        projectName TEXT,
        location TEXT,
        scheduleTime TEXT,
        status TEXT,
        userName TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_userName ON scan_schedules(userName);');
    await db
        .execute('CREATE INDEX idx_scheduleId ON scan_schedules(scheduleId);');
  }

  Future<List<ScanSchedule>> getStoredSchedules() async {
    final db = await database;
    final results = await db.query('scan_schedules');
    return results.map((row) => ScanSchedule.fromMap(row)).toList();
  }

  Future<int> insertSchedule(ScanSchedule schedule) async {
    final db = await database;
    try {
      return await db.insert(
        'scan_schedules',
        schedule.toMap(),
      );
    } catch (e) {
      // Use a logging package for better error handling
      print('Error inserting schedule: $e');
      return 0;
    }
  }

  Future<int> updateSchedule(ScanSchedule schedule) async {
    final db = await database;
    try {
      return await db.update(
        'scan_schedules',
        schedule.toMap(),
        where: 'scheduleId = ?',
        whereArgs: [schedule.scheduleId],
      );
    } catch (e) {
      print('Error updating schedule: $e');
      return 0;
    }
  }

  Future<int> deleteSchedule(int scheduleId) async {
    final db = await database;
    try {
      return await db.delete(
        'scan_schedules',
        where: 'scheduleId = ?',
        whereArgs: [scheduleId],
      );
    } catch (e) {
      print('Error deleting schedule: $e');
      return 0;
    }
  }

  Future<void> deleteOldSchedules(DateTime date) async {
    final db = await database;
    try {
      await db.delete(
        'scan_schedules',
        where: 'scheduleTime < ?',
        whereArgs: [date.toIso8601String()],
      );
    } catch (e) {
      print('Error deleting old schedules: $e');
    }
  }

  Future<void> deleteAllSchedules() async {
    final db = await database;
    try {
      await db.delete('scan_schedules'); // Deletes all rows in the table
    } catch (e) {
      print('Error deleting all schedules: $e');
    }
  }

  Future<List<ScanSchedule>> getSchedulesByUsername(String userName) async {
    final db = await database;
    final results = await db.query(
      'scan_schedules',
      where: 'userName = ?',
      whereArgs: [userName],
    );
    return results.map((row) => ScanSchedule.fromMap(row)).toList();
  }
}
