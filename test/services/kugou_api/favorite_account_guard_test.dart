import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md3music/services/kugou_api/kugou_api_client.dart';
import 'package:md3music/services/kugou_api/kugou_endpoints.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const accountA = 'fixture-account-a';
  const accountB = 'fixture-account-b';
  late KugouApiClient client;
  late _RecorderAdapter adapter;
  late Interceptor errorObserver;
  late List<DioException> errors;
  late String originalBaseUrl;
  late int initialRevision;
  final initializationSnapshots = <List<Object?>>[];
  final initializationReady = <Future<bool>>[];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'kugou_current_userid': accountA,
      'kugou_userid_$accountA': accountA,
    });
    installFakeSecureStorage();
    const secure = FlutterSecureStorage();
    await secure.write(key: 'kugou_token_$accountA', value: 'fixture-token-a');
    await secure.write(
      key: 'kugou_vip_token_$accountA',
      value: 'fixture-vip-a',
    );
    initialRevision = KugouApiClient.accountRevision.value;
    void onInitialized() {
      initializationSnapshots.add([
        client.userid,
        client.isLoggedIn,
        client.vipToken,
        KugouApiClient.accountRevision.value,
      ]);
      initializationReady.add(client.isLoggedInWhenReady());
    }

    KugouApiClient.accountRevision.addListener(onInitialized);
    client = KugouApiClient();
    originalBaseUrl = KugouEndpoints.baseUrl;
    client.updateBaseUrl('http://favorite-guard.invalid');
    client.dio.httpClientAdapter = _RecorderAdapter();
    await client.isLoggedInWhenReady();
    KugouApiClient.accountRevision.removeListener(onInitialized);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    installFakeSecureStorage();
    adapter = _RecorderAdapter();
    client.dio.httpClientAdapter = adapter;
    final generation = KugouApiClient.markServerStarting();
    KugouApiClient.markServerReady(generation);
    await client.clearCookies();
    await client.setLoginCookies('fixture-token-a', accountA);
    errors = [];
    errorObserver = InterceptorsWrapper(
      onError: (error, handler) {
        errors.add(error);
        handler.next(error);
      },
    );
    client.dio.interceptors.add(errorObserver);
  });

  tearDown(() async {
    client.dio.interceptors.remove(errorObserver);
    await client.clearCookies();
    uninstallFakeSecureStorage();
  });

  tearDownAll(() {
    client.updateBaseUrl(originalBaseUrl);
    client.dio.close(force: true);
    final generation = KugouApiClient.markServerStopping();
    KugouApiClient.markServerStopped(generation);
  });

  test('存储初始化完成后只通知一次，监听方能读取就绪的完整身份', () async {
    expect(initializationSnapshots, [
      [accountA, true, 'fixture-vip-a', initialRevision + 1],
    ]);
    expect(await Future.wait(initializationReady), [true]);
  });

  final writes =
      <String, Future<Map<String, dynamic>?> Function(String? account)>{
        'add': (account) => client.addPlaylistTracks(
          'fixture-list',
          'fixture-data',
          expectedAccountId: account,
        ),
        'delete': (account) => client.deletePlaylistTracks(
          'fixture-list',
          'fixture-fileids',
          expectedAccountId: account,
        ),
      };

  for (final entry in writes.entries) {
    test('${entry.key} 相符账号成功，身份约束仅存在于 extra', () async {
      expect(await entry.value(accountA), {'status': 1});
      final request = adapter.requests.single;
      expect(
        request.path,
        entry.key == 'add'
            ? KugouEndpoints.playlistTracksAdd
            : KugouEndpoints.playlistTracksDel,
      );
      expect(request.queryParameters['listid'], 'fixture-list');
      expect(
        request.queryParameters[entry.key == 'add' ? 'data' : 'fileids'],
        entry.key == 'add' ? 'fixture-data' : 'fixture-fileids',
      );
      expect(request.extra['expectedAccountId'], accountA);
      expect(request.queryParameters, isNot(contains('expectedAccountId')));
      expect(
        request.headers['Authorization'],
        'token=fixture-token-a;userid=$accountA',
      );
      expect(request.headers['x-apicache-bypass'], '1');
      expect(request.headers['Cache-Control'], 'no-cache');
      expect(request.queryParameters['t'], isA<int>());
    });

    test('${entry.key} 等待服务就绪途中切换账号，不调用 adapter 或改账号重试', () async {
      await client.setLoginCookies('fixture-token-b', accountB);
      expect(await client.switchToUser(accountA), isTrue);
      final generation = KugouApiClient.markServerStarting();
      final pending = entry.value(accountA);
      await pumpEventQueue();
      expect(adapter.requests, isEmpty);
      expect(errors, isEmpty);
      expect(await client.switchToUser(accountB), isTrue);
      KugouApiClient.markServerReady(generation);

      expect(await pending, isNull);
      expect(adapter.requests, isEmpty);
      expect(errors.single.type, DioExceptionType.cancel);
      expect(
        errors.single.requestOptions.headers,
        isNot(contains('Authorization')),
      );
      expect(client.userid, accountB);
    });

    test('${entry.key} 等待服务就绪途中退出，不调用 adapter', () async {
      final generation = KugouApiClient.markServerStarting();
      final pending = entry.value(accountA);
      await pumpEventQueue();
      await client.clearCookies();
      KugouApiClient.markServerReady(generation);

      expect(await pending, isNull);
      expect(adapter.requests, isEmpty);
      expect(errors.single.type, DioExceptionType.cancel);
    });
  }

  final guardedCalls =
      <String, Future<Map<String, dynamic>?> Function(String account)>{
        ...writes,
        'playlist': (account) =>
            client.getUserPlaylist(expectedAccountId: account),
        'all playlists': (account) =>
            client.getAllUserPlaylists(expectedAccountId: account),
        'favorite page': (account) => client.getFavoriteTracksPage(
          listid: 'fixture-list',
          expectedAccountId: account,
        ),
      };

  for (final entry in guardedCalls.entries) {
    test('${entry.key} 错误账号或未登录均被拒绝且不影响网络可达状态', () async {
      KugouApiClient.networkReachable.value = true;
      expect(await entry.value(accountB), isNull);
      await client.clearCookies();
      expect(await entry.value(accountA), isNull);
      expect(adapter.requests, isEmpty);
      expect(errors, hasLength(2));
      expect(
        errors.map((error) => error.type),
        everyElement(DioExceptionType.cancel),
      );
      expect(KugouApiClient.networkReachable.value, isTrue);
    });
  }

  test('原两个位置参数的写方法仍可使用', () async {
    expect(await client.addPlaylistTracks('fixture-list', 'fixture-data'), {
      'status': 1,
    });
    expect(
      await client.deletePlaylistTracks('fixture-list', 'fixture-fileids'),
      {'status': 1},
    );
    expect(adapter.requests, hasLength(2));
    for (final request in adapter.requests) {
      expect(request.extra, isNot(contains('expectedAccountId')));
    }
  });

  test('收藏分页只使用现有端点和参数，原样返回业务错误而非空歌曲列表', () async {
    adapter.response = const {'status': 0, 'error_code': 20017};
    expect(
      await client.getFavoriteTracksPage(
        listid: 'fixture-list',
        expectedAccountId: accountA,
      ),
      adapter.response,
    );
    final request = adapter.requests.single;
    expect(request.path, KugouEndpoints.playlistTrackAllNew);
    expect(request.queryParameters, {
      'listid': 'fixture-list',
      'page': 1,
      'pagesize': 200,
      't': isA<int>(),
    });
    expect(request.extra['noCache'], isTrue);
    expect(request.extra['expectedAccountId'], accountA);
    expect(request.headers['x-apicache-bypass'], '1');

    adapter.response = const {
      'status': 1,
      'data': {'unknown_field': 'preserved'},
    };
    expect(
      await client.getFavoriteTracksPage(
        listid: 'fixture-list',
        expectedAccountId: accountA,
        page: 3,
        pagesize: 17,
      ),
      adapter.response,
    );
    expect(adapter.requests.last.queryParameters['page'], 3);
    expect(adapter.requests.last.queryParameters['pagesize'], 17);
  });

  test('认证读取即使 noCache 为 false 仍绕过服务端缓存', () async {
    await client.getUserPlaylist(expectedAccountId: accountA);
    await client.getUserPlaylist();
    for (final request in adapter.requests) {
      expect(request.queryParameters['userid'], accountA);
      expect(request.extra['noCache'], isFalse);
      expect(request.headers['x-apicache-bypass'], '1');
      expect(request.headers['Cache-Control'], 'no-cache');
    }
  });

  test('匿名和 images 读取仍不带认证或默认 cache bypass', () async {
    await client.dio.get('/images');
    await client.clearCookies();
    await client.getUserPlaylist();
    for (final request in adapter.requests) {
      expect(request.headers, isNot(contains('Authorization')));
      expect(request.headers, isNot(contains('x-apicache-bypass')));
      expect(request.headers, isNot(contains('Cache-Control')));
    }
  });

  test('全量歌单每页都传递账号约束', () async {
    adapter.onRequest = (request) async {
      adapter.response = {
        'status': 1,
        'data': {
          'total': 2,
          'info': [
            {'listid': 'fixture-list-${request.queryParameters['page']}'},
          ],
        },
      };
    };
    final result = await client.getAllUserPlaylists(
      expectedAccountId: accountA,
    );
    expect((result?['data'] as Map)['info'], hasLength(2));
    expect(adapter.requests, hasLength(2));
    for (final request in adapter.requests) {
      expect(request.extra['expectedAccountId'], accountA);
      expect(request.queryParameters['userid'], accountA);
      expect(request.headers['x-apicache-bypass'], '1');
    }
  });

  test('全量歌单两页之间切号不会把第二页发往新账号或返回截断成功', () async {
    adapter.response = const {
      'status': 1,
      'data': {
        'total': 2,
        'info': [
          {'listid': 'fixture-list'},
        ],
      },
    };
    adapter.onRequest = (_) =>
        client.setLoginCookies('fixture-token-b', accountB);
    await expectLater(
      client.getAllUserPlaylists(expectedAccountId: accountA),
      throwsStateError,
    );
    expect(adapter.requests, hasLength(1));
    expect(errors.single.type, DioExceptionType.cancel);
  });

  test('登录、凭证更新、切换、退出和删除活动账号均在完整身份生效后通知', () async {
    final snapshots = <List<Object?>>[];
    final readySnapshots = <Future<bool>>[];
    final revision = KugouApiClient.accountRevision.value;
    void onAccountChanged() {
      snapshots.add([client.userid, client.isLoggedIn, client.vipToken]);
      readySnapshots.add(client.isLoggedInWhenReady());
    }

    KugouApiClient.accountRevision.addListener(onAccountChanged);
    addTearDown(
      () => KugouApiClient.accountRevision.removeListener(onAccountChanged),
    );

    await client.setLoginCookies('fixture-token-a', accountA);
    expect(await client.switchToUser('fixture-missing'), isFalse);
    expect(snapshots, isEmpty);
    await client.setLoginCookies(
      'fixture-token-b',
      accountB,
      vipToken: 'fixture-vip-b',
    );
    await client.setLoginCookies(
      'fixture-token-b-renewed',
      accountB,
      vipToken: 'fixture-vip-b',
    );
    expect(await client.switchToUser(accountA), isTrue);
    expect(await client.switchToUser(accountA), isTrue);
    await client.removeAccount(accountB);
    expect(snapshots, hasLength(3));
    await client.removeAccount(accountA);
    await client.setLoginCookies('fixture-token-a', accountA);
    await client.clearCookies();
    await client.clearCookies();

    expect(snapshots, [
      [accountB, true, 'fixture-vip-b'],
      [accountB, true, 'fixture-vip-b'],
      [accountA, true, null],
      [null, false, null],
      [accountA, true, null],
      [null, false, null],
    ]);
    expect(await Future.wait(readySnapshots), [
      true,
      true,
      true,
      false,
      true,
      false,
    ]);
    expect(KugouApiClient.accountRevision.value, revision + snapshots.length);
    expect(adapter.requests, isEmpty);
  });
}

class _RecorderAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Map<String, dynamic> response = const {'status': 1};
  Future<void> Function(RequestOptions request)? onRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await onRequest?.call(options);
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: const {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
