import 'package:freezed_annotation/freezed_annotation.dart';

part 'email_component.freezed.dart';
part 'email_component.g.dart';

@freezed
class EmailComponent with _$EmailComponent {
  const factory EmailComponent.text({
    required String id,
    @Default('') String content,
    @Default(TextComponentStyle()) TextComponentStyle style,
  }) = TextComponent;

  const factory EmailComponent.image({
    required String id,
    required String url,
    String? alt,
    String? link,
    @Default(ImageComponentStyle()) ImageComponentStyle style,
  }) = ImageComponent;

  const factory EmailComponent.button({
    required String id,
    required String text,
    required String url,
    @Default(ButtonComponentStyle()) ButtonComponentStyle style,
  }) = ButtonComponent;

  const factory EmailComponent.divider({
    required String id,
    @Default(DividerComponentStyle()) DividerComponentStyle style,
  }) = DividerComponent;

  const factory EmailComponent.spacer({
    required String id,
    @Default(40) double height,
  }) = SpacerComponent;

  const factory EmailComponent.social({
    required String id,
    @Default([]) List<SocialLink> links,
    @Default(SocialComponentStyle()) SocialComponentStyle style,
  }) = SocialComponent;

  // New email-builder-js block types
  const factory EmailComponent.avatar({
    required String id,
    required String imageUrl,
    String? alt,
    @Default(AvatarComponentStyle()) AvatarComponentStyle style,
  }) = AvatarComponent;

  const factory EmailComponent.heading({
    required String id,
    @Default('') String content,
    @Default(HeadingComponentStyle()) HeadingComponentStyle style,
  }) = HeadingComponent;

  const factory EmailComponent.html({
    required String id,
    @Default('') String htmlContent,
    @Default(HtmlComponentStyle()) HtmlComponentStyle style,
  }) = HtmlComponent;

  const factory EmailComponent.container({
    required String id,
    @Default([]) List<EmailComponent> children,
    @Default(ContainerComponentStyle()) ContainerComponentStyle style,
  }) = ContainerComponent;

  factory EmailComponent.fromJson(Map<String, dynamic> json) =>
      _$EmailComponentFromJson(json);
}

@freezed
class TextComponentStyle with _$TextComponentStyle {
  const factory TextComponentStyle({
    @Default(16) double fontSize,
    @Default('#000000') String color,
    @Default('left') String alignment,
    @Default(false) bool bold,
    @Default(false) bool italic,
    @Default(false) bool underline,
    @Default(1.5) double lineHeight,
    @Default(0) double paddingTop,
    @Default(0) double paddingBottom,
    @Default(0) double paddingLeft,
    @Default(0) double paddingRight,
    String? fontFamily,
  }) = _TextComponentStyle;

  factory TextComponentStyle.fromJson(Map<String, dynamic> json) =>
      _$TextComponentStyleFromJson(json);
}

@freezed
class ImageComponentStyle with _$ImageComponentStyle {
  const factory ImageComponentStyle({
    @Default('100%') String width,
    String? height,
    @Default('center') String alignment,
    @Default(0) double borderRadius,
    @Default(0) double paddingTop,
    @Default(0) double paddingBottom,
    @Default(0) double paddingLeft,
    @Default(0) double paddingRight,
  }) = _ImageComponentStyle;

  factory ImageComponentStyle.fromJson(Map<String, dynamic> json) =>
      _$ImageComponentStyleFromJson(json);
}

@freezed
class ButtonComponentStyle with _$ButtonComponentStyle {
  const factory ButtonComponentStyle({
    @Default('#007bff') String backgroundColor,
    @Default('#ffffff') String textColor,
    @Default(16) double fontSize,
    @Default(12) double paddingVertical,
    @Default(24) double paddingHorizontal,
    @Default(4) double borderRadius,
    @Default('center') String alignment,
    @Default(false) bool bold,
    @Default('auto') String width,
    @Default(20) double marginTop,
    @Default(20) double marginBottom,
  }) = _ButtonComponentStyle;

  factory ButtonComponentStyle.fromJson(Map<String, dynamic> json) =>
      _$ButtonComponentStyleFromJson(json);
}

@freezed
class DividerComponentStyle with _$DividerComponentStyle {
  const factory DividerComponentStyle({
    @Default('#cccccc') String color,
    @Default(1) double thickness,
    @Default(20) double marginTop,
    @Default(20) double marginBottom,
    @Default('solid') String style,
  }) = _DividerComponentStyle;

  factory DividerComponentStyle.fromJson(Map<String, dynamic> json) =>
      _$DividerComponentStyleFromJson(json);
}

@freezed
class SocialLink with _$SocialLink {
  const factory SocialLink({
    required String platform,
    required String url,
  }) = _SocialLink;

  factory SocialLink.fromJson(Map<String, dynamic> json) =>
      _$SocialLinkFromJson(json);
}

@freezed
class SocialComponentStyle with _$SocialComponentStyle {
  const factory SocialComponentStyle({
    @Default(32) double iconSize,
    @Default('center') String alignment,
    @Default(8) double spacing,
    @Default(20) double marginTop,
    @Default(20) double marginBottom,
  }) = _SocialComponentStyle;

  factory SocialComponentStyle.fromJson(Map<String, dynamic> json) =>
      _$SocialComponentStyleFromJson(json);
}

// New email-builder-js block styles
@freezed
class AvatarComponentStyle with _$AvatarComponentStyle {
  const factory AvatarComponentStyle({
    @Default(80) double size,
    @Default('center') String alignment,
    @Default(true) bool shape, // true = circle, false = square
    @Default(0) double paddingTop,
    @Default(0) double paddingBottom,
    @Default(0) double paddingLeft,
    @Default(0) double paddingRight,
    String? borderColor,
    @Default(0) double borderWidth,
  }) = _AvatarComponentStyle;

  factory AvatarComponentStyle.fromJson(Map<String, dynamic> json) =>
      _$AvatarComponentStyleFromJson(json);
}

@freezed
class HeadingComponentStyle with _$HeadingComponentStyle {
  const factory HeadingComponentStyle({
    @Default(32) double fontSize,
    @Default('#000000') String color,
    @Default('left') String alignment,
    @Default(true) bool bold,
    @Default(false) bool italic,
    @Default(false) bool underline,
    @Default(1.2) double lineHeight,
    @Default(0) double paddingTop,
    @Default(0) double paddingBottom,
    @Default(0) double paddingLeft,
    @Default(0) double paddingRight,
    String? fontFamily,
  }) = _HeadingComponentStyle;

  factory HeadingComponentStyle.fromJson(Map<String, dynamic> json) =>
      _$HeadingComponentStyleFromJson(json);
}

@freezed
class HtmlComponentStyle with _$HtmlComponentStyle {
  const factory HtmlComponentStyle({
    @Default(0) double paddingTop,
    @Default(0) double paddingBottom,
    @Default(0) double paddingLeft,
    @Default(0) double paddingRight,
  }) = _HtmlComponentStyle;

  factory HtmlComponentStyle.fromJson(Map<String, dynamic> json) =>
      _$HtmlComponentStyleFromJson(json);
}

@freezed
class ContainerComponentStyle with _$ContainerComponentStyle {
  const factory ContainerComponentStyle({
    @Default('#ffffff') String backgroundColor,
    @Default(0) double paddingTop,
    @Default(0) double paddingBottom,
    @Default(0) double paddingLeft,
    @Default(0) double paddingRight,
    @Default(0) double borderRadius,
    String? borderColor,
    @Default(0) double borderWidth,
  }) = _ContainerComponentStyle;

  factory ContainerComponentStyle.fromJson(Map<String, dynamic> json) =>
      _$ContainerComponentStyleFromJson(json);
}
