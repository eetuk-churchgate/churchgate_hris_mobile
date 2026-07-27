import 'dart:convert';
import 'package:flutter/material.dart';

class PerformanceData {
  final int? id;
  final String? department;
  final String? pillarName;
  final double? weight;
  final double? progress;
  final String? status;
  final String? deadline;
  final List<KPIItem>? kpis;
  final String? userName;
  final String? submissionStatus;
  final String? appraisalCycle;
  final DateTime? createdAt;

  PerformanceData({
    this.id,
    this.department,
    this.pillarName,
    this.weight,
    this.progress,
    this.status,
    this.deadline,
    this.kpis,
    this.userName,
    this.submissionStatus,
    this.appraisalCycle,
    this.createdAt,
  });

  factory PerformanceData.fromJson(Map<String, dynamic> json) {
    List<KPIItem> kpis = [];
    
    if (json['kpi_data'] != null) {
      try {
        final kpiList = json['kpi_data'] is String 
            ? jsonDecode(json['kpi_data']) 
            : json['kpi_data'];
        
        if (kpiList is List) {
          kpis = kpiList.map((kpi) => KPIItem.fromJson(kpi)).toList();
        }
      } catch (e) {
        // Keep empty list if parsing fails
      }
    }

    return PerformanceData(
      id: json['id'],
      department: json['department'],
      pillarName: json['pillar_name'],
      weight: double.tryParse(json['weight']?.toString() ?? '0'),
      progress: double.tryParse(json['progress']?.toString() ?? '0'),
      status: json['status'],
      deadline: json['deadline']?.toString(),
      kpis: kpis,
      userName: json['user_name'],
      submissionStatus: json['submission_status'],
      appraisalCycle: json['appraisal_cycle'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'].toString()) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'department': department,
      'pillar_name': pillarName,
      'weight': weight,
      'progress': progress,
      'status': status,
      'deadline': deadline,
      'kpi_data': kpis != null ? jsonEncode(kpis!.map((k) => k.toJson()).toList()) : null,
      'user_name': userName,
      'submission_status': submissionStatus,
      'appraisal_cycle': appraisalCycle,
    };
  }
  
  double get calculatedProgress {
    if (kpis == null || kpis!.isEmpty) return progress ?? 0;
    
    double totalWeight = 0;
    double weightedProgress = 0;
    
    for (var kpi in kpis!) {
      final w = kpi.weight ?? 0;
      final current = double.tryParse(kpi.current ?? '0') ?? 0;
      final target = double.tryParse(kpi.target ?? '100') ?? 100;
      final kpiProgress = target > 0 ? (current / target) * 100 : 0;
      
      totalWeight += w;
      weightedProgress += (kpiProgress * w / 100);
    }
    
    return totalWeight > 0 ? weightedProgress : 0;
  }
}

class KPIItem {
  String? kpi;
  String? target;
  String? current;
  String? status;
  String? deadline;
  String? owner;
  double? weight;

  KPIItem({
    this.kpi,
    this.target,
    this.current,
    this.status,
    this.deadline,
    this.owner,
    this.weight,
  });

  factory KPIItem.fromJson(Map<String, dynamic> json) {
    return KPIItem(
      kpi: json['kpi'],
      target: json['target']?.toString(),
      current: json['current']?.toString(),
      status: json['status'],
      deadline: json['deadline']?.toString(),
      owner: json['owner'],
      weight: double.tryParse(json['weight']?.toString() ?? '0'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kpi': kpi,
      'target': target,
      'current': current,
      'status': status,
      'deadline': deadline,
      'owner': owner,
      'weight': weight,
    };
  }
  
  double get progressPercentage {
    final currentVal = double.tryParse(current ?? '0') ?? 0;
    final targetVal = double.tryParse(target ?? '100') ?? 100;
    return targetVal > 0 ? (currentVal / targetVal) * 100 : 0;
  }
}