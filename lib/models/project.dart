import 'package:flutter/material.dart';
import '../utils/date_utils.dart';

/// 프로젝트 모델 클래스
class Project {
  final String id;
  final String name;
  final String? description;
  final Color color;
  final List<String> teamMemberIds; // 팀원 사용자 ID 목록
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    required this.id,
    required this.name,
    this.description,
    this.color = const Color(0xFF2196F3),
    List<String>? teamMemberIds,
    required this.createdAt,
    required this.updatedAt,
  }) : teamMemberIds = teamMemberIds ?? [];

  /// JSON으로 변환 (저장용)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color.value,
      'teamMemberIds': teamMemberIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// JSON에서 Project 객체 생성
  factory Project.fromJson(Map<String, dynamic> json) {
    // team_member_ids (API 응답) 또는 teamMemberIds (로컬 저장) 처리
    List<String> teamMemberIds = [];
    final memberIdsKey = json.containsKey('team_member_ids') 
        ? 'team_member_ids' 
        : (json.containsKey('teamMemberIds') ? 'teamMemberIds' : null);
    
    if (memberIdsKey != null && json[memberIdsKey] != null) {
      try {
        final memberIds = json[memberIdsKey];
        if (memberIds is List) {
          teamMemberIds = memberIds.map((e) => e.toString()).toList();
        }
      } catch (e) {
        teamMemberIds = [];
      }
    }
    
    // 필드명 변환 (API는 snake_case, Flutter는 camelCase)
    final createdAtKey = json.containsKey('created_at') ? 'created_at' : 'createdAt';
    final updatedAtKey = json.containsKey('updated_at') ? 'updated_at' : 'updatedAt';
    
    // 날짜 파싱 (null 처리 포함)
    DateTime parseDate(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      if (dateValue is String) {
        return parseUtcToLocalOrNull(dateValue) ?? DateTime.now();
      }
      return DateTime.now();
    }
    
    // null 안전 처리
    final id = json['id'] as String?;
    final name = json['name'] as String?;
    
    if (id == null || name == null) {
      throw Exception('프로젝트 데이터에 필수 필드(id, name)가 없습니다: $json');
    }
    
    return Project(
      id: id,
      name: name,
      description: json['description'] as String?,
      color: Color(json['color'] is int ? json['color'] as int : (json['color'] is String ? int.parse(json['color'] as String) : 0xFF2196F3)),
      teamMemberIds: teamMemberIds,
      createdAt: parseDate(json[createdAtKey]),
      updatedAt: parseDate(json[updatedAtKey]),
    );
  }

  /// 프로젝트 복사본 생성
  Project copyWith({
    String? id,
    String? name,
    String? description,
    Color? color,
    List<String>? teamMemberIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      teamMemberIds: teamMemberIds ?? this.teamMemberIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

