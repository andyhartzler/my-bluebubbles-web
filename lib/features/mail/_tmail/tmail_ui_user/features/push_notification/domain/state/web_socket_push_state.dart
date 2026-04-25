import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class InitializingWebSocketPushChannel extends LoadingState {}

class WebSocketConnectionSuccess extends UIState {
  final WebSocketChannel webSocketChannel;

  WebSocketConnectionSuccess(this.webSocketChannel);

  @override
  List<Object?> get props => [webSocketChannel];
}

class WebSocketConnectionFailed extends FeatureFailure {

  WebSocketConnectionFailed({super.exception});
}