import 'package:bluebubbles/features/campaigns/email_builder/models/email_component.dart';
import 'package:bluebubbles/features/campaigns/email_builder/models/email_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes and deserializes complex email blocks', () {
    final document = EmailDocument(
      sections: [
        EmailSection(
          id: 'sec-1',
          columns: [
            EmailColumn(
              id: 'col-1',
              components: [
                const EmailComponent.heading(id: 'heading-1', content: 'Welcome'),
                const EmailComponent.text(id: 'text-1', content: 'Hello world'),
                const EmailComponent.button(
                  id: 'button-1',
                  text: 'Click me',
                  url: 'https://example.com',
                ),
                const EmailComponent.avatar(
                  id: 'avatar-1',
                  imageUrl: 'https://example.com/avatar.png',
                  alt: 'Avatar',
                ),
                EmailComponent.container(
                  id: 'container-1',
                  children: const [
                    EmailComponent.social(
                      id: 'social-1',
                      links: [
                        SocialLink(platform: 'twitter', url: 'https://twitter.com'),
                      ],
                    ),
                    EmailComponent.html(
                      id: 'html-1',
                      htmlContent: '<p>Custom block</p>',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
      settings: const EmailSettings(maxWidth: 700),
      theme: const {'color': 'blue'},
    );

    final json = document.toJson();
    final restored = EmailDocument.fromJson(json);

    expect(restored, equals(document));
    expect((restored.sections.first.columns.first.components[4] as ContainerComponent).children,
        isNotEmpty);
    expect(
      (restored.sections.first.columns.first.components[4] as ContainerComponent)
          .children
          .whereType<HtmlComponent>()
          .single
          .htmlContent,
      contains('Custom block'),
    );
  });
}
