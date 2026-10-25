import 'package:flutter/material.dart';
import '../../../../core/utils/image_url_helper.dart';

class FullImagePreviewDialog extends StatelessWidget {
  final String imageUrl;
  final String title;

  const FullImagePreviewDialog({
    super.key,
    required this.imageUrl,
    this.title = 'Bukti Transfer',
  });

  @override
  Widget build(BuildContext context) {
    final fullUrl = getFullImageUrl(imageUrl);
    final TransformationController transformController =
        TransformationController();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 750),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.image_outlined,
                      color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.zoom_out_map,
                        color: Colors.white70, size: 20),
                    tooltip: 'Reset Zoom',
                    onPressed: () {
                      transformController.value = Matrix4.identity();
                    },
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 22),
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),

            // Zoomable Image
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: InteractiveViewer(
                  transformationController: transformController,
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: fullUrl.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image_rounded,
                                    size: 48, color: Colors.white54),
                                SizedBox(height: 8),
                                Text(
                                  'Gambar tidak tersedia',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          )
                        : Image.network(
                            fullUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.broken_image_rounded,
                                        size: 48, color: Colors.white54),
                                    SizedBox(height: 8),
                                    Text(
                                      'Gagal memuat gambar bukti transfer',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
