import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class GroqAIService {
  static const String _apiKey = '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';
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static final _supabase = Supabase.instance.client;
  static List<Map<String, String>> _conversationHistory = [];

  static Future<String> getResponse(String query, Map<String, dynamic> userData) async {
    try {
      final context = await _buildUserContext(userData);
      
      _conversationHistory.add({'role': 'user', 'content': query});
      
      final messages = [
        {
          'role': 'system',
          'content': '''You are the Churchgate HRIS AI Assistant, a friendly and knowledgeable assistant for Churchgate Group employees in Nigeria.
          
          REAL EMPLOYEE DATA:
          $context
          
          CHURCHGATE GROUP INFO:
          - Premier property developer in Nigeria
          - Portfolio: World Trade Center Abuja, Churchgate Tower 1 & 2 Lagos, Churchgate Plaza Abuja, Warehouses, Ocean Terrace
          - Departments: Senior Management, Technology Group, Facility Management, HR, Sales & Marketing, Accounts & Finance, Procurement, Security, Legal, Operations, Engineering
          - Corporate Strategy 2026-2027: 4 Strategic Pillars (Occupancy & Revenue Growth, Process Simplification, Asset Reliability & Digitalization, People & Culture)
          - Values: Humility, Gratitude, Integrity, Hunger, Passion
          
          RULES:
          - ONLY use the real data provided above
          - NEVER make up information about this employee
          - If asked something not in the data, say "I don't have that information. Please contact HR at hr@churchgate.com"
          - Be conversational, friendly, and helpful
          - Keep responses concise but complete
          - Suggest follow-up questions when appropriate
          - You CAN chat about general topics and be a friendly assistant
          - Format lists clearly
          - Use emojis sparingly but appropriately'''
        }
      ];
      
      messages.addAll(_conversationHistory.map((m) => {'role': m['role'] ?? 'user', 'content': m['content'] ?? ''}));
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': messages,
          'temperature': 0.5,
          'max_tokens': 500,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['choices'][0]['message']['content'];
        _conversationHistory.add({'role': 'assistant', 'content': reply});
        if (_conversationHistory.length > 20) {
          _conversationHistory.removeAt(0);
          _conversationHistory.removeAt(0);
        }
        return reply;
      }
      return 'Sorry, I encountered an issue. Please try again or contact HR.';
    } catch (e) {
      return 'I\'m having trouble connecting. Please check your internet and try again.';
    }
  }

  static Future<String> _buildUserContext(Map<String, dynamic> user) async {
    final email = user['email'] ?? '';
    final empId = user['employee_id'] ?? '';
    final name = user['name'] ?? '';
    final dept = user['department'] ?? '';
    final position = user['position'] ?? '';
    
    String context = '''
    Name: $name
    Department: $dept
    Position: $position
    Employee ID: $empId
    Email: $email
    ''';
    
    // Real leave balance
    try {
      final leaves = await _supabase
          .from('leave_requests')
          .select('*')
          .eq('employee_id', empId)
          .eq('status', 'Approved');
      final usedDays = leaves.fold(0, (sum, l) => sum + ((l['no_of_days'] as num?)?.toInt() ?? 0));
      context += '\nLeave Balance: ${24 - usedDays} days remaining (Used $usedDays days this year)';
      
      // Pending leaves
      final pending = await _supabase
          .from('leave_requests')
          .select('*')
          .eq('employee_id', empId)
          .eq('status', 'Pending');
      if (pending.isNotEmpty) {
        context += '\nPending Leave Requests: ${pending.length}';
      }
    } catch (_) {}
    
    // Real KPI data
    try {
      final kpis = await _supabase
          .from('performance_data')
          .select('*')
          .eq('user_name', name)
          .limit(10);
      if (kpis.isNotEmpty) {
        context += '\n\nCurrent KPIs:';
        for (var k in kpis) {
          context += '\n- ${k['pillar_name']}: ${k['progress']}% (Weight: ${k['weight']}%)';
        }
      }
    } catch (_) {}
    
    // Real training data
    try {
      final training = await _supabase
          .from('lms_enrollments')
          .select('*')
          .eq('employee_id', empId);
      if (training.isNotEmpty) {
        final completed = training.where((t) => t['status'] == 'Completed').length;
        context += '\n\nTraining: ${training.length} enrolled, $completed completed';
      }
    } catch (_) {}
    
    // Team birthdays this month
    try {
      final team = await _supabase
          .from('employees')
          .select('first_name, last_name, date_of_birth')
          .eq('department', dept);
      final thisMonth = team.where((t) {
        final dob = t['date_of_birth'];
        if (dob == null) return false;
        final month = DateTime.tryParse(dob.toString())?.month;
        return month == DateTime.now().month;
      }).toList();
      if (thisMonth.isNotEmpty) {
        context += '\n\nTeam Birthdays This Month: ' + 
            thisMonth.map((t) => '${t['first_name']} ${t['last_name']}').join(', ');
      }
    } catch (_) {}
    
    // Appraisal status
    try {
      final appraisals = await _supabase
          .from('appraisals')
          .select('*')
          .eq('user_name', name)
          .order('submitted_date', ascending: false)
          .limit(1);
      if (appraisals.isNotEmpty) {
        context += '\n\nLatest Appraisal: ${appraisals[0]['status']} (${appraisals[0]['cycle_name']})';
      }
    } catch (_) {}
    
    return context;
  }

  static void clearConversation() {
    _conversationHistory.clear();
  }

  static List<String> getSuggestions(Map<String, dynamic> user) {
    return [
      'How many leave days do I have?',
      'What are my current KPIs?',
      'Show team birthdays this month',
      'What training courses are available?',
      'When is my next appraisal?',
      'What are my benefits?',
      'Tell me about Churchgate Group',
      'How do I apply for leave?',
    ];
  }
}
