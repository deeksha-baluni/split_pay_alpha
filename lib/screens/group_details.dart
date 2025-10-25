import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/header.dart';
import '../services/group_service.dart';
import '../services/auth_service.dart';
import '../services/invite_service.dart';
import 'add_bill.dart';
import 'members.dart';
import 'dart:convert';

class GroupDetailsPage extends StatefulWidget {
  final String groupId;

  const GroupDetailsPage({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  bool _isLoading = true;
  String _groupName = 'Group';
  String _groupDescription = '';
  List<Map<String, String>> _members = [];
  String? _currentUserEmail;
  String? _adminEmail;
  String? _adminName;
  bool _isCurrentUserAdmin = false;
  late GroupService _groupService;

  @override
  void initState() {
    super.initState();
    _groupService = Provider.of<GroupService>(context, listen: false);
    _loadGroupDetails();
  }

  Future<void> _loadGroupDetails() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = await AuthService.getProfile();
      _currentUserEmail = currentUser?.email ?? '';
      
      print('👤 Current user email: $_currentUserEmail');
      
      final groupData = await _groupService.fetchGroupDetails(widget.groupId);
      
      if (groupData != null && mounted) {
        // 🔍 DEBUG: Print EXACT response structure
        print('═══════════════════════════════════════');
        print('🔍 RAW GROUP DATA:');
        print(jsonEncode(groupData));
        print('═══════════════════════════════════════');
        
        // Print members specifically
        final membersList = groupData['members'];
        print('👥 Members field type: ${membersList.runtimeType}');
        print('👥 Members content: $membersList');
        
        if (membersList is List) {
          print('👥 Member count: ${membersList.length}');
          for (int i = 0; i < membersList.length; i++) {
            final member = membersList[i];
            print('   [$i] Type: ${member.runtimeType}');
            print('   [$i] Content: $member');
            if (member is Map) {
              print('   [$i] Keys: ${member.keys}');
              print('   [$i] _id: ${member['_id']}');
              print('   [$i] name: ${member['name']}');
              print('   [$i] email: ${member['email']}');
            }
          }
        }
        print('═══════════════════════════════════════');
        
        // Extract admin information
        final createdByField = groupData['createdBy'];
        String? adminId;
        
        if (createdByField is Map) {
          _adminEmail = createdByField['email']?.toString();
          _adminName = createdByField['name']?.toString();
          adminId = createdByField['_id']?.toString() ?? createdByField['id']?.toString();
        } else if (createdByField is String) {
          adminId = createdByField;
        }

        print('👑 Admin ID: $adminId, Name: $_adminName, Email: $_adminEmail');

        // Check if current user is admin
        _isCurrentUserAdmin = (_adminEmail != null && _adminEmail == _currentUserEmail);

        // Extract members
        _members.clear();
        
        if (membersList is List && membersList.isNotEmpty) {
          print('👥 Processing ${membersList.length} members from group...');
          
          for (final member in membersList) {
            if (member is Map) {
              final memberId = member['_id']?.toString() ?? member['id']?.toString() ?? '';
              final memberName = member['name']?.toString() ?? 'Member';
              final memberEmail = member['email']?.toString() ?? '';
              
              print('   Processing: $memberName');
              print('      ID: $memberId');
              print('      Email: $memberEmail');
              
              if (memberId.isNotEmpty && memberId != 'null') {
                // Generate consistent avatar
                final avatarId = memberEmail.isNotEmpty 
                    ? (memberEmail.hashCode.abs() % 70) + 1
                    : (memberId.hashCode.abs() % 70) + 1;
                
                final isAdmin = (memberId == adminId) || (memberEmail == _adminEmail && memberEmail.isNotEmpty);
                final isCurrentUser = (memberEmail == _currentUserEmail && memberEmail.isNotEmpty);
                
                _members.add({
                  'id': memberId,
                  'name': memberName,
                  'email': memberEmail,
                  'avatar': 'https://i.pravatar.cc/150?img=$avatarId',
                  'isCurrentUser': isCurrentUser ? 'true' : 'false',
                  'isAdmin': isAdmin ? 'true' : 'false',
                });
                
                print('   ✅ Added: $memberName (ID: $memberId)');
              }
            } else if (member is String) {
              print('   ⚠️ Member is just an ID string: $member');
              print('   ⚠️ Backend did not populate members. This will cause issues.');
            }
          }
        }
        
        // If members list is empty, show error
        if (_members.isEmpty) {
          throw Exception('No valid members found. The backend must populate member details in /group/get/:id endpoint.');
        }
        
        print('📋 Final members: ${_members.length}');
        for (var m in _members) {
          print('   - ${m['name']}: ID=${m['id']}, Email=${m['email']}');
        }
        
        // Set other group details
        setState(() {
          _groupName = groupData['name']?.toString() ?? 'Group';
          _groupDescription = groupData['description']?.toString() ?? '';
          _isLoading = false;
        });
        
        print('✅ Group loaded: $_groupName');
      } else {
        throw Exception('Failed to load group data');
      }
    } catch (e) {
      print('❌ Error loading group details: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showInviteDialog() {
    // Only admins can invite
    if (!_isCurrentUserAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.lock, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Only the group admin can invite members')),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final TextEditingController emailController = TextEditingController();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.person_add, color: theme.primaryColor),
              SizedBox(width: 12),
              Text('Invite Member'),
            ],
          ),
          content: TextField(
            controller: emailController,
            decoration: InputDecoration(
              hintText: 'Enter email address',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter an email'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                Navigator.of(ctx).pop();

                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => Center(
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Sending invite...'),
                        ],
                      ),
                    ),
                  ),
                );

                try {
                  final result = await InviteService.sendInvite(
                    groupId: widget.groupId,
                    friendEmail: email,
                  );

                  Navigator.of(context).pop(); // Close loading

                  if (result['success']) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(child: Text('Invite sent successfully!')),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Failed to send invite'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  Navigator.of(context).pop(); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Send Invite'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black87;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Header(
            title: _groupName,
            heightFactor: 0.12,
          ),
          if (_isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading group details...',
                      style: TextStyle(color: textColor.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadGroupDetails,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Group Info Card
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDark
                                  ? [
                                      primaryColor.withOpacity(0.2),
                                      primaryColor.withOpacity(0.05),
                                    ]
                                  : [
                                      primaryColor.withOpacity(0.15),
                                      primaryColor.withOpacity(0.05),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: primaryColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.groups,
                                size: 48,
                                color: primaryColor,
                              ),
                              SizedBox(height: 12),
                              Text(
                                _groupName,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Text(
                                '${_members.length} member${_members.length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textColor.withOpacity(0.6),
                                ),
                              ),
                              if (_groupDescription.isNotEmpty) ...[
                                SizedBox(height: 12),
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cardColor.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _groupDescription,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: textColor.withOpacity(0.7),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        SizedBox(height: 20),

                        // Quick Actions
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionCard(
                                icon: Icons.person_add,
                                label: 'Invite',
                                color: _isCurrentUserAdmin ? Colors.blue : Colors.grey,
                                onTap: _showInviteDialog,
                                cardColor: cardColor,
                                textColor: textColor,
                                isDisabled: !_isCurrentUserAdmin,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _buildActionCard(
                                icon: Icons.people,
                                label: 'Members',
                                color: Colors.green,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MembersPage(
                                        groupName: _groupName,
                                        members: _members,
                                        primaryColor: primaryColor,
                                      ),
                                    ),
                                  );
                                },
                                cardColor: cardColor,
                                textColor: textColor,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 24),

                        // Recent Activity Section
                        Text(
                          'Recent Activity',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 12),

                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 48,
                                color: isDark ? Colors.white24 : Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No expenses yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Add a bill to get started',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textColor.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                final invalidMembers = _members.where((m) => 
                  m['id'] == null || m['id']!.isEmpty || m['id'] == 'null'
                ).toList();
                
                if (invalidMembers.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Some members have invalid IDs. Cannot create bill.'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 3),
                    ),
                  );
                  return;
                }
                
                if (_members.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('No members in group. Cannot create bill.'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 3),
                    ),
                  );
                  return;
                }
                
                print('🚀 Navigating to AddBillPage with ${_members.length} members');
                print('📋 Members data:');
                for (var m in _members) {
                  print('   - ${m['name']}: ID=${m['id']}');
                }
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddBillPage(
                      groupId: widget.groupId,
                      members: _members,
                    ),
                  ),
                );
              },
              backgroundColor: primaryColor,
              icon: Icon(Icons.add, color: Colors.white),
              label: Text(
                'Add Bill',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required Color cardColor,
    required Color textColor,
    bool isDisabled = false,
  }) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
                SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDisabled ? textColor.withOpacity(0.5) : textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}