import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/engagement_service.dart';

class WellnessScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const WellnessScreen({super.key, required this.user});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  final _supabase = Supabase.instance.client;
  final _noteController = TextEditingController();
  int _selectedMood = 3;
  List<Map<String, dynamic>> _moodHistory = [];
  bool _loading = true;

  final List<Map<String, dynamic>> _moods = [
    {'emoji': '😢', 'label': 'Stressed', 'color': const Color(0xFFe53e3e)},
    {'emoji': '😕', 'label': 'Low', 'color': const Color(0xFFd69e2e)},
    {'emoji': '😐', 'label': 'Okay', 'color': const Color(0xFF3182ce)},
    {'emoji': '🙂', 'label': 'Good', 'color': const Color(0xFF38a169)},
    {'emoji': '😄', 'label': 'Great', 'color': const Color(0xFF2f855a)},
  ];

  final List<Map<String, String>> _wellnessTips = [
    {'tip': 'Take a 5-minute stretch break every hour', 'icon': '🧘'},
    {'tip': 'Stay hydrated - aim for 8 glasses of water daily', 'icon': '💧'},
    {'tip': 'Practice deep breathing for 2 minutes', 'icon': '🌬️'},
    {'tip': 'Take a short walk during lunch break', 'icon': '🚶'},
    {'tip': 'Disconnect from screens 30 minutes before bed', 'icon': '📵'},
    {'tip': 'Express gratitude - write down 3 things you\'re thankful for', 'icon': '🙏'},
    {'tip': 'Connect with a colleague for a quick chat', 'icon': '💬'},
    {'tip': 'Listen to calming music during focused work', 'icon': '🎵'},
  ];

  @override
  void initState() {
    super.initState();
    EngagementService.trackPageView(module: 'Wellness');
    _loadMoodHistory();
  }

  Future<void> _loadMoodHistory() async {
    setState(() => _loading = true);
    try {
      final response = await _supabase
          .from('mood_entries')
          .select('*')
          .eq('user_email', widget.user['email'] ?? '')
          .order('created_at', ascending: false)
          .limit(14);
      setState(() {
        _moodHistory = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveMood() async {
    final mood = _moods[_selectedMood - 1];
    try {
      await _supabase.from('mood_entries').insert({
        'user_email': widget.user['email'] ?? '',
        'user_name': widget.user['name'] ?? '',
        'mood': _selectedMood,
        'mood_label': mood['label'],
        'note': _noteController.text,
      });
      _noteController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${mood['emoji']} Mood logged!'), backgroundColor: const Color(0xFF38a169)),
      );
      _loadMoodHistory();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save'), backgroundColor: Colors.red),
      );
    }
  }

  double _getAverageMood() {
    if (_moodHistory.isEmpty) return 0;
    return _moodHistory.map((m) => (m['mood'] as num).toDouble()).reduce((a, b) => a + b) / _moodHistory.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(title: const Text('🧘 Wellness & Mood')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mood Check-in Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1A1A1A), Color(0xFF2D3748)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('How are you feeling today?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (index) {
                      final mood = _moods[index];
                      final isSelected = _selectedMood == index + 1;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedMood = index + 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? mood['color'] : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: isSelected ? Border.all(color: mood['color'], width: 2) : null,
            
                          ),
                          child: Text(mood['emoji'], style: const TextStyle(fontSize: 32)),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a note (optional)...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveMood,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0000)),
                      child: const Text('Save Mood'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Average mood
            if (_moodHistory.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Text(_moods[_getAverageMood().round() - 1]['emoji'], style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Average Mood', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('${_getAverageMood().toStringAsFixed(1)} / 5', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ]),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Mood Trend Chart
            if (_moodHistory.length >= 3) ...[
              const Text('📈 Mood Trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                height: 200,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(_moodHistory.length, (i) => FlSpot(i.toDouble(), (_moodHistory[_moodHistory.length - 1 - i]['mood'] as num).toDouble())),
                        color: const Color(0xFFCC0000),
                        barWidth: 3,
                        isCurved: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(show: true, color: const Color(0xFFCC0000).withOpacity(0.1)),
                      ),
                    ],
                    titlesData: const FlTitlesData(show: false),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    minY: 1, maxY: 5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Wellness Tips
            const Text('💡 Wellness Tips', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: _wellnessTips.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Text(item['icon']!, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item['tip']!, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                  ]),
                )).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Mood History
            const Text('📊 Recent Mood History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
                : _moodHistory.isEmpty
                    ? const Text('No mood entries yet', style: TextStyle(color: Colors.grey))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _moodHistory.length,
                        itemBuilder: (context, index) {
                          final entry = _moodHistory[index];
                          final mood = _moods.firstWhere((m) => m['label'] == entry['mood_label'], orElse: () => _moods[2]);
                          return ListTile(
                            leading: Text(mood['emoji'], style: const TextStyle(fontSize: 24)),
                            title: Text(entry['mood_label'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: entry['note'] != null && entry['note'].toString().isNotEmpty
                                ? Text(entry['note'], maxLines: 2, overflow: TextOverflow.ellipsis)
                                : null,
                            trailing: Text(_formatDate(entry['created_at']?.toString()), style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      if (dt.day == now.day) return 'Today';
      if (dt.day == now.day - 1) return 'Yesterday';
      return '${dt.day}/${dt.month}';
    } catch (e) {
      return '';
    }
  }
}