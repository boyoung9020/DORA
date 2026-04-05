import 'package:flutter/material.dart';

/// GitHub Linguist 언어 이름 → devicon 슬러그 (cdn.jsdelivr.net/devicon)
const Map<String, String> kGithubLanguageDeviconSlug = {
  'Apache Groovy': 'groovy',
  'C': 'c',
  'C#': 'csharp',
  'C++': 'cplusplus',
  'Clojure': 'clojure',
  'CMake': 'cmake',
  'CoffeeScript': 'coffeescript',
  'ColdFusion': 'coldfusion',
  'Crystal': 'crystal',
  'CSS': 'css3',
  'Dart': 'dart',
  'Dockerfile': 'docker',
  'Elixir': 'elixir',
  'Elm': 'elm',
  'Emacs Lisp': 'emacs',
  'Erlang': 'erlang',
  'F#': 'fsharp',
  'Fortran': 'fortran',
  'Go': 'go',
  'Gradle': 'gradle',
  'GraphQL': 'graphql',
  'Haskell': 'haskell',
  'HTML': 'html5',
  'Java': 'java',
  'JavaScript': 'javascript',
  'Julia': 'julia',
  'Jupyter Notebook': 'jupyter',
  'Kotlin': 'kotlin',
  'LESS': 'less',
  'Lua': 'lua',
  'MATLAB': 'matlab',
  'Nix': 'nixos',
  'Objective-C': 'objectivec',
  'Perl': 'perl',
  'PHP': 'php',
  'PowerShell': 'powershell',
  'Prolog': 'prolog',
  'Python': 'python',
  'R': 'r',
  'Ruby': 'ruby',
  'Rust': 'rust',
  'Scala': 'scala',
  'SCSS': 'sass',
  'Shell': 'bash',
  'Solidity': 'solidity',
  'Swift': 'swift',
  'TeX': 'latex',
  'TypeScript': 'typescript',
  'VBA': 'visualstudio',
  'Vue': 'vuejs',
  'Zig': 'zig',
};

/// linguist 대표 색 (없으면 [fallbackHueFromName])
const Map<String, int> kGithubLanguageColorHex = {
  'Dart': 0xFF00B4AB,
  'JavaScript': 0xFFf1e05a,
  'TypeScript': 0xFF3178c6,
  'Python': 0xFF3572A5,
  'HTML': 0xFFe34c26,
  'CSS': 0xFF563d7c,
  'SCSS': 0xFFc6538c,
  'Java': 0xFFb07219,
  'Kotlin': 0xFFA97BFF,
  'Swift': 0xFFfa7343,
  'Rust': 0xFFdea584,
  'Go': 0xFF00ADD8,
  'Ruby': 0xFF701516,
  'PHP': 0xFF4F5D95,
  'C++': 0xFFf34b7d,
  'C': 0xFF555555,
  'C#': 0xFF178600,
  'Shell': 0xFF89e051,
  'Dockerfile': 0xFF384d54,
  'Vue': 0xFF41b883,
  'Scala': 0xFFc22d40,
  'Perl': 0xFF0298c3,
  'Lua': 0xFF000080,
  'Haskell': 0xFF5e5086,
  'Elixir': 0xFF6e4a7e,
  'Clojure': 0xFFdb5855,
  'Erlang': 0xFFa90533,
};

String? techStackDeviconSvgUrl(String githubLanguageName) {
  final slug = kGithubLanguageDeviconSlug[githubLanguageName];
  if (slug == null) return null;
  return 'https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/$slug/$slug-original.svg';
}

Color techStackLanguageColor(String name) {
  final hex = kGithubLanguageColorHex[name];
  if (hex != null) {
    return Color(hex);
  }
  final hue = (name.hashCode % 360).toDouble();
  return HSLColor.fromAHSL(1, hue < 0 ? -hue : hue, 0.52, 0.45).toColor();
}
