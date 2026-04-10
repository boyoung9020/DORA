// GitHub 연동 모델 클래스들

class GitHubRepo {
  final String id;
  final String projectId;
  final String repoOwner;
  final String repoName;
  final bool hasToken;
  final DateTime createdAt;
  final DateTime updatedAt;

  GitHubRepo({
    required this.id,
    required this.projectId,
    required this.repoOwner,
    required this.repoName,
    required this.hasToken,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GitHubRepo.fromJson(Map<String, dynamic> json) {
    return GitHubRepo(
      id: json['id'] as String,
      projectId: (json['project_id'] ?? json['projectId']) as String,
      repoOwner: (json['repo_owner'] ?? json['repoOwner']) as String,
      repoName: (json['repo_name'] ?? json['repoName']) as String,
      hasToken: (json['has_token'] ?? json['hasToken'] ?? false) as bool,
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      updatedAt: DateTime.parse(json['updated_at'] ?? json['updatedAt']),
    );
  }

  String get fullName => '$repoOwner/$repoName';
}

/// GitHub API 저장소 공개 메타데이터 (/api/github/.../repo-details)
class GitHubRepoRemoteDetails {
  final String? description;
  final String defaultBranch;
  final int stargazersCount;
  final int forksCount;
  final int openIssuesCount;
  final String htmlUrl;

  GitHubRepoRemoteDetails({
    this.description,
    required this.defaultBranch,
    required this.stargazersCount,
    required this.forksCount,
    required this.openIssuesCount,
    required this.htmlUrl,
  });

  factory GitHubRepoRemoteDetails.fromJson(Map<String, dynamic> json) {
    int n(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    return GitHubRepoRemoteDetails(
      description: json['description'] as String?,
      defaultBranch:
          (json['default_branch'] ?? json['defaultBranch'] ?? '') as String,
      stargazersCount: n(json['stargazers_count'] ?? json['stargazersCount']),
      forksCount: n(json['forks_count'] ?? json['forksCount']),
      openIssuesCount:
          n(json['open_issues_count'] ?? json['openIssuesCount']),
      htmlUrl: (json['html_url'] ?? json['htmlUrl'] ?? '') as String,
    );
  }
}

class GitHubCommit {
  final String sha;
  final String message;
  final String authorName;
  final String? authorEmail;
  final String? authorAvatarUrl;
  final String date;
  final String url;
  final List<String> parents;
  final List<String> branchNames;
  final List<String> tagNames;

  GitHubCommit({
    required this.sha,
    required this.message,
    required this.authorName,
    this.authorEmail,
    this.authorAvatarUrl,
    required this.date,
    required this.url,
    this.parents = const [],
    this.branchNames = const [],
    this.tagNames = const [],
  });

  factory GitHubCommit.fromJson(Map<String, dynamic> json) {
    return GitHubCommit(
      sha: json['sha'] as String,
      message: json['message'] as String,
      authorName: (json['author_name'] ?? json['authorName']) as String,
      authorEmail: (json['author_email'] ?? json['authorEmail']) as String?,
      authorAvatarUrl: (json['author_avatar_url'] ?? json['authorAvatarUrl']) as String?,
      date: json['date'] as String,
      url: json['url'] as String,
      parents: (json['parents'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      branchNames: (json['branch_names'] ?? json['branchNames'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      tagNames: (json['tag_names'] ?? json['tagNames'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  String get shortSha => sha.length >= 7 ? sha.substring(0, 7) : sha;
  String get firstLine => message.split('\n').first;
}

/// 커밋 비교 결과의 파일 하나
class GitHubCompareFile {
  final String filename;
  final String? status;
  final int additions;
  final int deletions;
  final int changes;

  GitHubCompareFile({
    required this.filename,
    this.status,
    required this.additions,
    required this.deletions,
    required this.changes,
  });

  factory GitHubCompareFile.fromJson(Map<String, dynamic> json) {
    return GitHubCompareFile(
      filename: json['filename'] as String,
      status: json['status'] as String?,
      additions: (json['additions'] as num?)?.toInt() ?? 0,
      deletions: (json['deletions'] as num?)?.toInt() ?? 0,
      changes: (json['changes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 두 커밋 비교 결과
class GitHubCompareResult {
  final String base;
  final String head;
  final int? aheadBy;
  final int? behindBy;
  final int? totalCommits;
  final List<GitHubCompareFile> files;

  GitHubCompareResult({
    required this.base,
    required this.head,
    this.aheadBy,
    this.behindBy,
    this.totalCommits,
    this.files = const [],
  });

  factory GitHubCompareResult.fromJson(Map<String, dynamic> json) {
    return GitHubCompareResult(
      base: (json['base'] ?? '') as String,
      head: (json['head'] ?? '') as String,
      aheadBy: (json['ahead_by'] ?? json['aheadBy']) as int?,
      behindBy: (json['behind_by'] ?? json['behindBy']) as int?,
      totalCommits: (json['total_commits'] ?? json['totalCommits']) as int?,
      files: ((json['files'] as List<dynamic>?) ?? [])
          .map((e) => GitHubCompareFile.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GitHubBranch {
  final String name;
  final String sha;

  GitHubBranch({
    required this.name,
    required this.sha,
  });

  factory GitHubBranch.fromJson(Map<String, dynamic> json) {
    return GitHubBranch(
      name: json['name'] as String,
      sha: json['sha'] as String,
    );
  }

  String get shortSha => sha.length >= 7 ? sha.substring(0, 7) : sha;
}

class GitHubTag {
  final String name;
  final String sha;

  GitHubTag({required this.name, required this.sha});

  factory GitHubTag.fromJson(Map<String, dynamic> json) {
    return GitHubTag(
      name: json['name'] as String,
      sha: json['sha'] as String,
    );
  }

  String get shortSha => sha.length >= 7 ? sha.substring(0, 7) : sha;
}

/// GitHub /languages 한 항목 (저장소 기술 스택)
class GitHubLanguage {
  final String name;
  final int bytes;
  final double percentage;

  GitHubLanguage({
    required this.name,
    required this.bytes,
    required this.percentage,
  });

  factory GitHubLanguage.fromJson(Map<String, dynamic> json) {
    return GitHubLanguage(
      name: json['name'] as String,
      bytes: (json['bytes'] as num).toInt(),
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}


class GitHubRelease {
  final int id;
  final String tagName;
  final String name;
  final String? body;
  final bool draft;
  final bool prerelease;
  final String? publishedAt;
  final String url;
  final bool isLatest;

  GitHubRelease({
    required this.id,
    required this.tagName,
    required this.name,
    this.body,
    required this.draft,
    required this.prerelease,
    this.publishedAt,
    required this.url,
    required this.isLatest,
  });

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    return GitHubRelease(
      id: (json['id'] as num).toInt(),
      tagName: (json['tag_name'] ?? json['tagName']) as String,
      name: json['name'] as String,
      body: json['body'] as String?,
      draft: (json['draft'] ?? false) as bool,
      prerelease: (json['prerelease'] ?? false) as bool,
      publishedAt: (json['published_at'] ?? json['publishedAt']) as String?,
      url: json['url'] as String,
      isLatest: (json['is_latest'] ?? json['isLatest'] ?? false) as bool,
    );
  }

  String get displayDate {
    if (publishedAt == null) return '';
    try {
      final dt = DateTime.parse(publishedAt!).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return publishedAt!;
    }
  }
}


class GitHubPullRequest {
  final int number;
  final String title;
  final String state;
  final String author;
  final String? authorAvatarUrl;
  final String createdAt;
  final String updatedAt;
  final String url;
  final String headBranch;
  final String baseBranch;

  GitHubPullRequest({
    required this.number,
    required this.title,
    required this.state,
    required this.author,
    this.authorAvatarUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.url,
    required this.headBranch,
    required this.baseBranch,
  });

  factory GitHubPullRequest.fromJson(Map<String, dynamic> json) {
    return GitHubPullRequest(
      number: json['number'] as int,
      title: json['title'] as String,
      state: json['state'] as String,
      author: json['author'] as String,
      authorAvatarUrl: (json['author_avatar_url'] ?? json['authorAvatarUrl']) as String?,
      createdAt: (json['created_at'] ?? json['createdAt']) as String,
      updatedAt: (json['updated_at'] ?? json['updatedAt']) as String,
      url: json['url'] as String,
      headBranch: (json['head_branch'] ?? json['headBranch']) as String,
      baseBranch: (json['base_branch'] ?? json['baseBranch']) as String,
    );
  }
}

class GitHubIssue {
  final int number;
  final String title;
  final String state;
  final String author;
  final String? authorAvatarUrl;
  final String createdAt;
  final String updatedAt;
  final String url;
  final List<String> labels;
  final int comments;

  GitHubIssue({
    required this.number,
    required this.title,
    required this.state,
    required this.author,
    this.authorAvatarUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.url,
    this.labels = const [],
    this.comments = 0,
  });

  factory GitHubIssue.fromJson(Map<String, dynamic> json) {
    return GitHubIssue(
      number: json['number'] as int,
      title: json['title'] as String,
      state: json['state'] as String,
      author: json['author'] as String,
      authorAvatarUrl: (json['author_avatar_url'] ?? json['authorAvatarUrl']) as String?,
      createdAt: (json['created_at'] ?? json['createdAt']) as String,
      updatedAt: (json['updated_at'] ?? json['updatedAt']) as String,
      url: json['url'] as String,
      labels: (json['labels'] as List?)?.map((e) => e.toString()).toList() ?? [],
      comments: (json['comments'] as int?) ?? 0,
    );
  }
}
