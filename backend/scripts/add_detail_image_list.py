path = 'lib/screens/task_detail_screen.dart'
content = open(path, encoding='utf-8').read()

widget_code = '''
/// 상세 설명 이미지 미리보기 위젯
/// 별도 StatefulWidget으로 분리하여 이미지 추가/삭제 시 부모 rebuild 방지
class _DetailImageList extends StatefulWidget {
  final List<dynamic> images;
  final void Function(List<dynamic>) onChanged;

  const _DetailImageList({required this.images, required this.onChanged});

  @override
  State<_DetailImageList> createState() => _DetailImageListState();
}

class _DetailImageListState extends State<_DetailImageList> {
  late List<dynamic> _images;

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.images);
  }

  @override
  void didUpdateWidget(_DetailImageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.images != oldWidget.images) {
      _images = List.from(widget.images);
    }
  }

  void _remove(int index) {
    setState(() => _images.removeAt(index));
    widget.onChanged(_images);
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _images.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _XFileImage(
                        xfile: _images[index],
                        width: 100,
                        height: 100,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _remove(index),
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
    );
  }
}
'''

# 클래스 정의가 없으면 추가
if 'class _DetailImageList' not in content:
    content = content.rstrip('\n') + '\n' + widget_code + '\n'
    open(path, 'w', encoding='utf-8').write(content)
    print('_DetailImageList 클래스 추가 완료')
else:
    print('이미 클래스 존재 - 스킵')
