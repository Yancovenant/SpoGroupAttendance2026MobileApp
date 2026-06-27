import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../data/models/user.dart';
import '../data/models/employee.dart';
import '../data/models/gang.dart';
import '../data/models/attendance_record.dart';

import 'package:flutter/material.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('spo_attendance.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE attendance_records ADD COLUMN type TEXT DEFAULT "in"');
        }
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        username TEXT UNIQUE,
        password_hash TEXT,
        is_password_md5 INTEGER,
        external_id TEXT,
        is_active INTEGER,
        gang_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE employees (
        id INTEGER PRIMARY KEY,
        external_id TEXT UNIQUE,
        name TEXT,
        gender TEXT,
        gang_code TEXT,
        gang_id INTEGER,
        is_active INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE gangs (
        id INTEGER PRIMARY KEY,
        name TEXT,
        gang_code TEXT,
        remarks TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        record_id TEXT UNIQUE,
        date TEXT,
        user_id INTEGER,
        gang_id INTEGER,
        type TEXT,
        group_photo_path TEXT,
        latitude REAL,
        longitude REAL,
        present_worker_ids TEXT,
        sync_status INTEGER,
        conflict_worker_ids TEXT
      )
    ''');
  }

  // --- BATCH INSERTIONS (10k Performance) ---
  Future<void> insertUsers(List<User> users) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var user in users) {
      batch.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertEmployees(List<Employee> employees) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var emp in employees) {
      batch.insert('employees', emp.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertGangs(List<Gang> gangs) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var gang in gangs) {
      batch.insert('gangs', gang.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // --- FETCHING ---
  Future<User?> getUserByUsername(String username) async {
    final db = await instance.database;
    final result = await db.query('users', where: 'username = ?', whereArgs: [username]);
    if (result.isNotEmpty) return User.fromMap(result.first);
    return null;
  }

  Future<List<Employee>> getEmployeesByGangCode(String gangCode) async {
    final db = await instance.database;
    final result = await db.query('employees', where: 'gang_code = ? AND is_active = 1', whereArgs: [gangCode]);
    return result.map((map) => Employee.fromMap(map)).toList();
  }

  Future<void> savePulledData(Map<String, dynamic> data) async {
    if (data['res_users'] != null) {
      debugPrint('[SPO_DEBUG] -> Parsing ${(data['res_users'] as List).length} users...');
      final users = (data['res_users'] as List).map((u) => User(
        id: int.tryParse(u['id'].toString()), username: u['username']?.toString(),
        passwordHash: u['password_hash']?.toString() ?? '', isPasswordMd5: u['is_password_md5'].toString() == '1',
        externalId: u['external_id']?.toString(), isActive: u['is_active'].toString() == "1",
        gangId: u['gang_id'] != null ? int.tryParse(u['gang_id'].toString()) : null,
      )).toList();
      debugPrint('[SPO_DEBUG] -> Inserting users into DB...');
      await insertUsers(users);
      debugPrint('[SPO_DEBUG] -> Users inserted.');
    }

    if (data['res_employees'] != null) {
      debugPrint('[SPO_DEBUG] -> Parsing ${(data['res_employees'] as List).length} employees...');
      final employees = (data['res_employees'] as List).map((e) => Employee(
        id: int.tryParse(e['id'].toString()), externalId: e['external_id']?.toString(),
        name: e['name']?.toString() ?? '', gender: e['gender']?.toString(),
        gangCode: e['gang_code']?.toString(), gangId: e['gang_id'] != null ? int.tryParse(e['gang_id'].toString()) : null,
        isActive: e['is_active'].toString() == '1',
      )).toList();
      debugPrint('[SPO_DEBUG] -> Inserting employees into DB...');
      await insertEmployees(employees);
      debugPrint('[SPO_DEBUG] -> Employees inserted.');
    }

    if (data['res_gangs'] != null) {
      debugPrint('[SPO_DEBUG] -> Parsing ${(data['res_gangs'] as List).length} gangs...');
      final gangs = (data['res_gangs'] as List).map((g) => Gang(
        id: int.tryParse(g['id'].toString()), name: g['name']?.toString() ?? '',
        gangCode: g['gang_code']?.toString(), remarks: g['remarks']?.toString(),
      )).toList();
      debugPrint('[SPO_DEBUG] -> Inserting gangs into DB...');
      await insertGangs(gangs);
      debugPrint('[SPO_DEBUG] -> Gangs inserted.');
    }
  }
}