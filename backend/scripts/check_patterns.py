path = 'lib/screens/task_detail_screen.dart'
content = open(path, encoding='utf-8').read()

# 1번 확인
idx = content.find('_selectedDetailImages = []; //')
if idx >= 0:
    print('[1] 근처:', repr(content[idx:idx+120]))

# 2번 확인
idx2 = content.find('_isEditing = true;')
if idx2 >= 0:
    print('[2] 근처:', repr(content[idx2-80:idx2+50]))

# 4번 확인
idx4 = content.find('List<String> imageUrls = List<String>.from(')
if idx4 >= 0:
    print('[4] 근처:', repr(content[idx4-30:idx4+150]))

# 5번 확인
idx5 = content.find('_selectedDetailImages.clear();')
if idx5 >= 0:
    print('[5] 근처:', repr(content[idx5-30:idx5+100]))
