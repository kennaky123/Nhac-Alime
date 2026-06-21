import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/firebase_service.dart';

class AdminSalesStatsScreen extends StatelessWidget {
  const AdminSalesStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Sales Performance', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales Trend (Successful Conversions)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildSalesChart(colorScheme),
            const SizedBox(height: 32),
            _buildSummaryCards(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart(ColorScheme colorScheme) {
    return FutureBuilder<Map<String, int>>(
      future: FirebaseService.instance.getPremiumSalesData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data!;
        if (data.isEmpty) {
          return Container(
            height: 300,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('No sales data yet.'),
          );
        }

        final List<String> keys = data.keys.toList();
        final List<BarChartGroupData> barGroups = [];
        
        for (int i = 0; i < keys.length; i++) {
          barGroups.add(
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[keys[i]]!.toDouble(),
                  color: colorScheme.primary,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
          );
        }

        return Container(
          height: 350,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(24),
          ),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (data.values.isEmpty ? 0 : data.values.reduce((a, b) => a > b ? a : b) + 2).toDouble(),
              barGroups: barGroups,
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < keys.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(keys[value.toInt()], style: const TextStyle(fontSize: 10)),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCards(ColorScheme colorScheme) {
    return FutureBuilder<Map<String, int>>(
      future: FirebaseService.instance.getPremiumSalesData(),
      builder: (context, snapshot) {
        int totalSales = 0;
        if (snapshot.hasData) {
          totalSales = snapshot.data!.values.fold(0, (sum, val) => sum + val);
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [colorScheme.primary, colorScheme.secondary]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const Icon(Icons.trending_up, color: Colors.white, size: 40),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Conversions', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  Text(
                    '$totalSales Premium Users',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
