// home_screen.dart
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'login_screen.dart';
import 'tank_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  const HomeScreen({super.key, required this.username});

  @override
    State<HomeScreen> createState() => _HomeScreenState();
  }
  
  class _HomeScreenState extends State<HomeScreen> {
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        body: Center(
          child: Text("Home Screen for ${widget.username}"),
        ),
      );
    }
}

class DashboardScreen extends StatefulWidget {
  final String username;
  const DashboardScreen({super.key, required this.username});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String statusUrl =
      'https://humancc.site/syasyaaina/sensor_SER/pump_control.php';
  final String sensorUrl =
      'https://humancc.site/syasyaaina/sensor_SER/latest_sensor.php';
  final String historyUrl =
      'https://humancc.site/syasyaaina/sensor_SER/history.php';

  bool loading = true;
  bool pumpLoading = false;
  double tankLevel = 0;
  double temperature = 0;
  double humidity = 0;
  bool rainCollected = false;
  bool pumpOn = false;
  String pumpMode = "AUTO";
  List<dynamic> sensorHistory = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchAllData();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) => fetchAllData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchAllData() async {
    setState(() => loading = true);
    try {
      final pumpResp = await http.get(Uri.parse(statusUrl));
      if (pumpResp.statusCode == 200) {
        final data = json.decode(pumpResp.body);
        pumpMode = data['mode'] ?? 'AUTO';
      }
      final sensorResp = await http.get(Uri.parse(sensorUrl));
      if (sensorResp.statusCode == 200) {
        final data = json.decode(sensorResp.body);
        tankLevel = (data['tank_level'] as num?)?.toDouble() ?? 0;
        temperature = (data['temperature'] as num?)?.toDouble() ?? 0;
        humidity = (data['humidity'] as num?)?.toDouble() ?? 0;
        rainCollected = data['rain_collected'] == true;
        pumpOn = (data['relay_status'] == 'ON');
      }
      final histResp = await http.get(Uri.parse(historyUrl));
      if (histResp.statusCode == 200) {
        sensorHistory = json.decode(histResp.body);
      }
    } catch (e) {
      print('Error: $e');
    }
    setState(() => loading = false);
  }

  Future<void> setPump(bool turnOn) async {
    setState(() {
      pumpLoading = true;
      pumpOn = turnOn;
    });
    final previousStatus = !turnOn;
    try {
      final response = await http.post(
        Uri.parse(statusUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'mode': 'MANUAL', 'status': turnOn ? 'ON' : 'OFF'}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to set pump status');
      }
      await fetchAllData();
    } catch (e) {
      setState(() {
        pumpOn = previousStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to change pump status')),
      );
    }
    setState(() {
      pumpLoading = false;
    });
  }

  Future<void> setPumpMode(String mode) async {
    setState(() => loading = true);
    try {
      await http.post(
        Uri.parse(statusUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'mode': mode}),
      );
      await fetchAllData();
    } catch (e) {
      print('Error: $e');
    }
    setState(() => loading = false);
  }

  Widget _buildCard(
      {required Widget child, Color? color, EdgeInsets? padding}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: padding ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }

  void _showHistoryModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF7FAFE),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.4,
          maxChildSize: 0.96,
          expand: false,
          builder: (_, scrollController) => Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Full Sensor History",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: sensorHistory.length,
                    itemBuilder: (context, i) {
                      final record = sensorHistory[i];
                      DateTime dt =
                          DateTime.tryParse(record["timestamp"] ?? "") ??
                              DateTime.now();
                      String formattedTime =
                          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        color: Colors.white,
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          leading: Icon(
                            record['relay_status'] == "ON"
                                ? Icons.bolt
                                : Icons.power_off,
                            color: record['relay_status'] == "ON"
                                ? Colors.teal
                                : Colors.grey[400],
                            size: 24,
                          ),
                          title: Text(
                              "Tank: ${record['tank_level']?.toStringAsFixed(1) ?? "--"}%",
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                          subtitle: Row(
                            children: [
                              const Icon(Icons.thermostat,
                                  size: 15, color: Colors.redAccent),
                              Text(
                                  "${record['temperature']?.toStringAsFixed(1) ?? '--'}°C  ",
                                  style: const TextStyle(fontSize: 13)),
                              const Icon(Icons.water_drop,
                                  size: 14, color: Colors.blue),
                              Text(
                                  "${record['humidity']?.toStringAsFixed(0) ?? '--'}%",
                                  style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 8),
                              Icon(
                                record['rain_collected']
                                    ? Icons.check_circle
                                    : Icons.cloud_off,
                                color: record['rain_collected']
                                    ? Colors.green
                                    : Colors.grey,
                                size: 14,
                              ),
                            ],
                          ),
                          trailing: Text(formattedTime,
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 14)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final latestRecord = sensorHistory.isNotEmpty ? sensorHistory.first : null;
    DateTime? latestDT;
    String latestTime = '';
    if (latestRecord != null && latestRecord["timestamp"] != null) {
      latestDT = DateTime.tryParse(latestRecord["timestamp"]);
      if (latestDT != null) {
        latestTime =
            "${latestDT.hour.toString().padLeft(2, '0')}:${latestDT.minute.toString().padLeft(2, '0')}";
      }
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 209, 231, 239),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 206, 239, 255),
        elevation: 0,
        toolbarHeight: 70,
        title: Row(
          children: [
            Expanded(
              child: Text(
                "Welcome Back,",
                style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[700]),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.teal, size: 26),
              tooltip: "Refresh now",
              onPressed: fetchAllData,
            ),
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.teal.shade50,
              child: const Icon(Icons.person, color: Color.fromARGB(255, 0, 110, 150), size: 28),
            ),
            const SizedBox(width: 12),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.only(left: 22, bottom: 2),
            child: Row(
              children: [
                Text(
                  "${widget.username} ",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 26),
                ),
                const Icon(Icons.waving_hand, color: Colors.amber, size: 24),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: "Logout",
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => LoginScreen()),
                        (_) => false);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -- Tank Level Card with navigation to detail screen
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TankLevelDetailScreen(
                                sensorHistory: sensorHistory),
                          ),
                        );
                      },
                      child: _buildCard(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            CircularPercentIndicator(
                              radius: 50.0,
                              lineWidth: 11.0,
                              percent: (tankLevel / 100.0).clamp(0, 1),
                              center: Text(
                                "${tankLevel.toStringAsFixed(0)}%",
                                style: const TextStyle(
                                    fontSize: 26, fontWeight: FontWeight.bold),
                              ),
                              progressColor: Colors.blue,
                              backgroundColor: Colors.teal.shade50,
                            ),
                            const SizedBox(width: 22),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Tank Level",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 20)),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${tankLevel.toStringAsFixed(1)} %",
                                    style: TextStyle(
                                        fontSize: 17, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.opacity, color:  Colors.blue, size: 38)
                          ],
                        ),
                      ),
                    ),
                  ),

                  // -- Row Cards for Temp/Humidity and Rainwater
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildCard(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 0),
                            child: Column(
                              children: [
                                const Icon(Icons.thermostat,
                                    color: Colors.red, size: 30),
                                const SizedBox(height: 3),
                                Text("${temperature.toStringAsFixed(1)}°C",
                                    style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildCard(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 0),
                            child: Column(
                              children: [
                                const Icon(Icons.water_drop,
                                    color: Colors.blue, size: 30),
                                const SizedBox(height: 3),
                                Text("${humidity.toStringAsFixed(0)}%",
                                    style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildCard(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 0),
                            child: Column(
                              children: [
                                Icon(
                                  rainCollected
                                      ? Icons.check_circle
                                      : Icons.cloud_off,
                                  color: rainCollected
                                      ? Colors.green
                                      : Colors.grey,
                                  size: 30,
                                ),
                                const SizedBox(height: 3),
                                Text(rainCollected ? "Collected" : "No Rain",
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // -- Pump Control Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: _buildCard(
                      child: ListTile(
                        leading: Icon(
                          pumpOn ? Icons.flash_on : Icons.flash_off,
                          color: pumpOn ? Colors.teal : Colors.grey,
                          size: 36,
                        ),
                        title: Text("Pump Status: ${pumpOn ? "ON" : "OFF"}",
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text("Mode: $pumpMode"),
                        trailing: pumpLoading
                            ? const SizedBox(
                                width: 26,
                                height: 26,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Switch(
                                value: pumpOn,
                                onChanged: pumpMode == "MANUAL" && !pumpLoading
                                    ? (v) => setPump(v)
                                    : null,
                              ),
                      ),
                    ),
                  ),

                  // -- Mode buttons row
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 22, vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: pumpMode == "MANUAL"
                                ? null
                                : () async => await setPumpMode("MANUAL"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple.shade50,
                              foregroundColor: Colors.deepPurple,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              elevation: 0,
                            ),
                            child: const Text("MANUAL"),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: pumpMode == "AUTO"
                                ? null
                                : () async => await setPumpMode("AUTO"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade50,
                              foregroundColor: Colors.teal,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              elevation: 0,
                            ),
                            child: const Text("AUTO"),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Sensor History Preview Card
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 22, vertical: 2),
                    child: Row(
                      children: [
                        const Text(
                          "Sensor History",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                        const Spacer(),
                        if (latestRecord != null)
                          GestureDetector(
                            onTap: () => _showHistoryModal(context),
                            child: const Row(
                              children: [
                                Text("View All",
                                    style: TextStyle(
                                        color: Colors.teal,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15)),
                                Icon(Icons.expand_more,
                                    color: Colors.teal, size: 20)
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: _buildCard(
                      color: const Color(0xFFFAFAFE),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: latestRecord != null
                          ? ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 0),
                              leading: Icon(
                                latestRecord['relay_status'] == "ON"
                                    ? Icons.bolt
                                    : Icons.power_off,
                                color: latestRecord['relay_status'] == "ON"
                                    ? Colors.teal
                                    : Colors.grey[400],
                                size: 28,
                              ),
                              title: Text(
                                  "Tank: ${latestRecord['tank_level']?.toStringAsFixed(1) ?? '--'}%",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16)),
                              subtitle: Row(
                                children: [
                                  const Icon(Icons.thermostat,
                                      size: 15, color: Colors.redAccent),
                                  Text(
                                      "${latestRecord['temperature']?.toStringAsFixed(1) ?? '--'}°C  ",
                                      style: const TextStyle(fontSize: 13)),
                                  const Icon(Icons.water_drop,
                                      size: 14, color: Colors.blue),
                                  Text(
                                      "${latestRecord['humidity']?.toStringAsFixed(0) ?? '--'}%",
                                      style: const TextStyle(fontSize: 13)),
                                  const SizedBox(width: 7),
                                  Icon(
                                    latestRecord['rain_collected']
                                        ? Icons.check_circle
                                        : Icons.cloud_off,
                                    color: latestRecord['rain_collected']
                                        ? Colors.green
                                        : Colors.grey,
                                    size: 14,
                                  ),
                                ],
                              ),
                              trailing: Text(latestTime,
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 15)),
                            )
                          : const Padding(
                              padding: EdgeInsets.all(18.0),
                              child: Text(
                                "No history available.",
                                style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
