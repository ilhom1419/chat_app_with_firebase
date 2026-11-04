import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_player/video_player.dart';
import '../../domain/repositories/story_repository.dart';
import '../utils/story_gradients.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';
import '../../../../shared/widgets/floating_bottom_sheet.dart';
import '../../../media_editor/presentation/pages/media_editor_page.dart';
import '../../../media_editor/presentation/pages/video_trim_page.dart';

class CreateStoryPage extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String? currentUserPhoto;

  const CreateStoryPage({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    this.currentUserPhoto,
  });

  @override
  State<CreateStoryPage> createState() => _CreateStoryPageState();
}

class _CreateStoryPageState extends State<CreateStoryPage> {
  final _picker = ImagePicker();
  final _captionController = TextEditingController();
  final _textStoryController = TextEditingController();

  int _selectedTabIndex = 0; // 0: Photo, 1: Text
  int _selectedGradientIndex = 0;
  File? _selectedImageFile;
  File? _selectedVideoFile;
  VideoPlayerController? _videoPreviewController;
  bool _isLoading = false;

  // Selected author (personal vs channel)
  late String _authorId;
  late String _authorName;
  String? _authorAvatar;
  bool _isChannel = false;
  bool _isGroup = false;

  List<Map<String, dynamic>> _userChannels = [];
  List<Map<String, dynamic>> _userGroups = [];

  @override
  void initState() {
    super.initState();
    _authorId = widget.currentUserId;
    _authorName = widget.currentUserName;
    _authorAvatar = widget.currentUserPhoto;
    _loadUserChannels();
  }

  Future<void> _loadUserChannels() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('chats')
          .where('isChannel', isEqualTo: true)
          .where('createdBy', isEqualTo: widget.currentUserId)
          .get();

      final groupSnap = await FirebaseFirestore.instance
          .collection('chats')
          .where('isGroup', isEqualTo: true)
          .where('createdBy', isEqualTo: widget.currentUserId)
          .get();

      if (mounted) {
        setState(() {
          _userChannels = snap.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['groupName'] as String? ?? 'Kanal',
              'avatar': data['groupImage'] as String?,
            };
          }).toList();
          _userGroups = groupSnap.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['groupName'] as String? ?? 'Guruh',
              'avatar': data['groupAvatar'] as String?,
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading user channels: $e');
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _textStoryController.dispose();
    _videoPreviewController?.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1800,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        _videoPreviewController?.pause();
        _videoPreviewController?.dispose();
        _videoPreviewController = null;
        _selectedVideoFile = null;

        final edited = await MediaEditorPage.open(
          context,
          imageFile: File(picked.path),
          isStoryMode: true,
        );
        if (edited != null && mounted) {
          setState(() {
            _selectedImageFile = edited;
          });
        } else if (mounted && _selectedImageFile == null) {
          setState(() {
            _selectedImageFile = File(picked.path);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocalizationService.formatError(e))),
        );
      }
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final picked = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 5),
      );
      if (picked != null && mounted) {
        final trimmed = await VideoTrimPage.open(
          context,
          videoFile: File(picked.path),
        );
        final videoToUse = trimmed ?? File(picked.path);
        if (mounted) {
          _videoPreviewController?.pause();
          _videoPreviewController?.dispose();
          final controller = VideoPlayerController.file(videoToUse);
          await controller.initialize();
          controller.setLooping(true);
          controller.play();

          setState(() {
            _selectedVideoFile = videoToUse;
            _selectedImageFile = null;
            _videoPreviewController = controller;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocalizationService.formatError(e))),
        );
      }
    }
  }

  Future<void> _publishStory() async {
    if (_selectedTabIndex == 0) {
      // Photo / Video story
      if (_selectedImageFile == null && _selectedVideoFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocalizationService.translate('select_media_first'))),
        );
        return;
      }
    } else {
      // Text story
      if (_textStoryController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocalizationService.translate('enter_story_text'))),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? mediaUrl;

      if (_selectedTabIndex == 0) {
        if (_selectedVideoFile != null) {
          // Upload trimmed video
          final bytesToUse = await _selectedVideoFile!.readAsBytes();
          try {
            final filename =
                '${DateTime.now().millisecondsSinceEpoch}_${widget.currentUserId}.mp4';
            final storageRef = FirebaseStorage.instance
                .ref()
                .child('stories')
                .child(filename);

            final uploadTask = await storageRef.putData(
              bytesToUse,
              SettableMetadata(contentType: 'video/mp4'),
            );
            mediaUrl = await uploadTask.ref.getDownloadURL();
          } catch (storageErr) {
            final base64String = base64Encode(bytesToUse);
            mediaUrl = 'data:video/mp4;base64,$base64String';
          }
        } else if (_selectedImageFile != null) {
          // Compress & Upload edited image
          final filePath = _selectedImageFile!.path;
          final compressedBytes = await FlutterImageCompress.compressWithFile(
            filePath,
            quality: 80,
            minWidth: 1080,
            minHeight: 1920,
          );

          final bytesToUse = compressedBytes ?? await _selectedImageFile!.readAsBytes();

          try {
            final filename =
                '${DateTime.now().millisecondsSinceEpoch}_${widget.currentUserId}.jpg';
            final storageRef = FirebaseStorage.instance
                .ref()
                .child('stories')
                .child(filename);

            final uploadTask = await storageRef.putData(
              bytesToUse,
              SettableMetadata(contentType: 'image/jpeg'),
            );
            mediaUrl = await uploadTask.ref.getDownloadURL();
          } catch (storageErr) {
            // Fallback to base64 if Firebase Storage rules or bucket are unavailable
            final base64String = base64Encode(bytesToUse);
            mediaUrl = 'data:image/jpeg;base64,$base64String';
          }
        }
      }

      final caption = _selectedTabIndex == 0 &&
              _captionController.text.trim().isNotEmpty
          ? _captionController.text.trim()
          : null;

      final textContent = _selectedTabIndex == 1
          ? _textStoryController.text.trim()
          : null;

      await context.read<StoryRepository>().createStory(
            authorId: _authorId,
            authorName: _authorName,
            authorAvatar: _authorAvatar,
            isChannel: _isChannel,
            isGroup: _isGroup,
            mediaUrl: mediaUrl,
            caption: caption,
            textContent: textContent,
            gradientIndex: _selectedGradientIndex,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocalizationService.translate('story_posted_success')),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocalizationService.formatError(e)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showAuthorPickerSheet() {
    showKakkuFloatingBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  LocalizationService.of(context).get('choose_story_author'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(
                  widget.currentUserName,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  LocalizationService.of(context).get('personal_profile_story'),
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: !_isChannel
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() {
                    _authorId = widget.currentUserId;
                    _authorName = widget.currentUserName;
                    _authorAvatar = widget.currentUserPhoto;
                    _isChannel = false;
                    _isGroup = false;
                  });
                  Navigator.of(ctx).pop();
                },
              ),
              if (_userChannels.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      LocalizationService.of(context).get('your_channels_story'),
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                ..._userChannels.map((channel) {
                  final isSelected =
                      _isChannel && _authorId == channel['id'];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.deepOrange,
                      child: Icon(Icons.campaign, color: Colors.white),
                    ),
                    title: Text(
                      channel['name'] as String,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      LocalizationService.of(context).get('on_behalf_of_channel'),
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary)
                        : null,
                    onTap: () {
                      setState(() {
                        _authorId = channel['id'] as String;
                        _authorName = channel['name'] as String;
                        _authorAvatar = channel['avatar'] as String?;
                        _isChannel = true;
                        _isGroup = false;
                      });
                      Navigator.of(ctx).pop();
                    },
                  );
                }),
              ],
              if (_userGroups.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'GURUHLARINGIZ',
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                ..._userGroups.map((group) {
                  final isSelected =
                      _isGroup && _authorId == group['id'];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.indigoAccent,
                      child: Icon(Icons.group, color: Colors.white),
                    ),
                    title: Text(
                      group['name'] as String,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Guruh nomidan',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary)
                        : null,
                    onTap: () {
                      setState(() {
                        _authorId = group['id'] as String;
                        _authorName = group['name'] as String;
                        _authorAvatar = group['avatar'] as String?;
                        _isChannel = false;
                        _isGroup = true;
                      });
                      Navigator.of(ctx).pop();
                    },
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: GestureDetector(
          onTap: (_userChannels.isNotEmpty || _userGroups.isNotEmpty) ? _showAuthorPickerSheet : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _authorName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_userChannels.isNotEmpty) ...[
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70, size: 20),
              ],
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _publishStory,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: Text(
                      LocalizationService.translate('share_story_btn'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔘 Segmented Tab Switcher (Photo vs Text)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 0
                            ? AppColors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.photo_camera_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            LocalizationService.translate('photo_label'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 1
                            ? AppColors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.text_fields_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            LocalizationService.translate('text_label'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 📱 Main Editor Area
          Expanded(
            child: _selectedTabIndex == 0
                ? _buildPhotoEditor()
                : _buildTextEditor(),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoEditor() {
    final hasMedia = _selectedImageFile != null || _selectedVideoFile != null;
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            clipBehavior: Clip.antiAlias,
            child: _selectedVideoFile != null &&
                    _videoPreviewController != null &&
                    _videoPreviewController!.value.isInitialized
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio:
                              _videoPreviewController!.value.aspectRatio,
                          child: VideoPlayer(_videoPreviewController!),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(Icons.content_cut_rounded,
                                    color: Colors.white),
                                tooltip: LocalizationService.translate('trim_video_tooltip'),
                                onPressed: () async {
                                  final retrimmed = await VideoTrimPage.open(
                                    context,
                                    videoFile: _selectedVideoFile!,
                                  );
                                  if (retrimmed != null && mounted) {
                                    _videoPreviewController?.pause();
                                    _videoPreviewController?.dispose();
                                    final c =
                                        VideoPlayerController.file(retrimmed);
                                    await c.initialize();
                                    c.setLooping(true);
                                    c.play();
                                    setState(() {
                                      _selectedVideoFile = retrimmed;
                                      _videoPreviewController = c;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(Icons.refresh_rounded,
                                    color: Colors.white),
                                tooltip: LocalizationService.translate('select_other_video'),
                                onPressed: () =>
                                    _pickVideo(ImageSource.gallery),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : (_selectedImageFile != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            _selectedImageFile!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.black54,
                                  child: IconButton(
                                    icon: const Icon(Icons.edit_rounded,
                                        color: Colors.white),
                                    tooltip: LocalizationService.translate('edit'),
                                    onPressed: () async {
                                      final edited =
                                          await MediaEditorPage.open(
                                        context,
                                        imageFile: _selectedImageFile!,
                                        isStoryMode: true,
                                      );
                                      if (edited != null && mounted) {
                                        setState(() {
                                          _selectedImageFile = edited;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  backgroundColor: Colors.black54,
                                  child: IconButton(
                                    icon: const Icon(Icons.refresh_rounded,
                                        color: Colors.white),
                                    tooltip: LocalizationService.translate('select_other_image'),
                                    onPressed: () =>
                                        _pickImage(ImageSource.gallery),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.perm_media_outlined,
                                size: 64, color: Colors.white38),
                            const SizedBox(height: 16),
                            Text(
                              LocalizationService.of(context).get('select_media_for_story'),
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 16),
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _pickImage(ImageSource.gallery),
                                  icon: const Icon(Icons.photo_library_rounded,
                                      color: Colors.white),
                                  label: Text(LocalizationService.translate('photo_gallery'),
                                      style: TextStyle(color: Colors.white)),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.white.withOpacity(0.15),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _pickImage(ImageSource.camera),
                                  icon: const Icon(Icons.camera_alt_rounded,
                                      color: Colors.white),
                                  label: Text(LocalizationService.translate('photo_camera'),
                                      style: TextStyle(color: Colors.white)),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.deepOrange.withOpacity(0.85),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _pickVideo(ImageSource.gallery),
                                  icon: const Icon(
                                      Icons.video_library_rounded,
                                      color: Colors.white),
                                  label: Text(LocalizationService.translate('video_gallery'),
                                      style: TextStyle(color: Colors.white)),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.teal.withOpacity(0.85),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _pickVideo(ImageSource.camera),
                                  icon: const Icon(
                                      Icons.videocam_rounded,
                                      color: Colors.white),
                                  label: Text(LocalizationService.translate('video_camera'),
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )),
          ),
        ),

        // Caption Input Field
        if (hasMedia)
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24),
              ),
              child: TextField(
                controller: _captionController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: LocalizationService.translate('optional_caption_hint'),
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.edit_note_rounded,
                      color: Colors.white54),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTextEditor() {
    final gradient = StoryGradients.getGradient(_selectedGradientIndex);

    return Column(
      children: [
        // Live Gradient Preview Container with editable text
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: TextField(
              controller: _textStoryController,
              textAlign: TextAlign.center,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                height: 1.35,
                shadows: [
                  Shadow(
                    blurRadius: 8,
                    color: Colors.black38,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              decoration: InputDecoration(
                hintText: LocalizationService.translate('write_thoughts_hint'),
                hintStyle: const TextStyle(
                  color: Colors.white54,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ),

        // Gradient Palette Selector
        SafeArea(
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: StoryGradients.gradients.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedGradientIndex == index;
                final grad = StoryGradients.getGradient(index);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedGradientIndex = index;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: isSelected ? 48 : 40,
                    height: isSelected ? 48 : 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: grad,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : Border.all(color: Colors.white24, width: 1),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
