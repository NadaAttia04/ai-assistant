import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_session.dart';
import '../models/doctor.dart';
import '../models/medicine.dart';
import '../models/investigation.dart';
import '../models/management.dart';
import '../models/patient.dart';

class ApiService {
  static const _base = 'http://192.168.1.7:5000';
  static final _headers = {'Content-Type': 'application/json'};

  // ── Auth ──────────────────────────────────────────────────────────────────

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

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final res = await http.post(
      Uri.parse('$_base/auth/forgot_password'),
      headers: _headers,
      body: jsonEncode({'email': email}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> changePassword(
      String userId, String currentPassword, String newPassword) async {
    final res = await http.post(
      Uri.parse('$_base/auth/change_password'),
      headers: _headers,
      body: jsonEncode({
        'user_id': userId,
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    return jsonDecode(res.body);
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final res = await http.get(Uri.parse('$_base/users/$userId'));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateUserProfile(
      String userId, Map<String, dynamic> fields) async {
    final res = await http.put(
      Uri.parse('$_base/users/$userId'),
      headers: _headers,
      body: jsonEncode(fields),
    );
    return jsonDecode(res.body);
  }

  static Future<String?> uploadAvatar(String userId, String imagePath) async {
    final uri = Uri.parse('$_base/users/$userId/avatar');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('avatar', imagePath));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final data = jsonDecode(res.body);
    if (data['error'] != null) throw Exception(data['error']);
    return data['avatar_url'] as String?;
  }

  // ── Consultation Chat ─────────────────────────────────────────────────────

  static Future<String> getOrCreateConsultation({
    required String patientId,
    required String doctorId,
    required String patientName,
    required String doctorName,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/consultations'),
      headers: _headers,
      body: jsonEncode({
        'patient_id': patientId,
        'doctor_id': doctorId,
        'patient_name': patientName,
        'doctor_name': doctorName,
      }),
    );
    final data = jsonDecode(res.body);
    if (data['error'] != null) throw Exception(data['error']);
    return data['room_id'] as String;
  }

  static Future<List<Map<String, dynamic>>> getConsultationMessages(
      String roomId) async {
    final res =
        await http.get(Uri.parse('$_base/consultations/$roomId/messages'));
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['messages'] as List);
  }

  static Future<Map<String, dynamic>> sendConsultationMessage(
      String roomId, String senderRole, String senderName, String content) async {
    final res = await http.post(
      Uri.parse('$_base/consultations/$roomId/message'),
      headers: _headers,
      body: jsonEncode({
        'sender_role': senderRole,
        'sender_name': senderName,
        'content': content,
      }),
    );
    final data = jsonDecode(res.body);
    if (data['error'] != null) throw Exception(data['error']);
    return data['message'] as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getPatientConsultations(
      String patientId) async {
    final res =
        await http.get(Uri.parse('$_base/consultations/patient/$patientId'));
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['consultations'] as List);
  }

  static Future<List<Map<String, dynamic>>> getDoctorConsultations(
      String doctorId) async {
    final res =
        await http.get(Uri.parse('$_base/consultations/doctor/$doctorId'));
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['consultations'] as List);
  }

  // ── Chat Sessions ─────────────────────────────────────────────────────────

  static Future<String> createChatSession(String userId) async {
    final res = await http.post(Uri.parse('$_base/chats/$userId/new'));
    final data = jsonDecode(res.body);
    if (data['error'] != null) throw Exception(data['error']);
    return data['chat_id'] as String;
  }

  static Future<List<ChatSessionMeta>> getChatSessions(String userId) async {
    final res = await http.get(Uri.parse('$_base/chats/$userId'));
    final data = jsonDecode(res.body);
    return (data['sessions'] as List)
        .map((s) => ChatSessionMeta.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getSessionMessages(
      String chatId) async {
    try {
      final res = await http.get(Uri.parse('$_base/chats/session/$chatId'));
      final data = jsonDecode(res.body);
      final msgs = List<Map<String, dynamic>>.from(data['messages'] as List);
      // Cache for offline use
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_msgs_$chatId', jsonEncode(msgs));
      return msgs;
    } catch (_) {
      // Return cached messages when offline
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cache_msgs_$chatId');
      if (cached != null) {
        return List<Map<String, dynamic>>.from(jsonDecode(cached) as List);
      }
      rethrow;
    }
  }

  static Future<void> deleteChatSession(String chatId) async {
    await http.delete(Uri.parse('$_base/chats/session/$chatId'));
  }

  // ── Session-based messaging ───────────────────────────────────────────────

  /// Returns {response, severity} where severity may be null.
  static Future<Map<String, String?>> sendChatMessage(
      String query, String userId, String chatId,
      {String role = 'patient'}) async {
    final res = await http.post(
      Uri.parse('$_base/chat'),
      headers: _headers,
      body: jsonEncode({
        'query': query,
        'user_id': userId,
        'chat_id': chatId,
        'role': role,
      }),
    );
    final data = jsonDecode(res.body);
    if (data['error'] != null) throw Exception(data['error']);
    return {
      'response': data['response'] as String,
      'severity': data['severity'] as String?,
    };
  }

  static Future<Map<String, String?>> sendMessageWithImage(
      String query, String imagePath, String userId, String chatId,
      {String role = 'patient'}) async {
    final uri = Uri.parse('$_base/analyze_image');
    final request = http.MultipartRequest('POST', uri)
      ..fields['query'] = query
      ..fields['user_id'] = userId
      ..fields['chat_id'] = chatId
      ..fields['role'] = role
      ..files.add(await http.MultipartFile.fromPath('image', imagePath));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final data = jsonDecode(res.body);
    if (data['error'] != null) throw Exception(data['error']);
    return {
      'response': data['response'] as String,
      'severity': data['severity'] as String?,
    };
  }

  static Future<Map<String, String?>> sendMessageWithFile(
      String query, String filePath, String fileName,
      String userId, String chatId,
      {String role = 'patient'}) async {
    final uri = Uri.parse('$_base/upload_file');
    final request = http.MultipartRequest('POST', uri)
      ..fields['query'] = query
      ..fields['user_id'] = userId
      ..fields['chat_id'] = chatId
      ..fields['role'] = role
      ..files.add(await http.MultipartFile.fromPath(
        'file', filePath,
        filename: fileName,
      ));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final data = jsonDecode(res.body);
    if (data['error'] != null) throw Exception(data['error']);
    return {
      'response': data['response'] as String,
      'severity': data['severity'] as String?,
    };
  }

  // ── Services ──────────────────────────────────────────────────────────────

  static Future<List<Doctor>> getDoctors({String specialty = 'all'}) async {
    final res = await http.get(
        Uri.parse('$_base/doctors?specialty=${Uri.encodeComponent(specialty)}'));
    final data = jsonDecode(res.body);
    return (data['doctors'] as List)
        .map((d) => Doctor.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Medicine>> getMedicines({String category = 'all'}) async {
    final res = await http.get(
        Uri.parse('$_base/medicines?category=${Uri.encodeComponent(category)}'));
    final data = jsonDecode(res.body);
    return (data['medicines'] as List)
        .map((m) => Medicine.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getAppointments(
      {String doctorId = '', String status = 'all'}) async {
    final params = <String>[];
    if (doctorId.isNotEmpty) params.add('doctor_id=$doctorId');
    if (status != 'all') params.add('status=$status');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final res = await http.get(Uri.parse('$_base/appointments$query'));
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['appointments'] as List);
  }

  static Future<List<Map<String, dynamic>>> getPendingPatients() async {
    final res = await http.get(Uri.parse('$_base/pending_patients'));
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['patients'] as List);
  }

  static Future<List<Patient>> getPatients(String doctorId) async {
    final res =
        await http.get(Uri.parse('$_base/patients/doctor/$doctorId'));
    final data = jsonDecode(res.body);
    return (data['patients'] as List)
        .map((p) => Patient.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  // ── Legacy single-session (kept for backward compat) ─────────────────────

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

  // ── Patients ──────────────────────────────────────────────────────────────

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
        'name': name, 'sex': sex, 'age': age,
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

  // ── Investigations ────────────────────────────────────────────────────────

  static Future<List<Investigation>> getInvestigations(
      String patientId) async {
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

  // ── Management ────────────────────────────────────────────────────────────

  static Future<List<Management>> getManagement(String patientId) async {
    final res =
        await http.get(Uri.parse('$_base/patients/$patientId/management'));
    final data = jsonDecode(res.body);
    return (data['management'] as List)
        .map((e) => Management.fromJson(e))
        .toList();
  }
}
