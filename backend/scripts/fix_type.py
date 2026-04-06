path = 'lib/screens/task_detail_screen.dart'
content = open(path, encoding='utf-8').read()

# onChanged 타입을 XFile로 맞춤
old = '''                            _DetailImageList(
                              images: _selectedDetailImages,
                              onChanged: (updated) {
                                _selectedDetailImages = updated;
                              },
                            ),'''

new = '''                            _DetailImageList(
                              images: _selectedDetailImages,
                              onChanged: (updated) {
                                _selectedDetailImages = updated.cast<XFile>();
                              },
                            ),'''

if old in content:
    content = content.replace(old, new, 1)
    open(path, 'w', encoding='utf-8').write(content)
    print('타입 캐스트 추가 완료')
else:
    print('패턴 없음')
