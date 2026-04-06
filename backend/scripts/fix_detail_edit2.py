path = 'lib/screens/task_detail_screen.dart'
content = open(path, encoding='utf-8').read()

# 1. _existingDetailImageUrls 추가 (실제 바이트로 찾기)
old1 = '_selectedDetailImages = []; // ?곸꽭 ??'
if old1 not in content:
    # 더 짧은 패턴으로 시도
    idx = content.find('_selectedDetailImages = []; //')
    if idx >= 0:
        end = content.find('\n', idx)
        line = content[idx:end]
        new_line = '  List<XFile> ' + line.strip() + '\n  List<String> _existingDetailImageUrls = []; // 편집 중 기존 저장 이미지 URL'
        content = content[:idx] + new_line + content[end:]
        print('[1] _existingDetailImageUrls 추가 완료')
    else:
        print('[1] 패턴 없음')
else:
    print('[1] old1 패턴 발견 - 처리')

# 2. 편집 진입 시 _existingDetailImageUrls 초기화
# 패턴: setState(() {\n ... _isEditing = true;\n ... });
import re
pattern2 = r'(setState\(\(\) \{\s*_isEditing = true;\s*\}\);)'
def replace2(m):
    return ('setState(() {\n'
            '                        _isEditing = true;\n'
            '                        _existingDetailImageUrls = List<String>.from(currentTask.detailImageUrls);\n'
            '                      });')
new_content, count = re.subn(pattern2, replace2, content)
if count > 0:
    content = new_content
    print(f'[2] 편집 진입 초기화 추가 완료 ({count}곳)')
else:
    print('[2] 패턴 없음 - 수동 확인')
    idx2 = content.find('_isEditing = true;')
    if idx2 >= 0:
        print(repr(content[idx2-60:idx2+60]))

# 4. _saveTask imageUrls 소스 변경
old4 = 'List<String> imageUrls = List<String>.from(currentTask.detailImageUrls);'
new4 = 'List<String> imageUrls = List<String>.from(_existingDetailImageUrls);'
if old4 in content:
    content = content.replace(old4, new4, 1)
    print('[4] _saveTask imageUrls 소스 변경 완료')
else:
    print('[4] 패턴 없음')

open(path, 'w', encoding='utf-8').write(content)
print('저장 완료')
