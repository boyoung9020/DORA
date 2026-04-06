path = 'lib/screens/task_detail_screen.dart'
content = open(path, encoding='utf-8').read()

# 중복 제거
old = '  List<XFile>   List<XFile> _selectedDetailImages'
new = '  List<XFile> _selectedDetailImages'
if old in content:
    content = content.replace(old, new, 1)
    open(path, 'w', encoding='utf-8').write(content)
    print('중복 제거 완료')
else:
    print('패턴 없음')
    idx = content.find('_selectedDetailImages')
    print(repr(content[idx-20:idx+60]))
