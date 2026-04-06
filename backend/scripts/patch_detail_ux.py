"""Fix 1: detail TextField에 focusNode 추가
Fix 2: 이미지 목록을 _DetailImageList 위젯으로 교체
"""
import re

path = 'lib/screens/task_detail_screen.dart'
content = open(path, encoding='utf-8').read()

# Fix 1: focusNode 추가
old1 = 'controller: _detailController,\n              maxLines: null,'
new1 = 'controller: _detailController,\n              focusNode: _detailFocusNode,\n              maxLines: null,'
if old1 in content:
    content = content.replace(old1, new1, 1)
    print('[Fix 1] focusNode 추가 완료')
else:
    print('[Fix 1] 패턴 없음')

# Fix 2: 이미지 미리보기 블록을 _DetailImageList 위젯으로 교체
# 이미지 미리보기 시작: if (_selectedDetailImages.isNotEmpty) ...[
# 이미지 미리보기 끝: ],  (닫는 ],)
# 정규식으로 해당 블록 탐지
old2_start = '                            // '
# 간단한 방법: 이미지 블록의 시작 ~ 끝 패턴
pattern = r'(                            // [^\n]*\n                            if \(_selectedDetailImages\.isNotEmpty\).*?                            \],\n)'
match = re.search(pattern, content, re.DOTALL)
if match:
    replacement = (
        '                            // 이미지 미리보기 - 별도 위젯으로 분리하여 부모 rebuild 방지\n'
        '                            _DetailImageList(\n'
        '                              images: _selectedDetailImages,\n'
        '                              onChanged: (updated) {\n'
        '                                _selectedDetailImages = updated;\n'
        '                              },\n'
        '                            ),\n'
    )
    content = content[:match.start()] + replacement + content[match.end():]
    print('[Fix 2] 이미지 블록 교체 완료')
else:
    print('[Fix 2] 패턴 없음 - 수동 확인 필요')
    # 범위 확인용
    idx = content.find('_selectedDetailImages.isNotEmpty')
    if idx >= 0:
        print('근처 텍스트:', repr(content[idx-50:idx+200]))

open(path, 'w', encoding='utf-8').write(content)
print('저장 완료')
