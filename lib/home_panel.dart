import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'panels/profile.dart';
import 'panels/group.dart';
import 'panels/create_group.dart';
import 'panels/balances.dart';
import 'screens/add_bill.dart';
import 'services/auth_service.dart';
import 'services/group_service.dart';
import 'services/invite_service.dart';
import 'services/notification_service.dart';

class HomePanel extends StatefulWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;
  final VoidCallback onLogout;

  const HomePanel({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
    required this.onLogout,
  });

  @override
  State<HomePanel> createState() => _HomePanelState();
}

class _HomePanelState extends State<HomePanel> {
  String? _name;
  List<Map<String, dynamic>> _pendingInvites = [];
  List<Map<String, dynamic>> _notifications = [];
  bool _loadingInvites = false;
  bool _loadingNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadPendingInvites();
    _loadNotifications();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GroupService>(context, listen: false).fetchGroups();
    });
  }

  Future<void> _loadProfile() async {
    final profile = await AuthService.getProfile();
    if (profile != null && mounted) {
      setState(() {
        _name = profile.name;
      });
    }
  }

  Future<void> _loadPendingInvites() async {
    setState(() => _loadingInvites = true);
    try {
      final invites = await InviteService.getPendingInvites();
      if (mounted) {
        setState(() {
          _pendingInvites = invites;
          _loadingInvites = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingInvites = false);
      }
    }
  }

  Future<void> _loadNotifications() async {
    setState(() => _loadingNotifications = true);
    try {
      final notifications = await NotificationService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _loadingNotifications = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingNotifications = false);
      }
    }
  }

  Future<void> _handleAcceptInvite(String inviteId, String groupName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Accepting invite...'),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await InviteService.acceptInvite(inviteId);
      Navigator.of(context).pop();

      if (result['success']) {
        await Future.wait([
          Provider.of<GroupService>(context, listen: false).fetchGroups(),
          _loadPendingInvites(),
        ]);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Joined "$groupName" successfully!')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleRejectInvite(String inviteId, String groupName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Rejecting invite...'),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await InviteService.rejectInvite(inviteId);
      Navigator.of(context).pop();

      if (result['success']) {
        await _loadPendingInvites();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Declined invitation to "$groupName"')),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _dismissNotification(String notificationId) async {
    try {
      await NotificationService.dismissNotification(notificationId);
      await _loadNotifications();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error dismissing notification'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToCreateGroup() {
    final svc = Provider.of<GroupService>(context, listen: false);
    svc.selectedIndex = 2;
  }

  // NEW: Show group selection dialog and navigate to Add Bill page
  void _showAddBillDialog() async {
    final groupService = Provider.of<GroupService>(context, listen: false);
    final groups = groupService.groups;

    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please create a group first'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Show dialog to select group
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.receipt_long, color: Theme.of(context).primaryColor),
              SizedBox(width: 12),
              Text('Select Group'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: groups.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                final group = groups[index];
                return ListTile(
                  leading: Icon(
                    Icons.groups,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: Text(
                    group.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text('${group.members} member${group.members != 1 ? 's' : ''}'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    // Save context references before async operations
                    final navigator = Navigator.of(context);
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    
                    // Close selection dialog
                    navigator.pop();

                    // Show loading dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (loadingCtx) => WillPopScope(
                        onWillPop: () async => false,
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Loading group details...'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );

                    try {
                      // Fetch group details to get members with timeout
                      final groupData = await groupService.fetchGroupDetails(group.id!)
                          .timeout(
                            Duration(seconds: 15),
                            onTimeout: () {
                              throw Exception('Request timed out. Please check your connection.');
                            },
                          );

                      if (groupData == null) {
                        throw Exception('Failed to load group details');
                      }

                      print('📦 Group data received: ${groupData.keys}');

                      // Extract members
                      List<Map<String, String>> members = [];
                      final membersList = groupData['members'];
                      
                      print('👥 Members list type: ${membersList.runtimeType}');
                      print('👥 Members list: $membersList');
                      
                      if (membersList is List && membersList.isNotEmpty) {
                        for (final member in membersList) {
                          if (member is Map) {
                            final memberId = member['_id']?.toString() ?? member['id']?.toString() ?? '';
                            final memberName = member['name']?.toString() ?? 'Member';
                            final memberEmail = member['email']?.toString() ?? '';
                            
                            print('   Processing: $memberName (ID: $memberId)');
                            
                            if (memberId.isNotEmpty && memberId != 'null') {
                              final avatarId = memberEmail.isNotEmpty 
                                  ? (memberEmail.hashCode.abs() % 70) + 1
                                  : (memberId.hashCode.abs() % 70) + 1;
                              
                              members.add({
                                'id': memberId,
                                'name': memberName,
                                'email': memberEmail,
                                'avatar': 'https://i.pravatar.cc/150?img=$avatarId',
                              });
                              
                              print('   ✅ Added: $memberName');
                            }
                          }
                        }
                      }

                      print('📋 Total members extracted: ${members.length}');

                      if (members.isEmpty) {
                        throw Exception('No valid members found in group. Please ensure the group has members.');
                      }

                      // Close loading dialog using saved navigator
                      if (mounted && navigator.canPop()) {
                        navigator.pop();
                      }

                      // Navigate to Add Bill page using saved navigator
                      if (mounted) {
                        navigator.push(
                          MaterialPageRoute(
                            builder: (context) => AddBillPage(
                              groupId: group.id!,
                              members: members,
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      print('❌ Error in _showAddBillDialog: $e');
                      
                      // Close loading dialog using saved navigator
                      if (mounted && navigator.canPop()) {
                        try {
                          navigator.pop();
                        } catch (_) {}
                      }
                      
                      if (mounted) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 4),
                            action: SnackBarAction(
                              label: 'OK',
                              textColor: Colors.white,
                              onPressed: () {},
                            ),
                          ),
                        );
                      }
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHome(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;
    final colorPrimary = isDark ? Color(0xFF2266B6) : Color(0xFF3A7FD5);
    final background = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textPrimary = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;

    final media = MediaQuery.of(context);
    final size = media.size;
    final textScale = media.textScaler.scale(1.0);
    final horizontalPadding = (size.width * 0.045).clamp(12.0, 24.0);
    final cardRadius = (size.width * 0.035).clamp(12.0, 18.0);
    final sectionTitleSize = (size.width * 0.045).clamp(16.0, 20.0) * textScale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRoundedHeader(context, colorPrimary, cardColor, textPrimary),

        Expanded(
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(horizontalPadding),
            color: background,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pending Invitations Section
                  if (_pendingInvites.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Pending Invitations",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: sectionTitleSize,
                                color: textPrimary,
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_pendingInvites.length}',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh, size: 20),
                          onPressed: _loadPendingInvites,
                          tooltip: 'Refresh invites',
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    ..._pendingInvites.map((invite) => _buildInviteCard(
                      invite: invite,
                      cardColor: cardColor,
                      textPrimary: textPrimary,
                      colorPrimary: colorPrimary,
                      cardRadius: cardRadius,
                      isDark: isDark,
                    )),
                    SizedBox(height: 20),
                  ],

                  // Notifications Section
                  if (_notifications.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Notifications",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: sectionTitleSize,
                                color: textPrimary,
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorPrimary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_notifications.length}',
                                style: TextStyle(
                                  color: colorPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh, size: 20),
                          onPressed: _loadNotifications,
                          tooltip: 'Refresh notifications',
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    ..._notifications.map((notification) => _buildNotificationCard(
                      notification: notification,
                      cardColor: cardColor,
                      textPrimary: textPrimary,
                      colorPrimary: colorPrimary,
                      cardRadius: cardRadius,
                      isDark: isDark,
                    )),
                    SizedBox(height: 20),
                  ],

                  // Empty state when no invites or notifications
                  if (_pendingInvites.isEmpty && _notifications.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 64,
                              color: isDark ? Colors.white24 : Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              "No pending invitations",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "You're all caught up!",
                              style: TextStyle(
                                fontSize: 14,
                                color: textPrimary.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInviteCard({
    required Map<String, dynamic> invite,
    required Color cardColor,
    required Color textPrimary,
    required Color colorPrimary,
    required double cardRadius,
    required bool isDark,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.mail_outline,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite['groupName'] ?? 'Group',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Invited by ${invite['senderName'] ?? 'Someone'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: textPrimary.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAcceptInvite(
                      invite['id'],
                      invite['groupName'] ?? 'Group',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: Text(
                      'Accept',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleRejectInvite(
                      invite['id'],
                      invite['groupName'] ?? 'Group',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Decline',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required Map<String, dynamic> notification,
    required Color cardColor,
    required Color textPrimary,
    required Color colorPrimary,
    required double cardRadius,
    required bool isDark,
  }) {
    final type = notification['type'] ?? 'info';
    Color accentColor;
    IconData icon;

    switch (type) {
      case 'accepted':
        accentColor = Colors.green;
        icon = Icons.check_circle_outline;
        break;
      case 'rejected':
        accentColor = Colors.red;
        icon = Icons.cancel_outlined;
        break;
      default:
        accentColor = colorPrimary;
        icon = Icons.info_outline;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: accentColor,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification['title'] ?? 'Notification',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (notification['message'] != null) ...[
                    SizedBox(height: 4),
                    Text(
                      notification['message'],
                      style: TextStyle(
                        fontSize: 13,
                        color: textPrimary.withOpacity(0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (notification['timestamp'] != null) ...[
                    SizedBox(height: 4),
                    Text(
                      notification['timestamp'],
                      style: TextStyle(
                        fontSize: 11,
                        color: textPrimary.withOpacity(0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 20),
              color: textPrimary.withOpacity(0.5),
              onPressed: () => _dismissNotification(notification['id']),
              tooltip: 'Dismiss',
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundedHeader(BuildContext context, Color colorPrimary, Color cardColor, Color textPrimary) {
    final screenHeight = MediaQuery.of(context).size.height;
    final headerHeight = screenHeight * 0.30;

    return Container(
      height: headerHeight,
      decoration: BoxDecoration(
        color: colorPrimary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: (headerHeight * 0.06).clamp(10.0, 24.0)),
              child: Center(
                child: Text(
                  "SplitPay",
                  style: TextStyle(
                    fontSize: (headerHeight * 0.09).clamp(18.0, 26.0),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: (headerHeight * 0.12).clamp(8.0, 28.0), left: 18, right: 18),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Container(
                      padding: EdgeInsets.all((headerHeight * 0.06).clamp(10.0, 20.0)),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular((headerHeight * 0.08).clamp(16.0, 28.0)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name != null
                                ? "Hi $_name, ready to split today's bill?"
                                : "Hi there, ready to split today's bill?",
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: (headerHeight * 0.06).clamp(14.0, 18.0),
                            ),
                          ),
                          SizedBox(height: (headerHeight * 0.04).clamp(8.0, 14.0)),
                          
                          // NEW: Two buttons side by side
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorPrimary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular((headerHeight * 0.05).clamp(10.0, 16.0)),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: (headerHeight * 0.06).clamp(8.0, 16.0), 
                                      vertical: (headerHeight * 0.05).clamp(8.0, 12.0)
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: _navigateToCreateGroup,
                                  icon: Icon(Icons.group_add, size: 18),
                                  label: Text(
                                    "Create Group",
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular((headerHeight * 0.05).clamp(10.0, 16.0)),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: (headerHeight * 0.06).clamp(8.0, 16.0), 
                                      vertical: (headerHeight * 0.05).clamp(8.0, 12.0)
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: _showAddBillDialog,
                                  icon: Icon(Icons.receipt_long, size: 18),
                                  label: Text(
                                    "Add Bill",
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  final List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.group_outlined), label: 'Groups'),
    BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: ''),
    BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Balances'),
    BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
  ];

  List<Widget> _tabs(BuildContext context) => [
    _buildHome(context),
    GroupsPanel(),
    CreateGroupPage(),
    BalancesPanel(),
    ProfilePanel(
      onLogout: widget.onLogout,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;
    final colorPrimary = Theme.of(context).primaryColor;

    return WillPopScope(
      onWillPop: () async {
        final svc = Provider.of<GroupService>(context, listen: false);
        if (svc.selectedIndex != 0) {
          svc.selectedIndex = 0;
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: Provider.of<GroupService>(context).selectedIndex == 4
            ? AppBar(
          title: Text('SplitPay'),
          actions: [
            IconButton(
              icon: Icon(isDark ? Icons.wb_sunny : Icons.nightlight_round),
              onPressed: widget.toggleTheme,
            ),
          ],
        )
            : null,
        body: Consumer<GroupService>(
          builder: (context, svc, _) {
            final idx = svc.selectedIndex;
            return AnimatedSwitcher(
              duration: Duration(milliseconds: 350),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _tabs(context)[idx],
            );
          },
        ),
        bottomNavigationBar: Consumer<GroupService>(
          builder: (context, svc, _) {
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? Color(0xFF1E1E2E) : Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                    blurRadius: 25,
                    offset: Offset(0, 10),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(
                          icon: Icons.home_rounded,
                          label: 'Home',
                          index: 0,
                          currentIndex: svc.selectedIndex,
                          colorPrimary: colorPrimary,
                          isDark: isDark,
                          onTap: () {
                            svc.selectedIndex = 0;
                            _loadPendingInvites();
                            _loadNotifications();
                          },
                        ),
                        _buildNavItem(
                          icon: Icons.groups_rounded,
                          label: 'Groups',
                          index: 1,
                          currentIndex: svc.selectedIndex,
                          colorPrimary: colorPrimary,
                          isDark: isDark,
                          onTap: () => svc.selectedIndex = 1,
                        ),
                        _buildNavItem(
                          icon: Icons.add_circle,
                          label: '',
                          index: 2,
                          currentIndex: svc.selectedIndex,
                          colorPrimary: colorPrimary,
                          isDark: isDark,
                          isCenter: true,
                          onTap: () => svc.selectedIndex = 2,
                        ),
                        _buildNavItem(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Balances',
                          index: 3,
                          currentIndex: svc.selectedIndex,
                          colorPrimary: colorPrimary,
                          isDark: isDark,
                          onTap: () => svc.selectedIndex = 3,
                        ),
                        _buildNavItem(
                          icon: Icons.person_rounded,
                          label: 'Profile',
                          index: 4,
                          currentIndex: svc.selectedIndex,
                          colorPrimary: colorPrimary,
                          isDark: isDark,
                          onTap: () => svc.selectedIndex = 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required int currentIndex,
    required Color colorPrimary,
    required bool isDark,
    required VoidCallback onTap,
    bool isCenter = false,
  }) {
    final isSelected = currentIndex == index;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isCenter ? 0 : (isSelected ? 16 : 12),
          vertical: isCenter ? 0 : 8,
        ),
        decoration: BoxDecoration(
          color: isSelected && !isCenter
              ? colorPrimary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(isCenter ? 50 : 16),
        ),
        child: isCenter
            ? Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorPrimary,
                      colorPrimary.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorPrimary.withOpacity(0.4),
                      blurRadius: 15,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 32,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? colorPrimary : (isDark ? Colors.white54 : Colors.grey),
                    size: 24,
                  ),
                  if (isSelected && label.isNotEmpty) ...[
                    SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: colorPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}