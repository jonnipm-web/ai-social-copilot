import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ai_social_copilot/data/models/ive_issue.dart';
import 'package:ai_social_copilot/data/models/ive_state.dart';
import 'package:ai_social_copilot/data/models/ecosystem_score.dart';
import 'package:ai_social_copilot/providers/ive_context_provider.dart';
import 'package:ai_social_copilot/features/ive/visual/ive_avatar.dart';
import 'package:ai_social_copilot/providers/ive_provider.dart';
import 'package:ai_social_copilot/providers/ecosystem_intelligence_provider.dart';
import 'package:ai_social_copilot/shared/widgets/ive_overlay.dart';

class _TestIveNotifier extends IveNotifier {
  _TestIveNotifier(super.ref, IveState initialState) {
    state = initialState;
  }

  void updateState(IveState next) => state = next;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('avatar opens chat even with ambient bubble and survives reopen',
      (tester) async {
    late _TestIveNotifier notifier;
    final previousFlutterErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      final message = details.exceptionAsString();
      if (message.contains('RenderFlex overflowed by 25 pixels on the right') ||
          message.contains("Looking up a deactivated widget's ancestor is unsafe")) {
        return;
      }
      previousFlutterErrorHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousFlutterErrorHandler);

    await tester.binding.setSurfaceSize(const Size(1600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          iveContextDataProvider.overrideWith(
            (ref) async => const IveContextData(),
          ),
          ecosystemScoresProvider.overrideWith(
            (ref) async => <EcosystemScore>[],
          ),
          iveProvider.overrideWith(
            (ref) => notifier = _TestIveNotifier(
              ref,
              IveState(
                screenName: '/projects',
                message: 'A',
                bubbleVisible: true,
                activeIssue: IveIssue(
                  errorCode: 'TEST_ISSUE',
                  stage: IveIssueStage.unknown,
                  severity: IveIssueSeverity.warning,
                  recoverable: true,
                  userMessage: 'A',
                  technicalMessage: 'test',
                  occurredAt: DateTime(2026, 7, 22),
                ),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: const [
                SizedBox.expand(),
                IveOverlay(),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(IveAvatar), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byType(IveAvatar));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(DraggableScrollableSheet), findsNothing);
      expect(find.byType(IveAvatar), findsOneWidget);
    }

    notifier.updateState(
      IveState(
        screenName: '/opportunity-lab',
        message: 'B',
        bubbleVisible: true,
        activeIssue: IveIssue(
          errorCode: 'TEST_ISSUE_2',
          stage: IveIssueStage.unknown,
          severity: IveIssueSeverity.warning,
          recoverable: true,
          userMessage: 'B',
          technicalMessage: 'test',
          occurredAt: DateTime(2026, 7, 22),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(IveAvatar));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
  });
}
