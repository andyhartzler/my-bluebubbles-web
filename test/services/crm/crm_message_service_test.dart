import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/crm/crm_message_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CRMMessageService', () {
    test('fallback queue only runs once when createChat fails', () async {
      final service = CRMMessageService();
      final chat = Chat(guid: 'test-guid', chatIdentifier: 'test-identifier');
      int queueCount = 0;

      Future<Chat?> findExisting(String _) async => null;
      Future<Chat?> waitForChat(String _, {Chat? seed}) async => chat;
      Future<bool> queueText(Chat _, String __) async {
        queueCount += 1;
        return true;
      }
      Future<String> determineService(String _) async => 'SMS';
      Future<dynamic> createChat(List<String> addresses, String? message, String service) {
        throw Exception('createChat failure');
      }

      final success = await service.sendSingleMessageForTest(
        phoneNumber: '+15555550123',
        message: 'Hello world',
        findExistingChatOverride: findExisting,
        waitForChatOverride: waitForChat,
        queueTextMessageOverride: queueText,
        determineServiceOverride: determineService,
        createChatOverride: createChat,
      );

      expect(success, isTrue);
      expect(queueCount, 1);
    });
  });
}
