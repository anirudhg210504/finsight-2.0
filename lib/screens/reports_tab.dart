import 'package:flutter/material.dart';
import 'package:finsight/models/transaction_model.dart';
import 'package:finsight/services/auth_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

// Enums to manage UI state
enum ReportPeriod { weekly, monthly, yearly }
enum ChartType { bar, line, pie }

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  ReportPeriod _selectedPeriod = ReportPeriod.monthly;
  ChartType _selectedChartType = ChartType.bar;
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  final _authService = AuthService();

  // Colors
  static const Color debitColor = Colors.red;
  static const Color creditColor = Colors.green;
  static const Color primaryChartColor = Color(0xFF006241);

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    if (!_isLoading) setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception("User not logged in");

      final response = await Supabase.instance.client
          .from('transactions')
          .select()
          .eq('user_id', user.id)
          .order('transaction_date', ascending: false);

      final transactions = (response as List)
          .map((map) => TransactionModel.fromJson(map))
          .toList();

      if (mounted) {
        setState(() {
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error loading reports: ${e.toString()}"))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Reports"),
        backgroundColor: const Color(0xFF006241),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildReportBody(),
      ),
    );
  }

  Widget _buildReportBody() {
    final chartData = _generateChartData();

    if (chartData.dataPoints.isEmpty || (chartData.total1 == 0 && chartData.total2 == 0)) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildPeriodToggleButtons(),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  "No data for this period.",
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPeriodToggleButtons(),
          const SizedBox(height: 24),

          Text(
            chartData.title,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),

          if (_selectedPeriod == ReportPeriod.monthly)
            Text(
              NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(chartData.total1),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: debitColor),
              textAlign: TextAlign.center,
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSummaryText("Spent", chartData.total1, debitColor),
                const SizedBox(width: 24),
                _buildSummaryText("Income", chartData.total2, creditColor),
              ],
            ),

          const SizedBox(height: 24),
          _buildChartTypeToggles(), // This is the fixed widget
          const SizedBox(height: 24),

          AspectRatio(
            aspectRatio: 1.5,
            child: _buildChart(chartData), // This switch is now safe
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryText(String title, double total, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        Text(
          NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(total),
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildPeriodToggleButtons() {
    return Center(
      child: ToggleButtons(
        isSelected: [
          _selectedPeriod == ReportPeriod.weekly,
          _selectedPeriod == ReportPeriod.monthly,
          _selectedPeriod == ReportPeriod.yearly,
        ],
        onPressed: (index) {
          setState(() {
            _selectedPeriod = ReportPeriod.values[index];
            _selectedChartType = ChartType.bar;
          });
        },
        borderRadius: BorderRadius.circular(8),
        selectedColor: Colors.white,
        fillColor: primaryChartColor,
        color: primaryChartColor,
        children: const [
          Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Weekly')),
          Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Monthly')),
          Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Yearly')),
        ],
      ),
    );
  }

  // --- THIS IS THE FIXED TOGGLE BUTTON LOGIC ---
  Widget _buildChartTypeToggles() {
    bool isCategorical = _selectedPeriod == ReportPeriod.monthly;
    bool isTimeSeries = !isCategorical;

    // Auto-switch logic if the current chart is not allowed
    if (isTimeSeries && _selectedChartType == ChartType.pie) {
      _selectedChartType = ChartType.bar;
    }
    if (isCategorical && _selectedChartType == ChartType.line) {
      _selectedChartType = ChartType.bar;
    }

    // Build the lists dynamically based on context
    List<Widget> children = [
      const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Icon(Icons.bar_chart)),
    ];
    List<bool> isSelected = [
      _selectedChartType == ChartType.bar,
    ];

    if (isTimeSeries) {
      children.add(const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Icon(Icons.show_chart)));
      isSelected.add(_selectedChartType == ChartType.line);
    }

    if (isCategorical) {
      children.add(const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Icon(Icons.pie_chart)));
      isSelected.add(_selectedChartType == ChartType.pie);
    }

    return Center(
      child: ToggleButtons(
        isSelected: isSelected,
        onPressed: (index) {
          setState(() {
            if (isTimeSeries) {
              // Buttons are [Bar, Line]
              _selectedChartType = (index == 0) ? ChartType.bar : ChartType.line;
            } else { // isCategorical
              // Buttons are [Bar, Pie]
              _selectedChartType = (index == 0) ? ChartType.bar : ChartType.pie;
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        children: children,
      ),
    );
  }
  // --- END OF FIX ---

  Widget _buildChart(ReportChartData data) {
    // This logic is now safe because _buildChartTypeToggles fixes the state first
    switch (_selectedChartType) {
      case ChartType.line:
        return _buildLineChart(data);
      case ChartType.pie:
        return _buildPieChart(data);
      case ChartType.bar:
      default:
        return _buildBarChart(data);
    }
  }

  Widget _buildBarChart(ReportChartData data) {
    final bool isMonthly = _selectedPeriod == ReportPeriod.monthly;
    final double maxY = (data.dataPoints.map((p) => p.value1 + p.value2).reduce(max) * 1.2).clamp(100.0, double.infinity);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final point = data.dataPoints[group.x];
              String text = '${point.label}\n';
              if (isMonthly) {
                text += NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(point.value1);
              } else {
                text += 'Spent: ${NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(point.value1)}\n';
                text += 'Income: ${NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(point.value2)}';
              }
              return BarTooltipItem(text, const TextStyle(color: Colors.white));
            },
          ),
        ),
        titlesData: _buildChartTitles(data),
        borderData: FlBorderData(show: false),
        gridData: _buildGridData(maxY),
        barGroups: List.generate(data.dataPoints.length, (i) {
          final point = data.dataPoints[i];
          return BarChartGroupData(
            x: i,
            barRods: isMonthly
                ? [
              BarChartRodData(
                toY: point.value1,
                color: Colors.primaries[i % Colors.primaries.length],
                width: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ]
                : [
              BarChartRodData(
                  toY: point.value1 + point.value2,
                  color: creditColor,
                  width: 16,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                  rodStackItems: [
                    BarChartRodStackItem(0, point.value1, debitColor),
                  ]
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildLineChart(ReportChartData data) {
    final double maxY = (data.dataPoints.map((p) => max(p.value1, p.value2)).reduce(max) * 1.2).clamp(100.0, double.infinity);

    final debitSpots = List.generate(data.dataPoints.length, (i) {
      return FlSpot(i.toDouble(), data.dataPoints[i].value1);
    });
    final creditSpots = List.generate(data.dataPoints.length, (i) {
      return FlSpot(i.toDouble(), data.dataPoints[i].value2);
    });

    return LineChart(
      LineChartData(
        maxY: maxY,
        minY: 0,
        gridData: _buildGridData(maxY),
        borderData: FlBorderData(show: false),
        titlesData: _buildChartTitles(data),
        lineBarsData: [
          _buildLineBarData(debitSpots, debitColor),
          _buildLineBarData(creditSpots, creditColor),
        ],
      ),
    );
  }

  LineChartBarData _buildLineBarData(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 4,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withOpacity(0.2),
      ),
    );
  }

  Widget _buildPieChart(ReportChartData data) {
    // Pie chart is always for monthly (debit only)
    return PieChart(
      PieChartData(
        sections: List.generate(data.dataPoints.length, (i) {
          final point = data.dataPoints[i];
          final percentage = (point.value1 / data.total1) * 100;
          return PieChartSectionData(
            color: Colors.primaries[i % Colors.primaries.length],
            value: point.value1,
            title: '${percentage.toStringAsFixed(0)}%',
            radius: 100,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black, blurRadius: 2)],
            ),
          );
        }),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }

  FlTitlesData _buildChartTitles(ReportChartData data) {
    return FlTitlesData(
      show: true,
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) {
            if (value == 0 || value == meta.max) return const Text('');
            return Text(
              NumberFormat.compactSimpleCurrency(locale: 'en_IN').format(value),
              style: const TextStyle(fontSize: 10),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 38,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index >= data.dataPoints.length) return const Text('');
            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 4.0,
              child: Text(
                data.dataPoints[index].label,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
      ),
    );
  }

  FlGridData _buildGridData(double maxY) {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: (maxY / 4).clamp(1.0, double.infinity),
      getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[300], strokeWidth: 1),
    );
  }

  ReportChartData _generateChartData() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case ReportPeriod.weekly:
        return _getWeeklyData(now);
      case ReportPeriod.monthly:
        return _getMonthlyData(now);
      case ReportPeriod.yearly:
        return _getYearlyData(now);
    }
  }

  ReportChartData _getWeeklyData(DateTime now) {
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59));

    final thisWeekTxs = _transactions.where((tx) {
      return tx.transactionDate.isAfter(DateUtils.dateOnly(startOfWeek)) &&
          tx.transactionDate.isBefore(endOfWeek);
    }).toList();

    final dailyDebits = List.filled(7, 0.0);
    final dailyCredits = List.filled(7, 0.0);
    double totalDebit = 0;
    double totalCredit = 0;

    for (var tx in thisWeekTxs) {
      if (tx.type == TransactionType.debit) {
        dailyDebits[tx.transactionDate.weekday - 1] += tx.amount;
        totalDebit += tx.amount;
      } else {
        dailyCredits[tx.transactionDate.weekday - 1] += tx.amount;
        totalCredit += tx.amount;
      }
    }

    final titles = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dataPoints = List.generate(7, (i) {
      return ChartDataPoint(titles[i], dailyDebits[i], dailyCredits[i]);
    });

    return ReportChartData(
      title: 'This Week',
      total1: totalDebit,
      total2: totalCredit,
      dataPoints: dataPoints,
    );
  }

  ReportChartData _getMonthlyData(DateTime now) {
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59);

    final thisMonthDebits = _transactions.where((tx) {
      return tx.type == TransactionType.debit &&
          tx.transactionDate.isAfter(startOfMonth) &&
          tx.transactionDate.isBefore(endOfMonth);
    }).toList();

    final categoryTotals = <String, double>{};
    double totalDebit = 0;
    for (var tx in thisMonthDebits) {
      final category = tx.category ?? 'Other';
      categoryTotals[category] = (categoryTotals[category] ?? 0) + tx.amount;
      totalDebit += tx.amount;
    }

    final sortedEntries = categoryTotals.entries.toList();
    sortedEntries.sort((a, b) => b.value.compareTo(a.value));

    final dataPoints = sortedEntries.map((e) {
      return ChartDataPoint(e.key, e.value, 0);
    }).toList();

    return ReportChartData(
      title: 'This Month\'s Spending',
      total1: totalDebit,
      total2: 0,
      dataPoints: dataPoints,
    );
  }

  ReportChartData _getYearlyData(DateTime now) {
    final startOfYear = DateTime(now.year, 1, 1);
    final endOfYear = DateTime(now.year, 12, 31, 23, 59);

    final thisYearTxs = _transactions.where((tx) {
      return tx.transactionDate.isAfter(startOfYear) &&
          tx.transactionDate.isBefore(endOfYear);
    }).toList();

    final monthlyDebits = List.filled(12, 0.0);
    final monthlyCredits = List.filled(12, 0.0);
    double totalDebit = 0;
    double totalCredit = 0;

    for (var tx in thisYearTxs) {
      if (tx.type == TransactionType.debit) {
        monthlyDebits[tx.transactionDate.month - 1] += tx.amount;
        totalDebit += tx.amount;
      } else {
        monthlyCredits[tx.transactionDate.month - 1] += tx.amount;
        totalCredit += tx.amount;
      }
    }

    final titles = DateFormat.E().dateSymbols.SHORTMONTHS;
    final dataPoints = List.generate(12, (i) {
      return ChartDataPoint(titles[i], monthlyDebits[i], monthlyCredits[i]);
    });

    return ReportChartData(
      title: 'This Year',
      total1: totalDebit,
      total2: totalCredit,
      dataPoints: dataPoints,
    );
  }
}

// Helper class to hold processed chart data
// value1 is Debit, value2 is Credit
class ChartDataPoint {
  final String label;
  final double value1;
  final double value2;
  ChartDataPoint(this.label, this.value1, [this.value2 = 0]);
}

// Helper class to hold the processed chart data
// total1 is Debit, total2 is Credit
class ReportChartData {
  final String title;
  final double total1;
  final double total2;
  final List<ChartDataPoint> dataPoints;

  ReportChartData({
    required this.title,
    required this.total1,
    required this.total2,
    required this.dataPoints,
  });
}