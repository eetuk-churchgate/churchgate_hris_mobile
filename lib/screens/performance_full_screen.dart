import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/engagement_service.dart';

class PerformanceFullScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const PerformanceFullScreen({super.key, required this.user});

  @override
  State<PerformanceFullScreen> createState() => _PerformanceFullScreenState();
}

class _PerformanceFullScreenState extends State<PerformanceFullScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _myKpis = [];
  List<Map<String, dynamic>> _deptKpis = [];
  List<Map<String, dynamic>> _appraisals = [];
  Map<String, dynamic>? _latestAppraisal;
  bool _loading = true;

  final List<String> _pillars = [
    'Occupancy & Revenue Growth',
    'Process Simplification',
    'Asset Reliability & Digitalization',
    'People & Culture',
  ];

  @override
  void initState() {
    super.initState();
    EngagementService.trackPageView(module: 'Performance');
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    try {
      final userName = widget.user['name'] ?? '';
      final userDept = widget.user['department'] ?? '';
      final empId = widget.user['employee_id'] ?? '';

      // Load my KPIs
      final kpis = await _supabase.from('performance_data').select('*').eq('user_name', userName).order('created_at', ascending: false);
      
      // Load department KPIs
      final deptKpis = await _supabase.from('performance_data').select('*').eq('department', userDept).order('created_at', ascending: false);
      
      // Load appraisals
      final appraisals = await _supabase.from('appraisals').select('*').eq('user_name', userName).order('submitted_date', ascending: false);
      
      // Load latest appraisal
      final latest = await _supabase.from('appraisals').select('*').eq('user_name', userName).order('submitted_date', ascending: false).limit(1).maybeSingle();

      setState(() {
        _myKpis = List<Map<String, dynamic>>.from(kpis);
        _deptKpis = List<Map<String, dynamic>>.from(deptKpis);
        _appraisals = List<Map<String, dynamic>>.from(appraisals);
        _latestAppraisal = latest;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  double _getOverallProgress() {
    if (_myKpis.isEmpty) return 0;
    double total = 0;
    for (var kpi in _myKpis) {
      total += (kpi['progress'] as num?)?.toDouble() ?? 0;
    }
    return total / _myKpis.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        title: const Text('📈 Performance'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFCC0000),
          labelColor: const Color(0xFFCC0000),
          unselectedLabelColor: Colors.grey,
          isScrollable: true,
          tabs: const [
            Tab(text: 'My KPIs'),
            Tab(text: 'Department'),
            Tab(text: 'Appraisals'),
            Tab(text: 'Analytics'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMyKpisTab(),
                _buildDepartmentTab(),
                _buildAppraisalsTab(),
                _buildAnalyticsTab(),
              ],
            ),
    );
  }

  Widget _buildMyKpisTab() {
    final overall = _getOverallProgress();
    final color = overall >= 85 ? const Color(0xFF38a169) : overall >= 65 ? const Color(0xFFd69e2e) : const Color(0xFFCC0000);
    final status = overall >= 85 ? 'On Track' : overall >= 65 ? 'Needs Attention' : 'At Risk';

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Overall Score Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1A1A1A), Color(0xFF2D3748)]), borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                const Text('Overall Performance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 12),
                Text('${overall.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 48, fontWeight: FontWeight.bold)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
                const SizedBox(height: 12),
                ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: overall / 100, backgroundColor: Colors.white24, color: color, minHeight: 8)),
              ]),
            ),
            const SizedBox(height: 20),

            // KPI Cards by Pillar
            for (var pillar in _pillars)
              _buildPillarSection(pillar),

            if (_myKpis.isEmpty)
              Container(padding: const EdgeInsets.all(40), child: const Column(children: [Text('📊', style: TextStyle(fontSize: 48)), SizedBox(height: 12), Text('No KPIs assigned yet', style: TextStyle(color: Colors.grey, fontSize: 16))])),
          ],
        ),
      ),
    );
  }

  Widget _buildPillarSection(String pillar) {
    final pillarKpis = _myKpis.where((k) => k['pillar_name'] == pillar).toList();
    if (pillarKpis.isEmpty) return const SizedBox.shrink();

    final avgProgress = pillarKpis.fold(0.0, (sum, k) => sum + ((k['progress'] as num?)?.toDouble() ?? 0)) / pillarKpis.length;
    final color = avgProgress >= 85 ? const Color(0xFF38a169) : avgProgress >= 65 ? const Color(0xFFd69e2e) : const Color(0xFFCC0000);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 4, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Expanded(child: Text(pillar, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            Text('${avgProgress.toStringAsFixed(0)}%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: avgProgress / 100, backgroundColor: Colors.grey.shade200, color: color, minHeight: 6)),
          const SizedBox(height: 12),
          for (var kpi in pillarKpis) _buildKpiItem(kpi),
        ],
      ),
    );
  }

  Widget _buildKpiItem(Map<String, dynamic> kpi) {
    final progress = (kpi['progress'] as num?)?.toDouble() ?? 0;
    final color = progress >= 85 ? const Color(0xFF38a169) : progress >= 65 ? const Color(0xFFd69e2e) : const Color(0xFFCC0000);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(kpi['kpi_name'] ?? 'KPI', style: const TextStyle(fontSize: 13))),
        Text('$progress%', style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }

  Widget _buildDepartmentTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _deptKpis.length,
        itemBuilder: (context, index) {
          final kpi = _deptKpis[index];
          final progress = (kpi['progress'] as num?)?.toDouble() ?? 0;
          final color = progress >= 85 ? const Color(0xFF38a169) : progress >= 65 ? const Color(0xFFd69e2e) : const Color(0xFFCC0000);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(radius: 14, backgroundColor: color, child: Text((kpi['user_name'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10))),
                const SizedBox(width: 8),
                Expanded(child: Text(kpi['user_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                Text('$progress%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 8),
              Text(kpi['kpi_name'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress / 100, backgroundColor: Colors.grey.shade200, color: color, minHeight: 4)),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildAppraisalsTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_latestAppraisal != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1A1A1A), Color(0xFF2D3748)]), borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  const Text('Latest Appraisal', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(_latestAppraisal!['cycle_name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF38a169).withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Text(_latestAppraisal!['status'] ?? 'Pending', style: const TextStyle(color: Color(0xFF38a169), fontWeight: FontWeight.w600))),
                ]),
              ),
              const SizedBox(height: 20),
            ],
            if (_appraisals.isEmpty)
              Container(padding: const EdgeInsets.all(40), child: const Column(children: [Text('📝', style: TextStyle(fontSize: 48)), SizedBox(height: 12), Text('No appraisals yet', style: TextStyle(color: Colors.grey, fontSize: 16))]))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _appraisals.length,
                itemBuilder: (context, index) {
                  final app = _appraisals[index];
                  final statusColor = app['status'] == 'Completed' ? const Color(0xFF38a169) : app['status'] == 'Pending' ? const Color(0xFFd69e2e) : const Color(0xFF3182ce);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                    child: Row(children: [
                      Container(width: 40, height: 40, decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.assessment, color: statusColor)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(app['cycle_name'] ?? 'Appraisal', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(app['submitted_date']?.toString()?.substring(0, 10) ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ])),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Text(app['status'] ?? '', style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600))),
                    ]),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    final overall = _getOverallProgress();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress by pillar chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Progress by Pillar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    barGroups: _pillars.map((pillar) {
                      final kpis = _myKpis.where((k) => k['pillar_name'] == pillar).toList();
                      final avg = kpis.isEmpty ? 0.0 : kpis.fold(0.0, (sum, k) => sum + ((k['progress'] as num?)?.toDouble() ?? 0)) / kpis.length;
                      return BarChartGroupData(x: _pillars.indexOf(pillar), barRods: [BarChartRodData(toY: avg, color: const Color(0xFFCC0000), width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]);
                    }).toList(),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                        if (value.toInt() < _pillars.length) {
                          return Text(_pillars[value.toInt()].substring(0, 4), style: const TextStyle(fontSize: 8));
                        }
                        return const Text('');
                      })),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    maxY: 100,
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}