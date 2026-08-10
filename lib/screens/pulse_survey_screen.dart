import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PulseSurveyScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const PulseSurveyScreen({super.key, required this.user});

  @override
  State<PulseSurveyScreen> createState() => _PulseSurveyScreenState();
}

class _PulseSurveyScreenState extends State<PulseSurveyScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  List<Map<String, dynamic>> _surveys = [];
  List<Map<String, dynamic>> _myResponses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final surveys = await _supabase.from('pulse_surveys').select('*').eq('is_active', true).order('created_at', ascending: false);
    final responses = await _supabase.from('pulse_responses').select('*, pulse_surveys(question)').eq('employee_id', widget.user['employee_id']).order('created_at', ascending: false);
    setState(() {
      _surveys = List<Map<String, dynamic>>.from(surveys);
      _myResponses = List<Map<String, dynamic>>.from(responses);
      _loading = false;
    });
  }

  Future<void> _answerSurvey(Map<String, dynamic> survey) async {
    int rating = 3;
    final commentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(survey['question'] ?? 'Survey'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
                  return IconButton(
                    icon: Icon(i < rating ? Icons.star : Icons.star_border, color: const Color(0xFFD4AF37), size: 36),
                    onPressed: () => setDialogState(() => rating = i + 1),
                  );
                })),
                Text(rating == 5 ? 'Excellent!' : rating == 4 ? 'Good' : rating == 3 ? 'Okay' : rating == 2 ? 'Not Great' : 'Poor', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 12),
                TextField(controller: commentController, decoration: const InputDecoration(labelText: 'Comment (optional)', border: OutlineInputBorder()), maxLines: 2),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Skip')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _supabase.from('pulse_responses').upsert({
                    'survey_id': survey['id'],
                    'employee_id': widget.user['employee_id'],
                    'employee_name': widget.user['name'],
                    'rating': rating,
                    'comment': commentController.text.trim(),
                  });
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Response recorded! ✅'), backgroundColor: Colors.green));
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0000)),
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Pulse Surveys'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD4AF37),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [Tab(text: 'Active'), Tab(text: 'My Responses')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
          : TabBarView(
              controller: _tabController,
              children: [_buildActiveSurveys(), _buildMyResponses()],
            ),
    );
  }

  Widget _buildActiveSurveys() {
    if (_surveys.isEmpty) return const Center(child: Text('No active surveys'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _surveys.length,
      itemBuilder: (context, index) {
        final s = _surveys[index];
        final alreadyAnswered = _myResponses.any((r) => r['survey_id'] == s['id']);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: alreadyAnswered ? Colors.green.withOpacity(0.1) : const Color(0xFFCC0000).withOpacity(0.1), child: Icon(alreadyAnswered ? Icons.check : Icons.edit, color: alreadyAnswered ? Colors.green : const Color(0xFFCC0000))),
            title: Text(s['question'] ?? ''),
            subtitle: Text(alreadyAnswered ? 'Already answered' : 'Tap to answer'),
            trailing: alreadyAnswered ? null : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: alreadyAnswered ? null : () => _answerSurvey(s),
          ),
        );
      },
    );
  }

  Widget _buildMyResponses() {
    if (_myResponses.isEmpty) return const Center(child: Text('No responses yet'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myResponses.length,
      itemBuilder: (context, index) {
        final r = _myResponses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) => Icon(i < (r['rating'] ?? 3) ? Icons.star : Icons.star_border, color: const Color(0xFFD4AF37), size: 16))),
            title: Text(r['pulse_surveys']?['question'] ?? 'Survey', style: const TextStyle(fontSize: 13)),
            subtitle: r['comment'] != null && r['comment'].toString().isNotEmpty ? Text(r['comment'], style: TextStyle(fontSize: 11, color: Colors.grey.shade600)) : null,
            trailing: Text(DateFormat('MMM d').format(DateTime.parse(r['created_at'].toString())), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ),
        );
      },
    );
  }
}