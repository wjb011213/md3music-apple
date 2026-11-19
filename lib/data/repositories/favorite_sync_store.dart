import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../services/favorite_sync.dart';
import '../models/song.dart';

class FavoriteSyncState {
  const FavoriteSyncState({this.cloud = const [], this.local = const [],
    this.pending = const [], this.lastSyncTime});
  final List<Song> cloud;
  final List<Song> local;
  final List<FavoriteIntent> pending;
  final DateTime? lastSyncTime;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'cloud': cloud.map((s) => favoriteSongMetadata(s).toJson()).toList(),
    'local': local.map((s) => favoriteSongMetadata(s).toJson()).toList(),
    'pending': pending.map((p) => p.toJson()).toList(),
    'lastSync': lastSyncTime?.toIso8601String(),
  };

  factory FavoriteSyncState.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) throw const FormatException('Unknown favorite cache version');
    List<Song> songs(String key) => (json[key] as List).map((s) => Song.fromJson(Map<String, dynamic>.from(s as Map))).toList();
    return FavoriteSyncState(
      cloud: songs('cloud'), local: songs('local'),
      pending: (json['pending'] as List).map((p) => FavoriteIntent.fromJson(Map<String, dynamic>.from(p as Map))).toList(),
      lastSyncTime: DateTime.tryParse('${json['lastSync']}'),
    );
  }
}

/// One atomic value holds both the confirmed snapshot and the outbox. The key
/// is captured by the caller, never recomputed after an asynchronous account switch.
class FavoriteSyncStore {
  String _key(String? account) => account == null
      ? 'favorite_sync_v1_guest' : 'favorite_sync_v1_account_$account';

  Future<FavoriteSyncState> load(String? account) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key(account));
    if (json != null) {
      // Corrupt outboxes must not silently turn into an empty queue.
      return FavoriteSyncState.fromJson(Map<String, dynamic>.from(jsonDecode(json) as Map));
    }
    final legacyKey = account == null ? 'favorite_songs' : 'favorite_songs_$account';
    final legacy = <Song>[];
    for (final row in prefs.getStringList(legacyKey) ?? const <String>[]) {
      try { legacy.add(Song.fromJson(Map<String, dynamic>.from(jsonDecode(row) as Map))); } catch (_) {}
    }
    // Old red hearts are only cached display data, not new upload requests.
    // Otherwise upgrading would resurrect songs removed on another device.
    return FavoriteSyncState(
      cloud: account == null ? const [] : legacy.where((s) => s.isOnline).toList(),
      local: account == null ? legacy : legacy.where((s) => !s.isOnline).toList(),
    );
  }

  Future<void> save(String? account, FavoriteSyncState state) async {
    final encoded = jsonEncode(state.toJson());
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key(account), encoded)) {
      throw const FavoriteSyncException('无法保存待同步记录，请检查存储空间');
    }
  }
}
