import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/engagement_service.dart';

class LMSScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const LMSScreen({super.key, required this.user});

  @override
  State<LMSScreen> createState() => _LMSScreenState();
}

class _LMSScreenState extends State<LMSScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _myEnrollments = [];
  bool _loading = true;

  final List<Map<String, dynamic>> _allCourses = [
    // FREE COURSES - Harvard
    {'title': 'CS50: Introduction to Computer Science', 'provider': 'Harvard University', 'platform': 'edX', 'url': 'https://www.edx.org/cs50', 'category': 'Technology', 'level': 'Beginner', 'duration': '12 weeks', 'certificate': 'Free', 'price': 'Free', 'rating': 4.9, 'enrolled': '2M+', 'icon': '💻'},
    {'title': 'Data Science: R Basics', 'provider': 'Harvard University', 'platform': 'edX', 'url': 'https://www.edx.org/learn/r-programming/harvard-university-data-science-r-basics', 'category': 'Data & Analytics', 'level': 'Beginner', 'duration': '8 weeks', 'certificate': 'Free', 'price': 'Free', 'rating': 4.8, 'enrolled': '1M+', 'icon': '📊'},
    {'title': 'Contract Law: From Trust to Promise to Contract', 'provider': 'Harvard University', 'platform': 'edX', 'url': 'https://www.edx.org/learn/contract-law/harvard-university-contract-law-from-trust-to-promise-to-contract', 'category': 'Legal', 'level': 'Beginner', 'duration': '8 weeks', 'certificate': 'Free', 'price': 'Free', 'rating': 4.7, 'enrolled': '500K+', 'icon': '⚖️'},
    
    // IBM
    {'title': 'IBM Data Science Professional Certificate', 'provider': 'IBM', 'platform': 'Coursera', 'url': 'https://www.coursera.org/professional-certificates/ibm-data-science', 'category': 'Data & Analytics', 'level': 'Beginner', 'duration': '6 months', 'certificate': 'Paid', 'price': '\$39/month', 'rating': 4.7, 'enrolled': '1M+', 'icon': '📊'},
    {'title': 'IBM Cybersecurity Analyst Professional Certificate', 'provider': 'IBM', 'platform': 'Coursera', 'url': 'https://www.coursera.org/professional-certificates/ibm-cybersecurity-analyst', 'category': 'Technology', 'level': 'Intermediate', 'duration': '4 months', 'certificate': 'Paid', 'price': '\$39/month', 'rating': 4.8, 'enrolled': '200K+', 'icon': '🔒'},
    {'title': 'IT Fundamentals for Cybersecurity', 'provider': 'IBM', 'platform': 'Coursera', 'url': 'https://www.coursera.org/learn/it-fundamentals-cybersecurity', 'category': 'Technology', 'level': 'Beginner', 'duration': '4 weeks', 'certificate': 'Free', 'price': 'Free', 'rating': 4.6, 'enrolled': '100K+', 'icon': '🛡️'},
    
    // Google
    {'title': 'Google Project Management Professional Certificate', 'provider': 'Google', 'platform': 'Coursera', 'url': 'https://www.coursera.org/professional-certificates/google-project-management', 'category': 'Management', 'level': 'Beginner', 'duration': '6 months', 'certificate': 'Paid', 'price': '\$39/month', 'rating': 4.9, 'enrolled': '1.5M+', 'icon': '📋'},
    {'title': 'Google Data Analytics Professional Certificate', 'provider': 'Google', 'platform': 'Coursera', 'url': 'https://www.coursera.org/professional-certificates/google-data-analytics', 'category': 'Data & Analytics', 'level': 'Beginner', 'duration': '6 months', 'certificate': 'Paid', 'price': '\$39/month', 'rating': 4.8, 'enrolled': '2M+', 'icon': '📈'},
    {'title': 'Google IT Support Professional Certificate', 'provider': 'Google', 'platform': 'Coursera', 'url': 'https://www.coursera.org/professional-certificates/google-it-support', 'category': 'Technology', 'level': 'Beginner', 'duration': '6 months', 'certificate': 'Paid', 'price': '\$39/month', 'rating': 4.8, 'enrolled': '1M+', 'icon': '🔧'},
    
    // Udemy Free Courses
    {'title': 'Introduction to Python Programming', 'provider': 'Udemy', 'platform': 'Udemy', 'url': 'https://www.udemy.com/course/pythonforbeginners/', 'category': 'Technology', 'level': 'Beginner', 'duration': '2 hours', 'certificate': 'Free', 'price': 'Free', 'rating': 4.5, 'enrolled': '500K+', 'icon': '🐍'},
    {'title': 'Excel for Beginners', 'provider': 'Udemy', 'platform': 'Udemy', 'url': 'https://www.udemy.com/course/excel-for-beginners/', 'category': 'Data & Analytics', 'level': 'Beginner', 'duration': '3 hours', 'certificate': 'Free', 'price': 'Free', 'rating': 4.4, 'enrolled': '300K+', 'icon': '📊'},
    {'title': 'Leadership & Management Essentials', 'provider': 'Udemy', 'platform': 'Udemy', 'url': 'https://www.udemy.com/course/leadership-and-management/', 'category': 'Management', 'level': 'Intermediate', 'duration': '5 hours', 'certificate': 'Free', 'price': 'Free', 'rating': 4.3, 'enrolled': '200K+', 'icon': '👑'},
    
    // LinkedIn Learning
    {'title': 'Project Management Foundations', 'provider': 'LinkedIn Learning', 'platform': 'LinkedIn', 'url': 'https://www.linkedin.com/learning/project-management-foundations-4', 'category': 'Management', 'level': 'Beginner', 'duration': '3 hours', 'certificate': 'Free trial', 'price': 'Free trial', 'rating': 4.7, 'enrolled': '800K+', 'icon': '📋'},
    {'title': 'Communication Foundations', 'provider': 'LinkedIn Learning', 'platform': 'LinkedIn', 'url': 'https://www.linkedin.com/learning/communication-foundations-2', 'category': 'Soft Skills', 'level': 'Beginner', 'duration': '1.5 hours', 'certificate': 'Free trial', 'price': 'Free trial', 'rating': 4.6, 'enrolled': '600K+', 'icon': '💬'},
    
    // Coursera Free
    {'title': 'Financial Markets', 'provider': 'Yale University', 'platform': 'Coursera', 'url': 'https://www.coursera.org/learn/financial-markets-global', 'category': 'Finance', 'level': 'Beginner', 'duration': '7 weeks', 'certificate': 'Free', 'price': 'Free', 'rating': 4.8, 'enrolled': '1M+', 'icon': '💰'},
    {'title': 'The Science of Well-Being', 'provider': 'Yale University', 'platform': 'Coursera', 'url': 'https://www.coursera.org/learn/the-science-of-well-being', 'category': 'Wellness', 'level': 'Beginner', 'duration': '6 weeks', 'certificate': 'Free', 'price': 'Free', 'rating': 4.9, 'enrolled': '3M+', 'icon': '🧘'},
    {'title': 'AI For Everyone', 'provider': 'DeepLearning.AI', 'platform': 'Coursera', 'url': 'https://www.coursera.org/learn/ai-for-everyone', 'category': 'Technology', 'level': 'Beginner', 'duration': '4 weeks', 'certificate': 'Free', 'price': 'Free', 'rating': 4.8, 'enrolled': '1M+', 'icon': '🤖'},
    
    // Facility Management
    {'title': 'Facility Management Professional', 'provider': 'IFMA', 'platform': 'IFMA', 'url': 'https://www.ifma.org/professional-development/', 'category': 'Facility Management', 'level': 'Professional', 'duration': 'Self-paced', 'certificate': 'Paid', 'price': '\$500', 'rating': 4.6, 'enrolled': '50K+', 'icon': '🏢'},
    {'title': 'Sustainable Building Design', 'provider': 'MIT', 'platform': 'edX', 'url': 'https://www.edx.org/learn/sustainability/massachusetts-institute-of-technology-sustainable-building-design', 'category': 'Facility Management', 'level': 'Advanced', 'duration': '13 weeks', 'certificate': 'Paid', 'price': '\$150', 'rating': 4.7, 'enrolled': '100K+', 'icon': '🌱'},
    
    // HR Courses
    {'title': 'Human Resource Management', 'provider': 'SHRM', 'platform': 'SHRM', 'url': 'https://www.shrm.org/learningandcareer/learning/', 'category': 'Human Resources', 'level': 'Professional', 'duration': 'Self-paced', 'certificate': 'Paid', 'price': '\$400', 'rating': 4.8, 'enrolled': '200K+', 'icon': '👥'},
    {'title': 'Diversity & Inclusion in the Workplace', 'provider': 'University of Michigan', 'platform': 'Coursera', 'url': 'https://www.coursera.org/learn/diversity-inclusion-workplace', 'category': 'Human Resources', 'level': 'Beginner', 'duration': '4 weeks', 'certificate': 'Free', 'price': 'Free', 'rating': 4.7, 'enrolled': '500K+', 'icon': '🌈'},
    
    // Sales & Marketing
    {'title': 'Digital Marketing Specialization', 'provider': 'University of Illinois', 'platform': 'Coursera', 'url': 'https://www.coursera.org/specializations/digital-marketing', 'category': 'Sales & Marketing', 'level': 'Beginner', 'duration': '8 months', 'certificate': 'Paid', 'price': '\$39/month', 'rating': 4.7, 'enrolled': '500K+', 'icon': '📱'},
    {'title': 'Sales Training: Practical Techniques', 'provider': 'HubSpot Academy', 'platform': 'HubSpot', 'url': 'https://academy.hubspot.com/courses/sales-training', 'category': 'Sales & Marketing', 'level': 'Beginner', 'duration': '3 hours', 'certificate': 'Free', 'price': 'Free', 'rating': 4.5, 'enrolled': '300K+', 'icon': '💼'},
    
    // Finance & Accounting
    {'title': 'Financial Accounting', 'provider': 'Wharton School', 'platform': 'Coursera', 'url': 'https://www.coursera.org/learn/wharton-accounting', 'category': 'Finance', 'level': 'Beginner', 'duration': '4 weeks', 'certificate': 'Free', 'price': 'Free', 'rating': 4.7, 'enrolled': '500K+', 'icon': '📚'},
    {'title': 'Introduction to Corporate Finance', 'provider': 'Wharton School', 'platform': 'Coursera', 'url': 'https://www.coursera.org/learn/wharton-finance', 'category': 'Finance', 'level': 'Beginner', 'duration': '4 weeks', 'certificate': 'Free', 'price': 'Free', 'rating': 4.7, 'enrolled': '400K+', 'icon': '💹'},
  ];

  String _selectedCategory = 'All';
  String _selectedLevel = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    EngagementService.trackPageView(module: 'Training');
    _tabController = TabController(length: 3, vsync: this);
    _loadEnrollments();
  }

  Future<void> _loadEnrollments() async {
    try {
      final response = await _supabase.from('lms_enrollments').select('*').eq('employee_id', widget.user['employee_id'] ?? '').order('created_at', ascending: false);
      setState(() => _myEnrollments = List<Map<String, dynamic>>.from(response));
    } catch (e) {}
  }

  List<Map<String, dynamic>> get _filteredCourses {
    return _allCourses.where((c) {
      final matchesCategory = _selectedCategory == 'All' || c['category'] == _selectedCategory;
      final matchesLevel = _selectedLevel == 'All' || c['level'] == _selectedLevel;
      final matchesSearch = _searchQuery.isEmpty || c['title']!.toLowerCase().contains(_searchQuery.toLowerCase()) || c['provider']!.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesLevel && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        title: const Text('🎓 Training & Courses'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFCC0000),
          labelColor: const Color(0xFFCC0000),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'My Courses'),
            Tab(text: 'Browse All'),
            Tab(text: 'Categories'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyCourses(),
          _buildBrowseAll(),
          _buildCategories(),
        ],
      ),
    );
  }

  Widget _buildMyCourses() {
    return RefreshIndicator(
      onRefresh: _loadEnrollments,
      child: _myEnrollments.isEmpty
          ? Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('📚', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text('No courses enrolled yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: () => _tabController.animateTo(1), child: const Text('Browse Courses')),
              ]),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _myEnrollments.length,
              itemBuilder: (context, index) {
                final enrollment = _myEnrollments[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFCC0000).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.school, color: Color(0xFFCC0000))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(enrollment['course_name'] ?? 'Course', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(enrollment['status'] ?? 'In Progress', style: TextStyle(color: enrollment['status'] == 'Completed' ? const Color(0xFF38a169) : const Color(0xFFd69e2e), fontSize: 12)),
                    ])),
                    if (enrollment['progress'] != null)
                      SizedBox(width: 50, child: Stack(children: [
                        CircularProgressIndicator(value: (enrollment['progress'] as num).toDouble() / 100, color: const Color(0xFFCC0000), backgroundColor: Colors.grey.shade200),
                        Center(child: Text('${enrollment['progress']}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                      ])),
                  ]),
                );
              },
            ),
    );
  }

  Widget _buildBrowseAll() {
    final courses = _filteredCourses;
    final categories = {'All', ..._allCourses.map((c) => c['category'] as String)};
    final levels = {'All', ..._allCourses.map((c) => c['level'] as String)};

    return Column(
      children: [
        // Search
        Padding(padding: const EdgeInsets.all(12), child: TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(hintText: 'Search courses...', prefixIcon: const Icon(Icons.search, color: Color(0xFFCC0000)), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
        )),
        // Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            ...categories.map((cat) => _filterChip(cat, _selectedCategory, () => setState(() => _selectedCategory = cat))),
            const SizedBox(width: 8),
            ...levels.map((lvl) => _filterChip(lvl, _selectedLevel, () => setState(() => _selectedLevel = lvl), isLevel: true)),
          ]),
        ),
        const SizedBox(height: 8),
        // Course list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return _buildCourseCard(course);
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String selected, VoidCallback onTap, {bool isLevel = false}) {
    final isSelected = selected == label;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? (isLevel ? const Color(0xFF3182ce) : const Color(0xFFCC0000)) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300),
          ),
          child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
        ),
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(course['icon'] ?? '📚', style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(course['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text('${course['provider']} • ${course['platform']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ])),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _infoBadge(course['level'] ?? '', Icons.signal_cellular_alt),
          const SizedBox(width: 6),
          _infoBadge(course['duration'] ?? '', Icons.access_time),
          const SizedBox(width: 6),
          _infoBadge(course['price'] ?? '', Icons.attach_money),
          const Spacer(),
          Icon(Icons.star, color: Colors.amber, size: 14),
          const SizedBox(width: 2),
          Text('${course['rating']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () async {
            final url = Uri.parse(course['url'] ?? '');
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0000)),
          child: const Text('Enroll Now'),
        )),
      ]),
    );
  }

  Widget _infoBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: Colors.grey.shade600),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(color: Colors.grey.shade700, fontSize: 10)),
      ]),
    );
  }

  Widget _buildCategories() {
    final cats = _allCourses.map((c) => c['category'] as String).toSet().toList();
    final icons = {'Technology': '💻', 'Data & Analytics': '📊', 'Management': '📋', 'Finance': '💰', 'Human Resources': '👥', 'Sales & Marketing': '📱', 'Facility Management': '🏢', 'Legal': '⚖️', 'Soft Skills': '💬', 'Wellness': '🧘'};
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(12),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: cats.map((cat) {
        final count = _allCourses.where((c) => c['category'] == cat).length;
        return GestureDetector(
          onTap: () {
            setState(() { _selectedCategory = cat; });
            _tabController.animateTo(1);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)]),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(icons[cat] ?? '📚', style: const TextStyle(fontSize: 36)),
              const SizedBox(height: 8),
              Text(cat, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 4),
              Text('$count courses', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            ]),
          ),
        );
      }).toList(),
    );
  }
}