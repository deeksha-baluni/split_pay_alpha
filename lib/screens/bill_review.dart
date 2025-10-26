import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart'; // ✅ ADD THIS
import '../components/header.dart';
import '../services/bill_service.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart'; // ✅ ADD THIS

class BillReviewPage extends StatefulWidget {
  final String expenseId;
  final String groupId;
  final List<Map<String, String>> members;
  final File billImage;

  const BillReviewPage({
    super.key,
    required this.expenseId,
    required this.groupId,
    required this.members,
    required this.billImage,
  });

  @override
  State<BillReviewPage> createState() => _BillReviewPageState();
}

class _BillReviewPageState extends State<BillReviewPage> {
  Map<String, dynamic>? _expenseDetails;
  bool _isLoading = true;
  String? _paidBy;
  Map<String, List<int>> _itemAssignments = {}; // itemIndex -> [memberIndices]
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadBillDetails();
    // Set first member as default payer
    if (widget.members.isNotEmpty) {
      _paidBy = widget.members[0]['email'];
    }
    
    // Debug: Print members data
    print('📋 BillReviewPage initialized with ${widget.members.length} members:');
    for (var member in widget.members) {
      print('   - ${member['name']}: ID=${member['id']}, Email=${member['email']}');
    }
  }

  Future<void> _loadBillDetails() async {
    try {
      print('📥 Loading bill details for expense: ${widget.expenseId}');
      
      final details = await BillService.getBillDetails(widget.expenseId);
      
      if (details != null && mounted) {
        print('✅ Bill details loaded successfully');
        print('   Total: ₹${details['totalAmount']}');
        print('   Items: ${(details['items'] as List?)?.length ?? 0}');
        
        // 🔧 FIX: Detect and correct parsing errors
        final items = details['items'] as List?;
        if (items != null) {
          print('\n🔍 Checking for parsing errors...');
          double calculatedTotal = 0.0;
          
          for (int i = 0; i < items.length; i++) {
            final item = items[i];
            final name = item['name'] ?? 'Item ${i + 1}';
            final price = (item['price'] ?? 0).toDouble();
            final quantity = (item['quantity'] ?? 1).toInt();
            final itemTotal = price * quantity;
            
            calculatedTotal += itemTotal;
            print('   ${i + 1}. $name: $quantity × ₹$price = ₹$itemTotal');
            
            // 🚨 DETECT: If itemTotal is way off, the parsing is wrong
            if (itemTotal > (details['totalAmount'] * 0.8)) {
              print('   ⚠️ WARNING: ${name} total (₹$itemTotal) is >80% of bill total (₹${details['totalAmount']})');
              print('   This suggests quantity and unit price might be swapped!');
            }
          }
          
          final billTotal = (details['totalAmount'] ?? 0).toDouble();
          final difference = (calculatedTotal - billTotal).abs();
          
          print('\n📊 Totals:');
          print('   Calculated: ₹${calculatedTotal.toStringAsFixed(2)}');
          print('   Bill Total: ₹${billTotal.toStringAsFixed(2)}');
          print('   Difference: ₹${difference.toStringAsFixed(2)}');
          
          if (difference > 1.0) {
            print('   ❌ Mismatch detected! Items don\'t add up to bill total.');
            print('   This is likely a parsing error from the OCR/LLM.');
          }
        }
        
        setState(() {
          _expenseDetails = details;
          _isLoading = false;
          
          // Initialize assignments - assign all items to all members by default
          if (items != null) {
            for (int i = 0; i < items.length; i++) {
              _itemAssignments[i.toString()] = 
                  List.generate(widget.members.length, (index) => index);
            }
          }
        });
      } else {
        throw Exception('Failed to load bill details');
      }
    } catch (e) {
      print('❌ Error loading bill details: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading bill details: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _toggleMemberForItem(int itemIndex, int memberIndex) {
    setState(() {
      final key = itemIndex.toString();
      if (_itemAssignments[key] == null) {
        _itemAssignments[key] = [];
      }
      
      if (_itemAssignments[key]!.contains(memberIndex)) {
        _itemAssignments[key]!.remove(memberIndex);
      } else {
        _itemAssignments[key]!.add(memberIndex);
      }
    });
  }

  void _editItem(int itemIndex) {
    final items = _expenseDetails?['items'] as List?;
    if (items == null || itemIndex >= items.length) return;

    final item = items[itemIndex];
    final nameController = TextEditingController(text: item['name'] ?? '');
    final priceController = TextEditingController(text: (item['price'] ?? 0).toString());
    final quantityController = TextEditingController(text: (item['quantity'] ?? 1).toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.edit, color: Theme.of(context).primaryColor),
              SizedBox(width: 12),
              Text('Edit Item'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Item Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  decoration: InputDecoration(
                    labelText: 'Unit Price (₹)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Price per single item',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Item Total:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '₹${(double.tryParse(priceController.text) ?? 0) * (int.tryParse(quantityController.text) ?? 1)}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = nameController.text.trim();
                final newQuantity = int.tryParse(quantityController.text) ?? 1;
                final newPrice = double.tryParse(priceController.text) ?? 0.0;

                if (newName.isEmpty || newPrice <= 0 || newQuantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter valid values'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                setState(() {
                  items[itemIndex]['name'] = newName;
                  items[itemIndex]['quantity'] = newQuantity;
                  items[itemIndex]['price'] = newPrice;

                  // Recalculate total
                  double newTotal = 0.0;
                  for (var item in items) {
                    newTotal += ((item['price'] ?? 0).toDouble() * (item['quantity'] ?? 1).toInt());
                  }
                  _expenseDetails?['totalAmount'] = newTotal;
                });

                Navigator.pop(ctx);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Item updated successfully'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitBill() async {
    if (_paidBy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select who paid the bill'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Validate all members have valid IDs
    print('🔍 Validating member IDs...');
    for (var member in widget.members) {
      final memberId = member['id'];
      final memberName = member['name'];
      
      if (memberId == null || memberId.isEmpty || memberId == 'null') {
        print('❌ Invalid ID for member: $memberName (ID: $memberId)');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Member "$memberName" has invalid ID. Cannot proceed.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
      print('   ✅ $memberName: ID=$memberId');
    }

    setState(() => _isProcessing = true);

    try {
      // 🔍 VERIFY: Fetch fresh group data to ensure member IDs are correct
      print('\n🔍 Fetching fresh group data from backend...');
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final groupUri = Uri.parse('https://split-pay-q4wa.onrender.com/api/v1/group/get/${widget.groupId}');
      final groupHeaders = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final groupRes = await http.get(groupUri, headers: groupHeaders).timeout(const Duration(seconds: 10));
      print('📡 Group fetch status: ${groupRes.statusCode}');

      if (groupRes.statusCode != 200) {
        throw Exception('Failed to fetch group data');
      }

      final groupParsed = jsonDecode(groupRes.body);
      final backendGroup = groupParsed['group'];
      
      // Extract actual member IDs from backend
      List<String> backendMemberIds = [];
      if (backendGroup['members'] is List) {
        for (var member in backendGroup['members']) {
          String memberId = '';
          if (member is Map) {
            memberId = member['_id']?.toString() ?? '';
          } else if (member is String) {
            memberId = member;
          }
          if (memberId.isNotEmpty) {
            backendMemberIds.add(memberId);
          }
        }
      }

      print('👥 Backend group member IDs: $backendMemberIds');

      // Verify our members are in the backend list
      for (var member in widget.members) {
        final memberId = member['id'];
        if (!backendMemberIds.contains(memberId)) {
          throw Exception('Member ${member['name']} (ID: $memberId) is not in the group according to backend!');
        }
      }
      print('✅ All members verified in backend group');

      final items = _expenseDetails?['items'] as List?;
      if (items == null) throw Exception('No items found');

      print('📊 Calculating splits for ${items.length} items...');

      // Calculate how much each member owes
      Map<String, double> memberOwes = {};
      Map<String, String> memberIdMap = {}; // email -> id mapping
      
      for (var member in widget.members) {
        final email = member['email']!;
        final id = member['id']!;
        memberOwes[email] = 0.0;
        memberIdMap[email] = id;
      }

      // Calculate split for each item
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final itemName = item['name'] ?? 'Item ${i + 1}';
        final price = (item['price'] ?? 0).toDouble();
        final quantity = (item['quantity'] ?? 1).toInt();
        final totalPrice = price * quantity;
        
        final assignedMembers = _itemAssignments[i.toString()] ?? [];
        
        if (assignedMembers.isEmpty) {
          print('   ⚠️ $itemName: No members assigned, skipping');
          continue;
        }
        
        final perPerson = totalPrice / assignedMembers.length;
        
        print('   📦 $itemName (₹$totalPrice):');
        
        for (final memberIdx in assignedMembers) {
          final memberEmail = widget.members[memberIdx]['email']!;
          final memberName = widget.members[memberIdx]['name']!;
          memberOwes[memberEmail] = (memberOwes[memberEmail] ?? 0) + perPerson;
          print('      - $memberName owes ₹${perPerson.toStringAsFixed(2)}');
        }
      }

      // Find the payer's user ID
      final payerId = memberIdMap[_paidBy];
      
      if (payerId == null || payerId.isEmpty) {
        throw Exception('Payer ID not found for email: $_paidBy');
      }
      
      final payerMember = widget.members.firstWhere((m) => m['email'] == _paidBy);
      print('\n💰 PAYER INFORMATION:');
      print('   Name: ${payerMember['name']}');
      print('   Email: $_paidBy');
      print('   ID: $payerId');

      // Create assignments for backend
      List<Map<String, dynamic>> assignments = [];
      
      print('\n📋 CREATING ASSIGNMENTS:');
      double totalAssigned = 0.0;
      
      for (var member in widget.members) {
        final memberEmail = member['email']!;
        final memberId = member['id']!;
        final memberName = member['name']!;
        final amount = memberOwes[memberEmail] ?? 0.0;
        
        print('   👤 $memberName (ID: $memberId)');
        print('      Email: $memberEmail');
        print('      Owes: ₹${amount.toStringAsFixed(2)}');
        
        // ✅ CRITICAL FIX: Skip if this person is the payer
        if (memberId == payerId) {
          print('      ⭐️ Skipped (this is the payer - no self-assignment)');
          continue;
        }
        
        if (amount > 0) {
          assignments.add({
            'from': memberId,
            'to': payerId,
            'amount': amount,
          });
          totalAssigned += amount;
          print('      ✅ Assignment created: $memberId → $payerId (₹${amount.toStringAsFixed(2)})');
        } else {
          print('      ⭕ Skipped (amount is 0)');
        }
      }

      if (assignments.isEmpty) {
        throw Exception('No valid assignments created. Please assign items to members other than the payer.');
      }

      print('\n📊 SUMMARY:');
      print('   Total bill: ₹${_expenseDetails?['totalAmount']}');
      print('   Total assigned to others: ₹${totalAssigned.toStringAsFixed(2)}');
      print('   Number of assignments: ${assignments.length}');

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text(
                  'Processing bill...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'Assigning expenses and updating balances',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );

      // Step 1: Assign money
      print('\n📤 STEP 1: Calling assignMoney API...');
      final assignResult = await BillService.assignMoney(
        expenseId: widget.expenseId,
        assignments: assignments,
      );

      print('📥 assignMoney response:');
      print(jsonEncode(assignResult));

      if (assignResult['success'] != true) {
        throw Exception(assignResult['message'] ?? 'Failed to assign money');
      }

      print('✅ Money assigned successfully');

      // Step 2: Settle assignments
      print('\n📤 STEP 2: Calling settleAssignments API...');
      final settleResult = await BillService.settleAssignments(
        expenseId: widget.expenseId,
      );

      print('📥 settleAssignments response:');
      print(jsonEncode(settleResult));

      Navigator.of(context).pop(); // Close loading dialog

      if (settleResult['success'] == true) {
        print('✅ Assignments settled successfully');
        
        // ✅ NEW: Cache this expense locally in GroupService
        try {
          final groupService = Provider.of<GroupService>(context, listen: false);
          
          // Create expense summary with item names
          String description = 'Recent Bill';
          if (items.isNotEmpty) {
            final itemNames = items.take(2).map((item) => item['name'] ?? 'Item').join(', ');
            description = items.length > 2 
                ? '$itemNames and ${items.length - 2} more items'
                : itemNames;
          }
          
          final expenseSummary = {
            '_id': widget.expenseId,
            'description': description,
            'totalAmount': _expenseDetails?['totalAmount'] ?? 0.0,
            'assignments': assignments.map((a) {
              final fromMember = widget.members.firstWhere((m) => m['id'] == a['from']);
              final toMember = widget.members.firstWhere((m) => m['id'] == a['to']);
              return {
                'from': {
                  '_id': a['from'],
                  'name': fromMember['name'],
                  'email': fromMember['email'],
                },
                'to': {
                  '_id': a['to'],
                  'name': toMember['name'],
                  'email': toMember['email'],
                },
                'amount': a['amount'],
              };
            }).toList(),
            'items': items,
            'createdAt': DateTime.now().toIso8601String(),
          };
          
          groupService.addExpenseToGroup(widget.groupId, expenseSummary);
          print('✅ Expense cached locally in GroupService');
        } catch (e) {
          print('⚠️ Error caching expense: $e');
          // Non-critical error, continue
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Bill processed successfully!')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate back to home (removes all routes until first)
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        throw Exception(settleResult['message'] ?? 'Failed to settle assignments');
      }
    } catch (e) {
      print('\n❌ ERROR in _submitBill:');
      print('   ${e.toString()}');
      print('   Stack trace:');
      print(StackTrace.current);
      
      // Close loading dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black87;
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Header(
            title: 'Review Bill',
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
                    Text('Loading bill details...'),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bill Image Preview
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            widget.billImage,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      SizedBox(height: 24),

                      // Total Amount
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            Text(
                              '₹ ${_expenseDetails?['totalAmount']?.toStringAsFixed(2) ?? '0.00'}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // Paid By
                      Text(
                        'Paid By',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 10),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardColor,
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _paidBy,
                            isExpanded: true,
                            icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                            items: widget.members.map((member) {
                              return DropdownMenuItem<String>(
                                value: member['email'],
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundImage: NetworkImage(member['avatar']!),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      member['name']!,
                                      style: TextStyle(color: textColor),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _paidBy = value;
                              });
                            },
                          ),
                        ),
                      ),

                      SizedBox(height: 24),

                      // Items Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Items',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Text(
                            'Tap to assign',
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),

                      // Items List
                      ...(_expenseDetails?['items'] as List? ?? [])
                          .asMap()
                          .entries
                          .map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final assignedMembers = _itemAssignments[index.toString()] ?? [];
                        
                        return _buildItemCard(
                          index: index,
                          itemName: item['name'] ?? 'Item',
                          price: (item['price'] ?? 0).toDouble(),
                          quantity: (item['quantity'] ?? 1).toInt(),
                          assignedMembers: assignedMembers,
                          cardColor: cardColor,
                          textColor: textColor,
                          primaryColor: primaryColor,
                        );
                      }).toList(),

                      SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isLoading
          ? null
          : Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _submitBill,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: _isProcessing
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Submit Bill',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildItemCard({
    required int index,
    required String itemName,
    required double price,
    required int quantity,
    required List<int> assignedMembers,
    required Color cardColor,
    required Color textColor,
    required Color primaryColor,
  }) {
    final totalPrice = price * quantity;
    final splitAmount = assignedMembers.isEmpty 
        ? 0.0 
        : totalPrice / assignedMembers.length;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Qty: $quantity × ₹${price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    '₹${totalPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.edit, size: 18),
                    color: primaryColor,
                    onPressed: () => _editItem(index),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    tooltip: 'Edit item',
                  ),
                ],
              ),
            ],
          ),
          
          SizedBox(height: 12),
          Divider(height: 1),
          SizedBox(height: 12),
          
          // Member chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.members.asMap().entries.map((entry) {
              final memberIndex = entry.key;
              final member = entry.value;
              final isAssigned = assignedMembers.contains(memberIndex);
              
              return GestureDetector(
                onTap: () => _toggleMemberForItem(index, memberIndex),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAssigned 
                        ? primaryColor.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isAssigned 
                          ? primaryColor 
                          : Colors.grey.withOpacity(0.3),
                      width: isAssigned ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundImage: NetworkImage(member['avatar']!),
                      ),
                      SizedBox(width: 6),
                      Text(
                        member['name']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isAssigned ? FontWeight.w600 : FontWeight.normal,
                          color: isAssigned ? primaryColor : textColor.withOpacity(0.7),
                        ),
                      ),
                      if (isAssigned) ...[
                        SizedBox(width: 4),
                        Icon(Icons.check, size: 14, color: primaryColor),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          
          if (assignedMembers.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              'Split: ₹${splitAmount.toStringAsFixed(2)} per person',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: textColor.withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}