path = 'lib/screens/task_detail_screen.dart'
content = open(path, encoding='utf-8').read()

# 잔여 고아 코드 제거
# _DetailImageList 위젯 다음에 남아있는 불필요한 닫는 괄호들
old = '''                            _DetailImageList(
                              images: _selectedDetailImages,
                              onChanged: (updated) {
                                _selectedDetailImages = updated;
                              },
                            ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),'''

new = '''                            _DetailImageList(
                              images: _selectedDetailImages,
                              onChanged: (updated) {
                                _selectedDetailImages = updated;
                              },
                            ),
                            const SizedBox(height: 8),'''

if old in content:
    content = content.replace(old, new, 1)
    open(path, 'w', encoding='utf-8').write(content)
    print('고아 코드 제거 완료')
else:
    print('패턴 없음 - 수동 확인')
    idx = content.find('_DetailImageList(')
    if idx >= 0:
        print(repr(content[idx:idx+400]))
