import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../models/performance_model.dart';

class PerformanceFullScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const PerformanceFullScreen({super.key, required this.user});

  @override
  State<PerformanceFullScreen> createState() => _PerformanceFullScreenState();
}

class _PerformanceFullScreenState extends State<PerformanceFullScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  List<PerformanceData> _pillars = [];
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  String _appraisalCycle = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    final userName = widget.user['name'] ?? '';
    
    try {
      final data = await _supabase
          .from('performance_data')
          .select()
          .eq('user_name', userName)
          .order('created_at', ascending: false);

      if (data.isNotEmpty) {
        _pillars = data.map((json) => PerformanceData.fromJson(json)).toList();
        _appraisalCycle = _pillars.first.appraisalCycle ?? '';
      }

      final historyData = await _supabase
          .from('kpi_history')
          .select()
          .eq('user_name', userName)
          .order('created_at', ascending: false)
          .limit(30);

      _history = List<Map<String, dynamic>>.from(historyData);
    } catch (e) {
      // Keep empty state
    }

    setState(() => _loading = false);
  }

  double get _overallScore {
    if (_pillars.isEmpty) return 0;
    double totalWeight = 0;
    double weightedScore = 0;
    for (var pillar in _pillars) {
      final w = pillar.weight ?? 0;
      final p = pillar.calculatedProgress;
      totalWeight += w;
      weightedScore += (p * w / 100);
    }
    return totalWeight > 0 ? weightedScore : 0;
  }

  Future<void> _updateKPI(int pillarId, int kpiIndex, String newValue) async {
    if (newValue.isEmpty) return;

    try {
      final pillar = _pillars.firstWhere((p) => p.id == pillarId);
      final kpis = List<KPIItem>.from(pillar.kpis ?? []);
      
      if (kpiIndex < kpis.length) {
        final updatedKPI = KPIItem(
          kpi: kpis[kpiIndex].kpi,
          target: kpis[kpiIndex].target,
          current: newValue,
          status: kpis[kpiIndex].status,
          deadline: kpis[kpiIndex].deadline,
          owner: kpis[kpiIndex].owner,
          weight: kpis[kpiIndex].weight,
        );
        
        final progress = updatedKPI.progressPercentage;
        if (progress >= 100) {
          updatedKPI.status = 'Completed';
        } else if (progress > 0) {
          updatedKPI.status = 'In Progress';
        }
        
        kpis[kpiIndex] = updatedKPI;
        
        final kpiData = jsonEncode(kpis.map((k) => k.toJson()).toList());
        
        double totalWeight = 0;
        double weightedProgress = 0;
        for (var kpi in kpis) {
          final w = kpi.weight ?? 0;
          totalWeight += w;
          weightedProgress += (kpi.progressPercentage * w / 100);
        }
        final newProgress = totalWeight > 0 ? weightedProgress : 0;
        
        await _supabase
            .from('performance_data')
            .update({
              'kpi_data': kpiData,
              'progress': newProgress,
              'submission_status': 'Draft',
            })
            .eq('id', pillarId);
        
        await _supabase.from('kpi_history').insert({
          'action': 'Updated',
          'kpi_name': kpis[kpiIndex].kpi ?? 'KPI',
          'user_name': widget.user['name'] ?? '',
          'pillar': pillar.pillarName ?? '',
          'created_at': DateTime.now().toIso8601String(),
        });

        await _loadAllData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('KPI updated successfully'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submitPerformance(int pillarId) async {
    try {
      await _supabase
          .from('performance_data')
          .update({'submission_status': 'Submitted'})
          .eq('id', pillarId);
      
      await _loadAllData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Performance submitted for approval'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Performance'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD4AF37),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'KPIs'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
          : _pillars.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.trending_up, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No KPIs assigned yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverview(),
                    _buildKPIDetail(),
                    _buildHistory(),
                  ],
                ),
    );
  }

  Widget _buildOverview() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildScoreCard(),
            const SizedBox(height: 20),
            if (_appraisalCycle.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Color(0xFFD4AF37), size: 18),
                    const SizedBox(width: 8),
                    Text('Cycle: $_appraisalCycle',
                        style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            const Text('Performance Pillars',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 12),
            ..._pillars.map((pillar) => _buildPillarCard(pillar)),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    final score = _overallScore;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF2D2A1F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37), width: 1),
      ),
      child: Column(
        children: [
          const Text('Overall Performance Score',
              style: TextStyle(color: Color(0xFFF5E6CC), fontSize: 14)),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: score / 100),
                  duration: const Duration(milliseconds: 1500),
                  builder: (context, value, _) {
                    return CircularProgressIndicator(
                      value: value,
                      strokeWidth: 10,
                      backgroundColor: Colors.grey.shade800,
                      color: score >= 70 ? const Color(0xFF38A169) : const Color(0xFFD4AF37),
                    );
                  },
                ),
              ),
              Text('${score.toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: score >= 70 ? Colors.green.withOpacity(0.2) : const Color(0xFFD4AF37).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              score >= 85 ? 'Excellent' : score >= 70 ? 'Good' : score >= 50 ? 'Average' : 'Needs Improvement',
              style: TextStyle(
                color: score >= 70 ? Colors.green : const Color(0xFFD4AF37),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarCard(PerformanceData pillar) {
    final progress = pillar.calculatedProgress;
    Color statusColor;
    switch (pillar.submissionStatus?.toLowerCase()) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'submitted':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(pillar.pillarName ?? 'Pillar',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(pillar.submissionStatus ?? 'Draft',
                      style: TextStyle(color: statusColor, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress / 100,
                backgroundColor: Colors.grey.shade200,
                color: progress >= 85 ? const Color(0xFF38A169) 
                    : progress >= 65 ? const Color(0xFFD4AF37) 
                    : const Color(0xFFCC0000),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${progress.toStringAsFixed(0)}% Complete',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                Text('Weight: ${pillar.weight ?? 0}%',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
            if (pillar.kpis != null && pillar.kpis!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${pillar.kpis!.length} KPIs',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPIDetail() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pillars.length,
        itemBuilder: (context, index) {
          final pillar = _pillars[index];
          return _buildExpandablePillar(pillar);
        },
      ),
    );
  }

  Widget _buildExpandablePillar(PerformanceData pillar) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFCC0000).withOpacity(0.1),
          child: const Icon(Icons.flag, color: Color(0xFFCC0000), size: 18),
        ),
        title: Text(pillar.pillarName ?? 'Pillar',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('Weight: ${pillar.weight}% • ${pillar.kpis?.length ?? 0} KPIs',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${pillar.calculatedProgress.toStringAsFixed(0)}%',
                style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFFCC0000), fontSize: 13)),
            if (pillar.submissionStatus != 'Submitted' && pillar.submissionStatus != 'Approved')
              TextButton(
                onPressed: () => _submitPerformance(pillar.id!),
                child: const Text('Submit', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
        children: [
          if (pillar.kpis != null)
            ...pillar.kpis!.asMap().entries.map((entry) {
              return _buildKPIItem(entry.value, pillar, entry.key);
            }),
        ],
      ),
    );
  }

  Widget _buildKPIItem(KPIItem kpi, PerformanceData pillar, int kpiIndex) {
    final progress = kpi.progressPercentage;
    Color progressColor;
    switch (kpi.status?.toLowerCase()) {
      case 'completed':
        progressColor = const Color(0xFF38A169);
        break;
      case 'in progress':
        progressColor = const Color(0xFF3182CE);
        break;
      case 'at risk':
        progressColor = const Color(0xFFCC0000);
        break;
      default:
        progressColor = const Color(0xFFD69E2E);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(kpi.kpi ?? 'KPI', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: progressColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(kpi.status ?? 'N/A',
                    style: TextStyle(color: progressColor, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: Colors.grey.shade200,
              color: progressColor,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _kpiInfoChip('Target', kpi.target ?? '100'),
              const SizedBox(width: 8),
              _kpiInfoChip('Current', kpi.current ?? '0'),
              const SizedBox(width: 8),
              _kpiInfoChip('Weight', '${kpi.weight ?? 0}%'),
            ],
          ),
          if (kpi.deadline != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Deadline: ${kpi.deadline}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
            ),
          const SizedBox(height: 8),
          if (pillar.submissionStatus != 'Submitted' && pillar.submissionStatus != 'Approved')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showUpdateDialog(kpi, pillar, kpiIndex),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Update Progress', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFCC0000),
                      side: const BorderSide(color: Color(0xFFCC0000)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _kpiInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label: $value', style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
    );
  }

  void _showUpdateDialog(KPIItem kpi, PerformanceData pillar, int kpiIndex) {
    final controller = TextEditingController(text: kpi.current ?? '0');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(kpi.kpi ?? 'Update KPI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Target: ${kpi.target}', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Current Value',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixText: '/ ${kpi.target}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateKPI(pillar.id!, kpiIndex, controller.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0000)),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No KPI history yet', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final h = _history[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFCC0000).withOpacity(0.1),
                child: const Icon(Icons.trending_up, color: Color(0xFFCC0000), size: 16),
              ),
              title: Text(h['kpi_name'] ?? 'KPI', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              subtitle: Text('${h['action']} • ${h['pillar'] ?? ''}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              trailing: Text(
                h['created_at']?.toString().substring(0, 10) ?? '',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ),
          );
        },
      ),
    );
  }
}