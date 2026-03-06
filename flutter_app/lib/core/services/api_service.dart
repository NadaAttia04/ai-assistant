import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/investigation.dart';
import '../models/management.dart';
import '../models/patient.dart';

class ApiService {
  static const _base = 'http://192.168.1.8:5000'; // physical device → host machine

  static final _headers = {'Content-Type': 'application/json'};

  // ── Auth ────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    final res = await http.post(
      Uri.parse('$_base/auth/register'),
      headers: _headers,
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final res = await http.post(
      Uri.parse('$_base/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(res.body);
  }

  // ── Chat ────────────────────────────────────────────────────────────────────

  static Future<String> sendMessage(String query, String userId) async {
    final res = await http.post(
      Uri.parse('$_base/ai_response'),
      headers: _headers,
      body: jsonEncode({'query': query, 'user_id': userId}),
    );
    final data = jsonDecode(res.body);
    if (data['error'] != null) throw Exception(data['error']);
    return data['response'] as String;
  }

  static Future<void> clearChat(String userId) async {
    await http.delete(Uri.parse('$_base/chat/$userId'));
  }

  // ── Patients ────────────────────────────────────────────────────────────────

  static Future<String> createPatient({
    required String doctorId,
    required String name,
    required String sex,
    required String age,
    required String symptoms,
    String allergies = '',
    String preExistingConditions = '',
  }) async {
    final res = await http.post(
      Uri.parse('$_base/patients'),
      headers: _headers,
      body: jsonEncode({
        'doctor_id': doctorId,
        'name': name,
        'sex': sex,
        'age': age,
        'symptoms': symptoms,
        'allergies': allergies,
        'pre_existing_conditions': preExistingConditions,
      }),
    );
    final data = jsonDecode(res.body);
    if (data['error'] != null) throw Exception(data['error']);
    return data['patient_id'] as String;
  }

  static Future<Patient> getPatient(String patientId) async {
    final res = await http.get(Uri.parse('$_base/patients/$patientId'));
    final data = jsonDecode(res.body);
    if (data['error'] != null) throw Exception(data['error']);
    return Patient.fromJson(data);
  }

  // ── Investigations ──────────────────────────────────────────────────────────

  static Future<List<Investigation>> getInvestigations(String patientId) async {
    final res =
        await http.get(Uri.parse('$_base/patients/$patientId/investigations'));
    final data = jsonDecode(res.body);
    return (data['investigations'] as List)
        .map((e) => Investigation.fromJson(e))
        .toList();
  }

  static Future<List<Management>> updateInvestigationResult(
      String investigationId, String result, String patientId) async {
    final res = await http.put(
      Uri.parse('$_base/investigations/$investigationId'),
      headers: _headers,
      body: jsonEncode({'result': result, 'patient_id': patientId}),
    );
    final data = jsonDecode(res.body);
    if (data['error'] != null) throw Exception(data['error']);
    return (data['management'] as List)
        .map((e) => Management.fromJson(e))
        .toList();
  }

  // ── Management ──────────────────────────────────────────────────────────────

  static Future<List<Management>> getManagement(String patientId) async {
    final res =
        await http.get(Uri.parse('$_base/patients/$patientId/management'));
    final data = jsonDecode(res.body);
    return (data['management'] as List)
        .map((e) => Management.fromJson(e))
        .toList();
  }
}
