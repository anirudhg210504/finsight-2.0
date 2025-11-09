// lib/screens/reports_tab.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finsight/models/transaction_model.dart';
import 'package:finsight/services/auth_service.dart';

enum ReportPeriod { weekly, monthly, yearly }
enum ReportType { byTime, byCategory }
enum ChartType { bar, line, pie }

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});
  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  final _authService = AuthService();
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;

  ReportPeriod _period = ReportPeriod.monthly;
  ReportType _reportType = ReportType.byTime;
  ChartType _chartType = ChartType.bar;

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
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not logged in');

      final data = await Supabase.instance.client
          .from('transactions')
          .select()
          .eq('user_id', user.id)
          .order('transaction_date', ascending: true);

      _transactions = (data as List)
          .map((m) => TransactionModel.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Load failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _generateReportData();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: const Color(0xFF006241),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
          ? const Center(child: Text('No transactions found'))
          : RefreshIndicator(
        onRefresh: _loadTransactions,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: 16),
            _buildReportTypeSelector(),
            const SizedBox(height: 16),
            Text(
              report.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _summaryTile('Spent', report.totalDebit, Colors.red),
                const SizedBox(width: 24),
                _summaryTile('Income', report.totalCredit, Colors.green),
              ],
            ),
            const SizedBox(height: 16),
            _buildChartTypeSelector(),
            const SizedBox(height: 16),
            SizedBox(
              height: _chartType == ChartType.pie
                  ? MediaQuery.of(context).size.width * 1.1
                  : MediaQuery.of(context).size.width * 0.7,
              child: _buildChart(report),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Center(
      child: ToggleButtons(
        borderRadius: BorderRadius.circular(8),
        fillColor: const Color(0xFF006241),
        selectedColor: Colors.white,
        color: const Color(0xFF006241),
        isSelected: [
          _period == ReportPeriod.weekly,
          _period == ReportPeriod.monthly,
          _period == ReportPeriod.yearly
        ],
        onPressed: (i) => setState(() {
          _period = ReportPeriod.values[i];
          _reportType = ReportType.byTime;
          _chartType = ChartType.bar;
        }),
        children: const [
          Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Weekly')),
          Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Monthly')),
          Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Yearly')),
        ],
      ),
    );
  }

  Widget _buildReportTypeSelector() {
    return Center(
      child: ToggleButtons(
        borderRadius: BorderRadius.circular(8),
        isSelected: [
          _reportType == ReportType.byTime,
          _reportType == ReportType.byCategory,
        ],
        onPressed: (i) => setState(() {
          _reportType = ReportType.values[i];
          _chartType = (_reportType == ReportType.byCategory) ? ChartType.pie : ChartType.bar;
        }),
        children: const [
          Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('By Time')),
          Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('By Category')),
        ],
      ),
    );
  }

  Widget _buildChartTypeSelector() {
    bool isByCategory = _reportType == ReportType.byCategory;

    if (isByCategory && _chartType == ChartType.line) {
      _chartType = ChartType.pie;
    }
    if (!isByCategory && _chartType == ChartType.pie) {
      _chartType = ChartType.bar;
    }

    return Center(
      child: ToggleButtons(
        borderRadius: BorderRadius.circular(8),
        isSelected: [
          _chartType == ChartType.bar,
          isByCategory
              ? _chartType == ChartType.pie
              : _chartType == ChartType.line,
        ],
        onPressed: (i) => setState(() {
          if (isByCategory) {
            _chartType = (i == 0) ? ChartType.bar : ChartType.pie;
          } else {
            _chartType = (i == 0) ? ChartType.bar : ChartType.line;
          }
        }),
        children: [
          const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.bar_chart)),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(isByCategory ? Icons.pie_chart : Icons.show_chart),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          _formatCurrency(value),
          style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildChart(ReportData report) {
    switch (_chartType) {
      case ChartType.line:
        return _buildLineChart(report);
      case ChartType.pie:
        return _buildPieChart(report);
      case ChartType.bar:
      default:
        return _buildBarChart(report);
    }
  }

  Widget _buildBarChart(ReportData report) {
    if (report.data.isEmpty) return const SizedBox();
    final maxDebit = report.data.map((p) => p.debit).reduce(max);
    final maxCredit = report.data.map((p) => p.credit).reduce(max);
    final maxY = max(100.0, max(maxDebit, maxCredit) * 1.2);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        minY: 0,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 6,
            tooltipPadding: const EdgeInsets.all(8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final data = report.data[group.x.toInt()];
              final amount = rod.toY;
              final isDebit = rodIndex == 0;
              final label = data.label;
              final typeText = isDebit ? "spent" : "received";
              final color = isDebit ? Colors.redAccent : Colors.greenAccent;
              return BarTooltipItem(
                "₹${amount.toStringAsFixed(2)} $typeText on $label",
                TextStyle(color: color, fontSize: 12),
              );
            },
          ),
        ),
        barGroups: List.generate(report.data.length, (i) {
          final p = report.data[i];
          return BarChartGroupData(
            x: i,
            barsSpace: 6,
            barRods: [
              BarChartRodData(
                toY: p.debit,
                width: 8,
                color: debitColor,
              ),
              BarChartRodData(
                toY: p.credit,
                width: 8,
                color: creditColor,
              ),
            ],
          );
        }),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.grey[300], strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: _titles(report),
      ),
    );
  }

  Widget _buildLineChart(ReportData report) {
    if (report.data.isEmpty) return const SizedBox();
    final maxY = max(100.0, report.data.map((p) => max(p.debit, p.credit)).reduce(max) * 1.2);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        clipData: FlClipData.all(),
        gridData: FlGridData(
          show: true,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.grey[300], strokeWidth: 1),
        ),
        titlesData: _titles(report),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: Colors.red,
            barWidth: 3,
            spots: [
              for (int i = 0; i < report.data.length; i++)
                FlSpot(i.toDouble(), report.data[i].debit)
            ],
            belowBarData: BarAreaData(show: true, color: Colors.red.withOpacity(0.15)),
          ),
          LineChartBarData(
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            spots: [
              for (int i = 0; i < report.data.length; i++)
                FlSpot(i.toDouble(), report.data[i].credit)
            ],
            belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.15)),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(ReportData report) {
    if (report.data.isEmpty) {
      return const Center(child: Text("No data for pie chart."));
    }

    // Create sections for both debit and credit in the same chart
    final List<PieChartSectionData> sections = [];
    final List<_PieLegendItem> legendItems = [];
    int colorIndex = 0;

    // Add debit sections
    for (var dataPoint in report.data) {
      if (dataPoint.debit > 0) {
        final totalAmount = report.totalDebit + report.totalCredit;
        final percentage = (dataPoint.debit / totalAmount) * 100;

        sections.add(
          PieChartSectionData(
            color: Colors.primaries[colorIndex % Colors.primaries.length],
            value: dataPoint.debit,
            title: '${percentage.toStringAsFixed(0)}%',
            showTitle: percentage > 5, // Only show if slice is > 5%
            radius: 100,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black, blurRadius: 2)],
            ),
          ),
        );

        legendItems.add(_PieLegendItem(
          label: '${dataPoint.label} (Spent)',
          color: Colors.primaries[colorIndex % Colors.primaries.length],
        ));

        colorIndex++;
      }
    }

    // Add credit sections
    for (var dataPoint in report.data) {
      if (dataPoint.credit > 0) {
        final totalAmount = report.totalDebit + report.totalCredit;
        final percentage = (dataPoint.credit / totalAmount) * 100;

        sections.add(
          PieChartSectionData(
            color: Colors.accents[colorIndex % Colors.accents.length],
            value: dataPoint.credit,
            title: '${percentage.toStringAsFixed(0)}%',
            showTitle: percentage > 5, // Only show if slice is > 5%
            radius: 100,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black, blurRadius: 2)],
            ),
          ),
        );

        legendItems.add(_PieLegendItem(
          label: '${dataPoint.label} (Income)',
          color: Colors.accents[colorIndex % Colors.accents.length],
        ));

        colorIndex++;
      }
    }

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildCombinedLegend(legendItems),
      ],
    );
  }

  Widget _buildCombinedLegend(List<_PieLegendItem> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Wrap(
        spacing: 12.0,
        runSpacing: 8.0,
        alignment: WrapAlignment.center,
        children: items.map((item) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 12, height: 12, color: item.color),
              const SizedBox(width: 4),
              Text(item.label, style: const TextStyle(fontSize: 11)),
            ],
          );
        }).toList(),
      ),
    );
  }

  FlTitlesData _titles(ReportData report) {
    final n = report.data.length;

    double interval = 1.0;
    bool rotate = false;

    if (_period == ReportPeriod.monthly && _reportType == ReportType.byTime) {
      interval = max(1, (n / 8).ceil()).toDouble();
    }
    if (_reportType == ReportType.byCategory && n > 6) {
      rotate = true;
    }

    return FlTitlesData(
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            getTitlesWidget: (v, _) {
              if (v <= 0) return const SizedBox();
              return Text(_formatIndianUnits(v),
                  style: const TextStyle(fontSize: 10));
            }),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: rotate ? 45 : 30,
          interval: interval,
          getTitlesWidget: (v, meta) {
            final idx = v.toInt();
            if (idx < 0 || idx >= report.data.length) return const SizedBox();
            if (idx % interval.toInt() != 0) return const SizedBox();

            String label = report.data[idx].label;
            if (rotate && label.length > 8) {
              label = '${label.substring(0, 7)}...';
            }

            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 4,
              angle: rotate ? 1.05 : 0,
              child: Text(
                label,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    final f = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return f.format(value);
  }

  String _formatIndianUnits(double v) {
    if (v < 1000) return "₹${v.toStringAsFixed(0)}";
    if (v >= 10000000) return "₹${(v / 10000000).toStringAsFixed(1)}Cr";
    if (v >= 100000) return "₹${(v / 100000).toStringAsFixed(1)}L";
    if (v >= 1000) return "₹${(v / 1000).toStringAsFixed(1)}K";
    return "₹${v.toStringAsFixed(0)}";
  }

  ReportData _generateReportData() {
    final now = DateUtils.dateOnly(DateTime.now());
    if (_transactions.isEmpty) return ReportData([], 'No data', 0, 0);

    DateTime start, end;
    String title;
    switch (_period) {
      case ReportPeriod.weekly:
        start = now.subtract(Duration(days: now.weekday - 1));
        end = start.add(const Duration(days: 6));
        title = 'This Week';
        break;
      case ReportPeriod.monthly:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0);
        title = 'This Month';
        break;
      case ReportPeriod.yearly:
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31);
        title = 'This Year';
        break;
    }

    final txs = _transactions.where((t) {
      final d = DateUtils.dateOnly(t.transactionDate);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();

    if (_reportType == ReportType.byTime) {
      if (_period == ReportPeriod.weekly) {
        return _generateWeeklyByTime(txs, title);
      } else if (_period == ReportPeriod.monthly) {
        return _generateMonthlyByTime(txs, title, end.day);
      } else {
        return _generateYearlyByTime(txs, title);
      }
    } else {
      return _generateDataByCategory(txs, title);
    }
  }

  ReportData _generateWeeklyByTime(List<TransactionModel> txs, String title) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final debit = List.filled(7, 0.0);
    final credit = List.filled(7, 0.0);
    double totalDebit = 0, totalCredit = 0;
    for (var t in txs) {
      final i = t.transactionDate.weekday - 1;
      if (t.type == TransactionType.debit) {
        debit[i] += t.amount;
        totalDebit += t.amount;
      } else {
        credit[i] += t.amount;
        totalCredit += t.amount;
      }
    }
    final points = List.generate(7, (i) => DataPoint(days[i], debit[i], credit[i]));
    return ReportData(points, title, totalDebit, totalCredit);
  }

  ReportData _generateMonthlyByTime(List<TransactionModel> txs, String title, int daysInMonth) {
    final debit = List.filled(daysInMonth, 0.0);
    final credit = List.filled(daysInMonth, 0.0);
    double totalDebit = 0, totalCredit = 0;
    for (var t in txs) {
      final d = t.transactionDate.day - 1;
      if (t.type == TransactionType.debit) {
        debit[d] += t.amount;
        totalDebit += t.amount;
      } else {
        credit[d] += t.amount;
        totalCredit += t.amount;
      }
    }
    final points = List.generate(daysInMonth, (i) => DataPoint('${i + 1}', debit[i], credit[i]));
    return ReportData(points, '$title (by Day)', totalDebit, totalCredit);
  }

  ReportData _generateYearlyByTime(List<TransactionModel> txs, String title) {
    final months = DateFormat.MMM().dateSymbols.SHORTMONTHS;
    final debit = List.filled(12, 0.0);
    final credit = List.filled(12, 0.0);
    double totalDebit = 0, totalCredit = 0;
    for (var t in txs) {
      final m = t.transactionDate.month - 1;
      if (t.type == TransactionType.debit) {
        debit[m] += t.amount;
        totalDebit += t.amount;
      } else {
        credit[m] += t.amount;
        totalCredit += t.amount;
      }
    }
    final points = List.generate(12, (i) => DataPoint(months[i], debit[i], credit[i]));
    return ReportData(points, title, totalDebit, totalCredit);
  }

  ReportData _generateDataByCategory(List<TransactionModel> txs, String title) {
    final debitCat = <String, double>{};
    final creditCat = <String, double>{};
    double totalDebit = 0, totalCredit = 0;

    for (final tx in txs) {
      final cat = tx.category ?? 'Other';
      if (tx.type == TransactionType.debit) {
        debitCat[cat] = (debitCat[cat] ?? 0) + tx.amount;
        totalDebit += tx.amount;
      } else {
        creditCat[cat] = (creditCat[cat] ?? 0) + tx.amount;
        totalCredit += tx.amount;
      }
    }

    final allCats = {...debitCat.keys, ...creditCat.keys}.toList()..sort();
    final points = allCats
        .map((c) => DataPoint(c, debitCat[c] ?? 0, creditCat[c] ?? 0))
        .toList();

    return ReportData(
      points,
      '$title (by Category)',
      totalDebit,
      totalCredit,
    );
  }
}

class DataPoint {
  final String label;
  final double debit;
  final double credit;
  DataPoint(this.label, this.debit, this.credit);
}

class ReportData {
  final List<DataPoint> data;
  final String title;
  final double totalDebit;
  final double totalCredit;
  ReportData(this.data, this.title, this.totalDebit, this.totalCredit);
}

class _PieLegendItem {
  final String label;
  final Color color;
  _PieLegendItem({required this.label, required this.color});
}