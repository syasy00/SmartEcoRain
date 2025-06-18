import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

class TankLevelDetailScreen extends StatelessWidget {
  final List<dynamic> sensorHistory;
  TankLevelDetailScreen({required this.sensorHistory});

  // --- Rain Gain Calculation ---
  double calculateRainGainPercent(List<dynamic> history) {
    double totalRainGain = 0.0;
    double? rainStartLevel;
    bool raining = false;

    // Loop from oldest to newest
    for (final record in history.reversed) {
      final isRaining = record['rain_collected'] == true;
      final pumpOff = record['relay_status'] == 'OFF';
      final tankLevel = (record['tank_level'] as num?)?.toDouble() ?? 0.0;

      // Debug print

      if (isRaining && pumpOff) {
        if (!raining) {
          rainStartLevel = tankLevel;
          raining = true;
        }
      } else {
        if (raining && rainStartLevel != null) {
          double rainEndLevel = tankLevel;
          double gain = rainEndLevel - rainStartLevel;
          // Debug print
          if (gain > 0) totalRainGain += gain;
          rainStartLevel = null;
          raining = false;
        }
      }
    }

    // Handle if history ends during a rain event
    if (raining && rainStartLevel != null) {
      double rainEndLevel =
          (history.first['tank_level'] as num?)?.toDouble() ?? 0.0;
      double gain = rainEndLevel - rainStartLevel;
      if (gain > 0) totalRainGain += gain;
    }

    return totalRainGain;
  }

  @override
  Widget build(BuildContext context) {
    double currentLevel = sensorHistory.isNotEmpty
        ? (sensorHistory.first['tank_level'] as num?)?.toDouble() ?? 0
        : 0;
    int pumpActivations =
        sensorHistory.where((r) => r['relay_status'] == 'ON').length;

    double usageDrop = 0;
    if (sensorHistory.length > 1) {
      double first =
          (sensorHistory.first['tank_level'] as num?)?.toDouble() ?? 0;
      double last = (sensorHistory.last['tank_level'] as num?)?.toDouble() ?? 0;
      usageDrop = ((first - last) / (first == 0 ? 1 : first)) * 100;
    }

    // Calculate Rain Gain
    double rainGain = calculateRainGainPercent(sensorHistory);

    String suggestion = currentLevel < 30
        ? "Tank is low. Pump will refill soon."
        : currentLevel > 90
            ? "Tank is almost full. No need to refill."
            : "Tank level is optimal.";

    List<double> chartData = sensorHistory
        .take(7)
        .map<double>((r) => (r['tank_level'] as num?)?.toDouble() ?? 0)
        .toList()
        .reversed
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFE8F8F6), // Soft mint background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF183153)), // deep blue
        title: Text(
          'Tank Level Details',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            color: Color(0xFF183153),
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color.fromARGB(255, 232, 245, 248), Color.fromARGB(255, 248, 252, 254)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 30),
          children: [
            // Dashboard-like header with gradient (optional)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFCCF1F8), Color(0xFFEAF7F7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(255, 2, 175, 255).withOpacity(0.09),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chart
                    SizedBox(
                      height: 190,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LineChart(
                          LineChartData(
                            minY: 0,
                            maxY: 100,
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 32,
                                  getTitlesWidget: (v, meta) => Text(
                                    "${v.toInt()}",
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color.fromARGB(255, 79, 146, 163),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  interval: 20,
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 28,
                                  getTitlesWidget: (v, meta) => Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      "${v.toInt() + 1}",
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color.fromARGB(255, 79, 146, 163)),
                                    ),
                                  ),
                                ),
                              ),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(
                              show: true,
                              horizontalInterval: 20,
                              verticalInterval: 1,
                              getDrawingHorizontalLine: (v) => FlLine(
                                color: Colors.teal.shade100,
                                strokeWidth: 1,
                              ),
                              getDrawingVerticalLine: (v) => FlLine(
                                color: Colors.teal.shade50,
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(
                                  color: Colors.teal.shade50, width: 2),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: chartData
                                    .asMap()
                                    .entries
                                    .map((e) =>
                                        FlSpot(e.key.toDouble(), e.value))
                                    .toList(),
                                isCurved: true,
                                color: const Color.fromARGB(255, 20, 155, 179), // Modern vibrant teal
                                dotData: FlDotData(
                                    show: true, 
                                    getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: 4.0)),
                                belowBarData: BarAreaData(
                                    show: true,
                                    color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.11)),
                                barWidth: 4,
                                isStrokeCapRound: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            icon: Icons.water_drop_rounded,
                            label: "Current Tank Level",
                            value: "${currentLevel.toStringAsFixed(1)}%",
                            valueColor: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                            icon: Icons.refresh_rounded,
                            label: "Pump Activations",
                            value: "$pumpActivations times",
                            valueColor: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            icon: Icons.trending_down_rounded,
                            label: "Estimated Usage",
                            value:
                                "${usageDrop.abs().toStringAsFixed(1)}% drop",
                            valueColor: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                            icon: Icons.cloud_download_rounded,
                            label: "Rain Gain",
                            value: "+${rainGain.toStringAsFixed(1)}%",
                            valueColor: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
           
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: _suggestionBox(suggestion),
            ),
            const SizedBox(height: 25),
            // Recent Tank Levels 
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Text("Recent Tank Levels",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  )),
            ),
            const SizedBox(height: 10),
            ...sensorHistory.take(10).map((record) {
              DateTime dt = DateTime.tryParse(record["timestamp"] ?? "") ??
                  DateTime.now();
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(255, 0, 130, 150).withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.water_drop,
                        color: Colors.blue, size: 28),
                    title: Text(
                      "${(record['tank_level'] as num?)?.toStringAsFixed(2) ?? '--'}%",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}",
                      style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF18B8B5).withOpacity(0.09),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: valueColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: valueColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: valueColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionBox(String text) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 2, 175, 255).withOpacity(0.09),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color.fromARGB(255, 67, 120, 133)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  color:  const Color.fromARGB(255, 67, 120, 133),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      );
}
