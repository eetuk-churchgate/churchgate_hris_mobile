import '../services/engagement_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AttendanceReportScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const AttendanceReportScreen({super.key, required this.user});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _attendanceData = [];
  List<Map<String, dynamic>> _gpsData = [];
  List<Map<String, dynamic>> _combinedReport = [];
  bool _loading = true;
  DateTime _selectedDate = DateTime.now();
  String _selectedSource = 'All';
  String _selectedStatus = 'All';

  @override
  void initState() {
    super.initState();
    EngagementService.trackPageView(module: 'Attendance Report');
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      final biometric = await _supabase
          .from('attendance')
          .select()
          .eq('sync_date', dateStr)
          .order('employee_name', ascending: true);
      
      final gps = await _supabase
          .from('gps_attendance')
          .select()
          .eq('sync_date', dateStr)
          .order('employee_name', ascending: true);

      setState(() {
        _attendanceData = List<Map<String, dynamic>>.from(biometric);
        _gpsData = List<Map<String, dynamic>>.from(gps);
        _combinedReport = _generateCombinedReport();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _generateCombinedReport() {
    Map<String, Map<String, dynamic>> employeeMap = {};

    for (var record in _attendanceData) {
      final empId = record['employee_id']?.toString() ?? '';
      if (empId.isEmpty) continue;

      if (!employeeMap.containsKey(empId)) {
        employeeMap[empId] = {
          'employee_id': empId,
          'employee_name': record['employee_name'] ?? 'Unknown',
          'date': record['sync_date'] ?? '',
          'biometric_in': record['in_time'] ?? '',
          'biometric_out': record['out_time'] ?? '',
          'biometric_hours': record['work_hours']?.toString() ?? '0',
          'biometric_source': record['source'] ?? '',
          'biometric_status': record['status'] ?? 'Absent',
          'gps_in': '',
          'gps_out': '',
          'gps_location': '',
          'gps_status': '',
        };
      }

      final entry = employeeMap[empId]!;
      final inTime = record['in_time']?.toString() ?? '';
      if (inTime.isNotEmpty) entry['biometric_in'] = inTime;
      final outTime = record['out_time']?.toString() ?? '';
      if (outTime.isNotEmpty) entry['biometric_out'] = outTime;
      final hours = record['work_hours']?.toString() ?? '';
      if (hours.isNotEmpty) entry['biometric_hours'] = hours;
      final status = record['status']?.toString() ?? '';
      if (status.isNotEmpty) entry['biometric_status'] = status;
    }

    for (var record in _gpsData) {
      final empId = record['employee_id']?.toString() ?? '';
      if (empId.isEmpty) continue;
      
      final clockType = record['clock_type']?.toString() ?? '';

      if (!employeeMap.containsKey(empId)) {
        employeeMap[empId] = {
          'employee_id': empId,
          'employee_name': record['employee_name'] ?? 'Unknown',
          'date': record['sync_date'] ?? '',
          'biometric_in': '',
          'biometric_out': '',
          'biometric_hours': '0',
          'biometric_source': '',
          'biometric_status': 'Absent',
          'gps_in': clockType == 'In' ? (record['clock_time']?.toString() ?? '') : '',
          'gps_out': clockType == 'Out' ? (record['clock_time']?.toString() ?? '') : '',
          'gps_location': record['location_name']?.toString() ?? '',
          'gps_status': record['status']?.toString() ?? 'Pending',
        };
      } else {
        final entry = employeeMap[empId]!;
        if (clockType == 'In') {
          entry['gps_in'] = record['clock_time']?.toString() ?? '';
        } else if (clockType == 'Out') {
          entry['gps_out'] = record['clock_time']?.toString() ?? '';
        }
        final location = record['location_name']?.toString() ?? '';
        if (location.isNotEmpty) entry['gps_location'] = location;
        final gpsStatus = record['status']?.toString() ?? '';
        if (gpsStatus.isNotEmpty) entry['gps_status'] = gpsStatus;
      }
    }

    for (var entry in employeeMap.values) {
      final hasBiometric = entry['biometric_status'].toString().isNotEmpty && 
                           entry['biometric_status'] != 'Absent';
      final hasGPS = entry['gps_status'].toString().isNotEmpty && 
                     entry['gps_status'] == 'Approved';
      
      entry['final_status'] = (hasBiometric || hasGPS) ? 'Present' : 'Absent';
      
      double totalHours = 0;
      final hoursStr = entry['biometric_hours'].toString();
      if (hoursStr.isNotEmpty) {
        totalHours += double.tryParse(hoursStr) ?? 0;
      }
      entry['total_hours'] = totalHours.toStringAsFixed(1);
    }

    return employeeMap.values.toList()
      ..sort((a, b) => (a['employee_name'] ?? '').compareTo(b['employee_name'] ?? ''));
  }

  List<Map<String, dynamic>> get _filteredReport {
    return _combinedReport.where((record) {
      bool matchesSource = true;
      bool matchesStatus = true;

      if (_selectedSource == 'Biometric') {
        matchesSource = record['biometric_status'].toString().isNotEmpty && 
                       record['biometric_status'] != 'Absent';
      } else if (_selectedSource == 'GPS') {
        matchesSource = record['gps_status'].toString().isNotEmpty;
      }

      if (_selectedStatus != 'All') {
        matchesStatus = record['final_status'] == _selectedStatus;
      }

      return matchesSource && matchesStatus;
    }).toList();
  }

  Map<String, int> get _stats {
    final total = _combinedReport.length;
    final present = _combinedReport.where((r) => r['final_status'] == 'Present').length;
    final absent = total - present;
    return {'total': total, 'present': present, 'absent': absent};
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadReport();
    }
  }

  Future<void> _downloadCSV() async {
    try {
      // Generate CSV content
      StringBuffer csv = StringBuffer();
      csv.writeln('Employee Name,Employee ID,Biometric In,Biometric Out,Biometric Hours,GPS In,GPS Out,GPS Location,Total Hours,Status');
      
      for (var record in _filteredReport) {
        csv.writeln('"${record['employee_name']}","${record['employee_id']}","${record['biometric_in']}","${record['biometric_out']}","${record['biometric_hours']}","${record['gps_in']}","${record['gps_out']}","${record['gps_location']}","${record['total_hours']}","${record['final_status']}"');
      }

      // Add summary
      csv.writeln('');
      csv.writeln('Summary');
      csv.writeln('Date,${DateFormat('yyyy-MM-dd').format(_selectedDate)}');
      csv.writeln('Total Employees,${_stats['total']}');
      csv.writeln('Present,${_stats['present']}');
      csv.writeln('Absent,${_stats['absent']}');
      csv.writeln('Generated,${DateTime.now().toString()}');

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'attendance_report_${DateFormat('yyyyMMdd').format(_selectedDate)}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csv.toString());

      // Share the file
      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Attendance Report - ${DateFormat('MMM d, yyyy').format(_selectedDate)}',
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report saved: $fileName'),
            backgroundColor: const Color(0xFF38A169),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final filtered = _filteredReport;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: filtered.isNotEmpty ? _downloadCSV : null,
            tooltip: 'Download CSV Report',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1A1A1A),
            child: Row(
              children: [
                _statBox('Total', stats['total'].toString(), Colors.white),
                const SizedBox(width: 12),
                _statBox('Present', stats['present'].toString(), const Color(0xFF38A169)),
                const SizedBox(width: 12),
                _statBox('Absent', stats['absent'].toString(), const Color(0xFFCC0000)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                InkWell(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8DCC8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: Color(0xFFCC0000)),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_drop_down, color: Color(0xFFCC0000)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('Source', ['All', 'Biometric', 'GPS'], _selectedSource, (val) {
                        setState(() => _selectedSource = val);
                      }),
                      const SizedBox(width: 8),
                      _filterChip('Status', ['All', 'Present', 'Absent'], _selectedStatus, (val) {
                        setState(() => _selectedStatus = val);
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _legendDot(const Color(0xFF3182CE), 'Biometric'),
                const SizedBox(width: 16),
                _legendDot(const Color(0xFF38A169), 'GPS'),
                const SizedBox(width: 16),
                _legendDot(const Color(0xFFD4AF37), 'Both'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('No records for ${DateFormat('MMM d, yyyy').format(_selectedDate)}',
                                style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReport,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return _buildEmployeeRow(filtered[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeRow(Map<String, dynamic> record) {
    final hasBiometric = record['biometric_status'].toString().isNotEmpty && 
                         record['biometric_status'] != 'Absent';
    final hasGPS = record['gps_status'].toString() == 'Approved';
    final isPresent = record['final_status'] == 'Present';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: isPresent ? const Color(0xFF38A169).withOpacity(0.1) : const Color(0xFFCC0000).withOpacity(0.1),
          child: Icon(
            isPresent ? Icons.check_circle : Icons.cancel,
            color: isPresent ? const Color(0xFF38A169) : const Color(0xFFCC0000),
            size: 20,
          ),
        ),
        title: Text(
          record['employee_name'] ?? 'Unknown',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'ID: ${record['employee_id']} | ${record['total_hours']}h',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasBiometric)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF3182CE).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Bio', style: TextStyle(fontSize: 9, color: Color(0xFF3182CE))),
              ),
            if (hasGPS)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF38A169).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('GPS', style: TextStyle(fontSize: 9, color: Color(0xFF38A169))),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                const Divider(),
                if (hasBiometric) ...[
                  _detailRow('Biometric In', record['biometric_in'] ?? 'N/A'),
                  _detailRow('Biometric Out', record['biometric_out'] ?? 'N/A'),
                  _detailRow('Biometric Hours', '${record['biometric_hours']}h'),
                  _detailRow('Source', record['biometric_source'] ?? 'N/A'),
                ],
                if (hasBiometric && hasGPS) const Divider(),
                if (hasGPS) ...[
                  _detailRow('GPS In', record['gps_in'] ?? 'N/A'),
                  _detailRow('GPS Out', record['gps_out'] ?? 'N/A'),
                  _detailRow('GPS Location', record['gps_location'] ?? 'N/A'),
                  _detailRow('GPS Status', record['gps_status'] ?? 'N/A'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, List<String> options, String selected, Function(String) onSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8DCC8)),
      ),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selected,
              isDense: true,
              style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A1A)),
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: (val) => onSelected(val ?? 'All'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }
}
