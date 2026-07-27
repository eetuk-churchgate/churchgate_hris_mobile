import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class LMSScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const LMSScreen({super.key, required this.user});

  @override
  State<LMSScreen> createState() => _LMSScreenState();
}

class _LMSScreenState extends State<LMSScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _courses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('lms_courses')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);
      
      setState(() {
        _courses = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Training & Courses')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
              ? const Center(child: Text('No courses available'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _courses.length,
                  itemBuilder: (context, index) {
                    final course = _courses[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFCC0000).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    course['provider'] ?? 'Training',
                                    style: const TextStyle(color: Color(0xFFCC0000), fontSize: 11),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    course['level'] ?? 'All Levels',
                                    style: TextStyle(color: Colors.blue.shade700, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              course['title'] ?? 'Course',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            if (course['description'] != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                course['description'],
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text('${course['duration_hours'] ?? 0}h',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                const SizedBox(width: 16),
                                if (course['certification_type'] != null) ...[
                                  Icon(Icons.verified, size: 16, color: const Color(0xFFD4AF37)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(course['certification_type'],
                                        style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12)),
                                  ),
                                ],
                              ],
                            ),
                            if (course['skills_gained'] != null) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                children: course['skills_gained']
                                    .toString()
                                    .split(',')
                                    .map((skill) => Chip(
                                          label: Text(skill.trim(), style: const TextStyle(fontSize: 10)),
                                          backgroundColor: const Color(0xFFD4AF37).withOpacity(0.1),
                                          padding: EdgeInsets.zero,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ))
                                    .toList(),
                              ),
                            ],
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (course['external_url'] != null) {
                                    final uri = Uri.parse(course['external_url']);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  }
                                },
                                icon: const Icon(Icons.open_in_browser, size: 18),
                                label: const Text('Start Course'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFCC0000),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}