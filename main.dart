import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';

void main() => runApp(const MoveGoApp());

class MoveGoApp extends StatelessWidget {
  const MoveGoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
      ), // 改為綠色主題，呼叫永續目標
      home: const MoveGoHomePage(),
    );
  }
}

class MoveGoHomePage extends StatefulWidget {
  const MoveGoHomePage({super.key});
  @override
  State<MoveGoHomePage> createState() => _MoveGoHomePageState();
}

class _MoveGoHomePageState extends State<MoveGoHomePage> {
  // --- 資料定義區 ---
  int _steps = 0;
  double _calories = 0.0;
  double _carbonSaved = 0.0; // 累計減碳量 (g)
  bool _badge1 = false;
  bool _badge2 = false;
  bool _badge3 = false;
  bool _badge4 = false;
  bool _badge5 = false;
  Color _n = Colors.blue;

  List<int> _historySteps = [1500, 2800, 3200, 4500, 1800, 2200, 0];
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startTracking();
  }

  // --- 邏輯處理區 ---

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _steps = prefs.getInt('steps') ?? 0;
      _carbonSaved = prefs.getDouble('carbonSaved') ?? 0.0; // 讀取減碳量
      _badge1 = prefs.getBool('badge1') ?? false;
      _badge2 = prefs.getBool('badge2') ?? false;
      _badge3 = prefs.getBool('badge3') ?? false;
      _badge4 = prefs.getBool('badge4') ?? false;
      _badge5 = prefs.getBool('badge5') ?? false;
      _updateEverything();
    });
  }

  void _updateEverything() {
    _calories = _steps * 0.04;

    // 【新功能】碳足跡計算邏輯：
    // 假設 1 步 = 0.0007 公里
    // 假設 1 公里省下 170g 的 CO2
    _carbonSaved = _steps * 0.0007 * 170;

    if (_steps >= 10 && !_badge1) {
      _badge1 = true;
      _n = Colors.green;
    }
    if (_steps >= 100 && !_badge2) {
      _badge2 = true;
      _n = const Color.fromARGB(255, 243, 33, 159);
    }
    if (_steps >= 500 && !_badge3) {
      _badge3 = true;
      _n = const Color.fromARGB(255, 240, 243, 33);
    }
    if (_steps >= 1000 && !_badge4) {
      _badge4 = true;
      _n = const Color.fromARGB(255, 243, 114, 33);
    }
    if (_steps >= 5000 && !_badge5) {
      _badge5 = true;

      _n = const Color.fromARGB(255, 33, 61, 243);
    }
    _historySteps[_historySteps.length - 1] = _steps;
  }

  void _startTracking() {
    _gyroSubscription = gyroscopeEventStream().listen((event) {
      double motion = event.x.abs() + event.y.abs() + event.z.abs();
      if (motion > 7.0) {
        setState(() {
          _steps++;
          _updateEverything();
        });
        _saveData();
      }
    });
  }

  void _resetData() async {
    // 1. 取得 SharedPreferences 實例
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      // 2. 重置記憶體中的變數
      _steps = 0;
      _calories = 0.0;
      _carbonSaved = 0.0;

      // 重置勳章
      _badge1 = false;
      _badge2 = false;
      _badge3 = false;
      _badge4 = false;
      _badge5 = false;

      // 更新相關計算
      _updateEverything();
    });

    // 3. 同步更新本地資料庫，確保下次打開 App 也是 0
    await prefs.setInt('steps', 0);
    await prefs.setDouble('carbonSaved', 0.0);
    await prefs.setBool('badge1', false);
    await prefs.setBool('badge2', false);
    await prefs.setBool('badge3', false);
    await prefs.setBool('badge4', false);
    await prefs.setBool('badge5', false);
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('steps', _steps);
    await prefs.setDouble('carbonSaved', _carbonSaved); // 儲存減碳量
    await prefs.setBool('badge1', _badge1);
    await prefs.setBool('badge2', _badge2);
    await prefs.setBool('badge3', _badge3);
    await prefs.setBool('badge4', _badge4);
    await prefs.setBool('badge5', _badge5);
  }

  // --- UI 介面區 ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("MoveGo 綠色里程"), centerTitle: true),

      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // 圓形進度
            CircularPercentIndicator(
              radius: 80,
              lineWidth: 10,
              percent: (_steps / 1000).clamp(0, 1),
              center: Text(
                "$_steps\n步",
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              progressColor: _n,
              circularStrokeCap: CircularStrokeCap.round,
            ),

            const SizedBox(height: 25),

            // 永續旅遊數據卡片
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildEcoStat(
                    "節省 CO2",
                    "${_carbonSaved.toStringAsFixed(1)}g",
                    Icons.eco,
                  ),
                  _buildEcoStat(
                    "消耗熱量",
                    "${_calories.toStringAsFixed(1)}kcal",
                    Icons.bolt,
                  ),
                ],
              ),
            ),

            const Divider(height: 40, indent: 30, endIndent: 30),

            // 圖表
            const Text(
              "本週步數統計",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            _buildChart(),
            const SizedBox(height: 10),

            // 加入手動重置按鈕
            TextButton.icon(
              onPressed: _resetData,
              icon: const Icon(Icons.restore, color: Colors.red),
              label: const Text("手動重置數據", style: TextStyle(color: Colors.red)),
            ),

            const SizedBox(height: 30),

            // 勳章牆
            const Text(
              "永續勳章",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center, // 居中對齊
              spacing: 20, // 左右間距
              runSpacing: 20, // 換行後的上下間距
              children: [
                _buildBadgeItem("🌱", "低碳使者", _badge1),
                _buildBadgeItem("🌳", "地球守護者", _badge2),
                _buildBadgeItem("🏆", "地球保衛者", _badge3),
                _buildBadgeItem("🏆🏆", "地球防衛者", _badge4),
                _buildBadgeItem("🏆🏆🏆", "地球環境保衛者", _badge5),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _steps += 10;
            _updateEverything();
          });
          _saveData();
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEcoStat(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.green, size: 30),
        const SizedBox(height: 5),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.green)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.lightGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    return Container(
      height: 180,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: BarChart(
        BarChartData(
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: _historySteps.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.toDouble(),
                  color: e.key == 6
                      ? Colors.green
                      : Colors.green.withOpacity(0.2),
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBadgeItem(String icon, String label, bool isUnlocked) {
    return Column(
      children: [
        AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: isUnlocked ? 1.0 : 0.2,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Text(icon, style: const TextStyle(fontSize: 30)),
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  void dispose() {
    _gyroSubscription?.cancel();
    super.dispose();
  }
}
