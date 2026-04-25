import 'package:bluebubbles/features/mail/_tmail/core/data/network/dio_client.dart';
import 'package:bluebubbles/features/mail/_tmail/scribe/scribe/ai/data/model/ai_api_request.dart';
import 'package:bluebubbles/features/mail/_tmail/scribe/scribe/ai/data/model/ai_api_response.dart';
import 'package:bluebubbles/features/mail/_tmail/scribe/scribe/ai/domain/model/ai_message.dart';

class AIApi {
  final DioClient _dioClient;
  final String aiEndpoint;

  AIApi(this._dioClient, this.aiEndpoint);

  Future<AIApiResponse> generateMessage(List<AIMessage> messages) async {
    final aiRequest = AIAPIRequest(messages: messages);

    final response = await _dioClient.post(
      aiEndpoint,
      data: aiRequest.toJson(),
      useJMAPHeader: false,
    );

    return AIApiResponse.fromJson(response);
  }
}
