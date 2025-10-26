import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/group_model.dart';
import 'auth_service.dart';
import 'dart:math';

// Helper function to get random group icon
IconData _getRandomGroupIcon() {
  final random = Random();
  final icons = [
    Icons.people,
    Icons.group,
    Icons.groups,
    Icons.family_restroom,
    Icons.emoji_people,
    Icons.restaurant,
    Icons.local_cafe,
    Icons.fastfood,
    Icons.nightlife,
    Icons.sports_bar,
    Icons.flight,
    Icons.beach_access,
    Icons.hotel,
    Icons.home,
    Icons.apartment,
    Icons.business,
    Icons.school,
    Icons.sports_soccer,
    Icons.sports_basketball,
    Icons.sports_esports,
    Icons.movie,
    Icons.theater_comedy,
    Icons.music_note,
    Icons.celebration,
    Icons.cake,
    Icons.card_giftcard,
    Icons.favorite,
    Icons.shopping_bag,
    Icons.shopping_cart,
  ];
  return icons[random.nextInt(icons.length)];
}

class GroupService extends ChangeNotifier {
  final List<GroupModel> _groups = [];
  final Map<String, List<Map<String, dynamic>>> _groupExpenses = {}; // ✅ NEW: Cache expenses per group
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  set selectedIndex(int v) {
    if (_selectedIndex == v) return;
    _selectedIndex = v;
    notifyListeners();
  }

  List<GroupModel> get groups => List.unmodifiable(_groups);

  void addGroup(GroupModel group) {
    _groups.insert(0, group);
    notifyListeners();
  }

  // ✅ NEW: Add expense to local cache
  void addExpenseToGroup(String groupId, Map<String, dynamic> expense) {
    if (!_groupExpenses.containsKey(groupId)) {
      _groupExpenses[groupId] = [];
    }
    _groupExpenses[groupId]!.insert(0, expense); // Add to beginning (most recent)
    notifyListeners();
  }

  // ✅ NEW: Get cached expenses for a group
  List<Map<String, dynamic>> getGroupExpenses(String groupId) {
    return _groupExpenses[groupId] ?? [];
  }

  // Clear all groups (call this on logout)
  void clearGroups() {
    _groups.clear();
    _groupExpenses.clear(); // ✅ NEW: Clear cached expenses too
    _selectedIndex = 0;
    notifyListeners();
  }

  void addSampleData() {
    // Removed sample data - only show real groups from backend
    return;
  }

  // Try to fetch user's groups from backend using /group/getAll
  Future<void> fetchGroups() async {
    final base = 'https://split-pay-q4wa.onrender.com/api/v1';
    final token = await AuthService.getToken();
    
    // If no token, clear groups and return
    if (token == null) {
      _groups.clear();
      notifyListeners();
      return;
    }
    
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final uri = Uri.parse('$base/group/getAll');
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      
      if (res.statusCode == 200) {
        final parsed = jsonDecode(res.body);
        List<dynamic>? arr;
        
        if (parsed is Map && parsed['success'] == true) {
          // Backend returns: { success: true, message: "...", groups: [...] }
          if (parsed['groups'] is List) {
            arr = parsed['groups'];
          }
        } else if (parsed is List) {
          arr = parsed;
        } else if (parsed is Map) {
          if (parsed['data'] is List) arr = parsed['data'];
          else if (parsed['data'] is Map && parsed['data']['groups'] is List) arr = parsed['data']['groups'];
        }
        
        if (arr != null) {
          _groups.clear();
          for (final item in arr) {
            try {
              final Map<String, dynamic> g = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);
              final membersField = g['members'];
              int membersCount = 1;
              List<String> avatars = [];
              
              if (membersField is List) {
                membersCount = membersField.length;
                try {
                  for (final m in membersField) {
                    if (m is Map && (m['email'] is String)) {
                      final email = m['email'] as String;
                      final id = (email.hashCode.abs() % 70) + 1;
                      avatars.add('https://i.pravatar.cc/150?img=$id');
                    }
                  }
                } catch (_) {}
              }

              _groups.add(GroupModel(
                id: g['_id']?.toString() ?? g['id']?.toString(),
                name: g['name']?.toString() ?? 'Group',
                members: membersCount,
                status: GroupStatus.settled,
                amount: 0,
                avatars: avatars,
                description: g['description']?.toString(),
              ));
            } catch (_) {}
          }
          notifyListeners();
          return;
        }
      } else if (res.statusCode == 400) {
        // User is not in any group - this is OK
        _groups.clear();
        notifyListeners();
        return;
      }
    } catch (e) {
      print('Error fetching groups: $e');
    }

    // If fetch failed or no groups, clear the list
    _groups.clear();
    notifyListeners();
  }
  
  // Delete a group by ID
  Future<bool> deleteGroup(String groupId) async {
    final base = 'https://split-pay-q4wa.onrender.com/api/v1';
    final token = await AuthService.getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final uri = Uri.parse('$base/group/delete/$groupId');
      final res = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 10));
      
      if (res.statusCode == 200 || res.statusCode == 204) {
        // Remove from local list
        _groups.removeWhere((g) => g.id == groupId);
        // ✅ NEW: Also remove cached expenses
        _groupExpenses.remove(groupId);
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Error deleting group: $e');
    }
    return false;
  }

  // Fetch single group details by ID
  Future<Map<String, dynamic>?> fetchGroupDetails(String groupId) async {
    final base = 'https://split-pay-q4wa.onrender.com/api/v1';
    final token = await AuthService.getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final uri = Uri.parse('$base/group/get/$groupId');
      print('📥 Fetching group from: $uri');
      
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      
      print('📡 Status: ${res.statusCode}');
      print('📡 Response body: ${res.body}');
      
      if (res.statusCode == 200) {
        final parsed = jsonDecode(res.body);
        
        // Print the EXACT structure
        print('📦 Parsed structure:');
        print('   Keys: ${parsed.keys}');
        if (parsed['group'] != null) {
          print('   group.members type: ${parsed['group']['members'].runtimeType}');
          print('   group.members: ${parsed['group']['members']}');
        }
        
        if (parsed is Map<String, dynamic>) {
          if (parsed['group'] is Map<String, dynamic>) {
            return parsed['group'] as Map<String, dynamic>;
          } else if (parsed['data'] is Map<String, dynamic>) {
            return parsed['data'] as Map<String, dynamic>;
          }
          return parsed;
        }
      }
    } catch (e) {
      print('❌ Error: $e');
    }
    return null;
  }
}