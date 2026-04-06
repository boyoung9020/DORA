import 'package:flutter/material.dart';
import '../../models/github.dart';

/// 각 커밋의 그래프 레이아웃 정보
class GitGraphNode {
  final int lane;
  final List<GitGraphEdge> edges;

  /// 이 행을 단순히 통과하는 레인 번호 목록 (커밋 없이 수직선만 그림)
  final List<int> passThroughLanes;

  /// 위쪽(자식 커밋)에서 이 노드로 연결되는 선이 있는지
  final bool connectedFromTop;

  GitGraphNode({
    required this.lane,
    required this.edges,
    this.passThroughLanes = const [],
    this.connectedFromTop = false,
  });
}

class GitGraphEdge {
  final int fromLane;
  final int toLane;
  final int toRow;
  final Color color;

  GitGraphEdge({
    required this.fromLane,
    required this.toLane,
    required this.toRow,
    required this.color,
  });
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

    // ── DEBUG: 데이터 확인 ─────────────────────────────
    debugPrint('═══ GitGraphLayout.compute ═══');
    debugPrint('commits count: ${commits.length}');
    for (int i = 0; i < commits.length && i < 5; i++) {
      final c = commits[i];
      final parentInMap = c.parents.map((p) => '${p.substring(0, 7)}(${shaToRow.containsKey(p) ? "✓" : "✗"})').join(', ');
      debugPrint('  [$i] sha=${c.sha.substring(0, 7)} parents=[$parentInMap] msg=${c.message.substring(0, c.message.length.clamp(0, 30))}');
    }

    // 레인 할당: 각 레인을 어떤 sha가 "예약"하고 있는지 추적
    // null = 비어있음
    final activeLanes = <String?>[];
    final nodeList = <GitGraphNode>[];
    int maxLane = 0;

    for (int row = 0; row < commits.length; row++) {
      final commit = commits[row];
      final sha = commit.sha;
      final parentShas = commit.parents;

      // 이 커밋이 어느 레인에 배치될지 찾기
      int lane = activeLanes.indexOf(sha);
      final bool connectedFromTop = lane != -1;
      if (lane == -1) {
        // 새 레인: 비어있는 슬롯 찾거나 새로 추가
        lane = activeLanes.indexOf(null);
        if (lane == -1) {
          lane = activeLanes.length;
          activeLanes.add(null);
        }
      }

      // 현재 레인 해제 (이 커밋이 소비함)
      activeLanes[lane] = null;

      // ── 통과 레인 캡처 (현재 레인 제외, 아직 예약된 레인들) ──────────────
      final passThroughLanes = <int>[];
      for (int j = 0; j < activeLanes.length; j++) {
        if (j != lane && activeLanes[j] != null) {
          passThroughLanes.add(j);
        }
      }

      final edges = <GitGraphEdge>[];

      if (parentShas.isNotEmpty) {
        // 첫 번째 부모: 직선 연결 — 같은 레인 유지
        final firstParent = parentShas[0];
        final firstParentRow = shaToRow[firstParent];

        // 부모가 데이터셋에 있을 때만 레인 예약 (없으면 좀비 레인 방지)
        if (firstParentRow != null) {
          activeLanes[lane] = firstParent;
          edges.add(GitGraphEdge(
            fromLane: lane,
            toLane: lane,
            toRow: firstParentRow,
            color: colorForLane(lane),
          ));
        }

        // 나머지 부모들: 머지 — 다른 레인에서 합류
        for (int p = 1; p < parentShas.length; p++) {
          final parentSha = parentShas[p];
          final parentRow = shaToRow[parentSha];

          // 부모가 데이터셋에 없으면 레인 할당하지 않음
          if (parentRow == null) continue;

          int parentLane = activeLanes.indexOf(parentSha);
          if (parentLane == -1) {
            parentLane = activeLanes.indexOf(null);
            if (parentLane == -1) {
              parentLane = activeLanes.length;
              activeLanes.add(parentSha);
            } else {
              activeLanes[parentLane] = parentSha;
            }
          }

          edges.add(GitGraphEdge(
            fromLane: lane,
            toLane: parentLane,
            toRow: parentRow,
            color: colorForLane(parentLane),
          ));
        }
      }

      // 뒤쪽 빈 레인 정리 (불필요한 레인 확장 방지)
      while (activeLanes.isNotEmpty && activeLanes.last == null) {
        activeLanes.removeLast();
      }

      nodeList.add(GitGraphNode(
        lane: lane,
        edges: edges,
        passThroughLanes: passThroughLanes,
        connectedFromTop: connectedFromTop,
      ));

      // maxLane 갱신
      if (lane > maxLane) maxLane = lane;
      for (int j = 0; j < activeLanes.length; j++) {
        if (activeLanes[j] != null && j > maxLane) maxLane = j;
      }
    }

    debugPrint('═══ Result: maxLane=$maxLane, lanes=${nodeList.map((n) => n.lane).toList()} ═══');
    return GitGraphLayout(nodes: nodeList, maxLane: maxLane);
  }

  /// 카드 미리보기용: 단순 직선 스파인
  static GitGraphLayout computeSimpleSpine(int rowCount) {
    if (rowCount <= 0) {
      return GitGraphLayout(nodes: [], maxLane: 0);
    }
    final nodes = <GitGraphNode>[];
    for (int row = 0; row < rowCount; row++) {
      final edges = <GitGraphEdge>[];
      if (row < rowCount - 1) {
        edges.add(GitGraphEdge(
          fromLane: 0,
          toLane: 0,
          toRow: row + 1,
          color: colorForLane(0),
        ));
      }
      nodes.add(GitGraphNode(lane: 0, edges: edges));
    }
    return GitGraphLayout(nodes: nodes, maxLane: 0);
  }
}

/// 그래프 선을 그리는 CustomPainter (행 단위)
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

    for (int row = startRow; row < end && row < layout.nodes.length; row++) {
      final node = layout.nodes[row];
      final cx = _laneX(node.lane);
      final cy = _rowY(row);
      final topY = cy - rowHeight / 2;
      final botY = cy + rowHeight / 2;
      final nodeColor = GitGraphLayout.colorForLane(node.lane);

      // ── 1. 통과 레인: 행 전체 높이에 수직선 ────────────────────────────
      for (final ptLane in node.passThroughLanes) {
        final ptX = _laneX(ptLane);
        canvas.drawLine(
          Offset(ptX, topY),
          Offset(ptX, botY),
          Paint()
            ..color = GitGraphLayout.colorForLane(ptLane).withValues(alpha: 0.7)
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke,
        );
      }

      // ── 2. 노드 자신의 레인 수직 연결 ──────────────────────────────────
      // 위쪽 연결: 자식 커밋에서 이 노드로 이어지는 선
      if (node.connectedFromTop) {
        canvas.drawLine(
          Offset(cx, topY),
          Offset(cx, cy),
          Paint()
            ..color = nodeColor.withValues(alpha: 0.8)
            ..strokeWidth = 2.0,
        );
      }

      // 아래쪽 연결: 같은 레인의 부모로 이어지는 선
      final hasSameLaneParent = node.edges.any((e) => e.fromLane == e.toLane);
      if (hasSameLaneParent) {
        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx, botY),
          Paint()
            ..color = nodeColor.withValues(alpha: 0.8)
            ..strokeWidth = 2.0,
        );
      }

      // ── 3. 머지/분기 곡선 (다른 레인으로 가는 엣지) ────────────────────
      for (final edge in node.edges) {
        if (edge.fromLane != edge.toLane) {
          final toX = _laneX(edge.toLane);
          final paint = Paint()
            ..color = edge.color.withValues(alpha: 0.8)
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke;

          final path = Path();
          path.moveTo(cx, cy);
          // 한 행 높이 내에서 베지어 곡선으로 다른 레인에 연결
          final midY = (cy + botY) / 2;
          path.cubicTo(cx, midY, toX, midY, toX, botY);
          canvas.drawPath(path, paint);
        }
      }
    }

    // ── 4. 노드 (원) — 선 위에 그려야 하므로 마지막 ─────────────────────
    for (int row = startRow; row < end && row < layout.nodes.length; row++) {
      final node = layout.nodes[row];
      final cx = _laneX(node.lane);
      final cy = _rowY(row);
      final color = GitGraphLayout.colorForLane(node.lane);
      final isMerge = node.edges.length > 1;

      // 흰 배경 원 (선 위에 덮음)
      canvas.drawCircle(
        Offset(cx, cy),
        nodeRadius + 2,
        Paint()..color = Colors.white,
      );

      // 채우기 원
      canvas.drawCircle(
        Offset(cx, cy),
        nodeRadius,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );

      // 머지 커밋: 속이 빈 원 (테두리만)
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
