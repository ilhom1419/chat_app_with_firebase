import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/message.dart';
import '../pages/pdf_viewer_page.dart';

/// A sleek, refined document and file attachment component.
/// Eliminates bulky double-nested borders and provides clear file metadata,
/// type-specific iconography, and responsive tap feedback.
class FileBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const FileBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  IconData _getFileIcon(String? fileName) {
    if (fileName == null) return Icons.insert_drive_file_rounded;
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.folder_zip_rounded;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_rounded;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'flac':
        return Icons.audio_file_rounded;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return Icons.video_file_rounded;
      case 'txt':
        return Icons.article_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileIconColor(String? fileName) {
    if (fileName == null) return const Color(0xFF38BDF8);
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return const Color(0xFFEF4444);
      case 'doc':
      case 'docx':
        return const Color(0xFF3B82F6);
      case 'zip':
      case 'rar':
      case '7z':
        return const Color(0xFFF59E0B);
      case 'xls':
      case 'xlsx':
      case 'csv':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6366F1);
    }
  }

  void _onOpen(BuildContext context) async {
    final path = message.fileUrl ?? '';
    final isPdf = (message.fileName ?? '').toLowerCase().endsWith('.pdf') ||
        path.toLowerCase().endsWith('.pdf');

    if (path.isNotEmpty && File(path).existsSync()) {
      if (isPdf) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfViewerPage(
              filePath: path,
              title: message.fileName ?? 'PDF Document',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File: ${message.fileName ?? path}')),
        );
      }
    } else if (path.startsWith('data:') || path.startsWith('http')) {
      // If base64 or remote URL, write to temporary file if PDF
      try {
        if (isPdf && path.contains('base64,')) {
          final bytes = Uri.parse(path).data?.contentAsBytes();
          if (bytes != null) {
            final tempDir = await getTemporaryDirectory();
            final tempFile =
                File('${tempDir.path}/${message.fileName ?? "temp.pdf"}');
            await tempFile.writeAsBytes(bytes);
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PdfViewerPage(
                    filePath: tempFile.path,
                    title: message.fileName ?? 'PDF Document',
                  ),
                ),
              );
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fayl: ${message.fileName ?? "Yuklanmoqda"}')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to open file: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = message.fileName ?? 'Fayl (Document)';
    final fileSize = message.fileSize ?? 'Hujjat';
    final iconData = _getFileIcon(fileName);
    final iconColor = _getFileIconColor(fileName);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onOpen(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          constraints: const BoxConstraints(maxWidth: 260),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Clean icon avatar with soft backdrop
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withOpacity(0.18)
                      : (isDark
                          ? iconColor.withOpacity(0.16)
                          : iconColor.withOpacity(0.12)),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    iconData,
                    color: isMe ? Colors.white : iconColor,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isMe
                            ? Colors.white
                            : (isDark
                                ? const Color(0xFFF8FAFC)
                                : const Color(0xFF0F172A)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fileSize,
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe
                            ? Colors.white.withOpacity(0.72)
                            : (isDark
                                ? Colors.white54
                                : Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isMe
                      ? Colors.white.withOpacity(0.12)
                      : (isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
                ),
                child: Icon(
                  Icons.arrow_downward_rounded,
                  size: 15,
                  color: isMe
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
