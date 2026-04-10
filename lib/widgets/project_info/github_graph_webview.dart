import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../models/github.dart';

/// WebView 기반 Git Graph 위젯 (VSCode Git Graph 방식)
class GitHubGraphWebView extends StatefulWidget {
  final List<GitHubCommit> commits;
  final List<GitHubBranch> branches;
  final bool isDark;
  final bool hasMore;
  final ValueChanged<String>? onCommitSelected;
  final VoidCallback? onLoadMore;

  const GitHubGraphWebView({
    super.key,
    required this.commits,
    required this.branches,
    required this.isDark,
    this.hasMore = false,
    this.onCommitSelected,
    this.onLoadMore,
  });

  @override
  State<GitHubGraphWebView> createState() => _GitHubGraphWebViewState();
}

class _GitHubGraphWebViewState extends State<GitHubGraphWebView> {
  InAppWebViewController? _ctrl;
  bool _ready = false;

  /// 번들에서 HTML 문자열을 읽은 뒤 true (웹·데스크톱 공통).
  bool _canBuild = false;

  /// [rootBundle]에서 읽은 그래프 HTML (data URL로 WebView에 주입)
  String? _htmlContent;

  @override
  void initState() {
    super.initState();
    // 웹도 HTTP로 assets/git_graph/index.html를 열면 배포 경로·iframe 기준으로
    // 요청이 안 보이거나 404가 나는 경우가 있어, 데스크톱과 같이 번들→data URL로 통일.
    _loadHtml();
  }

  Future<void> _loadHtml() async {
    try {
      final html = await rootBundle.loadString('assets/git_graph/index.html');
      if (mounted) {
        setState(() {
          _htmlContent = html;
          _canBuild = true;
        });
      }
    } catch (e) {
      debugPrint('[GitHubGraphWebView] HTML 로드 실패: $e');
    }
  }

  @override
  void didUpdateWidget(GitHubGraphWebView old) {
    super.didUpdateWidget(old);
    if (!_ready) return;
    if (old.isDark != widget.isDark) _setTheme(widget.isDark);
    if (old.commits != widget.commits ||
        old.hasMore != widget.hasMore ||
        old.branches != widget.branches) {
      _setData();
    }
  }

  Future<void> _setData() async {
    final ctrl = _ctrl;
    if (ctrl == null || !_ready) return;
    try {
      final result = await ctrl.callAsyncJavaScript(
        functionBody: 'window.setData(JSON.parse(data)); return "ok";',
        arguments: {'data': jsonEncode(_buildPayload())},
      );
      debugPrint('[GitHubGraphWebView] setData result: ${result?.value}');
    } catch (e) {
      debugPrint('[GitHubGraphWebView] setData 오류: $e');
    }
  }

  Future<void> _setTheme(bool isDark) async {
    try {
      await _ctrl?.callAsyncJavaScript(
        functionBody: 'window.setTheme(isDark); return "ok";',
        arguments: {'isDark': isDark},
      );
    } catch (e) {
      debugPrint('[GitHubGraphWebView] setTheme 오류: $e');
    }
  }

  Map<String, dynamic> _buildPayload() {
    final branchBySha = <String, List<String>>{};
    for (final b in widget.branches) {
      branchBySha.putIfAbsent(b.sha, () => []).add(b.name);
    }
    return {
      'commits': widget.commits.map((c) {
        final names = c.branchNames.isNotEmpty
            ? c.branchNames
            : (branchBySha[c.sha] ?? []);
        return {
          'sha': c.sha,
          'message': c.message,
          'authorName': c.authorName,
          'date': c.date,
          'parents': c.parents,
          'branchNames': names,
          'tagNames': c.tagNames,
        };
      }).toList(),
      'hasMore': widget.hasMore,
    };
  }

  void _loadIntoWebView(InAppWebViewController ctrl) {
    final html = _htmlContent;
    if (html == null) return;
    // 웹·Windows 공통: 네트워크에 git_graph 파일 요청이 안 잡혀도 되고, /assets 경로 404도 피함.
    final base64Html = base64Encode(utf8.encode(html));
    ctrl.loadUrl(
      urlRequest: URLRequest(
        url: WebUri('data:text/html;charset=utf-8;base64,$base64Html'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_canBuild) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return InAppWebView(
      initialSettings: InAppWebViewSettings(
        disableContextMenu: true,
        supportZoom: false,
        isInspectable: false,
        mediaPlaybackRequiresUserGesture: false,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
      ),
      onWebViewCreated: (ctrl) {
        _ctrl = ctrl;

        // JS → Flutter 핸들러 등록
        ctrl.addJavaScriptHandler(
          handlerName: 'onCommitClick',
          callback: (args) {
            if (args.isNotEmpty) {
              widget.onCommitSelected?.call(args[0] as String);
            }
          },
        );
        ctrl.addJavaScriptHandler(
          handlerName: 'onLoadMore',
          callback: (_) => widget.onLoadMore?.call(),
        );

        _loadIntoWebView(ctrl);
      },
      onLoadStop: (ctrl, url) async {
        debugPrint('[GitHubGraphWebView] onLoadStop: $url');
        _ready = true;
        await _setTheme(widget.isDark);
        await _setData();
      },
      onConsoleMessage: (ctrl, msg) {
        debugPrint('[WebView console] ${msg.message}');
      },
      onReceivedError: (ctrl, req, err) {
        debugPrint('[GitHubGraphWebView] error: ${err.description}');
      },
    );
  }
}
