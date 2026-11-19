import 'package:flutter/foundation.dart';

import '../data/models/song.dart';
import '../utils/playlist_write_payload.dart';
import 'kugou_api/kugou_api_client.dart';
import 'kugou_api/kugou_models.dart';

class FavoriteSyncException implements Exception {
  const FavoriteSyncException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// An explicit per-song intent, not a diff inferred from an incomplete list.
class FavoriteIntent {
  const FavoriteIntent({required this.song, required this.liked, required this.revision});
  final Song song;
  final bool liked;
  final int revision;

  Map<String, dynamic> toJson() => {
    'song': favoriteSongMetadata(song).toJson(),
    'liked': liked,
    'revision': revision,
  };

  factory FavoriteIntent.fromJson(Map<String, dynamic> json) => FavoriteIntent(
    song: Song.fromJson(Map<String, dynamic>.from(json['song'] as Map)),
    liked: json['liked'] as bool,
    revision: json['revision'] as int,
  );
}

/// Do not persist expiring playback URLs or remote-storage authentication URLs.
Song favoriteSongMetadata(Song s) => Song(
  id: s.id, title: s.title, artist: s.artist, album: s.album,
  duration: s.duration, artworkUri: s.artworkUri, isOnline: s.isOnline,
  localPath: s.isOnline ? null : s.localPath, albumId: s.albumId,
  artistId: s.artistId, albumAudioId: s.albumAudioId, quality: s.quality,
  isCloud: s.isCloud, fileId: s.fileId, playlistSort: s.playlistSort,
);

class FavoriteCloudSnapshot {
  FavoriteCloudSnapshot({required this.listId, required List<Song> songs,
    Map<String, List<int>> recordIds = const {}})
      : songs = List.unmodifiable(songs),
        recordIds = Map.unmodifiable(recordIds.map((k, v) => MapEntry(k, List<int>.unmodifiable(v))));
  final String listId;
  final List<Song> songs;
  final Map<String, List<int>> recordIds;
  bool contains(String id) => songs.any((song) => song.id == id);
}

abstract class FavoriteSyncRemote {
  String? get accountId;
  Listenable? get accountChanges => null;
  ValueListenable<bool>? get connectivity => null;
  Future<void> ready();
  Future<FavoriteCloudSnapshot> fetch(String accountId);
  Future<void> write(String accountId, FavoriteCloudSnapshot snapshot, FavoriteIntent intent);
}

/// A success field cannot override an explicit failure in another field.
bool favoriteWriteSucceeded(Map<String, dynamic>? result) {
  if (result == null) return false;
  final status = result['status'];
  final error = result['error_code'] ?? result['errorcode'];
  if (status != null && '$status' != '1') return false;
  if (error != null && '$error' != '0') return false;
  return '$status' == '1' || '$error' == '0';
}

void _checkRead(Map<String, dynamic>? result) {
  if (result == null ||
      (result['status'] != null && '${result['status']}' != '1') ||
      ((result['error_code'] ?? result['errorcode']) != null &&
          '${result['error_code'] ?? result['errorcode']}' != '0')) {
    throw const FavoriteSyncException('云端收藏读取失败，已保留本地数据');
  }
}

/// Strict pagination: failure/partial data is never a valid empty snapshot.
Future<FavoriteCloudSnapshot> loadFavoriteSnapshot({
  required String listId,
  required Future<Map<String, dynamic>?> Function(int page) fetchPage,
  int pageSize = 200,
  int maxPages = 50,
}) async {
  final songs = <String, Song>{};
  final records = <String, List<int>>{};
  final seenRows = <String>{};
  int? expectedTotal;
  String? version;
  var rowCount = 0;
  for (var page = 1; page <= maxPages; page++) {
    final result = await fetchPage(page);
    _checkRead(result);
    final rawData = result!['data'] ?? result;
    if (rawData is! Map) {
      throw const FavoriteSyncException('云端收藏格式异常，已保留本地数据');
    }
    List? batch;
    for (final key in const ['info', 'songs', 'list', 'tracks']) {
      final candidate = rawData[key];
      if (candidate is List) {
        batch ??= candidate;
        if (candidate.isNotEmpty) { batch = candidate; break; }
      }
    }
    if (batch == null) {
      throw const FavoriteSyncException('云端未返回收藏列表，已保留本地数据');
    }
    final totalValue = rawData['total'] ?? rawData['total_count'] ?? rawData['count'];
    final total = totalValue == null ? null : int.tryParse('$totalValue');
    if (totalValue != null && (total == null || total < 0)) {
      throw const FavoriteSyncException('收藏数量无效，请稍后重试');
    }
    if (page == 1) expectedTotal = total;
    if (expectedTotal != total) {
      throw const FavoriteSyncException('收藏正在其他设备更新，请重试');
    }
    final currentVersion = rawData['list_ver']?.toString();
    if (page == 1) version = currentVersion;
    if (version != currentVersion) {
      throw const FavoriteSyncException('收藏正在其他设备更新，请重试');
    }
    final before = seenRows.length;
    for (final row in batch) {
      if (row is! Map) throw const FavoriteSyncException('收藏条目格式异常');
      final detail = KugouSongDetail.fromJson(Map<String, dynamic>.from(row));
      if (detail.hash.isEmpty) throw const FavoriteSyncException('收藏条目缺少歌曲标识');
      final identity = '${detail.hash}:${detail.fileId ?? ''}';
      if (!seenRows.add(identity)) {
        throw const FavoriteSyncException('收藏分页重复，请重新同步');
      }
      songs[detail.hash] = detail.toSong();
      if (detail.fileId != null && detail.fileId! > 0) {
        records.putIfAbsent(detail.hash, () => []).add(detail.fileId!);
      }
      rowCount++;
    }
    if (expectedTotal != null && rowCount > expectedTotal) {
      throw const FavoriteSyncException('收藏数量发生变化，请重试');
    }
    final complete = expectedTotal != null
        ? rowCount == expectedTotal
        : batch.length < pageSize;
    if (complete) return FavoriteCloudSnapshot(listId: listId, songs: songs.values.toList(), recordIds: records);
    if (batch.isEmpty || seenRows.length == before) {
      throw const FavoriteSyncException('收藏尚未完整读取，已保留本地数据');
    }
  }
  throw const FavoriteSyncException('收藏超过本次同步上限，未覆盖本地数据');
}

class KugouFavoriteSyncRemote extends FavoriteSyncRemote {
  KugouApiClient get _api => KugouApiClient();
  @override
  String? get accountId => _api.isLoggedIn ? _api.userid : null;
  @override
  Listenable get accountChanges => KugouApiClient.accountRevision;
  @override
  ValueListenable<bool> get connectivity => KugouApiClient.networkReachable;
  @override
  Future<void> ready() async { await _api.isLoggedInWhenReady(); }

  void _checkAccount(String account) {
    if (accountId != account) throw const FavoriteSyncException('账号已变化，已暂停原账号同步');
  }

  @override
  Future<FavoriteCloudSnapshot> fetch(String accountId) async {
    _checkAccount(accountId);
    final result = await _api.getAllUserPlaylists(noCache: true, expectedAccountId: accountId);
    _checkAccount(accountId);
    _checkRead(result);
    final data = result!['data'];
    final rows = data is Map ? (data['info'] ?? data['list']) : data;
    if (rows is! List) throw const FavoriteSyncException('无法确认“我喜欢”歌单，请重新登录或重试');
    Map<String, dynamic>? favorite;
    final named = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      if ('${map['type'] ?? 0}' != '0' || '${map['source'] ?? 0}' == '2') continue;
      if ('${map['is_def']}' == '2') { favorite = map; break; }
      if (map['name'] == '我喜欢') named.add(map);
    }
    if (favorite == null && named.length == 1) favorite = named.single;
    final listId = favorite?['listid']?.toString() ?? '';
    // Never guess listid=2: that can address the wrong playlist/account.
    if (listId.isEmpty || listId == '0') throw const FavoriteSyncException('未找到“我喜欢”歌单，请重新登录或重试');
    final snapshot = await loadFavoriteSnapshot(
      listId: listId,
      fetchPage: (page) async {
        _checkAccount(accountId);
        final result = await _api.getFavoriteTracksPage(listid: listId, expectedAccountId: accountId, page: page);
        _checkAccount(accountId);
        return result;
      },
    );
    _checkAccount(accountId);
    return snapshot;
  }

  @override
  Future<void> write(String accountId, FavoriteCloudSnapshot snapshot, FavoriteIntent intent) async {
    _checkAccount(accountId);
    Map<String, dynamic>? result;
    if (intent.liked) {
      result = await _api.addPlaylistTracks(snapshot.listId, buildTrackAddData(intent.song), expectedAccountId: accountId);
    } else {
      final ids = snapshot.recordIds[intent.song.id];
      if (ids == null || ids.isEmpty) {
        throw const FavoriteSyncException('暂时无法确认收藏记录，取消操作待重试');
      }
      result = await _api.deletePlaylistTracks(snapshot.listId, ids.join(','), expectedAccountId: accountId);
    }
    _checkAccount(accountId);
    if (!favoriteWriteSucceeded(result)) {
      throw const FavoriteSyncException('云端未确认操作成功，已保留待同步记录');
    }
  }
}
