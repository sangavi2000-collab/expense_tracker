import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (defaultTargetPlatform == TargetPlatform.android) {
    SharedPreferencesAndroid.registerWith();
  }

  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8652F6),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F2FA),
      ),
      home: const HomePage(),
    );
  }
}

class Expense {
  Expense({
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
  });

  final String title;
  final double amount;
  final String category;
  final DateTime date;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      date: DateTime.parse(json['date'] as String),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Expense> _expenses = [];
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  static const String _storageKey = 'saved_expenses';

  final List<String> _categories = [
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Other',
  ];

  late DateTime _selectedMonth;
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);

    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    try {
      final savedData = await _preferences.getString(_storageKey);

      if (savedData != null) {
        final decodedData = jsonDecode(savedData) as List<dynamic>;
        final loadedExpenses = decodedData.map((item) {
          return Expense.fromJson(
            Map<String, dynamic>.from(item as Map),
          );
        }).toList();

        if (!mounted) return;

        setState(() {
          _expenses
            ..clear()
            ..addAll(loadedExpenses);
          _isLoading = false;
        });
      } else {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load saved expenses.')),
      );
    }
  }

  Future<void> _saveExpenses() async {
    try {
      final encodedData = jsonEncode(
        _expenses.map((expense) => expense.toJson()).toList(),
      );

      await _preferences.setString(_storageKey, encodedData);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save expenses.')),
      );
    }
  }

  double _totalForDate(DateTime date) {
    return _expenses
        .where(
          (expense) =>
      expense.date.year == date.year &&
          expense.date.month == date.month &&
          expense.date.day == date.day,
    )
        .fold(0, (total, expense) => total + expense.amount);
  }

  double _totalForMonth(DateTime month) {
    return _expenses
        .where(
          (expense) =>
      expense.date.year == month.year &&
          expense.date.month == month.month,
    )
        .fold(0, (total, expense) => total + expense.amount);
  }

  List<Expense> _expensesForSelectedMonth() {
    final result = _expenses
        .where(
          (expense) =>
      expense.date.year == _selectedMonth.year &&
          expense.date.month == _selectedMonth.month,
    )
        .toList();

    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  String _monthName(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return names[month - 1];
  }

  String _shortMonthName(int month) {
    return _monthName(month).substring(0, 3);
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  bool get _canGoToNextMonth {
    final now = DateTime.now();

    return _selectedMonth.year < now.year ||
        (_selectedMonth.year == now.year &&
            _selectedMonth.month < now.month);
  }

  void _changeMonth(int amount) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + amount,
      );
    });
  }

  Future<void> _showExpenseDialog({
    Expense? expense,
    int? index,
  }) async {
    final formKey = GlobalKey<FormState>();

    String enteredTitle = '';
    double? enteredAmount;
    String selectedCategory = expense?.category ?? _categories.first;

    final now = DateTime.now();
    DateTime selectedDate = expense?.date ??
        (_selectedMonth.year == now.year &&
            _selectedMonth.month == now.month
            ? now
            : _selectedMonth);

    final savedExpense = await showDialog<Expense>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> chooseDate() async {
              final pickedDate = await showDatePicker(
                context: dialogContext,
                initialDate: selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(
                  const Duration(days: 3650),
                ),
              );

              if (pickedDate != null) {
                setDialogState(() {
                  selectedDate = pickedDate;
                });
              }
            }

            return AlertDialog(
              title: Text(
                expense == null ? 'Add an expense' : 'Edit expense',
              ),
              content: SizedBox(
                width: 350,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          initialValue: expense?.title ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText: 'For example, Lunch',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter a description';
                            }
                            return null;
                          },
                          onSaved: (value) {
                            enteredTitle = value!.trim();
                          },
                        ),
                        TextFormField(
                          initialValue: expense?.amount.toString() ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            prefixText: '₹ ',
                          ),
                          keyboardType:
                          const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) {
                            final amount = double.tryParse(value ?? '');
                            if (amount == null || amount <= 0) {
                              return 'Enter an amount greater than 0';
                            }
                            return null;
                          },
                          onSaved: (value) {
                            enteredAmount = double.parse(value!);
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items: _categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                selectedCategory = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.calendar_month),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_formatDate(selectedDate)),
                            ),
                            TextButton(
                              onPressed: chooseDate,
                              child: const Text('Choose date'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;

                    formKey.currentState!.save();

                    Navigator.pop(
                      dialogContext,
                      Expense(
                        title: enteredTitle,
                        amount: enteredAmount!,
                        category: selectedCategory,
                        date: selectedDate,
                      ),
                    );
                  },
                  child: Text(expense == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || savedExpense == null) return;

    setState(() {
      if (index == null) {
        _expenses.add(savedExpense);
      } else {
        _expenses[index] = savedExpense;
      }
    });

    await _saveExpenses();
  }

  Future<void> _confirmDelete(int index) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete expense?'),
          content: Text(
            'Remove "${_expenses[index].title}" from your list?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldDelete != true) return;

    setState(() {
      _expenses.removeAt(index);
    });

    await _saveExpenses();
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Food':
        return const Color(0xFF8B5CF6);
      case 'Transport':
        return const Color(0xFF48B8C4);
      case 'Shopping':
        return const Color(0xFFFFA552);
      case 'Bills':
        return const Color(0xFF83C98A);
      default:
        return const Color(0xFFEC74A8);
    }
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant;
      case 'Transport':
        return Icons.directions_bus;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Bills':
        return Icons.receipt;
      default:
        return Icons.category;
    }
  }

  Widget _monthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => _changeMonth(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            '${_monthName(_selectedMonth.month)} ${_selectedMonth.year}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          IconButton(
            onPressed: _canGoToNextMonth ? () => _changeMonth(1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF8652F6)),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '₹${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF22183A),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expenseTile(Expense expense) {
    final expenseIndex = _expenses.indexOf(expense);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 4,
        ),
        leading: CircleAvatar(
          backgroundColor: _categoryColor(expense.category).withValues(
            alpha: 0.15,
          ),
          child: Icon(
            _iconForCategory(expense.category),
            color: _categoryColor(expense.category),
          ),
        ),
        title: Text(
          expense.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${expense.category} • ${_formatDate(expense.date)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '₹${expense.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Color(0xFF261A3D),
                fontWeight: FontWeight.bold,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (choice) {
                if (choice == 'edit') {
                  _showExpenseDialog(
                    expense: expense,
                    index: expenseIndex,
                  );
                } else if (choice == 'delete') {
                  _confirmDelete(expenseIndex);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _homePage() {
    final expenses = _expensesForSelectedMonth();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _monthSelector(),
          const SizedBox(height: 16),
          Row(
            children: [
              _summaryCard(
                title: 'Today',
                amount: _totalForDate(DateTime.now()),
                icon: Icons.today,
                color: const Color(0xFFECE4FF),
              ),
              const SizedBox(width: 12),
              _summaryCard(
                title: 'This month',
                amount: _totalForMonth(_selectedMonth),
                icon: Icons.calendar_month,
                color: const Color(0xFFE5F4E8),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent transactions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedTab = 1),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (expenses.isEmpty)
            _emptyMessage('No expenses for this month yet.')
          else
            ...expenses.take(4).map(_expenseTile),
        ],
      ),
    );
  }

  Widget _transactionsPage() {
    final expenses = _expensesForSelectedMonth();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _monthSelector(),
          const SizedBox(height: 18),
          Text(
            '${_monthName(_selectedMonth.month)} transactions',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (expenses.isEmpty)
            _emptyMessage('No expenses for this month yet.')
          else
            ...expenses.map(_expenseTile),
        ],
      ),
    );
  }

  Widget _analyticsPage() {
    final months = List.generate(
      6,
          (index) => DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 5 + index,
      ),
    );

    final monthlyTotals = months.map(_totalForMonth).toList();
    final largestMonth = monthlyTotals.fold<double>(
      0,
          (largest, value) => value > largest ? value : largest,
    );

    final double chartMaxY = largestMonth == 0
        ? 100.0
        : largestMonth * 1.25;

    final categoryTotals = <String, double>{
      for (final category in _categories)
        category: _expenses
            .where(
              (expense) =>
          expense.category == category &&
              expense.date.year == _selectedMonth.year &&
              expense.date.month == _selectedMonth.month,
        )
            .fold(0, (sum, expense) => sum + expense.amount),
    };

    final categoriesWithSpending = categoryTotals.entries
        .where((entry) => entry.value > 0)
        .toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analytics',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          _monthSelector(),
          const SizedBox(height: 18),
          _chartCard(
            title: 'Monthly spending',
            subtitle: 'Your last six months',
            child: SizedBox(
              height: 230,
              child: BarChart(
                BarChartData(
                  barTouchData: BarTouchData(enabled: false),
                  maxY: chartMaxY,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: chartMaxY / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: const Color(0xFFECE8F2),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '₹${value.toInt()}',
                            style: const TextStyle(
                              color: Color(0xFF8C8497),
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= months.length) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _shortMonthName(months[index].month),
                              style: const TextStyle(
                                color: Color(0xFF8C8497),
                                fontSize: 11,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(months.length, (index) {
                    final isSelectedMonth = index == months.length - 1;

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: monthlyTotals[index],
                          width: 18,
                          color: isSelectedMonth
                              ? const Color(0xFF8652F6)
                              : const Color(0xFFB79AF8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _chartCard(
            title: 'Spending by category',
            subtitle: '${_monthName(_selectedMonth.month)} breakdown',
            child: categoriesWithSpending.isEmpty
                ? SizedBox(
              height: 180,
              child: Center(
                child: Text(
                  'No expenses for this month yet.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
                : Column(
              children: [
                SizedBox(
                  height: 210,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(enabled: false),
                          centerSpaceRadius: 55,
                          sectionsSpace: 4,
                          sections: categoriesWithSpending.map((entry) {
                            return PieChartSectionData(
                              value: entry.value,
                              color: _categoryColor(entry.key),
                              radius: 24,
                              showTitle: false,
                            );
                          }).toList(),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              color: Color(0xFF8C8497),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '₹${_totalForMonth(_selectedMonth).toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Color(0xFF261A3D),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ...categoriesWithSpending.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: _categoryColor(entry.key),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(entry.key)),
                        Text(
                          '₹${entry.value.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsPage() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Settings',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 18),
        _chartCard(
          title: 'Expense categories',
          subtitle: 'Used when adding an expense',
          child: Column(
            children: _categories.map((category) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: _categoryColor(category).withValues(
                    alpha: 0.15,
                  ),
                  child: Icon(
                    _iconForCategory(category),
                    color: _categoryColor(category),
                  ),
                ),
                title: Text(category),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        _chartCard(
          title: 'Your data',
          subtitle: 'Expenses are saved automatically on this device.',
          child: const Row(
            children: [
              Icon(Icons.lock_outline, color: Color(0xFF8652F6)),
              SizedBox(width: 10),
              Expanded(
                child: Text('Your expense list stays on this device.'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chartCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF261A3D),
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF8C8497),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _emptyMessage(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long,
            size: 46,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _navigationItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedTab == index;
    final color = isSelected
        ? const Color(0xFF8652F6)
        : const Color(0xFF938C9D);

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: SizedBox(
          height: 62,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _homePage(),
      _transactionsPage(),
      _analyticsPage(),
      _settingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Expense Tracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFF5F2FA),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
        index: _selectedTab,
        children: pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : () => _showExpenseDialog(),
        backgroundColor: const Color(0xFF8652F6),
        foregroundColor: Colors.white,
        tooltip: 'Add expense',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          children: [
            _navigationItem(
              index: 0,
              icon: Icons.home_outlined,
              label: 'Home',
            ),
            _navigationItem(
              index: 1,
              icon: Icons.receipt_long_outlined,
              label: 'Transactions',
            ),
            const SizedBox(width: 48),
            _navigationItem(
              index: 2,
              icon: Icons.bar_chart_rounded,
              label: 'Analytics',
            ),
            _navigationItem(
              index: 3,
              icon: Icons.settings_outlined,
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}