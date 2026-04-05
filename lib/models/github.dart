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

class GitHubCommit {
  final String sha;
  final String message;
  final String authorName;
  final String? authorEmail;
  final String? authorAvatarUrl;
  final String date;
  final String url;
  final List<String> parents;

  GitHubCommit({
    required this.sha,
    required this.message,
    required this.authorName,
    this.authorEmail,
    this.authorAvatarUrl,
    required this.date,
    required this.url,
    this.parents = const [],
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
    );
  }

  String get shortSha => sha.length >= 7 ? sha.substring(0, 7) : sha;
  String get firstLine => message.split('\n').first;
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
