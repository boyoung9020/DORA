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

/// Reference 스타일 레인 할당 + 그래프 노드 계산
class GitGraphLayout {
  final List<GitGraphNode> nodes;
  final int maxLane;

  /// sha → lane 매핑 (full-graph 페인터용)
  final Map<String, int> laneBySha;

  GitGraphLayout({
    required this.nodes,
    required this.maxLane,
    this.laneBySha = const {},
  });

  // Reference 컬러 팔레트 (Tailwind)
  static const _laneColors = [
    Color(0xFF2563EB), // blue-600
    Color(0xFF16A34A), // green-600
    Color(0xFFDB2777), // pink-600
    Color(0xFFF59E0B), // amber-500
    Color(0xFF7C3AED), // violet-600
    Color(0xFF0EA5E9), // sky-500
    Color(0xFFEF4444), // red-500
  ];

  static Color colorForLane(int lane) =>
      _laneColors[lane % _laneColors.length];

  /// Reference 방식 레인 할당:
  /// - 첫 parent는 같은 lane 전파
  /// - merge parent(2번째+)는 새 lane 배정(또는 기존 유지)
  static GitGraphLayout compute(List<GitHubCommit> commits) {
    if (commits.isEmpty) {
      return GitGraphLayout(nodes: [], maxLane: 0);
    }

    // 1) 레인 할당 (reference: assignLanes)
    final laneBySha = <String, int>{};
    int nextLane = 0;

    for (final c in commits) {
      if (!laneBySha.containsKey(c.sha)) {
        laneBySha[c.sha] = nextLane++;
      }
      final lane = laneBySha[c.sha]!;
      final parents = c.parents;

      if (parents.isNotEmpty) {
        // 첫 번째 부모: 같은 lane 전파
        if (!laneBySha.containsKey(parents[0])) {
          laneBySha[parents[0]] = lane;
        }
        // 나머지 부모: 새 lane
        for (int p = 1; p < parents.length; p++) {
          if (!laneBySha.containsKey(parents[p])) {
            laneBySha[parents[p]] = nextLane++;
          }
        }
      }
    }

    final maxLane = nextLane > 0 ? nextLane - 1 : 0;

    // 2) sha → row 인덱스
    final shaToRow = <String, int>{};
    for (int i = 0; i < commits.length; i++) {
      shaToRow[commits[i].sha] = i;
    }

    // 3) 엣지 구성 + pass-through / connectedFromTop 계산
    // 각 엣지가 통과하는 중간 행의 lane 추적
    // activeEdges[row] = 해당 행을 통과하는 lane 집합
    final activeRanges = <_EdgeRange>[];
    final nodeEdges = List.generate(commits.length, (_) => <GitGraphEdge>[]);

    for (int row = 0; row < commits.length; row++) {
      final commit = commits[row];
      final lane = laneBySha[commit.sha] ?? 0;

      for (final parentSha in commit.parents) {
        final parentRow = shaToRow[parentSha];
        if (parentRow == null) continue;
        final parentLane = laneBySha[parentSha] ?? 0;

        nodeEdges[row].add(GitGraphEdge(
          fromLane: lane,
          toLane: parentLane,
          toRow: parentRow,
          color: colorForLane(lane),
        ));

        // 중간 행 통과 기록
        if (parentRow > row + 1) {
          activeRanges.add(_EdgeRange(
            startRow: row + 1,
            endRow: parentRow - 1,
            lane: parentLane,
          ));
        }
      }
    }

    // connectedFromTop 계산
    final connectedFromTop = List.filled(commits.length, false);
    for (int row = 0; row < commits.length; row++) {
      for (final edge in nodeEdges[row]) {
        if (edge.toRow < commits.length) {
          connectedFromTop[edge.toRow] = true;
        }
      }
    }

    // 4) 노드 생성
    final nodes = <GitGraphNode>[];
    for (int row = 0; row < commits.length; row++) {
      final lane = laneBySha[commits[row].sha] ?? 0;

      // 이 행을 통과하는 레인
      final ptLanes = <int>{};
      for (final r in activeRanges) {
        if (row >= r.startRow && row <= r.endRow) {
          ptLanes.add(r.lane);
        }
      }
      ptLanes.remove(lane); // 자기 레인은 제외

      nodes.add(GitGraphNode(
        lane: lane,
        edges: nodeEdges[row],
        passThroughLanes: ptLanes.toList()..sort(),
        connectedFromTop: connectedFromTop[row],
      ));
    }

    return GitGraphLayout(
      nodes: nodes,
      maxLane: maxLane,
      laneBySha: laneBySha,
    );
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

/// 엣지가 통과하는 행 범위
class _EdgeRange {
  final int startRow;
  final int endRow;
  final int lane;
  _EdgeRange({required this.startRow, required this.endRow, required this.lane});
}

/// 행 단위 그래프 페인터 (카드/패널 위젯용)
class GitGraphPainter extends CustomPainter {
  final GitGraphLayout layout;
  final double rowHeight;
  final double laneWidth;
  final double nodeRadius;
  final int startRow;
  final int endRow;

  static const double _padX = 10;

  GitGraphPainter({
    required this.layout,
    this.rowHeight = 28,
    this.laneWidth = 14,
    this.nodeRadius = 4,
    this.startRow = 0,
    this.endRow = -1,
  });

  double _laneX(int lane) => _padX + laneWidth * lane + laneWidth / 2;
  double _rowY(int row) => rowHeight * (row - startRow) + rowHeight / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final end = endRow < 0 ? layout.nodes.length : endRow;

    // ── 1. 엣지 (선) ──────────────────────────────────────────
    for (int row = startRow; row < end && row < layout.nodes.length; row++) {
      final node = layout.nodes[row];
      final cx = _laneX(node.lane);
      final cy = _rowY(row);
      final topY = cy - rowHeight / 2;
      final botY = cy + rowHeight / 2;

      // 통과 레인: 행 전체 높이 수직선
      for (final ptLane in node.passThroughLanes) {
        final ptX = _laneX(ptLane);
        canvas.drawLine(
          Offset(ptX, topY),
          Offset(ptX, botY),
          Paint()
            ..color = GitGraphLayout.colorForLane(ptLane).withValues(alpha: 0.9)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }

      // 위쪽 연결 (자식에서 이어짐)
      if (node.connectedFromTop) {
        canvas.drawLine(
          Offset(cx, topY),
          Offset(cx, cy),
          Paint()
            ..color = GitGraphLayout.colorForLane(node.lane).withValues(alpha: 0.9)
            ..strokeWidth = 2,
        );
      }

      // 엣지
      for (final edge in node.edges) {
        final color = GitGraphLayout.colorForLane(edge.fromLane);
        final paint = Paint()
          ..color = color.withValues(alpha: 0.9)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        if (edge.fromLane == edge.toLane) {
          // 같은 레인: 직선 (소스트리 스타일)
          canvas.drawLine(Offset(cx, cy), Offset(cx, botY), paint);
        } else {
          // 다른 레인: 부드러운 곡선
          final toX = _laneX(edge.toLane);
          final midY = (cy + botY) / 2;
          final path = Path()
            ..moveTo(cx, cy)
            ..cubicTo(cx, midY, toX, midY, toX, botY);
          canvas.drawPath(path, paint);
        }
      }
    }

    // ── 2. 노드 (원) — 선 위에 그려야 함 ──────────────────────
    for (int row = startRow; row < end && row < layout.nodes.length; row++) {
      final node = layout.nodes[row];
      final cx = _laneX(node.lane);
      final cy = _rowY(row);
      final color = GitGraphLayout.colorForLane(node.lane);

      // 흰 테두리 (boxShadow 효과)
      canvas.drawCircle(
        Offset(cx, cy),
        nodeRadius + 2,
        Paint()..color = Colors.white,
      );
      // 색 원
      canvas.drawCircle(
        Offset(cx, cy),
        nodeRadius,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GitGraphPainter old) =>
      old.layout != layout ||
      old.startRow != startRow ||
      old.endRow != endRow;
}

/// 전체 그래프 페인터 — WebView 방식으로 대체됨. 하위 호환용으로 유지.
@Deprecated('Use GitHubGraphWebView (WebView) instead')
class GitGraphFullPainter extends CustomPainter {
  final GitGraphLayout layout;
  final List<GitHubCommit> commits;
  final double rowH;
  final double laneW;
  final double padX;
  final double dotR;
  final double strokeWidth;

  GitGraphFullPainter({
    required this.layout,
    required this.commits,
    this.rowH = 28,
    this.laneW = 14,
    this.padX = 10,
    this.dotR = 4,
    this.strokeWidth = 2,
  });

  double _xForLane(int lane) => padX + lane * laneW + laneW / 2;
  double _yForIndex(int idx) => idx * rowH + rowH / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final shaToIndex = <String, int>{};
    for (int i = 0; i < commits.length; i++) {
      shaToIndex[commits[i].sha] = i;
    }

    // ── 엣지 (선/곡선) ────────────────────────────────────────
    for (final c in commits) {
      final srcIdx = shaToIndex[c.sha];
      final srcLane = layout.laneBySha[c.sha] ?? 0;
      if (srcIdx == null) continue;

      final x1 = _xForLane(srcLane);
      final y1 = _yForIndex(srcIdx);

      for (final p in c.parents) {
        final dstIdx = shaToIndex[p];
        if (dstIdx == null) continue;
        final dstLane = layout.laneBySha[p] ?? 0;

        final x2 = _xForLane(dstLane);
        final y2 = _yForIndex(dstIdx);

        final color = GitGraphLayout.colorForLane(srcLane);
        final paint = Paint()
          ..color = color.withValues(alpha: 0.9)
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        if (srcLane == dstLane) {
          // 같은 레인: 직선
          canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
        } else {
          // 다른 레인: 베지어 곡선 (소스트리 느낌)
          final midY = (y1 + y2) / 2;
          final path = Path()
            ..moveTo(x1, y1)
            ..cubicTo(x1, midY, x2, midY, x2, y2);
          canvas.drawPath(path, paint);
        }
      }
    }

    // ── 도트 ───────────────────────────────────────────────────
    for (int idx = 0; idx < commits.length; idx++) {
      final lane = layout.laneBySha[commits[idx].sha] ?? 0;
      final x = _xForLane(lane);
      final y = _yForIndex(idx);
      final color = GitGraphLayout.colorForLane(lane);

      // 흰 테두리 (boxShadow: 0 0 0 2px white)
      canvas.drawCircle(
        Offset(x, y),
        dotR + 2,
        Paint()..color = const Color(0xE6FFFFFF),
      );
      // 색 원
      canvas.drawCircle(
        Offset(x, y),
        dotR,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GitGraphFullPainter old) =>
      old.layout != layout ||
      old.commits != commits ||
      old.strokeWidth != strokeWidth;
}
