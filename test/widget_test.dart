import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nfc/main.dart';
import 'package:nfc/screen/profile_entry_screen.dart';
import 'package:nfc/screen/nfc_data_display_screen.dart';
import 'package:nfc/services/nfc_profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final openedUrls = <String>[];
  const nfcChannel = MethodChannel('plugins.flutter.io/nfc_manager');
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    openedUrls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nfcChannel, (call) async => false);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          (call) async {
            if (call.method == 'launch') {
              openedUrls.add((call.arguments as Map)['url'] as String);
            }
            return true;
          },
        );
  });
  testWidgets('App opens the profile entry screen', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.byType(ProfileEntryScreen), findsOneWidget);
    expect(find.text('Create Your NFC Profile'), findsOneWidget);
  });
  testWidgets('Name is required', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileEntryScreen()));
    await tester.pumpAndSettle();
    final button = find.text('Save Profile');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(find.text('Please enter your name'), findsOneWidget);
    expect(find.byType(NFCDataDisplayScreen), findsNothing);
  });
  testWidgets('Saving stays in the app and viewing opens the same profile link', (
    tester,
  ) async {
    final saved = {'_id': '1234567890abcdef12345678', 'name': 'Saved Name'};
    var saves = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MaterialApp(home: ProfileEntryScreen()));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Name *'),
          'Entered Name',
        );
        final button = find.text('Save Profile');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Your profile was saved successfully in the backend. HTML profile page is ready.',
          ),
          findsOneWidget,
        );
        expect(find.byType(ProfileEntryScreen), findsOneWidget);
        expect(find.byType(NFCDataDisplayScreen), findsNothing);
        expect(openedUrls, isEmpty);
        final view = find.text('View HTML Profile');
        await tester.ensureVisible(view);
        await tester.tap(view);
        await tester.pumpAndSettle();
        expect(openedUrls, [
          NFCProfileService.generateProfileHtmlUrl(saved['_id']!),
        ]);
        expect(find.text('View HTML Profile'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Name *'),
          'Updated Name',
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(saves, 2);
        expect(openedUrls, hasLength(1));
        await tester.ensureVisible(view);
        await tester.tap(view);
        await tester.pumpAndSettle();
        expect(openedUrls.last, openedUrls.first);
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getString('html_profile_id'), saved['_id']);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(const MaterialApp(home: ProfileEntryScreen()));
        await tester.pumpAndSettle();
        expect(find.text('Saved Name'), findsOneWidget);
        expect(saves, 2);
      },
      () => MockClient((request) async {
        if (request.method == 'GET') {
          if (request.url.path.contains('/getprofile/')) {
            return http.Response(jsonEncode({'data': saved}), 200);
          }
          expect(
            request.url.toString(),
            '${NFCProfileService.baseUrl}/profile-page/${saved['_id']}',
          );
          expect(request.headers['accept'], 'text/html');
          return http.Response(
            '<html>Saved Name</html>',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }
        saves++;
        expect(request.method, saves == 1 ? 'POST' : 'PUT');
        expect(
          request.url.toString(),
          saves == 1
              ? '${NFCProfileService.baseUrl}/create'
              : '${NFCProfileService.baseUrl}/profiles/${saved['_id']}',
        );
        expect(
          jsonDecode(request.body)['name'],
          saves == 1 ? 'Entered Name' : 'Updated Name',
        );
        return http.Response(
          jsonEncode({'data': saved}),
          saves == 1 ? 201 : 200,
        );
      }),
    );
  });
  testWidgets(
    'New user gets a separate profile and preserves the previous user',
    (tester) async {
      const arunId = '1234567890abcdef12345678';
      const hariId = 'abcdef1234567890abcdef12';
      final profiles = <String, Map<String, dynamic>>{};
      final methods = <String>[];
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(home: ProfileEntryScreen()),
          );
          await tester.pumpAndSettle();
          Future<void> saveName(String name) async {
            await tester.enterText(
              find.widgetWithText(TextFormField, 'Name *'),
              name,
            );
            final save = find.text('Save Profile');
            await tester.ensureVisible(save);
            await tester.tap(save);
            await tester.pumpAndSettle();
          }

          Future<void> viewProfile() async {
            final view = find.text('View HTML Profile');
            await tester.ensureVisible(view);
            await tester.tap(view);
            await tester.pumpAndSettle();
          }

          await saveName('Arun');
          await viewProfile();
          expect(find.text('Edit Current NFC Profile'), findsOneWidget);
          final newUser = find.text('Create New User');
          await tester.ensureVisible(newUser);
          await tester.tap(newUser);
          await tester.pumpAndSettle();
          expect(find.text('Create Your NFC Profile'), findsOneWidget);
          expect(find.text('View HTML Profile'), findsNothing);
          expect(
            tester
                .widget<TextFormField>(
                  find.widgetWithText(TextFormField, 'Name *'),
                )
                .controller!
                .text,
            isEmpty,
          );
          final preferences = await SharedPreferences.getInstance();
          expect(preferences.getString('html_profile_id'), isNull);
          // Restarting after New User must not restore Arun's ID.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            const MaterialApp(home: ProfileEntryScreen()),
          );
          await tester.pumpAndSettle();
          expect(find.text('Create Your NFC Profile'), findsOneWidget);
          await saveName('Hari');
          await viewProfile();
          await saveName('Hari Updated');
          expect(methods, ['POST', 'POST', 'PUT']);
          expect(profiles[arunId]!['name'], 'Arun');
          expect(profiles[hariId]!['name'], 'Hari Updated');
          expect(preferences.getString('html_profile_id'), hariId);
          expect(openedUrls, [
            NFCProfileService.generateProfileHtmlUrl(arunId),
            NFCProfileService.generateProfileHtmlUrl(hariId),
          ]);
        },
        () => MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              '<html>Profile</html>',
              200,
              headers: {'content-type': 'text/html'},
            );
          }
          methods.add(request.method);
          final id = request.method == 'POST'
              ? (profiles.isEmpty ? arunId : hariId)
              : request.url.pathSegments.last;
          profiles[id] = {
            '_id': id,
            ...jsonDecode(request.body) as Map<String, dynamic>,
          };
          return http.Response(
            jsonEncode({'data': profiles[id]}),
            request.method == 'POST' ? 201 : 200,
          );
        }),
      );
    },
  );
  testWidgets('Server failure leaves the form ready to retry', (tester) async {
    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MaterialApp(home: ProfileEntryScreen()));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Name *'),
          'My Name',
        );
        final button = find.text('Save Profile');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Backend save could not be confirmed'),
          findsOneWidget,
        );
        expect(find.byType(NFCDataDisplayScreen), findsNothing);
        expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNotNull,
        );
      },
      () => MockClient(
        (_) async => http.Response('{"message":"Server Error"}', 500),
      ),
    );
  });
  test('HTML profile errors do not masquerade as HTML success', () async {
    await http.runWithClient(() async {
      expect(
        await NFCProfileService.getProfileHtml('1234567890abcdef12345678'),
        isNull,
      );
    }, () => MockClient((_) async => http.Response('Profile not found', 404)));
  });
  testWidgets('Unavailable HTML keeps the saved ID without opening a page', (
    tester,
  ) async {
    const id = '1234567890abcdef12345678';
    final methods = <String>[];
    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MaterialApp(home: ProfileEntryScreen()));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Name *'),
          'My Name',
        );
        final button = find.text('Save Profile');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.textContaining('Card was not written'), findsOneWidget);
        expect(openedUrls, isEmpty);
        expect(find.text('View HTML Profile'), findsNothing);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(methods, ['POST', 'PUT']);
        expect(openedUrls, isEmpty);
      },
      () => MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response('Profile not found', 404);
        }
        methods.add(request.method);
        return http.Response(
          jsonEncode({
            'data': {'_id': id, 'name': 'My Name'},
          }),
          request.method == 'POST' ? 201 : 200,
        );
      }),
    );
  });
  for (final scenario in [
    'success',
    'read-only',
    'too small',
    'mismatch',
    'write io error',
    'verify io error',
    'cancel',
  ]) {
    testWidgets('NFC Save handles $scenario without opening the browser', (
      tester,
    ) async {
      const id = '1234567890abcdef12345678';
      Map<dynamic, dynamic>? written;
      var started = false;
      var stopped = false;
      var read = false;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(nfcChannel, (call) async {
        switch (call.method) {
          case 'Nfc#isAvailable':
            return true;
          case 'Nfc#startSession':
            started = true;
            expect((call.arguments as Map)['invalidateAfterFirstRead'], false);
            return null;
          case 'Ndef#write':
            if (scenario == 'write io error') {
              throw PlatformException(code: 'io_exception');
            }
            written = (call.arguments as Map)['message'] as Map;
            return null;
          case 'Ndef#read':
            read = true;
            if (scenario == 'verify io error') {
              throw PlatformException(code: 'io_exception');
            }
            return scenario == 'mismatch' ? {'records': []} : written;
          case 'Nfc#stopSession':
            stopped = true;
            return null;
          default:
            return null;
        }
      });
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(home: ProfileEntryScreen()),
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.widgetWithText(TextFormField, 'Name *'),
            'My Name',
          );
          final save = find.text('Save Profile');
          await tester.ensureVisible(save);
          await tester.tap(save);
          for (var i = 0; i < 20 && !started; i++) {
            await tester.pump(const Duration(milliseconds: 10));
          }
          expect(started, isTrue);
          expect(find.textContaining('Hold your NFC card'), findsOneWidget);
          expect(openedUrls, isEmpty);
          if (scenario == 'cancel') {
            final cancel = find.text('Cancel card write');
            await tester.ensureVisible(cancel);
            await tester.tap(cancel);
          } else {
            await messenger.handlePlatformMessage(
              nfcChannel.name,
              const StandardMethodCodec().encodeMethodCall(
                MethodCall('onDiscovered', {
                  'handle': 'test-card',
                  'ndef': {
                    'isWritable': scenario != 'read-only',
                    'maxSize': scenario == 'too small' ? 1 : 1024,
                    'cachedMessage': null,
                  },
                }),
              ),
              (_) {},
            );
          }
          await tester.pumpAndSettle();
          expect(stopped, isTrue);
          expect(openedUrls, isEmpty);
          if (scenario == 'success') {
            expect(read, isTrue);
            expect(
              find.textContaining('Write verified successfully'),
              findsOneWidget,
            );
            final record = (written!['records'] as List).single as Map;
            final payload = record['payload'] as List;
            final url = NFCProfileService.generateProfileHtmlUrl(id);
            // Decode the NFC URI payload independently of the writer.
            expect(payload.first, 2);
            expect(
              'https://www.${utf8.decode(payload.skip(1).cast<int>().toList())}',
              url,
            );
          } else {
            expect(
              find.textContaining('Write verified successfully'),
              findsNothing,
            );
            expect(
              find.textContaining(
                scenario == 'cancel'
                    ? 'canceled'
                    : scenario == 'mismatch'
                    ? 'verification failed'
                    : scenario == 'too small'
                    ? 'too large'
                    : scenario.endsWith('io error')
                    ? 'Keep the card firmly against'
                    : 'read-only',
              ),
              findsOneWidget,
            );
            if (scenario.endsWith('io error')) {
              expect(find.textContaining('PlatformException'), findsNothing);
              expect(
                find.textContaining('Profile saved on the server'),
                findsOneWidget,
              );
              expect(read, scenario == 'verify io error');
            }
            if (scenario != 'mismatch' && scenario != 'verify io error') {
              expect(written, isNull);
            }
          }
        },
        () => MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              '<html>Profile</html>',
              200,
              headers: {'content-type': 'text/html'},
            );
          }
          return http.Response(
            jsonEncode({
              'data': {'_id': id},
            }),
            201,
          );
        }),
      );
    });
  }
  test('New QR URLs and public profile links resolve the profile ID', () {
    const id = '1234567890abcdef12345678';
    final url = NFCProfileService.generateProfileQRUrl(id);
    expect(url, '${NFCProfileService.baseUrl}/profile-page/$id');
    expect(NFCProfileService.extractProfileIdFromUrl(url), id);
    expect(
      NFCProfileService.extractProfileIdFromUrl(
        '${NFCProfileService.baseUrl}/profile-page/$id',
      ),
      id,
    );
    expect(
      NFCProfileService.extractProfileIdFromUrl(
        'https://example.com/api/getprofile/$id',
      ),
      isNull,
    );
  });
}
