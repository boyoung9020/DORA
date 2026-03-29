import 'package:flutter/material.dart';
import '../../widgets/glass_container.dart';

const List<Map<String, String>> _mockPatchData = [
  {'date': '2024. 11. 25', 'version': '1.0.0', 'service': 'Face', 'content': '최초 배포'},
  {'date': '', 'version': '1.0.0', 'service': 'OCR', 'content': '최초 배포'},
  {'date': '', 'version': '1.0.0', 'service': 'Scene', 'content': '최초 배포'},
  {'date': '2025. 3. 4', 'version': '1.1.0', 'service': 'Face', 'content': '얼굴 분석 추가'},
  {'date': '', 'version': '1.1.0', 'service': 'OCR', 'content': 'OCR 전체화면'},
  {'date': '', 'version': '1.1.0', 'service': 'Scene', 'content': 'VLLM 테스트'},
  {'date': '', 'version': '', 'service': 'Milvus', 'content': 'keepalived 적용'},
  {'date': '2025. 3. 10', 'version': '1.0.0', 'service': 'Face', 'content': '/compare 추가'},
  {'date': '', 'version': '1.0.0', 'service': 'OCR', 'content': '롤백'},
  {'date': '', 'version': '1.0.0', 'service': 'Scene', 'content': '롤백'},
  {'date': '2025. 3. 13', 'version': '1.0.0', 'service': 'Face', 'content': '모든 인물에 대해서 pk추가'},
  {'date': '2025. 3. 18', 'version': '1.0.1 (임시)', 'service': 'OCR', 'content': 'bbox제외, response 통일, /search로 변경'},
  {'date': '2025. 3. 20', 'version': '1.1.1', 'service': 'OCR', 'content': 'code:200 제거, avg_confidence 고정값'},
  {'date': '2025. 3. 25', 'version': '1.2.1', 'service': 'Face', 'content': 'milvus 헬스 체크 적용'},
  {'date': '', 'version': '', 'service': 'Milvus', 'content': 'volume 설정 다시 설치'},
  {'date': '2025. 3. 30', 'version': '1.1.2', 'service': 'OCR', 'content': '리턴 한글 안되는 문제, log 간소화'},
  {'date': '2025. 3. 31', 'version': '1.1.3', 'service': 'OCR', 'content': '리스트로 처리할때 craft 좌표 중복 해결'},
  {'date': '2025. 4. 2', 'version': '1.2.2', 'service': 'Face', 'content': '얼굴 검출 없을때에 204 리턴'},
  {'date': '', 'version': '1.1.4', 'service': 'OCR', 'content': '모델 최신으로 변경/ 필요없는 모델 삭제'},
];

class PatchTab extends StatelessWidget {
  const PatchTab({super.key});

  static Color _serviceColor(String service) {
    switch (service) {
      case 'Face':
        return Colors.blue.shade700;
      case 'OCR':
        return Colors.amber.shade800;
      case 'Scene':
        return Colors.purple.shade700;
      case 'Milvus':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: GlassContainer(
        padding: EdgeInsets.zero,
        borderRadius: 16,
        blur: 20,
        gradientColors: [
          Colors.white.withValues(alpha: 0.9),
          Colors.white.withValues(alpha: 0.8),
        ],
        shadowBlurRadius: 8,
        shadowOffset: const Offset(0, 2),
        child: Column(
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('배포 및 패치 내역',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface)),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('새 패치 등록'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            // 테이블 헤더
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Row(
                children: [
                  _header(Icons.calendar_month_outlined, '날짜',
                      width: 130, colorScheme: colorScheme),
                  _header(null, '버전',
                      width: 120, colorScheme: colorScheme),
                  _header(Icons.dns_outlined, '서비스',
                      width: 110, colorScheme: colorScheme),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.edit_note_outlined,
                            size: 14,
                            color: colorScheme.onSurface
                                .withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Text('내용',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 테이블 본문
            if (_mockPatchData.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text('패치 내역이 없습니다.',
                    style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.5))),
              )
            else
              ..._mockPatchData.asMap().entries.map((entry) {
                final i = entry.key;
                final row = entry.value;
                final isNewGroup = row['date'] != '' && i != 0;
                final svc = row['service'] ?? '';
                final svcColor = _serviceColor(svc);

                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: isNewGroup
                          ? BorderSide(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                              width: 1.5)
                          : BorderSide(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.15)),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(row['date'] ?? '',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: row['date'] != ''
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: row['date'] != ''
                                    ? colorScheme.onSurface
                                        .withValues(alpha: 0.8)
                                    : Colors.transparent)),
                      ),
                      SizedBox(
                        width: 120,
                        child: (row['version'] ?? '').isNotEmpty
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(row['version'] ?? '',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.7))),
                              )
                            : const SizedBox.shrink(),
                      ),
                      SizedBox(
                        width: 110,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: svcColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(svc,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: svcColor)),
                        ),
                      ),
                      Expanded(
                        child: Text(row['content'] ?? '',
                            style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  static Widget _header(
    IconData? icon,
    String label, {
    required double width,
    required ColorScheme colorScheme,
  }) {
    return SizedBox(
      width: width,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon,
                size: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: colorScheme.onSurface.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}
