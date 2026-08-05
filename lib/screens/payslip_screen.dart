import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/engagement_service.dart';

class PayslipScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const PayslipScreen({super.key, required this.user});

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _payslips = [];
  bool _loading = true;
  double _totalGross = 0;
  double _totalNet = 0;

  @override
  void initState() {
    super.initState();
    EngagementService.trackPageView(module: 'Payslips');
    _loadPayslips();
  }

  Future<void> _loadPayslips() async {
    setState(() => _loading = true);
    try {
      final response = await _supabase
          .from('payslips')
          .select('*')
          .eq('employee_id', widget.user['employee_id'] ?? '')
          .order('created_at', ascending: false);

      double gross = 0, net = 0;
      for (var slip in response) {
        gross += (slip['gross_salary'] as num?)?.toDouble() ?? 0;
        net += (slip['net_salary'] as num?)?.toDouble() ?? 0;
      }

      setState(() {
        _payslips = List<Map<String, dynamic>>.from(response);
        _totalGross = gross;
        _totalNet = net;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(title: const Text('💰 My Payslips')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // YTD Summary Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF1A1A1A), Color(0xFF2D3748)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text('Year to Date Summary', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _ytdItem('Gross Pay', '₦${_formatAmount(_totalGross)}'),
                            _ytdItem('Deductions', '₦${_formatAmount(_totalGross - _totalNet)}'),
                            _ytdItem('Net Pay', '₦${_formatAmount(_totalNet)}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Payslip list
                  if (_payslips.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(40),
                      child: const Column(children: [
                        Text('📄', style: TextStyle(fontSize: 48)),
                        SizedBox(height: 12),
                        Text('No payslips available', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ]),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _payslips.length,
                      itemBuilder: (context, index) {
                        final slip = _payslips[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)]),
                          child: ListTile(
                            leading: Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(color: const Color(0xFFCC0000).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.receipt_long, color: Color(0xFFCC0000)),
                            ),
                            title: Text(slip['month_year'] ?? 'Payslip', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('Gross: ₦${_formatAmount(slip['gross_salary'])} | Net: ₦${_formatAmount(slip['net_salary'])}'),
                            trailing: slip['file_url'] != null
                                ? IconButton(
                                    icon: const Icon(Icons.download_rounded, color: Color(0xFFCC0000)),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('📥 Downloading payslip...'), backgroundColor: Color(0xFF38a169)),
                                      );
                                    },
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _ytdItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0';
    final parts = amount.toString().split('.');
    final intPart = parts[0].replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  }
}