import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../shared/utils/app_image.dart';
import '../../../../shared/widgets/floating_bottom_sheet.dart';
import '../../../../core/localization/localization_service.dart';
import '../../../messages/presentation/pages/pdf_viewer_page.dart';
import '../../../messages/presentation/widgets/voice_player_widget.dart';
import '../../domain/entities/saved_message.dart';

class SavedMessageBubble extends StatelessWidget {
  final SavedMessage message;
  final VoidCallback onDelete;

  const SavedMessageBubble({
    super.key,
    required this.message,
    required this.onDelete,
  });

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

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
        return Icons.folder_zip_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'mp3':
      case 'wav':
      case 'm4a':
        return Icons.audio_file_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileIconColor(String? fileName) {
    if (fileName == null) return Colors.blueAccent;
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Colors.redAccent;
      case 'doc':
      case 'docx':
        return Colors.blueAccent;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.amber;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      default:
        return AppColors.primary;
    }
  }

  void _onOpenFile(BuildContext context) async {
    final url = message.attachmentUrl ?? '';
    final name = message.attachmentName ?? 'document';
    final isPdf = name.toLowerCase().endsWith('.pdf') || url.toLowerCase().contains('.pdf');

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocalizationService.translate('file_unavailable'))),
      );
      return;
    }

    if (isPdf) {
      if (File(url).existsSync()) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfViewerPage(filePath: url, title: name),
          ),
        );
      } else if (url.startsWith('data:')) {
        try {
          final clean = url.contains(',') ? url.split(',').last.trim() : url.trim();
          final bytes = base64Decode(clean);
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/$name');
          await tempFile.writeAsBytes(bytes);
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PdfViewerPage(filePath: tempFile.path, title: name),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${LocalizationService.translate("download_failed")}: $e')),
            );
          }
        }
      } else {
        // Remote URL - download to temp and open
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocalizationService.translate('uploading')),
              duration: const Duration(seconds: 1),
            ),
          );
          final client = HttpClient();
          final request = await client.getUrl(Uri.parse(url));
          final response = await request.close();
          final bytes = await consolidateHttpClientResponseBytes(response);
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/$name');
          await tempFile.writeAsBytes(bytes);
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PdfViewerPage(filePath: tempFile.path, title: name),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${LocalizationService.translate("download_failed")}: $e')),
            );
          }
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name (${_formatFileSize(message.attachmentSize)})')),
      );
    }
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: imageUrl.startsWith('data:image/')
                    ? AppImage.memory(
                        imageUrl,
                        fit: BoxFit.contain,
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image_rounded, color: Colors.white, size: 64),
                      ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showKakkuFloatingBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (message.text != null && message.text!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: AppColors.primary),
                  title: Text(LocalizationService.translate('copy_action_title')),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.text!));
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(LocalizationService.translate('text_copied')),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              if (message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.open_in_new_rounded, color: Colors.blueAccent),
                  title: Text(LocalizationService.translate('open_file')),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _onOpenFile(context);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: Text(
                  LocalizationService.translate('delete_saved_message'),
                  style: const TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmDelete(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocalizationService.translate('delete_saved_message')),
        content: Text(LocalizationService.translate('delete_saved_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(LocalizationService.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.of(ctx).pop();
              onDelete();
            },
            child: Text(LocalizationService.translate('delete')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = DateFormat('HH:mm').format(message.createdAt);

    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onLongPress: () => _showContextMenu(context),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Forwarded attribution banner
                if (message.isForwarded) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.forward_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          LocalizationService.translate(
                            'forwarded_from',
                            params: {'name': message.originalSenderName ?? 'Foydalanuvchi'},
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Divider(
                    height: 1,
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                  const SizedBox(height: 6),
                ],

                // 2. Main content
                _buildContent(context, isDark),

                const SizedBox(height: 4),

                // 3. Footer: status + timestamp
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Spacer(),
                    if (message.uploadStatus == SavedMessageUploadStatus.uploading) ...[
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        LocalizationService.translate('uploading'),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ] else if (message.uploadStatus == SavedMessageUploadStatus.failed) ...[
                      const Icon(Icons.error_outline_rounded, size: 12, color: Colors.redAccent),
                      const SizedBox(width: 4),
                      Text(
                        LocalizationService.translate('save_failed'),
                        style: const TextStyle(fontSize: 10, color: Colors.redAccent),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.bookmark_rounded,
                      size: 13,
                      color: AppColors.primary.withOpacity(0.85),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    switch (message.type) {
      case SavedMessageType.image:
        final url = message.attachmentUrl ?? '';
        final isDataUri = url.startsWith('data:image/');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (url.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GestureDetector(
                  onTap: () => _showImageDialog(context, url),
                  child: isDataUri
                      ? AppImage.memory(
                          url,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 200,
                        )
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 200,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: 200,
                              color: isDark ? Colors.white10 : Colors.black12,
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 140,
                            color: isDark ? Colors.white10 : Colors.black12,
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                            ),
                          ),
                        ),
                ),
              ),
            if (message.text != null && message.text!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message.text!,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ],
        );

      case SavedMessageType.voice:
        final url = message.attachmentUrl ?? '';
        final duration = message.attachmentDuration ?? 0;
        return VoicePlayerWidget(
          url: url,
          duration: duration,
          isMe: true,
          messageId: message.savedId,
        );

      case SavedMessageType.audio:
        final url = message.attachmentUrl ?? '';
        final duration = message.attachmentDuration ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.audio_file_rounded, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message.attachmentName ?? 'Audio file',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (url.isNotEmpty)
              VoicePlayerWidget(
                url: url,
                duration: duration,
                isMe: true,
                messageId: message.savedId,
              ),
          ],
        );

      case SavedMessageType.document:
        final name = message.attachmentName ?? 'Document';
        final size = _formatFileSize(message.attachmentSize);
        final icon = _getFileIcon(name);
        final iconColor = _getFileIconColor(name);

        return InkWell(
          onTap: () => _onOpenFile(context),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        size.isNotEmpty ? size : LocalizationService.translate('document_file'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_downward_rounded,
                  color: isDark ? Colors.white38 : Colors.black38,
                  size: 20,
                ),
              ],
            ),
          ),
        );

      case SavedMessageType.text:
        return Text(
          message.text ?? '',
          style: TextStyle(
            fontSize: 15,
            height: 1.3,
            color: isDark ? Colors.white : Colors.black87,
          ),
        );
    }
  }
}
