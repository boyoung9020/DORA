import 'package:flutter/material.dart';
import '../../models/github.dart';

/// 각 커밋의 그래프 레이아웃 정보
class GitGraphNode {
  final int lane; // 세로 레인 번호 (0 = 가장 왼쪽)
  final List<GitGraphEdge> edges; // 부모 커밋으로 향하는 선

  GitGraphNode({required this.lane, required this.edges});
}

class GitGraphEdge {
  final int fromLane;
  final int toLane;
  final int toRow;
  final Color color;

  GitGraphEdge(
      {required this.fromLane,
      required this.toLane,
      required this.toRow,
      required this.color});
}

/// 커밋 목록으로부터 그래프 노드 정보를 계산
class GitGraphLayout {
  final List<GitGraphNode> nodes;
  final int maxLane;

  GitGraphLayout({required this.nodes, required this.maxLane});

  static const _laneColors = [
    Color(0xFFE07040), // 메인 브랜치 - 주황/갈색 (앱 테마)
    Color(0xFF4A90D9), // 파란색
    Color(0xFF50B83C), // 초록색
    Color(0xFFB4529A), // 보라색
    Color(0xFFD4A843), // 노란색
    Color(0xFF3BBFBF), // 청록색
    Color(0xFFE06060), // 빨강
    Color(0xFF808080), // 회색
  ];

  static Color colorForLane(int lane) =>
      _laneColors[lane % _laneColors.length];

  /// 커밋 리스트를 받아 레인 배치 및 엣지 계산
  static GitGraphLayout compute(List<GitHubCommit> commits) {
    if (commits.isEmpty) {
      return GitGraphLayout(nodes: [], maxLane: 0);
    }

    // sha -> row 인덱스
    final shaToRow = <String, int>{};
    for (int i = 0; i < commits.length; i++) {
      shaToRow[commits[i].sha] = i;
    }

    // 레인 할당: 각 레인을 어떤 sha가 "예약"하고 있는지 추적
    final activeLanes = <String?>[]; // 각 레인에 예약된 다음 sha (null = 비어있음)
    final nodeList = <GitGraphNode>[];
    int maxLane = 0;

    for (int row = 0; row < commits.length; row++) {
      final commit = commits[row];
      final sha = commit.sha;
      final parentShas = commit.parents;

      // 이 커밋이 어느 레인에 배치될지 찾기
      int lane = activeLanes.indexOf(sha);
      if (lane == -1) {
        // 새 레인 할당 (비어있는 레인 찾거나 새로 추가)
        lane = activeLanes.indexOf(null);
        if (lane == -1) {
          lane = activeLanes.length;
          activeLanes.add(sha);
        } else {
          activeLanes[lane] = sha;
        }
      }

      // 현재 레인 해제
      activeLanes[lane] = null;

      final edges = <GitGraphEdge>[];

      if (parentShas.isNotEmpty) {
        // 첫 번째 부모 (직선 연결 — 같은 레인 유지)
        final firstParent = parentShas[0];
        final firstParentRow = shaToRow[firstParent];

        // 첫 번째 부모를 현재 레인에 예약
        if (activeLanes[lane] == null) {
          activeLanes[lane] = firstParent;
        }

        if (firstParentRow != null) {
          edges.add(GitGraphEdge(
            fromLane: lane,
            toLane: lane,
            toRow: firstParentRow,
            color: colorForLane(lane),
          ));
        }

        // 나머지 부모들 (머지 — 다른 레인에서 합류하는 선)
        for (int p = 1; p < parentShas.length; p++) {
          final parentSha = parentShas[p];
          final parentRow = shaToRow[parentSha];

          // 이미 예약된 레인 찾기
          int parentLane = activeLanes.indexOf(parentSha);
          if (parentLane == -1) {
            // 새 레인 할당
            parentLane = activeLanes.indexOf(null);
            if (parentLane == -1) {
              parentLane = activeLanes.length;
              activeLanes.add(parentSha);
            } else {
              activeLanes[parentLane] = parentSha;
            }
          }

          if (parentRow != null) {
            edges.add(GitGraphEdge(
              fromLane: lane,
              toLane: parentLane,
              toRow: parentRow,
              color: colorForLane(parentLane),
            ));
          }
        }
      }

      nodeList.add(GitGraphNode(lane: lane, edges: edges));
      if (lane > maxLane) maxLane = lane;
      for (int l = 0; l < activeLanes.length; l++) {
        if (l > maxLane && activeLanes[l] != null) maxLane = l;
      }
    }

    return GitGraphLayout(nodes: nodeList, maxLane: maxLane);
  }
}

/// 그래프 선을 그리는 CustomPainter
class GitGraphPainter extends CustomPainter {
  final GitGraphLayout layout;
  final double rowHeight;
  final double laneWidth;
  final double nodeRadius;
  final int startRow;
  final int endRow;

  GitGraphPainter({
    required this.layout,
    this.rowHeight = 52,
    this.laneWidth = 16,
    this.nodeRadius = 4.5,
    this.startRow = 0,
    this.endRow = -1,
  });

  double _laneX(int lane) => laneWidth * lane + laneWidth / 2;
  double _rowY(int row) => rowHeight * (row - startRow) + rowHeight / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final end = endRow < 0 ? layout.nodes.length : endRow;

    // 세로 활성 레인 선 (배경 선)
    final activeRanges = <int, List<int>>{}; // lane -> [startRow, endRow]
    for (int row = startRow; row < end && row < layout.nodes.length; row++) {
      final node = layout.nodes[row];
      for (final edge in node.edges) {
        // 세로선 범위
        for (int lane in [edge.fromLane, edge.toLane]) {
          if (!activeRanges.containsKey(lane)) {
            activeRanges[lane] = [row, edge.toRow];
          } else {
            if (row < activeRanges[lane]![0]) activeRanges[lane]![0] = row;
            if (edge.toRow > activeRanges[lane]![1]) {
              activeRanges[lane]![1] = edge.toRow;
            }
          }
        }
      }
    }

    // 엣지 그리기
    for (int row = startRow; row < end && row < layout.nodes.length; row++) {
      final node = layout.nodes[row];
      for (final edge in node.edges) {
        final paint = Paint()
          ..color = edge.color.withValues(alpha: 0.7)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;

        final fromX = _laneX(edge.fromLane);
        final fromY = _rowY(row);
        final toX = _laneX(edge.toLane);
        final toRow = edge.toRow.clamp(startRow, end - 1);
        final toY = _rowY(toRow);

        if (edge.fromLane == edge.toLane) {
          // 직선
          canvas.drawLine(Offset(fromX, fromY), Offset(toX, toY), paint);
        } else {
          // 머지 커브
          final path = Path();
          path.moveTo(fromX, fromY);
          final midY = fromY + (toY - fromY) * 0.4;
          path.cubicTo(fromX, midY, toX, midY, toX, toY);
          canvas.drawPath(path, paint);
        }
      }
    }

    // 노드 (원) 그리기
    for (int row = startRow; row < end && row < layout.nodes.length; row++) {
      final node = layout.nodes[row];
      final cx = _laneX(node.lane);
      final cy = _rowY(row);
      final color = GitGraphLayout.colorForLane(node.lane);
      final isMerge = layout.nodes[row].edges.length > 1;

      // 바깥 원 (흰 테두리)
      canvas.drawCircle(
        Offset(cx, cy),
        nodeRadius + 2,
        Paint()..color = Colors.white,
      );

      // 안쪽 원
      canvas.drawCircle(
        Offset(cx, cy),
        nodeRadius,
        Paint()
          ..color = color
          ..style = isMerge ? PaintingStyle.fill : PaintingStyle.fill,
      );

      // 머지 커밋은 속이 빈 원
      if (isMerge) {
        canvas.drawCircle(
          Offset(cx, cy),
          nodeRadius - 1.5,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          Offset(cx, cy),
          nodeRadius - 1.5,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant GitGraphPainter old) =>
      old.layout != layout ||
      old.startRow != startRow ||
      old.endRow != endRow;
}
