path = 'lib/screens/task_detail_screen.dart'
content = open(path, encoding='utf-8').read()

# _pickDetailImages의 setState를 단순 대입으로 변경
# setState가 부모 전체를 rebuild하지 않도록
# _DetailImageList는 didUpdateWidget으로 동기화되므로
# 부모에서 setState 없이 _selectedDetailImages만 갱신 + _DetailImageList 위젯의 key를 통해 갱신

# 현재 코드: setState(() { _selectedDetailImages = List<XFile>.from(images); });
# 변경 후: _selectedDetailImages = List<XFile>.from(images); setState((){});  <- 이건 같음
# 근본 해결: _DetailImageList를 GlobalKey로 접근하여 직접 업데이트
# 또는 더 간단하게: _pickDetailImages를 _DetailImageList 위젯 내부로 이동

# 가장 간단한 방법: _pickDetailImages의 setState를 유지하되
# _detailFocusNode로 포커스 복구 (rebuild 후 포커스 재요청)

old = '''  Future<void> _pickDetailImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedDetailImages = List<XFile>.from(images);
        });
      }
    } catch (e) {'''

new = '''  Future<void> _pickDetailImages() async {
    final hadFocus = _detailFocusNode.hasFocus;
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedDetailImages = List<XFile>.from(images);
        });
        // 이미지 선택 후 detail 필드 포커스 복구
        if (hadFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _detailFocusNode.requestFocus();
          });
        }
      }
    } catch (e) {'''

if old in content:
    content = content.replace(old, new, 1)
    open(path, 'w', encoding='utf-8').write(content)
    print('_pickDetailImages 포커스 복구 추가 완료')
else:
    print('패턴 없음')
    idx = content.find('_pickDetailImages')
    if idx >= 0:
        print(repr(content[idx:idx+300]))
