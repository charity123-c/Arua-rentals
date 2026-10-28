import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../listings/presentation/listing_copy.dart';
import 'chat_providers.dart';

class ChatInboxScreen extends ConsumerWidget {
  const ChatInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(chatRoomsProvider);
    final uid = ref.watch(authStateProvider).asData?.value?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text(ListingCopy.inbox)),
      body: rooms.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => ErrorView(
          message: ListingCopy.chatInboxError,
          retryLabel: ListingCopy.retry,
          onRetry: () => ref.invalidate(chatRoomsProvider),
        ),
        data: (items) {
          if (items.isEmpty || uid == null) {
            return const EmptyView(
              title: ListingCopy.noChatsTitle,
              message: ListingCopy.noChatsMessage,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: items.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.xs),
            itemBuilder: (context, index) {
              final room = items[index];
              final unread = room.unreadFor(uid);
              return Card(
                child: ListTile(
                  onTap: () => context.go('/chat/${room.id}'),
                  leading: SizedBox(
                    width: AppLayout.listingThumbnailSize,
                    height: AppLayout.listingThumbnailSize,
                    child: AppNetworkImage(
                      imageUrl: room.listingThumb,
                      semanticLabel: room.listingTitle,
                    ),
                  ),
                  title: Text(
                    room.listingTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    room.lastMessage.isEmpty
                        ? ListingCopy.startConversation
                        : room.lastMessage,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: unread == 0
                      ? null
                      : CircleAvatar(
                          radius: AppSpacing.md,
                          child: Text('$unread'),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
