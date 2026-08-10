import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminSurveyManager extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminSurveyManager({super.key, required this.user});

  @override
  State<AdminSurveyManager> createState() => _AdminSurveyManagerState();
}

class _AdminSurveyManagerState extends State<AdminSurveyManager> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  List<Map<String, dynamic>> _surveys = [];
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _selectedSurvey;
  bool _loading = true;
  final _questionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    
    final surveys = await _supabase.from('pulse_surveys').select('*').order('created_at', ascending: false);
    setState(() {
      _surveys = List<Map<String, dynamic>>.from(surveys);
    });

    if (_selectedSurvey != null) {
      await _loadResults(_selectedSurvey!['id']);
    }

    setState(() => _loading = false);
  }

  Future<void> _loadResults(int surveyId) async {
    final responses = await _supabase
        .from('pulse_responses')
        .select('*')
        .eq('survey_id', surveyId)
        .order('created_at', ascending: false);

    setState(() => _results = List<Map<String, dynamic>>.from(responses));
  }

  Future<void> _createSurvey() async {
    final controller = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Survey'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Question',
            border: OutlineInputBorder(),
            hintText: 'e.g., How satisfied are you with...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: controller.text.trim().isEmpty ? null : () async {
              Navigator.pop(ctx);
              await _supabase.from('pulse_surveys').insert({
                'question': controller.text.trim(),
                'created_by': widget.user['name'] ?? 'Admin',
                'is_active': true,
              });
              _loadAll();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Survey created! ✅'), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0000)),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSurvey(int id, bool currentStatus) async {
    await _supabase.from('pulse_surveys').update({'is_active': !currentStatus}).eq('id', id);
    _loadAll();
  }

  Future<void> _deleteSurvey(int id) async {
    await _supabase.from('pulse_surveys').delete().eq('id', id);
    _loadAll();
    setState(() => _selectedSurvey = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Survey deleted'), backgroundColor: Colors.orange),
    );
  }

  double get _averageRating {
    if (_results.isEmpty) return 0;
    final total = _results.fold<int>(0, (sum, r) => sum + ((r['rating'] as int?) ?? 0));
    return total / _results.length;
  }

  Map<int, int> get _ratingDistribution {
    final dist = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (var r in _results) {
      final rating = r['rating'] as int? ?? 3;
      dist[rating] = (dist[rating] ?? 0) + 1;
    }
    return dist;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Survey Manager'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD4AF37),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [Tab(text: 'Manage'), Tab(text: 'Results')],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSurvey,
        backgroundColor: const Color(0xFFCC0000),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
          : TabBarView(
              controller: _tabController,
              children: [_buildManage(), _buildResults()],
            ),
    );
  }

  Widget _buildManage() {
    if (_surveys.isEmpty) {
      return const Center(child: Text('No surveys yet. Tap + to create one.'));
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _surveys.length,
        itemBuilder: (context, index) {
          final s = _surveys[index];
          final isActive = s['is_active'] == true;
          final isSelected = _selectedSurvey != null && _selectedSurvey!['id'] == s['id'];

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isSelected ? const BorderSide(color: Color(0xFFCC0000), width: 2) : BorderSide.none,
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                child: Icon(isActive ? Icons.check_circle : Icons.pause_circle, color: isActive ? Colors.green : Colors.grey, size: 20),
              ),
              title: Text(s['question'] ?? '', style: const TextStyle(fontSize: 13)),
              subtitle: Text('By ${s['created_by']} • ${DateFormat('MMM d').format(DateTime.parse(s['created_at'].toString()))}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              trailing: PopupMenuButton(
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    child: Text(isActive ? 'Deactivate' : 'Activate'),
                    onTap: () => _toggleSurvey(s['id'], isActive),
                  ),
                  PopupMenuItem(
                    child: const Text('View Results', style: TextStyle(color: Color(0xFF3182CE))),
                    onTap: () {
                      setState(() => _selectedSurvey = s);
                      _loadResults(s['id']);
                      _tabController.animateTo(1);
                    },
                  ),
                  PopupMenuItem(
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    onTap: () => _deleteSurvey(s['id']),
                  ),
                ],
              ),
              onTap: () {
                setState(() => _selectedSurvey = s);
                _loadResults(s['id']);
                _tabController.animateTo(1);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildResults() {
    if (_selectedSurvey == null) {
      return const Center(child: Text('Select a survey from Manage tab to see results'));
    }

    final dist = _ratingDistribution;
    final avg = _averageRating;
    final total = _results.length;

    return RefreshIndicator(
      onRefresh: () => _loadResults(_selectedSurvey!['id']),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1A1A1A), Color(0xFF2D2A1F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD4AF37)),
            ),
            child: Column(children: [
              Text(_selectedSurvey!['question'] ?? '', style: const TextStyle(color: Color(0xFFF5E6CC), fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _statItem('Responses', '$total', Colors.white),
                _statItem('Average', avg.toStringAsFixed(1), const Color(0xFFD4AF37)),
                _statItem('Active', _selectedSurvey!['is_active'] == true ? 'Yes' : 'No', _selectedSurvey!['is_active'] == true ? Colors.green : Colors.grey),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          const Text('Rating Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...List.generate(5, (i) {
            final rating = 5 - i;
            final count = dist[rating] ?? 0;
            final maxCount = dist.values.isEmpty ? 1 : dist.values.reduce((a, b) => a > b ? a : b);
            final barWidth = maxCount > 0 ? (count / maxCount * 250.0) : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(width: 70, child: Row(children: List.generate(rating, (_) => const Icon(Icons.star, color: Color(0xFFD4AF37), size: 14)))),
                const SizedBox(width: 8),
                Expanded(child: Container(height: 24, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)), child: Container(width: barWidth > 10 ? barWidth : 10, height: 24, decoration: BoxDecoration(color: const Color(0xFFCC0000), borderRadius: BorderRadius.circular(6))))),
                const SizedBox(width: 8),
                SizedBox(width: 30, child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
              ]),
            );
          }),
          const SizedBox(height: 20),
          const Text('Recent Responses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_results.isEmpty)
            const Text('No responses yet', style: TextStyle(color: Colors.grey))
          else
            ..._results.take(10).map((r) => Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) => Icon(i < (r['rating'] ?? 3) ? Icons.star : Icons.star_border, color: const Color(0xFFD4AF37), size: 14))),
                title: Text(r['employee_name'] ?? '', style: const TextStyle(fontSize: 13)),
                subtitle: r['comment'] != null && r['comment'].toString().isNotEmpty ? Text(r['comment'], style: TextStyle(fontSize: 11, color: Colors.grey.shade600)) : null,
                trailing: Text(DateFormat('MMM d').format(DateTime.parse(r['created_at'].toString())), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ),
            )),
        ]),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
    ]);
  }
}