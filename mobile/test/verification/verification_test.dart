import 'dart:convert';
import 'dart:io';

import 'package:datingapp/core/network/api_client.dart';
import 'package:datingapp/core/network/api_exception.dart';
import 'package:datingapp/core/theme/app_theme.dart';
import 'package:datingapp/verification/data/selfie_capture.dart';
import 'package:datingapp/verification/data/verification_repository.dart';
import 'package:datingapp/verification/domain/verification.dart';
import 'package:datingapp/verification/presentation/verification_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fake_token_storage.dart';

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.responses);

  final Map<String, Map<String, dynamic>> responses;
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(responses[options.path] ?? {}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _FakeRepository implements VerificationRepository {
  _FakeRepository({required this.status, VerificationChallenge? challenge})
    : challenge = (() async => challenge ?? _challenge());

  Future<VerificationState> Function() status;
  Future<VerificationChallenge> Function() challenge;
  Future<VerificationRequestInfo> Function(String path, String pose)? onSubmit;
  int statusCalls = 0;
  int challengeCalls = 0;
  final submissions = <(String, String)>[];

  @override
  Future<VerificationState> getStatus() {
    statusCalls++;
    return status();
  }

  @override
  Future<VerificationChallenge> getChallenge() {
    challengeCalls++;
    return challenge();
  }

  @override
  Future<VerificationRequestInfo> submit({
    required String selfiePath,
    required String pose,
  }) {
    submissions.add((selfiePath, pose));
    return onSubmit!(selfiePath, pose);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCapture implements SelfieCapture {
  _FakeCapture(this.path);

  String? path;
  int calls = 0;

  @override
  Future<String?> capture() async {
    calls++;
    return path;
  }
}

VerificationChallenge _challenge([
  String pose = 'thumbs_up',
  String label = 'Give a thumbs up',
]) =>
    VerificationChallenge(pose: pose, label: label, expiresAt: DateTime(2030));

VerificationRequestInfo _request(
  VerificationOutcome outcome, {
  String? reason,
  String? message,
}) => VerificationRequestInfo(
  id: 1,
  outcome: outcome,
  submittedAt: DateTime(2026, 9, 20),
  reason: reason,
  reasonMessage: message,
);

VerificationState _state({
  bool verified = false,
  bool canStart = true,
  VerificationRequestInfo? request,
}) => VerificationState(
  isVerified: verified,
  canStart: canStart,
  request: request,
);

ApiException _error(String code, String message, [int status = 422]) =>
    ApiException(code: code, message: message, statusCode: status);

/// A launcher that opens `/verification` and prints what it popped with, so
/// "Done" returning `true` only when verified can be asserted.
Widget _app(_FakeRepository repo, _FakeCapture capture) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(body: _Launcher(context)),
      ),
      GoRoute(
        path: '/verification',
        builder: (_, _) => const VerificationScreen(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      verificationRepositoryProvider.overrideWithValue(repo),
      selfieCaptureProvider.overrideWithValue(capture),
    ],
    child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
  );
}

class _Launcher extends StatefulWidget {
  const _Launcher(this.outer);

  final BuildContext outer;

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  String _popped = 'not opened';

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButton(
        onPressed: () async {
          final v = await context.push<bool>('/verification');
          setState(() => _popped = 'popped $v');
        },
        child: const Text('open'),
      ),
      Text(_popped),
    ],
  );
}

Future<void> _open(
  WidgetTester tester,
  _FakeRepository repo,
  _FakeCapture capture,
) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(repo, capture));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('VerificationRepository (docs/03 Verification)', () {
    (VerificationRepository, _RecordingAdapter) repoReturning(
      Map<String, Map<String, dynamic>> responses,
    ) {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final adapter = _RecordingAdapter(responses);
      dio.httpClientAdapter = adapter;
      return (
        VerificationRepository(
          ApiClient(tokenStorage: FakeTokenStorage(), dio: dio),
        ),
        adapter,
      );
    }

    test('getStatus maps the state and the latest request', () async {
      final (repo, _) = repoReturning({
        '/verification/status': {
          'is_verified': false,
          'can_start': true,
          'request': {
            'id': 4,
            'status': 'rejected',
            'submitted_at': '2026-09-20T10:00:00+00:00',
            'decided_at': '2026-09-20T10:00:05+00:00',
            'reason': 'no_face_detected',
            'reason_message': 'Try again in good light.',
          },
        },
      });

      final state = await repo.getStatus();

      expect(state.isVerified, isFalse);
      expect(state.canStart, isTrue);
      expect(state.request!.outcome, VerificationOutcome.rejected);
      expect(state.request!.reason, 'no_face_detected');
      expect(state.request!.reasonMessage, 'Try again in good light.');
    });

    test('a status with no request maps to null', () async {
      final (repo, _) = repoReturning({
        '/verification/status': {
          'is_verified': true,
          'can_start': false,
          'request': null,
        },
      });

      final state = await repo.getStatus();

      expect(state.isVerified, isTrue);
      expect(state.request, isNull);
    });

    test('processing and pending both read as in review', () {
      expect(
        VerificationOutcome.fromApi('in_review'),
        VerificationOutcome.inReview,
      );
      expect(
        VerificationOutcome.fromApi('anything-else'),
        VerificationOutcome.inReview,
      );
      expect(
        VerificationOutcome.fromApi('approved'),
        VerificationOutcome.approved,
      );
    });

    test('getChallenge maps the pose', () async {
      final (repo, _) = repoReturning({
        '/verification/challenge': {
          'challenge': {
            'pose': 'peace_sign',
            'label': 'Show a peace sign',
            'expires_at': '2026-09-20T10:15:00+00:00',
          },
        },
      });

      final challenge = await repo.getChallenge();

      expect(challenge.pose, 'peace_sign');
      expect(challenge.label, 'Show a peace sign');
    });

    test('submit posts the selfie and pose as multipart', () async {
      final (repo, adapter) = repoReturning({
        '/verification/request': {
          'request': {
            'id': 9,
            'status': 'in_review',
            'submitted_at': '2026-09-20T10:00:00+00:00',
            'decided_at': null,
            'reason': null,
            'reason_message': null,
          },
        },
      });
      final file = File('${Directory.systemTemp.path}/selfie_test.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
      addTearDown(() {
        // Windows keeps the file open while the upload stream drains.
        try {
          file.deleteSync();
        } on FileSystemException {
          // Left in the temp directory; harmless.
        }
      });

      final result = await repo.submit(selfiePath: file.path, pose: 'wave');

      expect(adapter.lastRequest!.method, 'POST');
      expect(adapter.lastRequest!.path, '/verification/request');
      final form = adapter.lastRequest!.data as FormData;
      expect(form.fields.single.key, 'pose');
      expect(form.fields.single.value, 'wave');
      expect(form.files.single.key, 'selfie');
      expect(result.outcome, VerificationOutcome.inReview);
    });
  });

  group('VerificationScreen', () {
    testWidgets(
      'intro: the pose, the privacy promise and a Take selfie button',
      (tester) async {
        final repo = _FakeRepository(status: () async => _state());
        await _open(tester, repo, _FakeCapture('/tmp/s.jpg'));

        expect(find.text("Show you're really you"), findsOneWidget);
        expect(find.text('Give a thumbs up'), findsOneWidget);
        expect(
          find.textContaining('deleted as soon as it is done'),
          findsOneWidget,
        );
        expect(find.text('Take selfie'), findsOneWidget);
      },
    );

    testWidgets('backing out of the camera submits nothing', (tester) async {
      final repo = _FakeRepository(status: () async => _state());
      final capture = _FakeCapture(null);
      await _open(tester, repo, capture);

      await tester.tap(find.text('Take selfie'));
      await tester.pumpAndSettle();

      expect(capture.calls, 1);
      expect(repo.submissions, isEmpty);
      expect(find.text('Take selfie'), findsOneWidget);
    });

    testWidgets('submits the photo with the pose it was asked for', (
      tester,
    ) async {
      final repo = _FakeRepository(
        status: () async => _state(),
        challenge: _challenge('peace_sign', 'Show a peace sign'),
      )..onSubmit = (_, _) async => _request(VerificationOutcome.approved);
      await _open(tester, repo, _FakeCapture('/tmp/s.jpg'));

      await tester.tap(find.text('Take selfie'));
      await tester.pumpAndSettle();

      expect(repo.submissions, [('/tmp/s.jpg', 'peace_sign')]);
    });

    testWidgets('approved: the badge, and Done reports success', (
      tester,
    ) async {
      final repo = _FakeRepository(status: () async => _state())
        ..onSubmit = (_, _) async => _request(VerificationOutcome.approved);
      await _open(tester, repo, _FakeCapture('/tmp/s.jpg'));

      await tester.tap(find.text('Take selfie'));
      await tester.pumpAndSettle();
      expect(find.text("You're verified"), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('popped true'), findsOneWidget);
    });

    testWidgets(
      'in review: a person will look, and Done reports not verified',
      (tester) async {
        final repo = _FakeRepository(status: () async => _state())
          ..onSubmit = (_, _) async => _request(VerificationOutcome.inReview);
        await _open(tester, repo, _FakeCapture('/tmp/s.jpg'));

        await tester.tap(find.text('Take selfie'));
        await tester.pumpAndSettle();
        expect(find.text("We're reviewing your selfie"), findsOneWidget);
        // It never says why, and never shows a score.
        expect(find.textContaining('score'), findsNothing);

        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(find.text('popped false'), findsOneWidget);
      },
    );

    testWidgets('rejected: the reason, and Try again starts over', (
      tester,
    ) async {
      final repo = _FakeRepository(status: () async => _state())
        ..onSubmit = (_, _) async => _request(
          VerificationOutcome.rejected,
          reason: 'no_face_detected',
          message: "We couldn't see a face in your selfie.",
        );
      await _open(tester, repo, _FakeCapture('/tmp/s.jpg'));
      await tester.tap(find.text('Take selfie'));
      await tester.pumpAndSettle();
      expect(
        find.text("We couldn't see a face in your selfie."),
        findsOneWidget,
      );
      expect(repo.statusCalls, 1);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(repo.statusCalls, 2);
      expect(find.text('Take selfie'), findsOneWidget);
    });

    testWidgets('coming back after a rejection reminds them why', (
      tester,
    ) async {
      final repo = _FakeRepository(
        status: () async => _state(
          request: _request(
            VerificationOutcome.rejected,
            reason: 'photo_unclear',
            message: 'Your selfie was too dark.',
          ),
        ),
      );
      await _open(tester, repo, _FakeCapture('/tmp/s.jpg'));

      expect(find.text('Your selfie was too dark.'), findsOneWidget);
      expect(find.text('Take selfie'), findsOneWidget);
    });

    testWidgets('already verified: shows it, asks for no selfie', (
      tester,
    ) async {
      final repo = _FakeRepository(
        status: () async => _state(verified: true, canStart: false),
      );
      await _open(tester, repo, _FakeCapture('/tmp/s.jpg'));

      expect(find.text("You're verified"), findsOneWidget);
      expect(repo.challengeCalls, 0);
    });

    testWidgets('already in review: shows that, asks for no selfie', (
      tester,
    ) async {
      final repo = _FakeRepository(
        status: () async => _state(
          canStart: false,
          request: _request(VerificationOutcome.inReview),
        ),
      );
      await _open(tester, repo, _FakeCapture('/tmp/s.jpg'));

      expect(find.text("We're reviewing your selfie"), findsOneWidget);
      expect(repo.challengeCalls, 0);
    });

    testWidgets('out of attempts for today', (tester) async {
      final repo = _FakeRepository(
        status: () async => _state(
          canStart: false,
          request: _request(VerificationOutcome.rejected),
        ),
      );
      await _open(tester, repo, _FakeCapture('/tmp/s.jpg'));

      expect(find.text('Come back tomorrow'), findsOneWidget);
      expect(find.text('Take selfie'), findsNothing);
    });

    testWidgets('an expired prompt is replaced with a fresh one', (
      tester,
    ) async {
      var issued = 0;
      final repo = _FakeRepository(status: () async => _state())
        ..challenge = () async {
          issued++;
          return issued == 1
              ? _challenge('thumbs_up', 'Give a thumbs up')
              : _challenge('wave', 'Wave at the camera');
        }
        ..onSubmit = (_, _) async =>
            throw _error('challenge_expired', 'That pose prompt has expired.');
      await _open(tester, repo, _FakeCapture('/tmp/s.jpg'));

      await tester.tap(find.text('Take selfie'));
      await tester.pumpAndSettle();

      expect(find.text('Wave at the camera'), findsOneWidget);
      expect(
        find.text('That prompt expired. Here is a new one.'),
        findsOneWidget,
      );
    });

    testWidgets('a missing profile photo says so and lets them retry', (
      tester,
    ) async {
      final repo = _FakeRepository(status: () async => _state())
        ..onSubmit = (_, _) async =>
            throw _error('photo_required', 'Add a profile photo first.');
      await _open(tester, repo, _FakeCapture('/tmp/s.jpg'));

      await tester.tap(find.text('Take selfie'));
      await tester.pumpAndSettle();

      expect(find.text('Add a profile photo first.'), findsOneWidget);
      expect(find.text('Take selfie'), findsOneWidget);
      // The same prompt is still valid.
      expect(find.text('Give a thumbs up'), findsOneWidget);
    });

    testWidgets('hitting the daily cap while submitting shows the limit', (
      tester,
    ) async {
      final repo = _FakeRepository(status: () async => _state())
        ..onSubmit = (_, _) async => throw _error(
          'too_many_attempts',
          'You have reached the daily verification limit.',
          429,
        );
      await _open(tester, repo, _FakeCapture('/tmp/s.jpg'));

      await tester.tap(find.text('Take selfie'));
      await tester.pumpAndSettle();

      expect(find.text('Come back tomorrow'), findsOneWidget);
      expect(
        find.text('You have reached the daily verification limit.'),
        findsOneWidget,
      );
    });

    testWidgets('a request already open elsewhere re-reads the state', (
      tester,
    ) async {
      var calls = 0;
      final repo =
          _FakeRepository(
              status: () async {
                calls++;
                return calls == 1
                    ? _state()
                    : _state(
                        canStart: false,
                        request: _request(VerificationOutcome.inReview),
                      );
              },
            )
            ..onSubmit = (_, _) async => throw _error(
              'verification_in_progress',
              'You already have a verification in progress.',
              409,
            );
      await _open(tester, repo, _FakeCapture('/tmp/s.jpg'));

      await tester.tap(find.text('Take selfie'));
      await tester.pumpAndSettle();

      expect(find.text("We're reviewing your selfie"), findsOneWidget);
    });

    testWidgets('a failed load shows Retry, and Retry recovers', (
      tester,
    ) async {
      var attempt = 0;
      final repo = _FakeRepository(
        status: () async {
          attempt++;
          if (attempt == 1) throw _error('server_error', 'Server down', 500);
          return _state();
        },
      );
      await _open(tester, repo, _FakeCapture('/tmp/s.jpg'));
      expect(find.text('Server down'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Take selfie'), findsOneWidget);
    });
  });
}
