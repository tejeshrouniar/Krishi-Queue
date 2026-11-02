import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:krishi_queue/core/network/krishi_gateway.dart';
import 'package:krishi_queue/core/storage/content_cache.dart';
import 'package:krishi_queue/features/ai_chat/data/ai_chat_api.dart';
import 'package:krishi_queue/features/ai_chat/data/ai_chat_models.dart';
import 'package:krishi_queue/features/ai_chat/domain/offline_assistant.dart';
import 'package:krishi_queue/features/market/data/market_price_repository.dart';
import 'package:krishi_queue/features/news/data/farmer_news_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mutable test fake deliberately simulates a device rejecting later writes.
// ignore: must_be_immutable
class FakePreferences extends Fake implements SharedPreferencesAsync {
  final Map<String, String> values = {};
  bool failWrites = false;
  @override
  Future<String?> getString(String key) async => values[key];
  @override
  Future<void> setString(String key, String value) async {
    if (failWrites) throw StateError('Storage blocked');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

class MemoryCache extends ContentCache {
  final Map<String, CachedContent> data = {};
  @override
  Future<CachedContent?> read(String key) async => data[key];
  @override
  Future<bool> write(String key, List<Map<String, dynamic>> records) async {
    data[key] = CachedContent(DateTime.now(), records);
    return true;
  }

  @override
  Future<void> clear() async => data.clear();
}

Map<String, dynamic> validPrice() => {
  'state': 'Chhattisgarh',
  'commodity': 'Paddy',
  'market': 'Raipur',
  'district': 'Raipur',
  'arrival_date': '30/10/2026',
  'min_price': '1800',
  'max_price': '2400',
  'modal_price': '2200',
};

void main() {
  test('gateway errors distinguish setup, sign-in, limits and rejected text without exposing responses', () async {
    final unconfigured = KrishiGateway(baseUrl: '');
    await expectLater(
      unconfigured.post('market', {}),
      throwsA(
        isA<GatewayException>().having(
          (e) => e.kind,
          'kind',
          GatewayFailure.configuration,
        ),
      ),
    );
    for (final entry in {
      400: GatewayFailure.input,
      401: GatewayFailure.signIn,
      403: GatewayFailure.access,
      429: GatewayFailure.limit,
      503: GatewayFailure.unavailable,
    }.entries) {
      final gateway = KrishiGateway(
        baseUrl: 'https://example.test',
        token: () async => 'token',
        client: MockClient(
          (_) async => http.Response('private provider details', entry.key),
        ),
      );
      try {
        await gateway.post('assistant', {'message': 'Help'});
        fail('A failed response must not look successful');
      } on GatewayException catch (error) {
        expect(error.kind, entry.value);
        expect(
          error.localizedMessage(hindi: true),
          isNot(contains('private provider')),
        );
        expect(error.localizedMessage(hindi: false), isNotEmpty);
      } finally {
        gateway.dispose();
      }
    }
    unconfigured.dispose();
  });
  test(
    'public cache handles corrupt storage and clears only its own keys',
    () async {
      final preferences = FakePreferences();
      final cache = ContentCache(preferences: preferences);
      preferences.values['unrelated'] = 'keep';
      preferences.values['public_cache_v1_market_cg'] = 'invalid-json';
      expect(await cache.read('market_cg'), isNull);
      expect(await cache.write('market_cg', [validPrice()]), isTrue);
      expect((await cache.read('market_cg'))?.records.length, 1);
      preferences.failWrites = true;
      expect(await cache.write('farmer_news', []), isFalse);
      await cache.clear();
      expect(preferences.values, {'unrelated': 'keep'});
    },
  );
  test(
    'offline helper responds usefully in both languages without live claims',
    () {
      expect(
        OfflineAssistant.answer('payment delayed', hindi: false),
        contains('cannot confirm'),
      );
      expect(OfflineAssistant.answer('टोकन', hindi: true), contains('अभ्यास'));
      expect(
        OfflineAssistant.answer('pesticide dose', hindi: false),
        contains('Do not mix'),
      );
      expect(
        OfflineAssistant.answer('2g network', hindi: false),
        contains('not a reserved slot'),
      );
      expect(
        OfflineAssistant.answer('schemes', hindi: false),
        contains('pmkisan.gov.in'),
      );
    },
  );

  test(
    'gateway never calls a provider without sign-in or an HTTPS gateway',
    () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      });
      final noToken = KrishiGateway(
        client: client,
        baseUrl: 'https://example.test/api',
        token: () async => null,
      );
      await expectLater(
        noToken.post('translate', {}),
        throwsA(isA<GatewayException>()),
      );
      final insecure = KrishiGateway(
        client: client,
        baseUrl: 'http://example.test/api',
        token: () async => 'token',
      );
      await expectLater(
        insecure.post('translate', {}),
        throwsA(isA<GatewayException>()),
      );
      expect(calls, 0);
    },
  );

  test(
    'chat sends only one consented question and uses Firebase bearer token',
    () async {
      final gateway = KrishiGateway(
        baseUrl: 'https://example.test/api/',
        token: () async => 'firebase-token',
        client: MockClient((request) async {
          expect(request.url.path, '/api/assistant');
          expect(request.headers['Authorization'], 'Bearer firebase-token');
          expect(jsonDecode(request.body), {
            'message': 'Prepare my visit',
            'language': 'en',
          });
          expect(request.body, isNot(contains('private-bank-reference')));
          return http.Response(jsonEncode({'text': 'Bring the receipt'}), 200);
        }),
      );
      final answer = await GeminiAiChatApi(gateway: gateway).send(
        const AiChatRequest(
          history: [],
          message: 'Prepare my visit',
          appContext: 'private-bank-reference',
        ),
      );
      expect(answer.text, 'Bring the receipt');
    },
  );

  test('parser rejects impossible dates and invalid price ranges', () {
    expect(MarketPrice.fromRecord(validPrice())?.modalPrice, 2200);
    expect(
      MarketPrice.fromRecord({...validPrice(), 'arrival_date': '31/02/2026'}),
      isNull,
    );
    expect(
      MarketPrice.fromRecord({...validPrice(), 'arrival_date': '2026-02-31'}),
      isNull,
    );
    expect(
      MarketPrice.fromRecord({...validPrice(), 'modal_price': '9999'}),
      isNull,
    );
    expect(
      MarketPrice.fromRecord({...validPrice(), 'min_price': '-1'}),
      isNull,
    );
    expect(
      MarketPrice.fromRecord({...validPrice(), 'min_price': 'NaN'}),
      isNull,
    );
  });

  test(
    'saved market reports require no network and survive an update failure',
    () async {
      var calls = 0;
      final cache = MemoryCache();
      cache.data['market_cg'] = CachedContent(DateTime(2026, 10, 30), [
        validPrice(),
      ]);
      final repository = MarketPriceRepositoryImpl(
        cache: cache,
        gateway: KrishiGateway(
          baseUrl: 'https://example.test',
          token: () async => 'token',
          client: MockClient((_) async {
            calls++;
            return http.Response('unavailable', 503);
          }),
        ),
      );
      expect((await repository.getCachedPrices()).length, 1);
      expect(calls, 0);
      expect((await repository.refreshMarketPrices()).length, 1);
      expect(calls, 1);
      expect(repository.fromCache, isTrue);
      expect(repository.refreshError, isNotNull);
    },
  );

  test(
    'news does not fetch at startup, filters unsafe links and saves reports',
    () async {
      var calls = 0;
      final cache = MemoryCache();
      final api = FarmerNewsApi(
        cache: cache,
        gateway: KrishiGateway(
          baseUrl: 'https://example.test',
          token: () async => 'token',
          client: MockClient((_) async {
            calls++;
            return http.Response(
              jsonEncode({
                'results': [
                  {
                    'title': 'Farmer update',
                    'link': 'https://example.test/story',
                    'description': 'An update',
                    'pubDate': '2026-10-30T10:00:00Z',
                  },
                  {'title': 'Unsafe', 'link': 'javascript:alert(1)'},
                ],
              }),
              200,
            );
          }),
        ),
      );
      expect(await api.fetchLatest(), isEmpty);
      expect(calls, 0);
      expect(
        (await api.fetchLatest(refresh: true)).single.title,
        'Farmer update',
      );
      expect(calls, 1);
      expect((await api.fetchLatest()).length, 1);
      expect(calls, 1);
      expect(api.fromCache, isTrue);
    },
  );
}
