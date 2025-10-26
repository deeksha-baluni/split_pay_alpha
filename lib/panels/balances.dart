import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/header.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart';
import 'package:fl_chart/fl_chart.dart';

class BalancesPanel extends StatefulWidget {
  const BalancesPanel({super.key});

  @override
  State<BalancesPanel> createState() => _BalancesPanelState();
}

class _BalancesPanelState extends State<BalancesPanel> {
  double _youOwe = 0.0;
  double _youAreOwed = 0.0;
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedPeriod = 'All Time'; // All Time, This Month, This Week

  @override
  void initState() {
    super.initState();
    _loadBalances();
  }

  Future<void> _loadBalances() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      print('📄 Loading user balances...');
      final userDetails = await AuthService.getUserDetails();
      
      print('📊 User details response: $userDetails');
      
      if (userDetails != null && mounted) {
        double youOwe = 0.0;
        double youAreOwed = 0.0;

        if (userDetails['user'] != null) {
          final userData = userDetails['user'];
          youOwe = _parseDouble(userData['youOwe']);
          youAreOwed = _parseDouble(userData['youAreOwed']);
        } 
        else if (userDetails['youOwe'] != null || userDetails['youAreOwed'] != null) {
          youOwe = _parseDouble(userDetails['youOwe']);
          youAreOwed = _parseDouble(userDetails['youAreOwed']);
        }

        setState(() {
          _youOwe = youOwe;
          _youAreOwed = youAreOwed;
          _isLoading = false;
        });
        
        print('✅ Balances loaded: You Owe: ₹$_youOwe, You Are Owed: ₹$_youAreOwed');
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load balance information';
        });
        print('❌ User details returned null');
      }
    } catch (e) {
      print('❌ Error loading balances: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading balances: ${e.toString()}';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading balances: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // Calculate analytics from cached expenses
  Map<String, dynamic> _calculateAnalytics() {
    final groupService = Provider.of<GroupService>(context, listen: false);
    final allGroups = groupService.groups;
    
    double totalSpending = 0.0;
    Map<String, double> categorySpending = {
      'Food & Dining': 0.0,
      'Travel': 0.0,
      'Shopping': 0.0,
      'Entertainment': 0.0,
      'Utilities': 0.0,
      'Other': 0.0,
    };
    
    Map<String, double> monthlySpending = {};
    Map<String, double> userBalances = {};
    int totalExpenses = 0;
    
    for (var group in allGroups) {
      if (group.id == null) continue;
      
      final expenses = groupService.getGroupExpenses(group.id!);
      totalExpenses += expenses.length;
      
      for (var expense in expenses) {
        final amount = (expense['totalAmount'] ?? 0).toDouble();
        totalSpending += amount;
        
        // Categorize based on description
        final description = (expense['description'] ?? '').toString().toLowerCase();
        String category = 'Other';
        
        if (description.contains('food') || description.contains('restaurant') || 
            description.contains('dinner') || description.contains('lunch') ||
            description.contains('breakfast') || description.contains('paneer') ||
            description.contains('chicken') || description.contains('pizza') ||
            description.contains('burger')) {
          category = 'Food & Dining';
        } else if (description.contains('travel') || description.contains('uber') ||
                   description.contains('taxi') || description.contains('flight') ||
                   description.contains('hotel')) {
          category = 'Travel';
        } else if (description.contains('shop') || description.contains('clothes') ||
                   description.contains('amazon') || description.contains('flipkart')) {
          category = 'Shopping';
        } else if (description.contains('movie') || description.contains('game') ||
                   description.contains('concert') || description.contains('party')) {
          category = 'Entertainment';
        } else if (description.contains('electric') || description.contains('water') ||
                   description.contains('rent') || description.contains('utility')) {
          category = 'Utilities';
        }
        
        categorySpending[category] = (categorySpending[category] ?? 0) + amount;
        
        // Monthly spending
        try {
          final dateStr = expense['createdAt']?.toString() ?? '';
          if (dateStr.isNotEmpty) {
            final date = DateTime.parse(dateStr);
            final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
            monthlySpending[monthKey] = (monthlySpending[monthKey] ?? 0) + amount;
          }
        } catch (e) {
          // Ignore date parse errors
        }
        
        // User balances from assignments
        final assignments = expense['assignments'] as List? ?? [];
        for (var assignment in assignments) {
          final fromName = assignment['from']?['name'] ?? 'Unknown';
          final toName = assignment['to']?['name'] ?? 'Unknown';
          final assignAmount = (assignment['amount'] ?? 0).toDouble();
          
          if (!userBalances.containsKey(fromName)) {
            userBalances[fromName] = 0.0;
          }
          userBalances[fromName] = userBalances[fromName]! + assignAmount;
        }
      }
    }
    
    return {
      'totalSpending': totalSpending,
      'categorySpending': categorySpending,
      'monthlySpending': monthlySpending,
      'userBalances': userBalances,
      'totalExpenses': totalExpenses,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color textPrimary = theme.textTheme.bodyMedium?.color ?? Colors.black87;
    final Color cardColor = theme.cardColor;
    final Color owedColor = theme.brightness == Brightness.dark 
        ? Colors.red[300]! 
        : Colors.redAccent;
    final Color owingColor = theme.brightness == Brightness.dark 
        ? Colors.greenAccent 
        : Colors.green;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Header(
            title: "Your Balances",
            heightFactor: 0.12,
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading balances...',
                          style: TextStyle(color: textPrimary.withOpacity(0.6)),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadBalances,
                    child: SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Consumer<GroupService>(
                          builder: (context, groupService, _) {
                            final analytics = _calculateAnalytics();
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Error message if any
                                if (_errorMessage != null) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(16),
                                    margin: EdgeInsets.only(bottom: 20),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.red.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.red),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Balance Cards Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildBalanceCard(
                                        icon: Icons.arrow_upward,
                                        label: "You Owe",
                                        amount: _youOwe,
                                        color: owedColor,
                                        cardColor: cardColor,
                                        textColor: textPrimary,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _buildBalanceCard(
                                        icon: Icons.arrow_downward,
                                        label: "You are Owed",
                                        amount: _youAreOwed,
                                        color: owingColor,
                                        cardColor: cardColor,
                                        textColor: textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                SizedBox(height: 20),
                                
                                // Net Balance Card
                                _buildNetBalanceCard(
                                  youOwe: _youOwe,
                                  youAreOwed: _youAreOwed,
                                  owedColor: owedColor,
                                  owingColor: owingColor,
                                  textColor: textPrimary,
                                ),
                                
                                SizedBox(height: 30),
                                
                                // Analytics Section Header
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Analytics',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: theme.primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${analytics['totalExpenses']} Bills',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: theme.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                SizedBox(height: 16),
                                
                                // Total Spending Card
                                _buildTotalSpendingCard(
                                  analytics['totalSpending'],
                                  cardColor,
                                  textPrimary,
                                  theme.primaryColor,
                                ),
                                
                                SizedBox(height: 16),
                                
                                // Spending by Category
                                if ((analytics['categorySpending'] as Map<String, double>)
                                    .values.any((v) => v > 0)) ...[
                                  _buildSectionTitle('Spending by Category', textPrimary),
                                  SizedBox(height: 12),
                                  _buildCategorySpendingChart(
                                    analytics['categorySpending'],
                                    cardColor,
                                    textPrimary,
                                  ),
                                  SizedBox(height: 16),
                                ],
                                
                                // Spending Over Time
                                if ((analytics['monthlySpending'] as Map<String, double>).isNotEmpty) ...[
                                  _buildSectionTitle('Spending Over Time', textPrimary),
                                  SizedBox(height: 12),
                                  _buildSpendingOverTimeChart(
                                    analytics['monthlySpending'],
                                    cardColor,
                                    textPrimary,
                                    theme.primaryColor,
                                  ),
                                  SizedBox(height: 16),
                                ],
                                
                                // User Balances
                                if ((analytics['userBalances'] as Map<String, double>).isNotEmpty) ...[
                                  _buildSectionTitle('Top Debtors', textPrimary),
                                  SizedBox(height: 12),
                                  _buildUserBalancesChart(
                                    analytics['userBalances'],
                                    cardColor,
                                    textPrimary,
                                    owedColor,
                                  ),
                                  SizedBox(height: 16),
                                ],
                                
                                // Info message
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: theme.primaryColor,
                                        size: 24,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Analytics are based on bills created during this session',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: textPrimary.withOpacity(0.7),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 20),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }

  Widget _buildBalanceCard({
    required IconData icon,
    required String label,
    required double amount,
    required Color color,
    required Color cardColor,
    required Color textColor,
  }) {
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              "₹ ${amount.toStringAsFixed(2)}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetBalanceCard({
    required double youOwe,
    required double youAreOwed,
    required Color owedColor,
    required Color owingColor,
    required Color textColor,
  }) {
    final netBalance = youAreOwed - youOwe;
    final isPositive = netBalance >= 0;
    final displayColor = isPositive ? owingColor : owedColor;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPositive
              ? [owingColor.withOpacity(0.2), owingColor.withOpacity(0.05)]
              : [owedColor.withOpacity(0.2), owedColor.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPositive
              ? owingColor.withOpacity(0.3)
              : owedColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Net Balance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor.withOpacity(0.7),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '₹ ${netBalance.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: displayColor,
            ),
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                size: 18,
                color: displayColor,
              ),
              SizedBox(width: 6),
              Text(
                isPositive
                    ? 'You are owed overall'
                    : 'You owe overall',
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSpendingCard(
    double totalSpending,
    Color cardColor,
    Color textColor,
    Color accentColor,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: accentColor,
                  size: 28,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Spending',
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '₹${totalSpending.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'All time expenses tracked',
            style: TextStyle(
              fontSize: 12,
              color: textColor.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySpendingChart(
    Map<String, double> categorySpending,
    Color cardColor,
    Color textColor,
  ) {
    // Filter out categories with 0 spending
    final nonZeroCategories = Map.fromEntries(
      categorySpending.entries.where((e) => e.value > 0)
    );
    
    if (nonZeroCategories.isEmpty) {
      return SizedBox.shrink();
    }

    final total = nonZeroCategories.values.fold(0.0, (sum, val) => sum + val);
    
    final colors = [
      Colors.orange,
      Colors.blue,
      Colors.purple,
      Colors.green,
      Colors.red,
      Colors.teal,
    ];

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Row(
              children: [
                // Pie Chart
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: nonZeroCategories.entries.toList().asMap().entries.map((entry) {
                        final index = entry.key;
                        final category = entry.value.key;
                        final value = entry.value.value;
                        final percentage = (value / total * 100);
                        
                        return PieChartSectionData(
                          color: colors[index % colors.length],
                          value: value,
                          title: '${percentage.toStringAsFixed(0)}%',
                          radius: 50,
                          titleStyle: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color.fromARGB(255, 0, 0, 0),
                          ),
                          titlePositionPercentageOffset: 0.5,
                        );
                      }).toList(),
                    ),
                  ),
                ),
                SizedBox(width: 20),
                // Legend
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: nonZeroCategories.entries.toList().asMap().entries.map((entry) {
                      final index = entry.key;
                      final category = entry.value.key;
                      final value = entry.value.value;
                      
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: colors[index % colors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                category,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '₹${value.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingOverTimeChart(
    Map<String, double> monthlySpending,
    Color cardColor,
    Color textColor,
    Color accentColor,
  ) {
    if (monthlySpending.isEmpty) return SizedBox.shrink();

    final sortedEntries = monthlySpending.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    final maxValue = sortedEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < sortedEntries.length) {
                          final month = sortedEntries[value.toInt()].key.split('-')[1];
                          return Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              month,
                              style: TextStyle(
                                color: textColor.withOpacity(0.6),
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '₹${(value / 1000).toStringAsFixed(0)}k',
                          style: TextStyle(
                            color: textColor.withOpacity(0.6),
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: sortedEntries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final value = entry.value.value;
                  
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: value,
                        color: accentColor,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBalancesChart(
    Map<String, double> userBalances,
    Color cardColor,
    Color textColor,
    Color accentColor,
  ) {
    // Get top 5 debtors
    final sortedBalances = userBalances.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final top5 = sortedBalances.take(5).toList();
    
    if (top5.isEmpty) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: top5.map((entry) {
          final name = entry.key;
          final amount = entry.value;
          final maxAmount = top5.first.value;
          final percentage = (amount / maxAmount);
          
          return Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '₹${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 8,
                    backgroundColor: accentColor.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
