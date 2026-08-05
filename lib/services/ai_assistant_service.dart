class AIAssistantService {
  static final Map<String, String> _knowledgeBase = {
    'leave': 'You have 18 annual leave days remaining. You can apply through the Leave Requests screen.',
    'appraisal': 'Your next appraisal is due in Q3 2026. Performance reviews are conducted twice yearly.',
    'birthday': 'Upcoming birthdays: Chika Ikwuegbu (May 13), Francis Asuquo (May 19), Rhoda Ajibola (May 25).',
    'training': 'Available courses: BMS Advanced, AI in FM, Leadership Excellence. Check the Training section.',
    'kpi': 'Your current performance score is 93.3%. Track KPIs in the Performance section.',
    'payroll': 'Payroll is processed on the 25th of each month. Contact Accounts for queries.',
    'clock': 'Clock in/out through the Clock In screen. GPS location is required.',
    'policy': 'HR policies are available in the Employee Handbook. Contact HR for specific questions.',
    'benefits': 'Churchgate offers health insurance (HMO), pension, annual leave, and performance bonuses.',
    'help': 'I can help with: Leave, Appraisals, Birthdays, Training, KPIs, Payroll, Clock In, Policies, Benefits.',
  };

  static String getResponse(String query) {
    final lower = query.toLowerCase();
    
    for (var entry in _knowledgeBase.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return 'I can help with leave, appraisals, training, KPIs, payroll, and more. What would you like to know?';
  }

  static List<String> getSuggestions() {
    return [
      'How many leave days do I have?',
      'When is my next appraisal?',
      'Show team birthdays this month',
      'What training courses are available?',
      'How do I clock in?',
      'What are my benefits?',
    ];
  }
}