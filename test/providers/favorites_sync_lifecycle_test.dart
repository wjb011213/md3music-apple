import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md3music/data/models/song.dart';
import 'package:md3music/data/repositories/favorite_sync_store.dart';
import 'package:md3music/providers/favorites_provider.dart';
import 'package:md3music/services/favorite_sync.dart';

Song _song(String id, {bool online = true}) => Song(
  id: id,
  title: 'Song $id',
  artist: 'Artist',
  album: 'Album',
  duration: const Duration(minutes: 3),
  artworkUri: 'https://example.test/$id.jpg',
  isOnline: online,
);

class _MemoryStore extends FavoriteSyncStore {
  final Map<String, FavoriteSyncState> data = {};
  String _key(String? account) => account ?? 'guest';

  @override
  Future<FavoriteSyncState> load(String? account) async =>
      data[_key(account)] ?? const FavoriteSyncState();

  @override
  Future<void> save(String? account, FavoriteSyncState state) async {
    data[_key(account)] = state;
  }
}

class _FakeRemote implements FavoriteSyncRemote {
  _FakeRemote({
    required this.accountId,
    required List<Song> songs,
    Map<String, List<int>>? recordIds,
  })  : _songs = List.of(songs),
        _recordIds = {
          for (var i = 0; i < songs.length; i++) songs[i].id: [100 + i],
          ...?recordIds,
        };

  @override
  String? accountId;
  @override
  Listenable? get accountChanges => null;
  @override
  ValueListenable<bool>? get connectivity => null;
  final List<Song> _songs;
  final Map<String, List<int>> _recordIds;
  bool failFetch = false;
  bool failWrite = false;
  int writes = 0;
  int fetches = 0;
  int _nextFileId = 900;
  Completer<void>? gate;
  final List<FavoriteIntent> writeLog = [];

  @override
  Future<void> ready() async {}

  Future<FavoriteCloudSnapshot> _snapshot() async => FavoriteCloudSnapshot(
    listId: 'list',
    songs: List.of(_songs),
    recordIds: _recordIds,
  );

  @override
  Future<FavoriteCloudSnapshot> fetch(String account) async {
    fetches++;
    if (gate != null) await gate!.future;
    if (failFetch) throw const FavoriteSyncException('offline');
    if (account != accountId) {
      throw const FavoriteSyncException('account changed');
    }
    return _snapshot();
  }

  @override
  Future<void> write(
    String account,
    FavoriteCloudSnapshot snapshot,
    FavoriteIntent intent,
  ) async {
    writes++;
    writeLog.add(intent);
    if (account != accountId) {
      throw const FavoriteSyncException('account changed');
    }
    if (failWrite) throw const FavoriteSyncException('write failed');
    _songs.removeWhere((s) => s.id == intent.song.id);
    if (intent.liked) {
      _songs.insert(0, intent.song);
      _recordIds[intent.song.id] = [_nextFileId++];
    } else {
      // 必须使用完整快照中的歌单记录 id，不能退回歌曲 hash。
      final ids = _recordIds[intent.song.id];
      if (ids == null || ids.isEmpty) {
        throw const FavoriteSyncException('missing record id');
      }
      _recordIds.remove(intent.song.id);
    }
  }

  void removeRemote(String id) {
    _songs.removeWhere((s) => s.id == id);
    _recordIds.remove(id);
  }
}

FavoritesProvider _provider(
  _FakeRemote remote,
  _MemoryStore store,
) => FavoritesProvider(
  syncOnStart: false,
  autoSync: false,
  remote: remote,
  store: store,
);

void main() {
  test('首次同步显示完整云端喜欢，不用缓存片段冒充云端', () async {
    final remote = _FakeRemote(accountId: 'u1', songs: [_song('a'), _song('b')]);
    final store = _MemoryStore();
    final provider = _provider(remote, store);
    provider.addFavoriteIds(['stale-cache-only']);

    await provider.loadFavorites();

    expect(provider.favoriteIds, {'a', 'b'});
    expect(provider.favoriteIds.contains('stale-cache-only'), isFalse);
    expect(provider.pendingCount, 0);
    expect(provider.lastSyncTime, isNotNull);
    expect(provider.syncRevision, 1);
    provider.dispose();
  });

  test('酷狗端取消的歌会消失，空/失败响应不会批量删除', () async {
    final remote = _FakeRemote(accountId: 'u1', songs: [_song('a'), _song('b')]);
    final store = _MemoryStore();
    final provider = _provider(remote, store);
    await provider.loadFavorites();

    remote.removeRemote('a');
    remote.failFetch = true;
    await provider.syncNow();
    // 拉取失败：保留上一份完整快照，不能当成“全部取消喜欢”。
    expect(provider.favoriteIds, {'a', 'b'});
    expect(provider.syncError, isNotNull);

    remote.failFetch = false;
    await provider.syncNow();
    expect(provider.favoriteIds, {'b'});
    expect(provider.syncError, isNull);
    provider.dispose();
  });

  test('喜欢后立即可见，云端确认后清空待同步', () async {
    final remote = _FakeRemote(accountId: 'u1', songs: [_song('a')]);
    final store = _MemoryStore();
    final provider = _provider(remote, store);
    await provider.loadFavorites();

    remote.gate = Completer<void>();
    await provider.setFavorite(_song('new'), true);
    expect(provider.isFavorite('new'), isTrue);
    expect(provider.pendingCount, 1);

    remote.gate!.complete();
    remote.gate = null;
    await provider.syncNow();
    expect(provider.pendingCount, 0);
    expect(provider.isFavorite('new'), isTrue);
    expect(remote.writeLog.single.liked, isTrue);
    provider.dispose();
  });

  test('写入失败保留待同步并跨重启重试，取消使用记录 fileid', () async {
    final remote = _FakeRemote(accountId: 'u1', songs: [_song('a')]);
    final store = _MemoryStore();
    final first = _provider(remote, store);
    await first.loadFavorites();

    remote.failWrite = true;
    await first.setFavorite(_song('b'), true);
    await first.syncNow();
    expect(first.pendingCount, 1);
    expect(first.syncError, isNotNull);
    first.dispose();

    final second = _provider(remote, store);
    await second.loadFavorites();
    expect(second.pendingCount, 1);
    expect(second.isFavorite('b'), isTrue);

    remote.failWrite = false;
    await second.syncNow();
    expect(second.pendingCount, 0);
    expect(second.syncError, isNull);
    expect(second.favoriteIds, contains('b'));

    await second.setFavorite(_song('b'), false);
    await second.syncNow();
    expect(second.pendingCount, 0);
    expect(second.favoriteIds, isNot(contains('b')));
    expect(remote.writeLog.last.liked, isFalse);
    second.dispose();
  });

  test('缺少云端记录 id 的取消不会被猜成 hash 删除', () async {
    final remote = _FakeRemote(
      accountId: 'u1',
      songs: [_song('x')],
      recordIds: {'x': []},
    );
    final store = _MemoryStore();
    final provider = _provider(remote, store);
    await provider.loadFavorites();

    await provider.setFavorite(_song('x'), false);
    await provider.syncNow();

    expect(provider.pendingCount, 1);
    expect(provider.syncError, isNotNull);
    expect(remote.writes, 1);
    provider.dispose();
  });

  test('快速反向操作按最新意图收敛', () async {
    final remote = _FakeRemote(accountId: 'u1', songs: []);
    final store = _MemoryStore();
    final provider = _provider(remote, store);
    await provider.loadFavorites();

    remote.gate = Completer<void>();
    await provider.setFavorite(_song('x'), true);
    await provider.setFavorite(_song('x'), false);
    expect(provider.isFavorite('x'), isFalse);
    expect(provider.pendingCount, 1);

    remote.gate!.complete();
    remote.gate = null;
    await provider.syncNow();
    expect(provider.pendingCount, 0);
    expect(provider.isFavorite('x'), isFalse);
    expect(remote._songs.map((s) => s.id), isNot(contains('x')));
    provider.dispose();
  });

  test('换账号后不显示旧账号收藏，写入只走新账号', () async {
    final remote = _FakeRemote(accountId: 'u1', songs: [_song('a')]);
    final store = _MemoryStore();
    final provider = _provider(remote, store);
    await provider.loadFavorites();
    expect(provider.favoriteIds, {'a'});

    remote.accountId = 'u2';
    remote._songs
      ..clear()
      ..add(_song('b'));
    await provider.loadFavorites();

    expect(provider.favoriteIds, {'b'});
    expect(provider.favoriteIds.contains('a'), isFalse);
    await provider.setFavorite(_song('b'), false);
    await provider.syncNow();
    expect(remote.writeLog.last.song.id, 'b');
    provider.dispose();
  });

  test('未登录时喜欢只保存本机，不产生云端写入', () async {
    final remote = _FakeRemote(accountId: null, songs: []);
    final store = _MemoryStore();
    final provider = _provider(remote, store);
    await provider.loadFavorites();

    await provider.setFavorite(_song('local-like'), true);
    await provider.setFavorite(_song('file', online: false), true);
    await provider.syncNow();

    expect(provider.isFavorite('local-like'), isTrue);
    expect(provider.isFavorite('file'), isTrue);
    expect(provider.pendingCount, 0);
    expect(provider.hasAccount, isFalse);
    expect(remote.writes, 0);
    provider.dispose();
  });
}
