import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'auth_service.dart';

class BillService {
  static const _base = 'https://split-pay-q4wa.onrender.com/api/v1';

  /// Upload a bill image
  static Future<Map<String, dynamic>> uploadBill({
    required File imageFile,
    required String groupId,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    try {
      final uri = Uri.parse('$_base/bills/upload');
      var request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['groupId'] = groupId;

      // Add the image file - field name must match backend expectation
      request.files.add(
        await http.MultipartFile.fromPath(
          'bill', // Backend expects 'bill' field name
          imageFile.path,
        ),
      );

      print('🚀 Uploading bill to: $uri');
      print('📦 GroupId: $groupId');
      print('📄 File path: ${imageFile.path}');

      final streamedResponse = await request.send()
          .timeout(const Duration(seconds: 45)); // Increased timeout for parsing
      final response = await http.Response.fromStream(streamedResponse);

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      final parsed = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': parsed['message'] ?? 'Bill uploaded successfully',
          'expense': parsed['expense'],
        };
      } else {
        return {
          'success': false,
          'message': parsed['message'] ?? 'Failed to upload bill',
        };
      }
    } catch (e) {
      print('❌ Error uploading bill: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  /// Get bill details by expense ID
  static Future<Map<String, dynamic>?> getBillDetails(String expenseId) async {
    final token = await AuthService.getToken();
    if (token == null) {
      return null;
    }

    final uri = Uri.parse('$_base/bills/getBillDetails/$expenseId');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      print('🔍 Fetching bill details for: $expenseId');
      final res = await http.get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      print('📡 getBillDetails status: ${res.statusCode}');
      print('📡 getBillDetails body: ${res.body}');

      if (res.statusCode == 200) {
        final parsed = jsonDecode(res.body);

        // Handle different response structures
        if (parsed is Map<String, dynamic>) {
          if (parsed['expense'] is Map<String, dynamic>) {
            return parsed['expense'] as Map<String, dynamic>;
          } else if (parsed['data'] is Map<String, dynamic>) {
            return parsed['data'] as Map<String, dynamic>;
          }
          return parsed;
        }
      }
    } catch (e) {
      print('❌ Error fetching bill details: $e');
    }
    return null;
  }

  /// Assign money to members
  /// Backend expects: assignments = [{ from: userId, to: userId, amount: number }]
  static Future<Map<String, dynamic>> assignMoney({
    required String expenseId,
    required List<Map<String, dynamic>> assignments,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final uri = Uri.parse('$_base/bills/assign-money');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({
      'expenseId': expenseId,
      'assignments': assignments,
    });

    try {
      print('💰 Assigning money for expense: $expenseId');
      print('📦 Assignments: ${jsonEncode(assignments)}');

      final res = await http.patch(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      print('📡 assignMoney status: ${res.statusCode}');
      print('📡 assignMoney body: ${res.body}');

      final parsed = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return {
          'success': true,
          'message': parsed['message'] ?? 'Money assigned successfully',
          'expense': parsed['expense'],
        };
      } else {
        return {
          'success': false,
          'message': parsed['message'] ?? 'Failed to assign money',
        };
      }
    } catch (e) {
      print('❌ Error assigning money: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  /// Settle assignments (update user balances)
  static Future<Map<String, dynamic>> settleAssignments({
    required String expenseId,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final uri = Uri.parse('$_base/bills/settleAssignment');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({
      'expenseId': expenseId,
    });

    try {
      print('✅ Settling assignments for expense: $expenseId');

      final res = await http.post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      print('📡 settleAssignments status: ${res.statusCode}');
      print('📡 settleAssignments body: ${res.body}');

      final parsed = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return {
          'success': true,
          'message': parsed['message'] ?? 'Assignments settled successfully',
          'expense': parsed['expense'],
        };
      } else {
        return {
          'success': false,
          'message': parsed['message'] ?? 'Failed to settle assignments',
        };
      }
    } catch (e) {
      print('❌ Error settling assignments: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }
}