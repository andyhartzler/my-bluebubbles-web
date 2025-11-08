import 'dart:async';

import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/conversation_text_field.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('chat creator enter guard triggers a single send', (tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) {
          capturedContext = context;
          return const SizedBox.shrink();
        },
      ),
    ));

    final state = _TestTextFieldComponentState();
    final focusNode = FocusNode();

    Completer<void>? pendingSend;
    int sendCount = 0;

    state.configure(
      focusNode: focusNode,
      sendMessage: ({String? effect}) {
        sendCount += 1;
        pendingSend = Completer<void>();
        return pendingSend!.future;
      },
    );

    const enterPhysical = PhysicalKeyboardKey.enter;
    const enterLogical = LogicalKeyboardKey.enter;

    expect(
      state.handleKey(
        focusNode,
        const KeyDownEvent(physicalKey: enterPhysical, logicalKey: enterLogical),
        capturedContext,
        true,
      ),
      KeyEventResult.handled,
    );
    expect(sendCount, 1);

    expect(
      state.handleKey(
        focusNode,
        const KeyDownEvent(physicalKey: enterPhysical, logicalKey: enterLogical),
        capturedContext,
        true,
      ),
      KeyEventResult.handled,
    );
    expect(sendCount, 1);

    expect(
      state.handleKey(
        focusNode,
        const KeyUpEvent(physicalKey: enterPhysical, logicalKey: enterLogical),
        capturedContext,
        true,
      ),
      KeyEventResult.handled,
    );
    expect(sendCount, 1);

    expect(
      state.handleKey(
        focusNode,
        const KeyDownEvent(physicalKey: enterPhysical, logicalKey: enterLogical),
        capturedContext,
        true,
      ),
      KeyEventResult.handled,
    );
    expect(sendCount, 1);

    pendingSend!.complete();
    await tester.pump();

    expect(
      state.handleKey(
        focusNode,
        const KeyDownEvent(physicalKey: enterPhysical, logicalKey: enterLogical),
        capturedContext,
        true,
      ),
      KeyEventResult.handled,
    );
    expect(sendCount, 2);

    expect(
      state.handleKey(
        focusNode,
        const KeyUpEvent(physicalKey: enterPhysical, logicalKey: enterLogical),
        capturedContext,
        true,
      ),
      KeyEventResult.handled,
    );

    pendingSend!.complete();
    await tester.pump();

    state.dispose();
    focusNode.dispose();
  });
}

class _TestTextFieldComponentState extends TextFieldComponentState {
  void configure({
    required FocusNode focusNode,
    required Future<void> Function({String? effect}) sendMessage,
  }) {
    controller = null;
    this.focusNode = focusNode;
    recorderController = null;
    initialAttachments = const <PlatformFile>[];
    textController = MentionTextEditingController();
    subjectTextController = SpellCheckTextEditingController();
    this.sendMessage = sendMessage;
    onAttachmentsChanged = null;
  }
}
