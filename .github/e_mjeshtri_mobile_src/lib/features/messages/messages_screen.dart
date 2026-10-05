import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../marketplace/marketplace_repository.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});
  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  late Future<List<Map<String, dynamic>>> future;
  final search = TextEditingController();
  String query = '';

  @override
  void initState() {
    super.initState();
    future = ref.read(marketplaceRepositoryProvider).conversations();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void reload() => setState(() => future = ref.read(marketplaceRepositoryProvider).conversations());

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Text(s.t('messages'), style: Theme.of(context).textTheme.headlineMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: search,
              onChanged: (v) => setState(() => query = v.trim().toLowerCase()),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: s.t('search')),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (snap.hasError) return Center(child: FilledButton(onPressed: reload, child: Text(s.t('retry'))));
                var items = snap.data ?? [];
                items = items.where((c) {
                  final p = (c['providers'] as Map?)?.cast<String, dynamic>() ?? {};
                  return query.isEmpty || (p['display_name'] ?? '').toString().toLowerCase().contains(query);
                }).toList();
                if (items.isEmpty) return EmptyState(icon: Icons.forum_outlined, title: s.t('noMessages'));
                return RefreshIndicator(
                  onRefresh: () async => reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = items[i];
                      final p = (c['providers'] as Map?)?.cast<String, dynamic>() ?? {};
                      final messages = (c['messages'] as List? ?? const []).cast<Map>();
                      messages.sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
                      final last = messages.isEmpty ? null : messages.first;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: .08), borderRadius: BorderRadius.circular(17)),
                          child: const Icon(Icons.handyman_rounded, color: AppColors.blue),
                        ),
                        title: Row(
                          children: [
                            Flexible(child: Text((p['display_name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800))),
                            if (hasActiveBlueTick(p))
                              const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, size: 16, color: AppColors.blue)),
                          ],
                        ),
                        subtitle: Text(last?['body']?.toString() ?? s.t('noMessages'), maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: last == null
                            ? null
                            : Text(
                                DateFormat('HH:mm').format(DateTime.parse(last['created_at'].toString()).toLocal()),
                                style: const TextStyle(color: AppColors.muted, fontSize: 12),
                              ),
                        onTap: () => context.push('/chat/${c['id']}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final input = TextEditingController();
  final picker = ImagePicker();
  bool sending = false;
  bool attaching = false;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (input.text.trim().isEmpty || sending) return;
    final text = input.text;
    input.clear();
    setState(() => sending = true);
    try {
      await ref.read(marketplaceRepositoryProvider).sendMessage(widget.conversationId, text);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _uploadXFile(XFile file, {required String messageType}) async {
    final name = file.name;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : (messageType == 'video' ? 'mp4' : 'jpg');
    final contentType = messageType == 'video'
        ? (ext == 'mov' ? 'video/quicktime' : 'video/mp4')
        : switch (ext) {
            'png' => 'image/png',
            'webp' => 'image/webp',
            'heic' => 'image/heic',
            'heif' => 'image/heif',
            _ => 'image/jpeg',
          };
    await ref.read(marketplaceRepositoryProvider).uploadChatAttachment(
      conversationId: widget.conversationId,
      bytes: await file.readAsBytes(),
      extension: ext,
      contentType: contentType,
      messageType: messageType,
      fileName: name,
    );
  }

  Future<void> _pickCamera() async {
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 84, maxWidth: 1800);
    if (file != null) await _uploadXFile(file, messageType: 'image');
  }

  Future<void> _pickGallery() async {
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 86, maxWidth: 1800);
    if (file != null) await _uploadXFile(file, messageType: 'image');
  }

  Future<void> _pickVideo() async {
    final file = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 2));
    if (file != null) await _uploadXFile(file, messageType: 'video');
  }

  Future<void> _pickDocument() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'txt', 'doc', 'docx'],
    );
    if (file == null) return;
    final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'txt';
    final contentType = switch (ext) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'text/plain',
    };
    await ref.read(marketplaceRepositoryProvider).uploadChatAttachment(
      conversationId: widget.conversationId,
      bytes: await file.readAsBytes(),
      extension: ext,
      contentType: contentType,
      messageType: 'file',
      fileName: file.name,
    );
  }

  Future<void> _shareLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw StateError(AppStrings.of(context).t('gpsDisabled'));
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw StateError(AppStrings.of(context).t('locationDenied'));
    }
    final position = await Geolocator.getCurrentPosition();
    await ref.read(marketplaceRepositoryProvider).sendLocationMessage(
      conversationId: widget.conversationId,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<void> _attachAction(Future<void> Function() action) async {
    if (attaching) return;
    setState(() => attaching = true);
    try {
      await action();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).t('errorGeneric'))));
    } finally {
      if (mounted) setState(() => attaching = false);
    }
  }

  void _openAttachments() {
    final s = AppStrings.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Wrap(
            runSpacing: 8,
            children: [
              ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text(s.t('camera')), onTap: () { Navigator.pop(sheetContext); _attachAction(_pickCamera); }),
              ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text(s.t('gallery')), onTap: () { Navigator.pop(sheetContext); _attachAction(_pickGallery); }),
              ListTile(leading: const Icon(Icons.video_library_outlined), title: Text(s.t('video')), onTap: () { Navigator.pop(sheetContext); _attachAction(_pickVideo); }),
              ListTile(leading: const Icon(Icons.attach_file_rounded), title: Text(s.t('document')), onTap: () { Navigator.pop(sheetContext); _attachAction(_pickDocument); }),
              ListTile(leading: const Icon(Icons.my_location_rounded), title: Text(s.t('shareLocation')), onTap: () { Navigator.pop(sheetContext); _attachAction(_shareLocation); }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(marketplaceRepositoryProvider);
    final s = AppStrings.of(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: repo.conversation(widget.conversationId),
      builder: (context, info) {
        final p = (info.data?['providers'] as Map?)?.cast<String, dynamic>() ?? {};
        final providerId = p['id']?.toString();
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Flexible(child: Text((p['display_name'] ?? s.t('chat')).toString())),
                if (hasActiveBlueTick(p))
                  const Padding(padding: EdgeInsets.only(left: 5), child: Icon(Icons.verified_rounded, size: 17, color: AppColors.blue)),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (providerId == null) return;
                  if (value == 'report') {
                    context.push('/report/new?providerId=$providerId&conversationId=${widget.conversationId}');
                  } else if (value == 'block') {
                    await repo.blockProvider(providerId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('blockedProvider'))));
                      context.pop();
                    }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'report', child: Text(s.t('reportUser'))),
                  PopupMenuItem(value: 'block', child: Text(s.t('blockProvider'))),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: repo.messagesStream(widget.conversationId),
                  builder: (context, snap) {
                    final items = snap.data ?? [];
                    if (items.isEmpty) return EmptyState(icon: Icons.forum_outlined, title: s.t('noMessages'));
                    final uid = repo.uid;
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _MessageBubble(message: items[i], mine: items[i]['sender_user_id'] == uid),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: attaching ? null : _openAttachments,
                        icon: attaching
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add_circle_outline_rounded),
                      ),
                      Expanded(
                        child: TextField(
                          controller: input,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(hintText: s.t('typeMessage')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(onPressed: sending ? null : send, icon: const Icon(Icons.send_rounded)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({required this.message, required this.mine});
  final Map<String, dynamic> message;
  final bool mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final system = message['is_system'] == true;
    final type = (message['message_type'] ?? 'text').toString();
    final metadata = (message['metadata'] as Map?)?.cast<String, dynamic>() ?? {};
    final bubbleColor = system
        ? Theme.of(context).dividerColor
        : mine
            ? AppColors.blue
            : Theme.of(context).cardColor;
    final textColor = mine ? Colors.white : Theme.of(context).colorScheme.onSurface;

    Widget content;
    if (type == 'image') {
      content = _ChatImage(path: metadata['storage_path']?.toString(), caption: message['body']?.toString(), mine: mine);
    } else if (type == 'video') {
      content = Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.play_circle_outline_rounded, color: textColor), const SizedBox(width: 8), Flexible(child: Text((metadata['file_name'] ?? message['body'] ?? 'Video').toString(), style: TextStyle(color: textColor)))]);
    } else if (type == 'file') {
      content = Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.description_outlined, color: textColor), const SizedBox(width: 8), Flexible(child: Text((metadata['file_name'] ?? message['body'] ?? '').toString(), style: TextStyle(color: textColor)))]);
    } else if (type == 'location') {
      final lat = metadata['latitude'] ?? '';
      final lng = metadata['longitude'] ?? '';
      content = Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.location_on_rounded, color: mine ? Colors.white : AppColors.blue), const SizedBox(width: 8), Flexible(child: Text('$lat, $lng', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)))]);
    } else {
      content = Text((message['body'] ?? '').toString(), style: TextStyle(color: textColor, fontStyle: system ? FontStyle.italic : null));
    }

    return Align(
      alignment: system ? Alignment.center : mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(18),
          border: mine || system ? null : Border.all(color: Theme.of(context).dividerColor),
        ),
        child: content,
      ),
    );
  }
}

class _ChatImage extends ConsumerWidget {
  const _ChatImage({required this.path, required this.caption, required this.mine});
  final String? path;
  final String? caption;
  final bool mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String?>(
      future: ref.read(marketplaceRepositoryProvider).chatMediaSignedUrl(path),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox(width: 180, height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(snap.data!, width: 220, height: 160, fit: BoxFit.cover),
            ),
            if (caption != null && caption!.trim().isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mine ? Colors.white : Theme.of(context).colorScheme.onSurface, fontSize: 12)),
            ],
          ],
        );
      },
    );
  }
}