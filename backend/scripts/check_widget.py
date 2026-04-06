content = open('lib/screens/task_detail_screen.dart', encoding='utf-8').read()
idx = content.find('_DetailImageList')
if idx >= 0:
    print('발견 위치:', idx)
    print(content[idx:idx+300])
else:
    print('없음')
