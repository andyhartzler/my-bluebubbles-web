import 'package:bluebubbles/models/crm/meeting.dart';
import 'package:bluebubbles/models/crm/member_portal.dart';
import 'package:bluebubbles/screens/crm/member_portal/member_portal_management_screen.dart';
import 'package:bluebubbles/screens/crm/meeting_detail_screen.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    CRMSupabaseService().debugSetInitialized(true);
  });

  tearDown(() {
    MemberPortalManagementScreen.recordingEmbedBuilderOverride = null;
    MeetingRecordingEmbed.debugForceRegistrationFailure = false;
    MeetingRecordingEmbed.debugForceSrcFailure = false;
    CRMSupabaseService().debugSetInitialized(false);
  });

  testWidgets(
    'Fallback link renders when recording embed fails',
    (tester) async {
      final capturedErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      final originalErrorWidgetBuilder = ErrorWidget.builder;

      FlutterError.onError = (details) {
        capturedErrors.add(details);
      };

      ErrorWidget.builder = (details) {
        capturedErrors.add(details);
        return originalErrorWidgetBuilder(details);
      };

      addTearDown(() {
        FlutterError.onError = originalOnError;
        ErrorWidget.builder = originalErrorWidgetBuilder;
      });

      MeetingRecordingEmbed.debugForceRegistrationFailure = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: MemberPortalManagementScreen(),
        ),
      );

      final state = tester.state(find.byType(MemberPortalManagementScreen)) as dynamic;

      const meeting = MemberPortalMeeting(
        id: '1',
        meetingId: 'meeting-1',
        createdAt: DateTime(2024, 1, 1),
        memberTitle: 'January Meeting',
        visibleToAll: true,
        visibleToAttendeesOnly: true,
        visibleToExecutives: true,
        isPublished: true,
        showRecording: true,
        recordingEmbedUrl: 'https://example.com/embed',
        recordingUrl: 'https://example.com/recording',
      );

      final meetingDetails = Meeting(
        id: 'meeting-1',
        meetingDate: DateTime(2024, 1, 1),
        meetingTitle: 'January Meeting',
        recordingUrl: meeting.recordingUrl,
        recordingEmbedUrl: meeting.recordingEmbedUrl,
      );

      state.setState(() {
        state._meetingsFuture = Future<List<MemberPortalMeeting>>.value(const [meeting]);
        state._editingMeetingId = meeting.id;
        state._selectedMeetingId = meeting.id;
        state._currentMeeting = meeting;
        state._selectedShowRecording = true;
        state._recordingExpanded = true;
        state._selectedVisibleToAll = meeting.visibleToAll;
        state._selectedVisibleToAttendeesOnly = meeting.visibleToAttendeesOnly;
        state._selectedVisibleToExecutives = meeting.visibleToExecutives;
        state._selectedIsPublished = meeting.isPublished;
        state._descriptionController = quill.QuillController.basic();
        state._summaryController = quill.QuillController.basic();
        state._keyPointsController = quill.QuillController.basic();
        state._actionItemsController = quill.QuillController.basic();
        state._selectedMeetingDetails = meetingDetails;
        state._loadingMeetingDetails = false;
        state._meetingDetailsError = null;
        state._meetingHasUnsavedChanges = false;
        state._meetingSaveError = null;
        state._meetingSaveSucceeded = false;
      });

      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Recording'));
      await tester.pumpAndSettle();

      expect(find.text('Open recording'), findsOneWidget);
      expect(capturedErrors, isEmpty);
    },
    skip: !kIsWeb,
  );
}
