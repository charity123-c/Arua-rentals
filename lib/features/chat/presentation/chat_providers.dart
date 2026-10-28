import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(),
);

final chatRoomsProvider = StreamProvider<List<ChatRoom>>((ref) async* {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    yield const [];
    return;
  }
  yield* ref.watch(chatRepositoryProvider).watchRooms(user.uid);
});

final chatRoomProvider = FutureProvider.family<ChatRoom, String>(
  (ref, roomId) => ref.watch(chatRepositoryProvider).getRoom(roomId),
);

final chatMessagesProvider = StreamProvider.family<ChatMessagePage, String>(
  (ref, roomId) => ref
      .watch(chatRepositoryProvider)
      .watchRecentMessages(roomId, limit: ChatRepository.pageSize),
);

final totalUnreadChatsProvider = Provider<int>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  final rooms = ref.watch(chatRoomsProvider).asData?.value;
  if (uid == null || rooms == null) return 0;
  return rooms.fold(0, (sum, room) => sum + room.unreadFor(uid));
});
