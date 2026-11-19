import 'package:flutter_test/flutter_test.dart';
import 'package:md3music/services/favorite_sync.dart';

Map<String, dynamic> _row(String hash, int fileId) => {
  'hash': hash,
  'filename': 'Song $hash',
  'songname': 'Song $hash',
  'fileid': fileId,
  'duration': 180,
};

Map<String, dynamic> _page(
  List<Map<String, dynamic>> rows, {
  int? total,
  int status = 1,
  int? version,
}) => {
  'status': status,
  'data': {
    'total': total ?? rows.length,
    if (version != null) 'list_ver': version,
    'info': rows,
  },
};

void main() {
  group('loadFavoriteSnapshot', () {
    test('完整分页才产生快照，并携带歌单记录 fileid', () async {
      final snapshot = await loadFavoriteSnapshot(
        listId: '77',
        pageSize: 2,
        fetchPage: (page) async => page == 1
            ? _page([_row('h1', 11), _row('h2', 12)], total: 3)
            : _page([_row('h3', 13)], total: 3),
      );

      expect(snapshot.listId, '77');
      expect(snapshot.songs.map((s) => s.id), ['h1', 'h2', 'h3']);
      expect(snapshot.recordIds['h1'], [11]);
      expect(snapshot.contains('h2'), isTrue);
    });

    test('后续页失败不会伪装成空收藏', () async {
      await expectLater(
        loadFavoriteSnapshot(
          listId: '77',
          pageSize: 2,
          fetchPage: (page) async =>
              page == 1 ? _page([_row('h1', 11), _row('h2', 12)], total: 3) : null,
        ),
        throwsA(isA<FavoriteSyncException>()),
      );
    });

    test('业务失败与总数变化都拒绝覆盖', () async {
      await expectLater(
        loadFavoriteSnapshot(
          listId: '77',
          fetchPage: (_) async => _page([_row('h1', 11)], status: 0),
        ),
        throwsA(isA<FavoriteSyncException>()),
      );
      await expectLater(
        loadFavoriteSnapshot(
          listId: '77',
          pageSize: 2,
          fetchPage: (page) async => page == 1
              ? _page([_row('h1', 11), _row('h2', 12)], total: 4)
              : _page([_row('h3', 13)], total: 5),
        ),
        throwsA(isA<FavoriteSyncException>()),
      );
    });

    test('重复分页不会产生重复歌曲', () async {
      await expectLater(
        loadFavoriteSnapshot(
          listId: '77',
          pageSize: 2,
          fetchPage: (_) async => _page([_row('h1', 11), _row('h1', 11)], total: 3),
        ),
        throwsA(isA<FavoriteSyncException>()),
      );
    });
  });

  group('favoriteWriteSucceeded', () {
    test('任一字段明确失败都不得报成功', () {
      expect(favoriteWriteSucceeded({'status': 1, 'error_code': 0}), isTrue);
      expect(favoriteWriteSucceeded({'error_code': 0}), isTrue);
      expect(favoriteWriteSucceeded({'status': 1, 'error_code': 5}), isFalse);
      expect(favoriteWriteSucceeded({'status': 0, 'error_code': 0}), isFalse);
      expect(favoriteWriteSucceeded(null), isFalse);
      expect(favoriteWriteSucceeded(const {}), isFalse);
    });
  });
}
