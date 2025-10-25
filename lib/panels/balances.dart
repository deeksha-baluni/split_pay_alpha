import 'package:flutter/material.dart';
import '../components/header.dart';
import '../services/auth_service.dart';

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
      print('🔄 Loading user balances...');
      final userDetails = await AuthService.getUserDetails();
      
      print('📊 User details response: $userDetails');
      
      if (userDetails != null && mounted) {
        // Handle different response structures
        double youOwe = 0.0;
        double youAreOwed = 0.0;

        // Check if the response has a 'user' field
        if (userDetails['user'] != null) {
          final userData = userDetails['user'];
          youOwe = _parseDouble(userData['youOwe']);
          youAreOwed = _parseDouble(userData['youAreOwed']);
        } 
        // Or if the data is directly in the response
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

  // Helper method to safely parse double values
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
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
                        child: Column(
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
                            
                            SizedBox(height: 30),
                            
                            // Net Balance Card
                            _buildNetBalanceCard(
                              youOwe: _youOwe,
                              youAreOwed: _youAreOwed,
                              owedColor: owedColor,
                              owingColor: owingColor,
                              textColor: textPrimary,
                            ),
                            
                            SizedBox(height: 30),
                            
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
                                      'Pull down to refresh your balance information',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: textPrimary.withOpacity(0.7),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Additional spacing at bottom
                            SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
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
}