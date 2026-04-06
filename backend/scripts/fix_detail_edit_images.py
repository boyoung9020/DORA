path = 'lib/screens/task_detail_screen.dart'
content = open(path, encoding='utf-8').read()

# 1. _existingDetailImageUrls 상태변수 추가
old1 = '  List<XFile> _selectedDetailImages = []; // ?怨멸쉭 ??곸뒠???醫뤾문?????筌왖'
new1 = ('  List<XFile> _selectedDetailImages = []; // 새로 추가할 이미지 (XFile)\n'
        '  List<String> _existingDetailImageUrls = []; // 편집 중 기존 저장 이미지 URL')
if old1 in content:
    content = content.replace(old1, new1, 1)
    print('[1] _existingDetailImageUrls 추가 완료')
else:
    print('[1] 패턴 없음')

# 2. 편집 모드 진입 시 _existingDetailImageUrls 초기화
old2 = '''                    if (_isEditing) {
                      _saveTask(context, taskProvider);
                    } else {
                      setState(() {
                        _isEditing = true;
                      });
                    }'''
new2 = '''                    if (_isEditing) {
                      _saveTask(context, taskProvider);
                    } else {
                      setState(() {
                        _isEditing = true;
                        _existingDetailImageUrls = List<String>.from(currentTask.detailImageUrls);
                      });
                    }'''
if old2 in content:
    content = content.replace(old2, new2, 1)
    print('[2] 편집 모드 진입 시 기존 URL 초기화 완료')
else:
    print('[2] 패턴 없음')

# 3. 편집 모드에서 기존 URL 이미지 + 새 XFile 이미지 표시 위젯 교체
old3 = '''                            // 이미지 미리보기 - 별도 위젯으로 분리하여 부모 rebuild 방지
                            _DetailImageList(
                              images: _selectedDetailImages,
                              onChanged: (updated) {
                                _selectedDetailImages = updated.cast<XFile>();
                              },
                            ),'''
new3 = '''                            // 기존 저장된 이미지 URL 미리보기 (삭제 가능)
                            if (_existingDetailImageUrls.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 100,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _existingDetailImageUrls.length,
                                  itemBuilder: (context, index) {
                                    final url = _existingDetailImageUrls[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              _resolveImageUrl(url),
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                width: 100, height: 100,
                                                color: Colors.grey[200],
                                                child: const Icon(Icons.broken_image_outlined),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 4, right: 4,
                                            child: GestureDetector(
                                              onTap: () => setState(() {
                                                _existingDetailImageUrls.removeAt(index);
                                              }),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.6),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.close, size: 16, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            // 새로 추가할 이미지 미리보기 - 별도 위젯으로 분리하여 부모 rebuild 방지
                            _DetailImageList(
                              images: _selectedDetailImages,
                              onChanged: (updated) {
                                _selectedDetailImages = updated.cast<XFile>();
                              },
                            ),'''
if old3 in content:
    content = content.replace(old3, new3, 1)
    print('[3] 기존 이미지 표시 추가 완료')
else:
    print('[3] 패턴 없음')

# 4. _saveTask에서 imageUrls를 _existingDetailImageUrls 기반으로 변경
old4 = '''      // ???筌왖 ??낆쨮??
      List<String> imageUrls = List<String>.from(currentTask.detailImageUrls);
      if (_selectedDetailImages.isNotEmpty) {
        final uploadedUrls = await _uploadService.uploadImagesFromXFiles(
          _selectedDetailImages,
        );
        imageUrls.addAll(uploadedUrls);
      }'''
new4 = '''      // 이미지 업로드: 기존 URL(삭제 반영) + 새로 추가된 이미지
      List<String> imageUrls = List<String>.from(_existingDetailImageUrls);
      if (_selectedDetailImages.isNotEmpty) {
        final uploadedUrls = await _uploadService.uploadImagesFromXFiles(
          _selectedDetailImages,
        );
        imageUrls.addAll(uploadedUrls);
      }'''
if old4 in content:
    content = content.replace(old4, new4, 1)
    print('[4] _saveTask 이미지 처리 수정 완료')
else:
    print('[4] 패턴 없음')

# 5. _saveTask에서 상태 초기화 시 _existingDetailImageUrls도 초기화
old5 = '''      setState(() {
        _isEditing = false;
        _selectedDetailImages.clear();
        _uploadedDetailImageUrls.clear();
      });'''
new5 = '''      setState(() {
        _isEditing = false;
        _selectedDetailImages.clear();
        _uploadedDetailImageUrls.clear();
        _existingDetailImageUrls.clear();
      });'''
if old5 in content:
    content = content.replace(old5, new5, 1)
    print('[5] _saveTask 상태 초기화 수정 완료')
else:
    print('[5] 패턴 없음')

open(path, 'w', encoding='utf-8').write(content)
print('저장 완료')
