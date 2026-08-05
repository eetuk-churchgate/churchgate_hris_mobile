import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/engagement_service.dart';

class NewsFeedScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const NewsFeedScreen({super.key, required this.user});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _posts = [];
  List<int> _likedPosts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    EngagementService.trackPageView(module: 'News Feed');
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    try {
      final response = await _supabase.from('news_feed').select('*').order('created_at', ascending: false).limit(30);
      final likes = await _supabase.from('news_likes').select('post_id').eq('user_email', widget.user['email'] ?? '');
      setState(() {
        _posts = List<Map<String, dynamic>>.from(response);
        _likedPosts = likes.map<int>((l) => l['post_id'] as int).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _likePost(int postId) async {
    try {
      if (_likedPosts.contains(postId)) {
        await _supabase.from('news_likes').delete().eq('post_id', postId).eq('user_email', widget.user['email'] ?? '');
        setState(() => _likedPosts.remove(postId));
      } else {
        await _supabase.from('news_likes').insert({'post_id': postId, 'user_email': widget.user['email'] ?? ''});
        setState(() => _likedPosts.add(postId));
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _commentOnPost(int postId) async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            const Text('💬 Add Comment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(controller: controller, autofocus: true, maxLines: 3, decoration: InputDecoration(hintText: 'Write a comment...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0000)), child: const Text('Post Comment'))),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _supabase.from('news_comments').insert({'post_id': postId, 'user_name': widget.user['name'], 'user_email': widget.user['email'], 'comment': result});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Comment posted!'), backgroundColor: Color(0xFF38a169)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(title: const Text('📰 Company News')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
          : _posts.isEmpty
              ? const Center(child: Text('No announcements yet', style: TextStyle(color: Colors.grey, fontSize: 16)))
              : RefreshIndicator(
                  onRefresh: _loadPosts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      return _buildNewsCard(post);
                    },
                  ),
                ),
    );
  }

  Widget _buildNewsCard(Map<String, dynamic> post) {
    final isLiked = _likedPosts.contains(post['id']);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post['image_url'] != null)
            ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), child: Image.network(post['image_url'], height: 200, width: double.infinity, fit: BoxFit.cover)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFCC0000).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(post['category'] ?? 'General', style: const TextStyle(color: Color(0xFFCC0000), fontSize: 11, fontWeight: FontWeight.w600))),
                const Spacer(),
                Icon(Icons.access_time, size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(_formatDate(post['created_at']?.toString()), style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ]),
              const SizedBox(height: 10),
              Text(post['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 6),
              Text(post['content'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.4)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    GestureDetector(
                      onTap: () => _likePost(post['id']),
                      child: Row(children: [
                        Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? const Color(0xFFCC0000) : Colors.grey, size: 20),
                        const SizedBox(width: 6),
                        Text('${post['likes'] ?? 0} Likes', style: TextStyle(color: isLiked ? const Color(0xFFCC0000) : Colors.grey.shade600, fontSize: 12)),
                      ]),
                    ),
                    GestureDetector(
                      onTap: () => _commentOnPost(post['id']),
                      child: Row(children: [
                        const Icon(Icons.comment_outlined, color: Colors.grey, size: 20),
                        const SizedBox(width: 6),
                        Text('Comment', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ]),
                    ),
                    Row(children: [
                      const Icon(Icons.share_outlined, color: Colors.grey, size: 20),
                      const SizedBox(width: 6),
                      Text('Share', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ]),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) return 'Today ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      if (dt.day == now.day - 1) return 'Yesterday';
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (e) {
      return '';
    }
  }
}