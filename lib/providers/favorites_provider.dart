import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/models/song.dart';
import '../data/repositories/favorite_sync_store.dart';
import '../services/favorite_sync.dart';
import '../services/kugou_api/kugou_api_client.dart';
import '../utils/playlist_write_payload.dart';

/// Cloud state plus durable, account-scoped user intents. A missing/failed page
/// never implies deletion; only setFavorite(false) creates a delete intent.
class FavoritesProvider extends ChangeNotifier with WidgetsBindingObserver {
  FavoritesProvider({bool syncOnStart = true, bool? autoSync,
    FavoriteSyncRemote? remote, FavoriteSyncStore? store})
      : _remote = remote ?? KugouFavoriteSyncRemote(),
        _store = store ?? FavoriteSyncStore(),
        _autoSync = autoSync ?? syncOnStart {
    if (_autoSync) {
      WidgetsBinding.instance.addObserver(this);
      _foreground = WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      _remote.accountChanges?.addListener(_onAccountChanged);
      _remote.connectivity?.addListener(_onConnectivityChanged);
      _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
        if (_foreground) unawaited(syncNow(force: false));
      });
    }
    if (syncOnStart) unawaited(loadFavorites());
  }

  final FavoriteSyncRemote _remote;
  final FavoriteSyncStore _store;
  final bool _autoSync;
  bool _disposed = false;
  bool _foreground = true;
  bool _accountInitialized = false;
  bool _storageReady = false;
  bool _loading = false;
  bool _syncing = false;
  String? _account;
  int _generation = 0;
  int _intentRevision = 0;
  int _syncRevision = 0;
  int _retryAttempt = 0;
  bool _syncRequested = false;
  DateTime? _lastAttempt;
  DateTime? _lastSync;
  String? _error;
  Future<void>? _loadFlight;
  Future<void>? _syncFlight;
  Future<void> _diskTail = Future<void>.value();
  Timer? _retryTimer;
  Timer? _pollTimer;
  List<Song> _cloud = [];
  List<Song> _local = [];
  List<Song> _favorites = [];
  Set<String> _favoriteIds = {};
  final Map<String, FavoriteIntent> _pending = {};
  final Set<String> _hintIds = {};

  List<Song> get favorites => List.unmodifiable(_favorites);
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  bool get isLoading => _loading;
  bool get isSyncing => _syncing;
  bool get hasAccount => _remote.accountId != null;
  int get pendingCount => _pending.length;
  String? get syncError => _error;
  DateTime? get lastSyncTime => _lastSync;
  int get syncRevision => _syncRevision;
  bool isFavorite(String songId) => _favoriteIds.contains(songId);
  List<Song> get favoritesForBridge => List.unmodifiable(_favorites.take(1000));

  void _notify() { if (!_disposed) notifyListeners(); }
  bool _current(String? account, int generation) => !_disposed &&
      _account == account && _remote.accountId == account && _generation == generation;

  void _clearView() {
    _cloud = []; _local = []; _favorites = []; _favoriteIds = {};
    _pending.clear(); _hintIds.clear();
    _lastSync = null; _lastAttempt = null; _error = null;
    _storageReady = false; _syncing = false;
    _syncFlight = null; _loadFlight = null;
    _retryTimer?.cancel(); _retryAttempt = 0;
  }

  Future<void> _ensureAccount() async {
    await _remote.ready();
    if (_disposed) return;
    final account = _remote.accountId;
    if (!_accountInitialized || account != _account) {
      _accountInitialized = true;
      _account = account;
      final generation = ++_generation;
      _clearView();
      _loading = true;
      _notify();
      final future = _loadLocal(account, generation);
      _loadFlight = future;
      await future;
      if (identical(_loadFlight, future)) _loadFlight = null;
    } else {
      await _loadFlight;
    }
  }

  Future<void> _loadLocal(String? account, int generation) async {
    try {
      // A logout/login round trip can race an earlier queued disk write.
      await _diskTail;
      final state = await _store.load(account);
      if (!_current(account, generation)) return;
      _cloud = List.of(state.cloud);
      _local = List.of(state.local);
      _pending.addEntries(state.pending.map((p) => MapEntry(p.song.id, p)));
      for (final p in state.pending) {
        if (p.revision > _intentRevision) _intentRevision = p.revision;
      }
      _lastSync = state.lastSyncTime;
      _storageReady = true;
      _rebuild();
    } catch (_) {
      if (_current(account, generation)) {
        _error = '无法读取收藏缓存，已暂停同步以保护待同步记录';
      }
    } finally {
      if (_current(account, generation)) { _loading = false; _notify(); }
    }
  }

  Future<void> _persist() {
    final account = _account;
    final state = FavoriteSyncState(cloud: List.of(_cloud), local: List.of(_local),
      pending: List.of(_pending.values), lastSyncTime: _lastSync);
    final future = _diskTail.then((_) => _store.save(account, state));
    // Preserve write order without poisoning later retries after a disk error.
    _diskTail = future.catchError((Object _) {});
    return future;
  }

  void _rebuild() {
    final songs = <String, Song>{};
    for (final s in _local) { songs[s.id] = s; }
    for (final s in _cloud) { songs.putIfAbsent(s.id, () => s); }
    for (final intent in _pending.values) {
      if (intent.liked) { songs[intent.song.id] = intent.song; }
      else { songs.remove(intent.song.id); }
    }
    // New local likes appear first while waiting for server acknowledgement.
    final recent = _pending.values.where((p) => p.liked).toList().reversed;
    _favorites = [for (final p in recent) p.song,
      ...songs.values.where((s) => !_pending.containsKey(s.id))];
    _favoriteIds = {...songs.keys, ..._hintIds};
    for (final p in _pending.values) {
      if (p.liked) { _favoriteIds.add(p.song.id); }
      else { _favoriteIds.remove(p.song.id); }
    }
  }

  Future<void> loadFavorites() => syncNow();

  /// Merge a page hint only before a complete cloud snapshot is available.
  /// Cached playlist pages must not resurrect remotely removed red hearts.
  void syncFavoriteIds(Set<String> ids) {
    if (_lastSync == null) { _hintIds..clear()..addAll(ids); _rebuild(); _notify(); }
  }
  void addFavoriteIds(List<String> ids) {
    if (_lastSync == null) { _hintIds.addAll(ids); _rebuild(); _notify(); }
  }

  Future<List<Song>> loadCloudFavoriteSongs() async {
    await _ensureAccount();
    if (_lastSync == null && hasAccount) await syncNow();
    return favorites;
  }

  void invalidateCloudFavoriteSongs() {
    _syncRequested = true;
    unawaited(syncNow());
  }

  Future<void> toggleFavorite(Song song) async {
    await _ensureAccount();
    await setFavorite(song, !isFavorite(song.id));
  }

  /// Explicit target state makes retry and rapid toggles idempotent.
  Future<void> setFavorite(Song song, bool liked) async {
    await _ensureAccount();
    if (_disposed || song.id.isEmpty) return;
    if (!_storageReady) {
      _error = '收藏缓存暂时不可用，本次操作尚未保存';
      _notify();
      return;
    }
    final account = _account;
    final generation = _generation;
    if (isFavorite(song.id) == liked && !_pending.containsKey(song.id)) return;
    _error = null;
    if (account == null || !song.isOnline) {
      _local.removeWhere((s) => s.id == song.id);
      if (liked) _local.insert(0, song);
      // Local files have no verified Kugou catalogue identity; never upload them.
    } else {
      _pending[song.id] = FavoriteIntent(song: favoriteSongMetadata(song),
        liked: liked, revision: ++_intentRevision);
    }
    _hintIds.remove(song.id);
    _rebuild(); _notify();
    try {
      await _persist();
      if (!_current(account, generation)) return;
      if (account != null && song.isOnline) {
        _syncRequested = true;
        unawaited(syncNow());
      }
    } catch (_) {
      if (_current(account, generation)) {
        _error = '待同步记录保存失败，尚未发送到云端，请重试';
        _notify();
      }
    }
  }

  Future<void> removeFavorite(String songId) async {
    await _ensureAccount();
    Song? song;
    for (final s in _favorites) { if (s.id == songId) { song = s; break; } }
    if (song != null) await setFavorite(song, false);
  }

  Future<void> syncNow({bool force = true}) async {
    try { await _ensureAccount(); } catch (_) { return; }
    if (_disposed || !_storageReady || _account == null) return;
    final inFlight = _syncFlight;
    if (inFlight != null) return inFlight;
    if (!force && _lastAttempt != null &&
        DateTime.now().difference(_lastAttempt!) < const Duration(seconds: 30)) return;
    final account = _account!;
    final generation = _generation;
    final completion = Completer<void>();
    _syncFlight = completion.future;
    _retryTimer?.cancel();
    _lastAttempt = DateTime.now();
    _syncing = true; _notify();
    try {
      var passes = 0;
      do {
        _syncRequested = false;
        await _syncPass(account, generation);
        passes++;
      } while (_current(account, generation) && _syncRequested && passes < 4);
      if (_current(account, generation)) { _error = null; _retryAttempt = 0; }
    } catch (e) {
      if (_current(account, generation)) {
        _error = e is FavoriteSyncException ? e.message : '同步暂未完成，已保留收藏和待同步记录';
      }
    } finally {
      if (_current(account, generation)) {
        _syncing = false;
        if (identical(_syncFlight, completion.future)) _syncFlight = null;
        _notify();
        if (_pending.isNotEmpty || _error != null) _scheduleRetry();
      }
      completion.complete();
    }
  }

  Future<void> _syncPass(String account, int generation) async {
    // Durability before any remote side effect (including a retry after disk failure).
    await _persist();
    if (!_current(account, generation)) return;
    var snapshot = await _remote.fetch(account);
    if (!_current(account, generation)) return;
    await _acceptSnapshot(snapshot);
    if (!_current(account, generation)) return;
    final intents = List<FavoriteIntent>.of(_pending.values);
    for (final intent in intents) {
      if (!_current(account, generation)) return;
      if (_pending[intent.song.id]?.revision != intent.revision) continue;
      if (snapshot.contains(intent.song.id) != intent.liked) {
        // Never reuse a song.fileId from another playlist; the gateway resolves
        // delete IDs only from this complete, fresh "我喜欢" snapshot.
        await _remote.write(account, snapshot, intent);
        if (!_current(account, generation)) return;
        snapshot = await _remote.fetch(account);
        if (!_current(account, generation)) return;
        await _acceptSnapshot(snapshot);
        if (!_current(account, generation)) return;
        if (snapshot.contains(intent.song.id) != intent.liked) {
          throw const FavoriteSyncException('操作已提交，等待云端确认；稍后将自动重试');
        }
      }
      // A newer toggle is not acknowledged by an older request.
      if (_pending[intent.song.id]?.revision == intent.revision) {
        _pending.remove(intent.song.id);
        _rebuild();
        await _persist();
        if (!_current(account, generation)) return;
        _notify();
      }
    }
  }

  Future<void> _acceptSnapshot(FavoriteCloudSnapshot snapshot) async {
    _cloud = List.of(snapshot.songs);
    _hintIds.clear();
    _lastSync = DateTime.now();
    _syncRevision++;
    _rebuild();
    await _persist();
    _notify();
  }

  void _scheduleRetry() {
    if (!_autoSync || !_foreground || _disposed || !hasAccount) return;
    const delays = [5, 15, 45, 120, 300];
    final index = _retryAttempt < delays.length ? _retryAttempt : delays.length - 1;
    _retryAttempt++;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delays[index]), () => unawaited(syncNow()));
  }

  void _onAccountChanged() {
    if (_disposed) return;
    ++_generation; _accountInitialized = false;
    _clearView(); _notify();
    unawaited(loadFavorites());
  }

  void _onConnectivityChanged() {
    if (_foreground && _remote.connectivity?.value == true) unawaited(syncNow());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) { unawaited(syncNow(force: false)); }
    else { _retryTimer?.cancel(); }
  }

  @override
  void dispose() {
    _disposed = true; ++_generation;
    _retryTimer?.cancel(); _pollTimer?.cancel();
    if (_autoSync) {
      WidgetsBinding.instance.removeObserver(this);
      _remote.accountChanges?.removeListener(_onAccountChanged);
      _remote.connectivity?.removeListener(_onConnectivityChanged);
    }
    super.dispose();
  }

  // Existing general playlist operations retain their public API.
  Future<Map<String, dynamic>?> createPlaylist(String name) async {
    final api = KugouApiClient();
    final userid = api.userid;
    if (userid == null) return null;
    return api.createPlaylist(name, listCreateUserid: userid);
  }
  Future<Map<String, dynamic>?> addTrackToPlaylist(String listid, Song song) =>
      KugouApiClient().addPlaylistTracks(listid, buildTrackAddData(song));
  Future<Map<String, dynamic>?> removeTrackFromPlaylist(String listid, String fileid) =>
      KugouApiClient().deletePlaylistTracks(listid, fileid);
  Future<Map<String, dynamic>?> deletePlaylist(String listid, {int type = 1}) =>
      KugouApiClient().deletePlaylist(listid, type: type);
  Future<Map<String, dynamic>?> getUserPlaylists({int page = 1, int pagesize = 30}) =>
      KugouApiClient().getUserPlaylist(page: page, pagesize: pagesize);
}
