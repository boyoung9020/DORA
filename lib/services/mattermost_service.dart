import '../utils/api_client.dart';

class MattermostSetting {
  final bool hasSetting;
  final String webhookUrl;
  final bool isEnabled;

  const MattermostSetting({
    required this.hasSetting,
    required this.webhookUrl,
    required this.isEnabled,
  });

  factory MattermostSetting.fromJson(Map<String, dynamic> json) {
    return MattermostSetting(
      hasSetting: json['has_setting'] as bool? ?? false,
      webhookUrl: json['webhook_url'] as String? ?? '',
      isEnabled: json['is_enabled'] as bool? ?? false,
    );
  }
}

class MattermostService {
  Future<MattermostSetting> getMySetting() async {
    final response = await ApiClient.get('/api/mattermost-setting/me');
    final data = ApiClient.handleResponse(response);
    return MattermostSetting.fromJson(data);
  }

  Future<void> upsertMySetting({
    required String webhookUrl,
    required bool isEnabled,
  }) async {
    await ApiClient.put(
      '/api/mattermost-setting/me',
      body: {'webhook_url': webhookUrl, 'is_enabled': isEnabled},
    );
  }

  Future<void> deleteMySetting() async {
    await ApiClient.delete('/api/mattermost-setting/me');
  }
}
