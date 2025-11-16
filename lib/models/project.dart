import 'package:flutter/material.dart';

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
    // teamMemberIds가 없거나 null인 경우 빈 리스트 반환
    List<String> teamMemberIds = [];
    if (json.containsKey('teamMemberIds') && json['teamMemberIds'] != null) {
      try {
        final memberIds = json['teamMemberIds'];
        if (memberIds is List) {
          teamMemberIds = memberIds.map((e) => e.toString()).toList();
        }
      } catch (e) {
        teamMemberIds = [];
      }
    }
    
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      color: Color(json['color'] ?? 0xFF2196F3),
      teamMemberIds: teamMemberIds,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
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

