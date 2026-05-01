import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoPickerWidget extends StatefulWidget {
  final void Function(List<File> photos) onPhotosChanged;

  const PhotoPickerWidget({super.key, required this.onPhotosChanged});

  @override
  State<PhotoPickerWidget> createState() => _PhotoPickerWidgetState();
}

class _PhotoPickerWidgetState extends State<PhotoPickerWidget> {
  final _photos = <File>[];
  final _picker = ImagePicker();

  Future<void> _pick(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final picked = await _picker.pickMultiImage();
      final files = picked.map((x) => File(x.path)).toList();
      setState(() => _photos.addAll(files));
    } else {
      final picked = await _picker.pickImage(source: source);
      if (picked != null) setState(() => _photos.add(File(picked.path)));
    }
    widget.onPhotosChanged(_photos);
  }

  void _remove(int index) {
    setState(() => _photos.removeAt(index));
    widget.onPhotosChanged(_photos);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Thumbnails
        if (_photos.isNotEmpty)
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_photos[i],
                        width: 80, height: 80, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: () => _remove(i),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_photos.isNotEmpty) const SizedBox(height: 8),

        // Buttons
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.camera),
              icon: const Icon(Icons.camera_alt, size: 18),
              label: const Text('Camera'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library, size: 18),
              label: const Text('Gallery'),
            ),
          ],
        ),
      ],
    );
  }
}
