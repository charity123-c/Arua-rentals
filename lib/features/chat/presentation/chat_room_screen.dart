import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../listings/presentation/listing_copy.dart';
import '../data/chat_repository.dart';
import 'chat_providers.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({required this.roomId, super.key});

  final String roomId;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _olderMessages = const [];
  DocumentSnapshot<Map<String, dynamic>>? _olderCursor;
  bool _loadingOlder = false;
  bool _hasOlder = true;
  bool _sending = false;
  bool _loadingFailed = false;
  String? _failedText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;
    try {
      await ref.read(chatRepositoryProvider).markRead(widget.roomId, uid);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(ListingCopy.chatReadFailed)));
    }
  }

  Future<void> _loadOlder(ChatMessagePage page) async {
    final cursor = _olderCursor ?? page.lastDocument;
    if (cursor == null || !_hasOlder || _loadingOlder || _loadingFailed) return;
    setState(() => _loadingOlder = true);
    try {
      final older = await ref
          .read(chatRepositoryProvider)
          .getOlderMessages(widget.roomId, startAfter: cursor);
      if (!mounted) return;
      setState(() {
        _olderMessages = [..._olderMessages, ...older.items];
        _olderCursor = older.lastDocument ?? cursor;
        _hasOlder = older.items.length == ChatRepository.pageSize;
        _loadingFailed = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _loadingFailed = true);
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _send() async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    final text = _messageController.text.trim();
    if (uid == null || text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _failedText = null;
    });
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(roomId: widget.roomId, senderId: uid, text: text);
      if (!mounted) return;
      _messageController.clear();
      setState(() => _failedText = null);
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: AppMotion.pageTransitionDuration,
          curve: Curves.easeOut,
        );
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _failedText = text);
      final message = error is AppException
          ? error.message
          : ListingCopy.chatSendFailed;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(chatRoomProvider(widget.roomId));
    final messagesState = ref.watch(chatMessagesProvider(widget.roomId));
    ref.listen(chatMessagesProvider(widget.roomId), (previous, next) {
      final previousMessages = previous?.asData?.value.items;
      final nextMessages = next.asData?.value.items;
      if (previousMessages != null &&
          nextMessages != null &&
          nextMessages.isNotEmpty &&
          previousMessages.first.id != nextMessages.first.id &&
          _scrollController.hasClients &&
          _scrollController.position.pixels < AppLayout.minimumTapTarget * 3) {
        unawaited(
          _scrollController.animateTo(
            0,
            duration: AppMotion.pageTransitionDuration,
            curve: Curves.easeOut,
          ),
        );
      }
      final uid = ref.read(authStateProvider).asData?.value?.uid;
      final latest = next.asData?.value.items.firstOrNull;
      if (uid != null &&
          latest != null &&
          latest.senderId != uid &&
          previous?.asData?.value.items.firstOrNull?.id != latest.id) {
        unawaited(_markRead());
      }
    });
    return roomState.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text(ListingCopy.chat)),
        body: const LoadingView(),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text(ListingCopy.chat)),
        body: ErrorView(
          message: ListingCopy.chatRoomError,
          retryLabel: ListingCopy.retry,
          onRetry: () => ref.invalidate(chatRoomProvider(widget.roomId)),
        ),
      ),
      data: (room) {
        final uid = ref.watch(authStateProvider).asData?.value?.uid;
        if (uid == null || !room.participants.contains(uid)) {
          return Scaffold(
            appBar: AppBar(title: const Text(ListingCopy.chat)),
            body: const Center(child: Text(ListingCopy.chatRoomError)),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(
              room.listingTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: messagesState.when(
                  loading: () => const LoadingView(),
                  error: (error, stackTrace) => ErrorView(
                    message: ListingCopy.chatMessagesError,
                    retryLabel: ListingCopy.retry,
                    onRetry: () =>
                        ref.invalidate(chatMessagesProvider(widget.roomId)),
                  ),
                  data: (page) {
                    final messages = [...page.items, ..._olderMessages];
                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: messages.length + 1,
                      itemBuilder: (context, index) {
                        if (index == messages.length) {
                          if (_loadingOlder) {
                            return const Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (_loadingFailed) {
                            return TextButton(
                              onPressed: () => _loadOlder(page),
                              child: const Text(ListingCopy.chatHistoryRetry),
                            );
                          }
                          if (!_hasOlder ||
                              (page.items.length < ChatRepository.pageSize &&
                                  _olderMessages.isEmpty)) {
                            return const SizedBox.shrink();
                          }
                          return TextButton(
                            onPressed: () => _loadOlder(page),
                            child: const Text(ListingCopy.loadEarlierMessages),
                          );
                        }
                        final message = messages[index];
                        return _MessageBubble(
                          message: message,
                          isMine: message.senderId == uid,
                        );
                      },
                    );
                  },
                ),
              ),
              if (_failedText != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(ListingCopy.messageFailedRetry),
                      ),
                      TextButton(
                        onPressed: () {
                          _messageController.text = _failedText!;
                          _send();
                        },
                        child: const Text(ListingCopy.retry),
                      ),
                    ],
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          maxLength: 1000,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText: ListingCopy.typeMessage,
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      IconButton.filled(
                        tooltip: _sending
                            ? ListingCopy.sendingMessage
                            : ListingCopy.sendMessage,
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: AppSpacing.md,
                                height: AppSpacing.md,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                      ),
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isMine ? colors.primaryContainer : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(message.text),
            if (isMine)
              Text(
                ListingCopy.messageSent,
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
  }
}
