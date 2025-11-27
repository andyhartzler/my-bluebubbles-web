// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'email_component.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

EmailComponent _$EmailComponentFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'text':
      return TextComponent.fromJson(json);
    case 'image':
      return ImageComponent.fromJson(json);
    case 'button':
      return ButtonComponent.fromJson(json);
    case 'divider':
      return DividerComponent.fromJson(json);
    case 'spacer':
      return SpacerComponent.fromJson(json);
    case 'social':
      return SocialComponent.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'EmailComponent',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$EmailComponent {
  String get id => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String id, String content, TextComponentStyle style)
        text,
    required TResult Function(String id, String url, String? alt, String? link,
            ImageComponentStyle style)
        image,
    required TResult Function(
            String id, String text, String url, ButtonComponentStyle style)
        button,
    required TResult Function(String id, DividerComponentStyle style) divider,
    required TResult Function(String id, double height) spacer,
    required TResult Function(
            String id, List<SocialLink> links, SocialComponentStyle style)
        social,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String content, TextComponentStyle style)?
        text,
    TResult? Function(String id, String url, String? alt, String? link,
            ImageComponentStyle style)?
        image,
    TResult? Function(
            String id, String text, String url, ButtonComponentStyle style)?
        button,
    TResult? Function(String id, DividerComponentStyle style)? divider,
    TResult? Function(String id, double height)? spacer,
    TResult? Function(
            String id, List<SocialLink> links, SocialComponentStyle style)?
        social,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String content, TextComponentStyle style)? text,
    TResult Function(String id, String url, String? alt, String? link,
            ImageComponentStyle style)?
        image,
    TResult Function(
            String id, String text, String url, ButtonComponentStyle style)?
        button,
    TResult Function(String id, DividerComponentStyle style)? divider,
    TResult Function(String id, double height)? spacer,
    TResult Function(
            String id, List<SocialLink> links, SocialComponentStyle style)?
        social,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(TextComponent value) text,
    required TResult Function(ImageComponent value) image,
    required TResult Function(ButtonComponent value) button,
    required TResult Function(DividerComponent value) divider,
    required TResult Function(SpacerComponent value) spacer,
    required TResult Function(SocialComponent value) social,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(TextComponent value)? text,
    TResult? Function(ImageComponent value)? image,
    TResult? Function(ButtonComponent value)? button,
    TResult? Function(DividerComponent value)? divider,
    TResult? Function(SpacerComponent value)? spacer,
    TResult? Function(SocialComponent value)? social,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(TextComponent value)? text,
    TResult Function(ImageComponent value)? image,
    TResult Function(ButtonComponent value)? button,
    TResult Function(DividerComponent value)? divider,
    TResult Function(SpacerComponent value)? spacer,
    TResult Function(SocialComponent value)? social,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this EmailComponent to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EmailComponentCopyWith<EmailComponent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmailComponentCopyWith<$Res> {
  factory $EmailComponentCopyWith(
          EmailComponent value, $Res Function(EmailComponent) then) =
      _$EmailComponentCopyWithImpl<$Res, EmailComponent>;
  @useResult
  $Res call({String id});
}

/// @nodoc
class _$EmailComponentCopyWithImpl<$Res, $Val extends EmailComponent>
    implements $EmailComponentCopyWith<$Res> {
  _$EmailComponentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TextComponentImplCopyWith<$Res>
    implements $EmailComponentCopyWith<$Res> {
  factory _$$TextComponentImplCopyWith(
          _$TextComponentImpl value, $Res Function(_$TextComponentImpl) then) =
      __$$TextComponentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String content, TextComponentStyle style});

  $TextComponentStyleCopyWith<$Res> get style;
}

/// @nodoc
class __$$TextComponentImplCopyWithImpl<$Res>
    extends _$EmailComponentCopyWithImpl<$Res, _$TextComponentImpl>
    implements _$$TextComponentImplCopyWith<$Res> {
  __$$TextComponentImplCopyWithImpl(
      _$TextComponentImpl _value, $Res Function(_$TextComponentImpl) _then)
      : super(_value, _then);

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? content = null,
    Object? style = null,
  }) {
    return _then(_$TextComponentImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      style: null == style
          ? _value.style
          : style // ignore: cast_nullable_to_non_nullable
              as TextComponentStyle,
    ));
  }

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TextComponentStyleCopyWith<$Res> get style {
    return $TextComponentStyleCopyWith<$Res>(_value.style, (value) {
      return _then(_value.copyWith(style: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$TextComponentImpl implements TextComponent {
  const _$TextComponentImpl(
      {required this.id,
      this.content = '',
      this.style = const TextComponentStyle(),
      final String? $type})
      : $type = $type ?? 'text';

  factory _$TextComponentImpl.fromJson(Map<String, dynamic> json) =>
      _$$TextComponentImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final String content;
  @override
  @JsonKey()
  final TextComponentStyle style;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'EmailComponent.text(id: $id, content: $content, style: $style)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TextComponentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.style, style) || other.style == style));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, content, style);

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TextComponentImplCopyWith<_$TextComponentImpl> get copyWith =>
      __$$TextComponentImplCopyWithImpl<_$TextComponentImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String id, String content, TextComponentStyle style)
        text,
    required TResult Function(String id, String url, String? alt, String? link,
            ImageComponentStyle style)
        image,
    required TResult Function(
            String id, String text, String url, ButtonComponentStyle style)
        button,
    required TResult Function(String id, DividerComponentStyle style) divider,
    required TResult Function(String id, double height) spacer,
    required TResult Function(
            String id, List<SocialLink> links, SocialComponentStyle style)
        social,
  }) {
    return text(id, content, style);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String content, TextComponentStyle style)?
        text,
    TResult? Function(String id, String url, String? alt, String? link,
            ImageComponentStyle style)?
        image,
    TResult? Function(
            String id, String text, String url, ButtonComponentStyle style)?
        button,
    TResult? Function(String id, DividerComponentStyle style)? divider,
    TResult? Function(String id, double height)? spacer,
    TResult? Function(
            String id, List<SocialLink> links, SocialComponentStyle style)?
        social,
  }) {
    return text?.call(id, content, style);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String content, TextComponentStyle style)? text,
    TResult Function(String id, String url, String? alt, String? link,
            ImageComponentStyle style)?
        image,
    TResult Function(
            String id, String text, String url, ButtonComponentStyle style)?
        button,
    TResult Function(String id, DividerComponentStyle style)? divider,
    TResult Function(String id, double height)? spacer,
    TResult Function(
            String id, List<SocialLink> links, SocialComponentStyle style)?
        social,
    required TResult orElse(),
  }) {
    if (text != null) {
      return text(id, content, style);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(TextComponent value) text,
    required TResult Function(ImageComponent value) image,
    required TResult Function(ButtonComponent value) button,
    required TResult Function(DividerComponent value) divider,
    required TResult Function(SpacerComponent value) spacer,
    required TResult Function(SocialComponent value) social,
  }) {
    return text(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(TextComponent value)? text,
    TResult? Function(ImageComponent value)? image,
    TResult? Function(ButtonComponent value)? button,
    TResult? Function(DividerComponent value)? divider,
    TResult? Function(SpacerComponent value)? spacer,
    TResult? Function(SocialComponent value)? social,
  }) {
    return text?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(TextComponent value)? text,
    TResult Function(ImageComponent value)? image,
    TResult Function(ButtonComponent value)? button,
    TResult Function(DividerComponent value)? divider,
    TResult Function(SpacerComponent value)? spacer,
    TResult Function(SocialComponent value)? social,
    required TResult orElse(),
  }) {
    if (text != null) {
      return text(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$TextComponentImplToJson(
      this,
    );
  }
}

abstract class TextComponent implements EmailComponent {
  const factory TextComponent(
      {required final String id,
      final String content,
      final TextComponentStyle style}) = _$TextComponentImpl;

  factory TextComponent.fromJson(Map<String, dynamic> json) =
      _$TextComponentImpl.fromJson;

  @override
  String get id;
  String get content;
  TextComponentStyle get style;

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TextComponentImplCopyWith<_$TextComponentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ImageComponentImplCopyWith<$Res>
    implements $EmailComponentCopyWith<$Res> {
  factory _$$ImageComponentImplCopyWith(_$ImageComponentImpl value,
          $Res Function(_$ImageComponentImpl) then) =
      __$$ImageComponentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String url,
      String? alt,
      String? link,
      ImageComponentStyle style});

  $ImageComponentStyleCopyWith<$Res> get style;
}

/// @nodoc
class __$$ImageComponentImplCopyWithImpl<$Res>
    extends _$EmailComponentCopyWithImpl<$Res, _$ImageComponentImpl>
    implements _$$ImageComponentImplCopyWith<$Res> {
  __$$ImageComponentImplCopyWithImpl(
      _$ImageComponentImpl _value, $Res Function(_$ImageComponentImpl) _then)
      : super(_value, _then);

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? url = null,
    Object? alt = freezed,
    Object? link = freezed,
    Object? style = null,
  }) {
    return _then(_$ImageComponentImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      alt: freezed == alt
          ? _value.alt
          : alt // ignore: cast_nullable_to_non_nullable
              as String?,
      link: freezed == link
          ? _value.link
          : link // ignore: cast_nullable_to_non_nullable
              as String?,
      style: null == style
          ? _value.style
          : style // ignore: cast_nullable_to_non_nullable
              as ImageComponentStyle,
    ));
  }

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ImageComponentStyleCopyWith<$Res> get style {
    return $ImageComponentStyleCopyWith<$Res>(_value.style, (value) {
      return _then(_value.copyWith(style: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$ImageComponentImpl implements ImageComponent {
  const _$ImageComponentImpl(
      {required this.id,
      required this.url,
      this.alt,
      this.link,
      this.style = const ImageComponentStyle(),
      final String? $type})
      : $type = $type ?? 'image';

  factory _$ImageComponentImpl.fromJson(Map<String, dynamic> json) =>
      _$$ImageComponentImplFromJson(json);

  @override
  final String id;
  @override
  final String url;
  @override
  final String? alt;
  @override
  final String? link;
  @override
  @JsonKey()
  final ImageComponentStyle style;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'EmailComponent.image(id: $id, url: $url, alt: $alt, link: $link, style: $style)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ImageComponentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.alt, alt) || other.alt == alt) &&
            (identical(other.link, link) || other.link == link) &&
            (identical(other.style, style) || other.style == style));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, url, alt, link, style);

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ImageComponentImplCopyWith<_$ImageComponentImpl> get copyWith =>
      __$$ImageComponentImplCopyWithImpl<_$ImageComponentImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String id, String content, TextComponentStyle style)
        text,
    required TResult Function(String id, String url, String? alt, String? link,
            ImageComponentStyle style)
        image,
    required TResult Function(
            String id, String text, String url, ButtonComponentStyle style)
        button,
    required TResult Function(String id, DividerComponentStyle style) divider,
    required TResult Function(String id, double height) spacer,
    required TResult Function(
            String id, List<SocialLink> links, SocialComponentStyle style)
        social,
  }) {
    return image(id, url, alt, link, style);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String content, TextComponentStyle style)?
        text,
    TResult? Function(String id, String url, String? alt, String? link,
            ImageComponentStyle style)?
        image,
    TResult? Function(
            String id, String text, String url, ButtonComponentStyle style)?
        button,
    TResult? Function(String id, DividerComponentStyle style)? divider,
    TResult? Function(String id, double height)? spacer,
    TResult? Function(
            String id, List<SocialLink> links, SocialComponentStyle style)?
        social,
  }) {
    return image?.call(id, url, alt, link, style);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String content, TextComponentStyle style)? text,
    TResult Function(String id, String url, String? alt, String? link,
            ImageComponentStyle style)?
        image,
    TResult Function(
            String id, String text, String url, ButtonComponentStyle style)?
        button,
    TResult Function(String id, DividerComponentStyle style)? divider,
    TResult Function(String id, double height)? spacer,
    TResult Function(
            String id, List<SocialLink> links, SocialComponentStyle style)?
        social,
    required TResult orElse(),
  }) {
    if (image != null) {
      return image(id, url, alt, link, style);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(TextComponent value) text,
    required TResult Function(ImageComponent value) image,
    required TResult Function(ButtonComponent value) button,
    required TResult Function(DividerComponent value) divider,
    required TResult Function(SpacerComponent value) spacer,
    required TResult Function(SocialComponent value) social,
  }) {
    return image(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(TextComponent value)? text,
    TResult? Function(ImageComponent value)? image,
    TResult? Function(ButtonComponent value)? button,
    TResult? Function(DividerComponent value)? divider,
    TResult? Function(SpacerComponent value)? spacer,
    TResult? Function(SocialComponent value)? social,
  }) {
    return image?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(TextComponent value)? text,
    TResult Function(ImageComponent value)? image,
    TResult Function(ButtonComponent value)? button,
    TResult Function(DividerComponent value)? divider,
    TResult Function(SpacerComponent value)? spacer,
    TResult Function(SocialComponent value)? social,
    required TResult orElse(),
  }) {
    if (image != null) {
      return image(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$ImageComponentImplToJson(
      this,
    );
  }
}

abstract class ImageComponent implements EmailComponent {
  const factory ImageComponent(
      {required final String id,
      required final String url,
      final String? alt,
      final String? link,
      final ImageComponentStyle style}) = _$ImageComponentImpl;

  factory ImageComponent.fromJson(Map<String, dynamic> json) =
      _$ImageComponentImpl.fromJson;

  @override
  String get id;
  String get url;
  String? get alt;
  String? get link;
  ImageComponentStyle get style;

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ImageComponentImplCopyWith<_$ImageComponentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ButtonComponentImplCopyWith<$Res>
    implements $EmailComponentCopyWith<$Res> {
  factory _$$ButtonComponentImplCopyWith(_$ButtonComponentImpl value,
          $Res Function(_$ButtonComponentImpl) then) =
      __$$ButtonComponentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String text, String url, ButtonComponentStyle style});

  $ButtonComponentStyleCopyWith<$Res> get style;
}

/// @nodoc
class __$$ButtonComponentImplCopyWithImpl<$Res>
    extends _$EmailComponentCopyWithImpl<$Res, _$ButtonComponentImpl>
    implements _$$ButtonComponentImplCopyWith<$Res> {
  __$$ButtonComponentImplCopyWithImpl(
      _$ButtonComponentImpl _value, $Res Function(_$ButtonComponentImpl) _then)
      : super(_value, _then);

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? text = null,
    Object? url = null,
    Object? style = null,
  }) {
    return _then(_$ButtonComponentImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      style: null == style
          ? _value.style
          : style // ignore: cast_nullable_to_non_nullable
              as ButtonComponentStyle,
    ));
  }

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ButtonComponentStyleCopyWith<$Res> get style {
    return $ButtonComponentStyleCopyWith<$Res>(_value.style, (value) {
      return _then(_value.copyWith(style: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$ButtonComponentImpl implements ButtonComponent {
  const _$ButtonComponentImpl(
      {required this.id,
      required this.text,
      required this.url,
      this.style = const ButtonComponentStyle(),
      final String? $type})
      : $type = $type ?? 'button';

  factory _$ButtonComponentImpl.fromJson(Map<String, dynamic> json) =>
      _$$ButtonComponentImplFromJson(json);

  @override
  final String id;
  @override
  final String text;
  @override
  final String url;
  @override
  @JsonKey()
  final ButtonComponentStyle style;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'EmailComponent.button(id: $id, text: $text, url: $url, style: $style)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ButtonComponentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.style, style) || other.style == style));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, text, url, style);

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ButtonComponentImplCopyWith<_$ButtonComponentImpl> get copyWith =>
      __$$ButtonComponentImplCopyWithImpl<_$ButtonComponentImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String id, String content, TextComponentStyle style)
        text,
    required TResult Function(String id, String url, String? alt, String? link,
            ImageComponentStyle style)
        image,
    required TResult Function(
            String id, String text, String url, ButtonComponentStyle style)
        button,
    required TResult Function(String id, DividerComponentStyle style) divider,
    required TResult Function(String id, double height) spacer,
    required TResult Function(
            String id, List<SocialLink> links, SocialComponentStyle style)
        social,
  }) {
    return button(id, this.text, url, style);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String content, TextComponentStyle style)?
        text,
    TResult? Function(String id, String url, String? alt, String? link,
            ImageComponentStyle style)?
        image,
    TResult? Function(
            String id, String text, String url, ButtonComponentStyle style)?
        button,
    TResult? Function(String id, DividerComponentStyle style)? divider,
    TResult? Function(String id, double height)? spacer,
    TResult? Function(
            String id, List<SocialLink> links, SocialComponentStyle style)?
        social,
  }) {
    return button?.call(id, this.text, url, style);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String content, TextComponentStyle style)? text,
    TResult Function(String id, String url, String? alt, String? link,
            ImageComponentStyle style)?
        image,
    TResult Function(
            String id, String text, String url, ButtonComponentStyle style)?
        button,
    TResult Function(String id, DividerComponentStyle style)? divider,
    TResult Function(String id, double height)? spacer,
    TResult Function(
            String id, List<SocialLink> links, SocialComponentStyle style)?
        social,
    required TResult orElse(),
  }) {
    if (button != null) {
      return button(id, this.text, url, style);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(TextComponent value) text,
    required TResult Function(ImageComponent value) image,
    required TResult Function(ButtonComponent value) button,
    required TResult Function(DividerComponent value) divider,
    required TResult Function(SpacerComponent value) spacer,
    required TResult Function(SocialComponent value) social,
  }) {
    return button(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(TextComponent value)? text,
    TResult? Function(ImageComponent value)? image,
    TResult? Function(ButtonComponent value)? button,
    TResult? Function(DividerComponent value)? divider,
    TResult? Function(SpacerComponent value)? spacer,
    TResult? Function(SocialComponent value)? social,
  }) {
    return button?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(TextComponent value)? text,
    TResult Function(ImageComponent value)? image,
    TResult Function(ButtonComponent value)? button,
    TResult Function(DividerComponent value)? divider,
    TResult Function(SpacerComponent value)? spacer,
    TResult Function(SocialComponent value)? social,
    required TResult orElse(),
  }) {
    if (button != null) {
      return button(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$ButtonComponentImplToJson(
      this,
    );
  }
}

abstract class ButtonComponent implements EmailComponent {
  const factory ButtonComponent(
      {required final String id,
      required final String text,
      required final String url,
      final ButtonComponentStyle style}) = _$ButtonComponentImpl;

  factory ButtonComponent.fromJson(Map<String, dynamic> json) =
      _$ButtonComponentImpl.fromJson;

  @override
  String get id;
  String get text;
  String get url;
  ButtonComponentStyle get style;

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ButtonComponentImplCopyWith<_$ButtonComponentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DividerComponentImplCopyWith<$Res>
    implements $EmailComponentCopyWith<$Res> {
  factory _$$DividerComponentImplCopyWith(_$DividerComponentImpl value,
          $Res Function(_$DividerComponentImpl) then) =
      __$$DividerComponentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, DividerComponentStyle style});

  $DividerComponentStyleCopyWith<$Res> get style;
}

/// @nodoc
class __$$DividerComponentImplCopyWithImpl<$Res>
    extends _$EmailComponentCopyWithImpl<$Res, _$DividerComponentImpl>
    implements _$$DividerComponentImplCopyWith<$Res> {
  __$$DividerComponentImplCopyWithImpl(_$DividerComponentImpl _value,
      $Res Function(_$DividerComponentImpl) _then)
      : super(_value, _then);

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? style = null,
  }) {
    return _then(_$DividerComponentImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      style: null == style
          ? _value.style
          : style // ignore: cast_nullable_to_non_nullable
              as DividerComponentStyle,
    ));
  }

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DividerComponentStyleCopyWith<$Res> get style {
    return $DividerComponentStyleCopyWith<$Res>(_value.style, (value) {
      return _then(_value.copyWith(style: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$DividerComponentImpl implements DividerComponent {
  const _$DividerComponentImpl(
      {required this.id,
      this.style = const DividerComponentStyle(),
      final String? $type})
      : $type = $type ?? 'divider';

  factory _$DividerComponentImpl.fromJson(Map<String, dynamic> json) =>
      _$$DividerComponentImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final DividerComponentStyle style;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'EmailComponent.divider(id: $id, style: $style)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DividerComponentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.style, style) || other.style == style));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, style);

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DividerComponentImplCopyWith<_$DividerComponentImpl> get copyWith =>
      __$$DividerComponentImplCopyWithImpl<_$DividerComponentImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String id, String content, TextComponentStyle style)
        text,
    required TResult Function(String id, String url, String? alt, String? link,
            ImageComponentStyle style)
        image,
    required TResult Function(
            String id, String text, String url, ButtonComponentStyle style)
        button,
    required TResult Function(String id, DividerComponentStyle style) divider,
    required TResult Function(String id, double height) spacer,
    required TResult Function(
            String id, List<SocialLink> links, SocialComponentStyle style)
        social,
  }) {
    return divider(id, style);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String content, TextComponentStyle style)?
        text,
    TResult? Function(String id, String url, String? alt, String? link,
            ImageComponentStyle style)?
        image,
    TResult? Function(
            String id, String text, String url, ButtonComponentStyle style)?
        button,
    TResult? Function(String id, DividerComponentStyle style)? divider,
    TResult? Function(String id, double height)? spacer,
    TResult? Function(
            String id, List<SocialLink> links, SocialComponentStyle style)?
        social,
  }) {
    return divider?.call(id, style);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String content, TextComponentStyle style)? text,
    TResult Function(String id, String url, String? alt, String? link,
            ImageComponentStyle style)?
        image,
    TResult Function(
            String id, String text, String url, ButtonComponentStyle style)?
        button,
    TResult Function(String id, DividerComponentStyle style)? divider,
    TResult Function(String id, double height)? spacer,
    TResult Function(
            String id, List<SocialLink> links, SocialComponentStyle style)?
        social,
    required TResult orElse(),
  }) {
    if (divider != null) {
      return divider(id, style);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(TextComponent value) text,
    required TResult Function(ImageComponent value) image,
    required TResult Function(ButtonComponent value) button,
    required TResult Function(DividerComponent value) divider,
    required TResult Function(SpacerComponent value) spacer,
    required TResult Function(SocialComponent value) social,
  }) {
    return divider(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(TextComponent value)? text,
    TResult? Function(ImageComponent value)? image,
    TResult? Function(ButtonComponent value)? button,
    TResult? Function(DividerComponent value)? divider,
    TResult? Function(SpacerComponent value)? spacer,
    TResult? Function(SocialComponent value)? social,
  }) {
    return divider?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(TextComponent value)? text,
    TResult Function(ImageComponent value)? image,
    TResult Function(ButtonComponent value)? button,
    TResult Function(DividerComponent value)? divider,
    TResult Function(SpacerComponent value)? spacer,
    TResult Function(SocialComponent value)? social,
    required TResult orElse(),
  }) {
    if (divider != null) {
      return divider(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$DividerComponentImplToJson(
      this,
    );
  }
}

abstract class DividerComponent implements EmailComponent {
  const factory DividerComponent(
      {required final String id,
      final DividerComponentStyle style}) = _$DividerComponentImpl;

  factory DividerComponent.fromJson(Map<String, dynamic> json) =
      _$DividerComponentImpl.fromJson;

  @override
  String get id;
  DividerComponentStyle get style;

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DividerComponentImplCopyWith<_$DividerComponentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SpacerComponentImplCopyWith<$Res>
    implements $EmailComponentCopyWith<$Res> {
  factory _$$SpacerComponentImplCopyWith(_$SpacerComponentImpl value,
          $Res Function(_$SpacerComponentImpl) then) =
      __$$SpacerComponentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, double height});
}

/// @nodoc
class __$$SpacerComponentImplCopyWithImpl<$Res>
    extends _$EmailComponentCopyWithImpl<$Res, _$SpacerComponentImpl>
    implements _$$SpacerComponentImplCopyWith<$Res> {
  __$$SpacerComponentImplCopyWithImpl(
      _$SpacerComponentImpl _value, $Res Function(_$SpacerComponentImpl) _then)
      : super(_value, _then);

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? height = null,
  }) {
    return _then(_$SpacerComponentImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      height: null == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SpacerComponentImpl implements SpacerComponent {
  const _$SpacerComponentImpl(
      {required this.id, this.height = 40, final String? $type})
      : $type = $type ?? 'spacer';

  factory _$SpacerComponentImpl.fromJson(Map<String, dynamic> json) =>
      _$$SpacerComponentImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final double height;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'EmailComponent.spacer(id: $id, height: $height)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SpacerComponentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.height, height) || other.height == height));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, height);

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SpacerComponentImplCopyWith<_$SpacerComponentImpl> get copyWith =>
      __$$SpacerComponentImplCopyWithImpl<_$SpacerComponentImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String id, String content, TextComponentStyle style)
        text,
    required TResult Function(String id, String url, String? alt, String? link,
            ImageComponentStyle style)
        image,
    required TResult Function(
            String id, String text, String url, ButtonComponentStyle style)
        button,
    required TResult Function(String id, DividerComponentStyle style) divider,
    required TResult Function(String id, double height) spacer,
    required TResult Function(
            String id, List<SocialLink> links, SocialComponentStyle style)
        social,
  }) {
    return spacer(id, height);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String content, TextComponentStyle style)?
        text,
    TResult? Function(String id, String url, String? alt, String? link,
            ImageComponentStyle style)?
        image,
    TResult? Function(
            String id, String text, String url, ButtonComponentStyle style)?
        button,
    TResult? Function(String id, DividerComponentStyle style)? divider,
    TResult? Function(String id, double height)? spacer,
    TResult? Function(
            String id, List<SocialLink> links, SocialComponentStyle style)?
        social,
  }) {
    return spacer?.call(id, height);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String content, TextComponentStyle style)? text,
    TResult Function(String id, String url, String? alt, String? link,
            ImageComponentStyle style)?
        image,
    TResult Function(
            String id, String text, String url, ButtonComponentStyle style)?
        button,
    TResult Function(String id, DividerComponentStyle style)? divider,
    TResult Function(String id, double height)? spacer,
    TResult Function(
            String id, List<SocialLink> links, SocialComponentStyle style)?
        social,
    required TResult orElse(),
  }) {
    if (spacer != null) {
      return spacer(id, height);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(TextComponent value) text,
    required TResult Function(ImageComponent value) image,
    required TResult Function(ButtonComponent value) button,
    required TResult Function(DividerComponent value) divider,
    required TResult Function(SpacerComponent value) spacer,
    required TResult Function(SocialComponent value) social,
  }) {
    return spacer(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(TextComponent value)? text,
    TResult? Function(ImageComponent value)? image,
    TResult? Function(ButtonComponent value)? button,
    TResult? Function(DividerComponent value)? divider,
    TResult? Function(SpacerComponent value)? spacer,
    TResult? Function(SocialComponent value)? social,
  }) {
    return spacer?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(TextComponent value)? text,
    TResult Function(ImageComponent value)? image,
    TResult Function(ButtonComponent value)? button,
    TResult Function(DividerComponent value)? divider,
    TResult Function(SpacerComponent value)? spacer,
    TResult Function(SocialComponent value)? social,
    required TResult orElse(),
  }) {
    if (spacer != null) {
      return spacer(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SpacerComponentImplToJson(
      this,
    );
  }
}

abstract class SpacerComponent implements EmailComponent {
  const factory SpacerComponent(
      {required final String id, final double height}) = _$SpacerComponentImpl;

  factory SpacerComponent.fromJson(Map<String, dynamic> json) =
      _$SpacerComponentImpl.fromJson;

  @override
  String get id;
  double get height;

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SpacerComponentImplCopyWith<_$SpacerComponentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SocialComponentImplCopyWith<$Res>
    implements $EmailComponentCopyWith<$Res> {
  factory _$$SocialComponentImplCopyWith(_$SocialComponentImpl value,
          $Res Function(_$SocialComponentImpl) then) =
      __$$SocialComponentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, List<SocialLink> links, SocialComponentStyle style});

  $SocialComponentStyleCopyWith<$Res> get style;
}

/// @nodoc
class __$$SocialComponentImplCopyWithImpl<$Res>
    extends _$EmailComponentCopyWithImpl<$Res, _$SocialComponentImpl>
    implements _$$SocialComponentImplCopyWith<$Res> {
  __$$SocialComponentImplCopyWithImpl(
      _$SocialComponentImpl _value, $Res Function(_$SocialComponentImpl) _then)
      : super(_value, _then);

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? links = null,
    Object? style = null,
  }) {
    return _then(_$SocialComponentImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      links: null == links
          ? _value._links
          : links // ignore: cast_nullable_to_non_nullable
              as List<SocialLink>,
      style: null == style
          ? _value.style
          : style // ignore: cast_nullable_to_non_nullable
              as SocialComponentStyle,
    ));
  }

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SocialComponentStyleCopyWith<$Res> get style {
    return $SocialComponentStyleCopyWith<$Res>(_value.style, (value) {
      return _then(_value.copyWith(style: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$SocialComponentImpl implements SocialComponent {
  const _$SocialComponentImpl(
      {required this.id,
      final List<SocialLink> links = const [],
      this.style = const SocialComponentStyle(),
      final String? $type})
      : _links = links,
        $type = $type ?? 'social';

  factory _$SocialComponentImpl.fromJson(Map<String, dynamic> json) =>
      _$$SocialComponentImplFromJson(json);

  @override
  final String id;
  final List<SocialLink> _links;
  @override
  @JsonKey()
  List<SocialLink> get links {
    if (_links is EqualUnmodifiableListView) return _links;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_links);
  }

  @override
  @JsonKey()
  final SocialComponentStyle style;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'EmailComponent.social(id: $id, links: $links, style: $style)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SocialComponentImpl &&
            (identical(other.id, id) || other.id == id) &&
            const DeepCollectionEquality().equals(other._links, _links) &&
            (identical(other.style, style) || other.style == style));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, const DeepCollectionEquality().hash(_links), style);

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SocialComponentImplCopyWith<_$SocialComponentImpl> get copyWith =>
      __$$SocialComponentImplCopyWithImpl<_$SocialComponentImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String id, String content, TextComponentStyle style)
        text,
    required TResult Function(String id, String url, String? alt, String? link,
            ImageComponentStyle style)
        image,
    required TResult Function(
            String id, String text, String url, ButtonComponentStyle style)
        button,
    required TResult Function(String id, DividerComponentStyle style) divider,
    required TResult Function(String id, double height) spacer,
    required TResult Function(
            String id, List<SocialLink> links, SocialComponentStyle style)
        social,
  }) {
    return social(id, links, style);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String content, TextComponentStyle style)?
        text,
    TResult? Function(String id, String url, String? alt, String? link,
            ImageComponentStyle style)?
        image,
    TResult? Function(
            String id, String text, String url, ButtonComponentStyle style)?
        button,
    TResult? Function(String id, DividerComponentStyle style)? divider,
    TResult? Function(String id, double height)? spacer,
    TResult? Function(
            String id, List<SocialLink> links, SocialComponentStyle style)?
        social,
  }) {
    return social?.call(id, links, style);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String content, TextComponentStyle style)? text,
    TResult Function(String id, String url, String? alt, String? link,
            ImageComponentStyle style)?
        image,
    TResult Function(
            String id, String text, String url, ButtonComponentStyle style)?
        button,
    TResult Function(String id, DividerComponentStyle style)? divider,
    TResult Function(String id, double height)? spacer,
    TResult Function(
            String id, List<SocialLink> links, SocialComponentStyle style)?
        social,
    required TResult orElse(),
  }) {
    if (social != null) {
      return social(id, links, style);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(TextComponent value) text,
    required TResult Function(ImageComponent value) image,
    required TResult Function(ButtonComponent value) button,
    required TResult Function(DividerComponent value) divider,
    required TResult Function(SpacerComponent value) spacer,
    required TResult Function(SocialComponent value) social,
  }) {
    return social(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(TextComponent value)? text,
    TResult? Function(ImageComponent value)? image,
    TResult? Function(ButtonComponent value)? button,
    TResult? Function(DividerComponent value)? divider,
    TResult? Function(SpacerComponent value)? spacer,
    TResult? Function(SocialComponent value)? social,
  }) {
    return social?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(TextComponent value)? text,
    TResult Function(ImageComponent value)? image,
    TResult Function(ButtonComponent value)? button,
    TResult Function(DividerComponent value)? divider,
    TResult Function(SpacerComponent value)? spacer,
    TResult Function(SocialComponent value)? social,
    required TResult orElse(),
  }) {
    if (social != null) {
      return social(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SocialComponentImplToJson(
      this,
    );
  }
}

abstract class SocialComponent implements EmailComponent {
  const factory SocialComponent(
      {required final String id,
      final List<SocialLink> links,
      final SocialComponentStyle style}) = _$SocialComponentImpl;

  factory SocialComponent.fromJson(Map<String, dynamic> json) =
      _$SocialComponentImpl.fromJson;

  @override
  String get id;
  List<SocialLink> get links;
  SocialComponentStyle get style;

  /// Create a copy of EmailComponent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SocialComponentImplCopyWith<_$SocialComponentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TextComponentStyle _$TextComponentStyleFromJson(Map<String, dynamic> json) {
  return _TextComponentStyle.fromJson(json);
}

/// @nodoc
mixin _$TextComponentStyle {
  double get fontSize => throw _privateConstructorUsedError;
  String get color => throw _privateConstructorUsedError;
  String get alignment => throw _privateConstructorUsedError;
  bool get bold => throw _privateConstructorUsedError;
  bool get italic => throw _privateConstructorUsedError;
  bool get underline => throw _privateConstructorUsedError;
  double get lineHeight => throw _privateConstructorUsedError;
  double get paddingTop => throw _privateConstructorUsedError;
  double get paddingBottom => throw _privateConstructorUsedError;
  String? get fontFamily => throw _privateConstructorUsedError;

  /// Serializes this TextComponentStyle to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TextComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TextComponentStyleCopyWith<TextComponentStyle> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TextComponentStyleCopyWith<$Res> {
  factory $TextComponentStyleCopyWith(
          TextComponentStyle value, $Res Function(TextComponentStyle) then) =
      _$TextComponentStyleCopyWithImpl<$Res, TextComponentStyle>;
  @useResult
  $Res call(
      {double fontSize,
      String color,
      String alignment,
      bool bold,
      bool italic,
      bool underline,
      double lineHeight,
      double paddingTop,
      double paddingBottom,
      String? fontFamily});
}

/// @nodoc
class _$TextComponentStyleCopyWithImpl<$Res, $Val extends TextComponentStyle>
    implements $TextComponentStyleCopyWith<$Res> {
  _$TextComponentStyleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TextComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fontSize = null,
    Object? color = null,
    Object? alignment = null,
    Object? bold = null,
    Object? italic = null,
    Object? underline = null,
    Object? lineHeight = null,
    Object? paddingTop = null,
    Object? paddingBottom = null,
    Object? fontFamily = freezed,
  }) {
    return _then(_value.copyWith(
      fontSize: null == fontSize
          ? _value.fontSize
          : fontSize // ignore: cast_nullable_to_non_nullable
              as double,
      color: null == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as String,
      alignment: null == alignment
          ? _value.alignment
          : alignment // ignore: cast_nullable_to_non_nullable
              as String,
      bold: null == bold
          ? _value.bold
          : bold // ignore: cast_nullable_to_non_nullable
              as bool,
      italic: null == italic
          ? _value.italic
          : italic // ignore: cast_nullable_to_non_nullable
              as bool,
      underline: null == underline
          ? _value.underline
          : underline // ignore: cast_nullable_to_non_nullable
              as bool,
      lineHeight: null == lineHeight
          ? _value.lineHeight
          : lineHeight // ignore: cast_nullable_to_non_nullable
              as double,
      paddingTop: null == paddingTop
          ? _value.paddingTop
          : paddingTop // ignore: cast_nullable_to_non_nullable
              as double,
      paddingBottom: null == paddingBottom
          ? _value.paddingBottom
          : paddingBottom // ignore: cast_nullable_to_non_nullable
              as double,
      fontFamily: freezed == fontFamily
          ? _value.fontFamily
          : fontFamily // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TextComponentStyleImplCopyWith<$Res>
    implements $TextComponentStyleCopyWith<$Res> {
  factory _$$TextComponentStyleImplCopyWith(_$TextComponentStyleImpl value,
          $Res Function(_$TextComponentStyleImpl) then) =
      __$$TextComponentStyleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {double fontSize,
      String color,
      String alignment,
      bool bold,
      bool italic,
      bool underline,
      double lineHeight,
      double paddingTop,
      double paddingBottom,
      String? fontFamily});
}

/// @nodoc
class __$$TextComponentStyleImplCopyWithImpl<$Res>
    extends _$TextComponentStyleCopyWithImpl<$Res, _$TextComponentStyleImpl>
    implements _$$TextComponentStyleImplCopyWith<$Res> {
  __$$TextComponentStyleImplCopyWithImpl(_$TextComponentStyleImpl _value,
      $Res Function(_$TextComponentStyleImpl) _then)
      : super(_value, _then);

  /// Create a copy of TextComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fontSize = null,
    Object? color = null,
    Object? alignment = null,
    Object? bold = null,
    Object? italic = null,
    Object? underline = null,
    Object? lineHeight = null,
    Object? paddingTop = null,
    Object? paddingBottom = null,
    Object? fontFamily = freezed,
  }) {
    return _then(_$TextComponentStyleImpl(
      fontSize: null == fontSize
          ? _value.fontSize
          : fontSize // ignore: cast_nullable_to_non_nullable
              as double,
      color: null == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as String,
      alignment: null == alignment
          ? _value.alignment
          : alignment // ignore: cast_nullable_to_non_nullable
              as String,
      bold: null == bold
          ? _value.bold
          : bold // ignore: cast_nullable_to_non_nullable
              as bool,
      italic: null == italic
          ? _value.italic
          : italic // ignore: cast_nullable_to_non_nullable
              as bool,
      underline: null == underline
          ? _value.underline
          : underline // ignore: cast_nullable_to_non_nullable
              as bool,
      lineHeight: null == lineHeight
          ? _value.lineHeight
          : lineHeight // ignore: cast_nullable_to_non_nullable
              as double,
      paddingTop: null == paddingTop
          ? _value.paddingTop
          : paddingTop // ignore: cast_nullable_to_non_nullable
              as double,
      paddingBottom: null == paddingBottom
          ? _value.paddingBottom
          : paddingBottom // ignore: cast_nullable_to_non_nullable
              as double,
      fontFamily: freezed == fontFamily
          ? _value.fontFamily
          : fontFamily // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TextComponentStyleImpl implements _TextComponentStyle {
  const _$TextComponentStyleImpl(
      {this.fontSize = 16,
      this.color = '#000000',
      this.alignment = 'left',
      this.bold = false,
      this.italic = false,
      this.underline = false,
      this.lineHeight = 1.5,
      this.paddingTop = 0,
      this.paddingBottom = 0,
      this.fontFamily});

  factory _$TextComponentStyleImpl.fromJson(Map<String, dynamic> json) =>
      _$$TextComponentStyleImplFromJson(json);

  @override
  @JsonKey()
  final double fontSize;
  @override
  @JsonKey()
  final String color;
  @override
  @JsonKey()
  final String alignment;
  @override
  @JsonKey()
  final bool bold;
  @override
  @JsonKey()
  final bool italic;
  @override
  @JsonKey()
  final bool underline;
  @override
  @JsonKey()
  final double lineHeight;
  @override
  @JsonKey()
  final double paddingTop;
  @override
  @JsonKey()
  final double paddingBottom;
  @override
  final String? fontFamily;

  @override
  String toString() {
    return 'TextComponentStyle(fontSize: $fontSize, color: $color, alignment: $alignment, bold: $bold, italic: $italic, underline: $underline, lineHeight: $lineHeight, paddingTop: $paddingTop, paddingBottom: $paddingBottom, fontFamily: $fontFamily)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TextComponentStyleImpl &&
            (identical(other.fontSize, fontSize) ||
                other.fontSize == fontSize) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.alignment, alignment) ||
                other.alignment == alignment) &&
            (identical(other.bold, bold) || other.bold == bold) &&
            (identical(other.italic, italic) || other.italic == italic) &&
            (identical(other.underline, underline) ||
                other.underline == underline) &&
            (identical(other.lineHeight, lineHeight) ||
                other.lineHeight == lineHeight) &&
            (identical(other.paddingTop, paddingTop) ||
                other.paddingTop == paddingTop) &&
            (identical(other.paddingBottom, paddingBottom) ||
                other.paddingBottom == paddingBottom) &&
            (identical(other.fontFamily, fontFamily) ||
                other.fontFamily == fontFamily));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, fontSize, color, alignment, bold,
      italic, underline, lineHeight, paddingTop, paddingBottom, fontFamily);

  /// Create a copy of TextComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TextComponentStyleImplCopyWith<_$TextComponentStyleImpl> get copyWith =>
      __$$TextComponentStyleImplCopyWithImpl<_$TextComponentStyleImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TextComponentStyleImplToJson(
      this,
    );
  }
}

abstract class _TextComponentStyle implements TextComponentStyle {
  const factory _TextComponentStyle(
      {final double fontSize,
      final String color,
      final String alignment,
      final bool bold,
      final bool italic,
      final bool underline,
      final double lineHeight,
      final double paddingTop,
      final double paddingBottom,
      final String? fontFamily}) = _$TextComponentStyleImpl;

  factory _TextComponentStyle.fromJson(Map<String, dynamic> json) =
      _$TextComponentStyleImpl.fromJson;

  @override
  double get fontSize;
  @override
  String get color;
  @override
  String get alignment;
  @override
  bool get bold;
  @override
  bool get italic;
  @override
  bool get underline;
  @override
  double get lineHeight;
  @override
  double get paddingTop;
  @override
  double get paddingBottom;
  @override
  String? get fontFamily;

  /// Create a copy of TextComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TextComponentStyleImplCopyWith<_$TextComponentStyleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ImageComponentStyle _$ImageComponentStyleFromJson(Map<String, dynamic> json) {
  return _ImageComponentStyle.fromJson(json);
}

/// @nodoc
mixin _$ImageComponentStyle {
  String get width => throw _privateConstructorUsedError;
  String? get height => throw _privateConstructorUsedError;
  String get alignment => throw _privateConstructorUsedError;
  double get borderRadius => throw _privateConstructorUsedError;
  double get paddingTop => throw _privateConstructorUsedError;
  double get paddingBottom => throw _privateConstructorUsedError;

  /// Serializes this ImageComponentStyle to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ImageComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ImageComponentStyleCopyWith<ImageComponentStyle> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ImageComponentStyleCopyWith<$Res> {
  factory $ImageComponentStyleCopyWith(
          ImageComponentStyle value, $Res Function(ImageComponentStyle) then) =
      _$ImageComponentStyleCopyWithImpl<$Res, ImageComponentStyle>;
  @useResult
  $Res call(
      {String width,
      String? height,
      String alignment,
      double borderRadius,
      double paddingTop,
      double paddingBottom});
}

/// @nodoc
class _$ImageComponentStyleCopyWithImpl<$Res, $Val extends ImageComponentStyle>
    implements $ImageComponentStyleCopyWith<$Res> {
  _$ImageComponentStyleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ImageComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? width = null,
    Object? height = freezed,
    Object? alignment = null,
    Object? borderRadius = null,
    Object? paddingTop = null,
    Object? paddingBottom = null,
  }) {
    return _then(_value.copyWith(
      width: null == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as String,
      height: freezed == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as String?,
      alignment: null == alignment
          ? _value.alignment
          : alignment // ignore: cast_nullable_to_non_nullable
              as String,
      borderRadius: null == borderRadius
          ? _value.borderRadius
          : borderRadius // ignore: cast_nullable_to_non_nullable
              as double,
      paddingTop: null == paddingTop
          ? _value.paddingTop
          : paddingTop // ignore: cast_nullable_to_non_nullable
              as double,
      paddingBottom: null == paddingBottom
          ? _value.paddingBottom
          : paddingBottom // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ImageComponentStyleImplCopyWith<$Res>
    implements $ImageComponentStyleCopyWith<$Res> {
  factory _$$ImageComponentStyleImplCopyWith(_$ImageComponentStyleImpl value,
          $Res Function(_$ImageComponentStyleImpl) then) =
      __$$ImageComponentStyleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String width,
      String? height,
      String alignment,
      double borderRadius,
      double paddingTop,
      double paddingBottom});
}

/// @nodoc
class __$$ImageComponentStyleImplCopyWithImpl<$Res>
    extends _$ImageComponentStyleCopyWithImpl<$Res, _$ImageComponentStyleImpl>
    implements _$$ImageComponentStyleImplCopyWith<$Res> {
  __$$ImageComponentStyleImplCopyWithImpl(_$ImageComponentStyleImpl _value,
      $Res Function(_$ImageComponentStyleImpl) _then)
      : super(_value, _then);

  /// Create a copy of ImageComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? width = null,
    Object? height = freezed,
    Object? alignment = null,
    Object? borderRadius = null,
    Object? paddingTop = null,
    Object? paddingBottom = null,
  }) {
    return _then(_$ImageComponentStyleImpl(
      width: null == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as String,
      height: freezed == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as String?,
      alignment: null == alignment
          ? _value.alignment
          : alignment // ignore: cast_nullable_to_non_nullable
              as String,
      borderRadius: null == borderRadius
          ? _value.borderRadius
          : borderRadius // ignore: cast_nullable_to_non_nullable
              as double,
      paddingTop: null == paddingTop
          ? _value.paddingTop
          : paddingTop // ignore: cast_nullable_to_non_nullable
              as double,
      paddingBottom: null == paddingBottom
          ? _value.paddingBottom
          : paddingBottom // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ImageComponentStyleImpl implements _ImageComponentStyle {
  const _$ImageComponentStyleImpl(
      {this.width = '100%',
      this.height,
      this.alignment = 'center',
      this.borderRadius = 0,
      this.paddingTop = 0,
      this.paddingBottom = 0});

  factory _$ImageComponentStyleImpl.fromJson(Map<String, dynamic> json) =>
      _$$ImageComponentStyleImplFromJson(json);

  @override
  @JsonKey()
  final String width;
  @override
  final String? height;
  @override
  @JsonKey()
  final String alignment;
  @override
  @JsonKey()
  final double borderRadius;
  @override
  @JsonKey()
  final double paddingTop;
  @override
  @JsonKey()
  final double paddingBottom;

  @override
  String toString() {
    return 'ImageComponentStyle(width: $width, height: $height, alignment: $alignment, borderRadius: $borderRadius, paddingTop: $paddingTop, paddingBottom: $paddingBottom)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ImageComponentStyleImpl &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.height, height) || other.height == height) &&
            (identical(other.alignment, alignment) ||
                other.alignment == alignment) &&
            (identical(other.borderRadius, borderRadius) ||
                other.borderRadius == borderRadius) &&
            (identical(other.paddingTop, paddingTop) ||
                other.paddingTop == paddingTop) &&
            (identical(other.paddingBottom, paddingBottom) ||
                other.paddingBottom == paddingBottom));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, width, height, alignment,
      borderRadius, paddingTop, paddingBottom);

  /// Create a copy of ImageComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ImageComponentStyleImplCopyWith<_$ImageComponentStyleImpl> get copyWith =>
      __$$ImageComponentStyleImplCopyWithImpl<_$ImageComponentStyleImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ImageComponentStyleImplToJson(
      this,
    );
  }
}

abstract class _ImageComponentStyle implements ImageComponentStyle {
  const factory _ImageComponentStyle(
      {final String width,
      final String? height,
      final String alignment,
      final double borderRadius,
      final double paddingTop,
      final double paddingBottom}) = _$ImageComponentStyleImpl;

  factory _ImageComponentStyle.fromJson(Map<String, dynamic> json) =
      _$ImageComponentStyleImpl.fromJson;

  @override
  String get width;
  @override
  String? get height;
  @override
  String get alignment;
  @override
  double get borderRadius;
  @override
  double get paddingTop;
  @override
  double get paddingBottom;

  /// Create a copy of ImageComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ImageComponentStyleImplCopyWith<_$ImageComponentStyleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ButtonComponentStyle _$ButtonComponentStyleFromJson(Map<String, dynamic> json) {
  return _ButtonComponentStyle.fromJson(json);
}

/// @nodoc
mixin _$ButtonComponentStyle {
  String get backgroundColor => throw _privateConstructorUsedError;
  String get textColor => throw _privateConstructorUsedError;
  double get fontSize => throw _privateConstructorUsedError;
  double get paddingVertical => throw _privateConstructorUsedError;
  double get paddingHorizontal => throw _privateConstructorUsedError;
  double get borderRadius => throw _privateConstructorUsedError;
  String get alignment => throw _privateConstructorUsedError;
  bool get bold => throw _privateConstructorUsedError;
  String get width => throw _privateConstructorUsedError;
  double get marginTop => throw _privateConstructorUsedError;
  double get marginBottom => throw _privateConstructorUsedError;

  /// Serializes this ButtonComponentStyle to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ButtonComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ButtonComponentStyleCopyWith<ButtonComponentStyle> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ButtonComponentStyleCopyWith<$Res> {
  factory $ButtonComponentStyleCopyWith(ButtonComponentStyle value,
          $Res Function(ButtonComponentStyle) then) =
      _$ButtonComponentStyleCopyWithImpl<$Res, ButtonComponentStyle>;
  @useResult
  $Res call(
      {String backgroundColor,
      String textColor,
      double fontSize,
      double paddingVertical,
      double paddingHorizontal,
      double borderRadius,
      String alignment,
      bool bold,
      String width,
      double marginTop,
      double marginBottom});
}

/// @nodoc
class _$ButtonComponentStyleCopyWithImpl<$Res,
        $Val extends ButtonComponentStyle>
    implements $ButtonComponentStyleCopyWith<$Res> {
  _$ButtonComponentStyleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ButtonComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? backgroundColor = null,
    Object? textColor = null,
    Object? fontSize = null,
    Object? paddingVertical = null,
    Object? paddingHorizontal = null,
    Object? borderRadius = null,
    Object? alignment = null,
    Object? bold = null,
    Object? width = null,
    Object? marginTop = null,
    Object? marginBottom = null,
  }) {
    return _then(_value.copyWith(
      backgroundColor: null == backgroundColor
          ? _value.backgroundColor
          : backgroundColor // ignore: cast_nullable_to_non_nullable
              as String,
      textColor: null == textColor
          ? _value.textColor
          : textColor // ignore: cast_nullable_to_non_nullable
              as String,
      fontSize: null == fontSize
          ? _value.fontSize
          : fontSize // ignore: cast_nullable_to_non_nullable
              as double,
      paddingVertical: null == paddingVertical
          ? _value.paddingVertical
          : paddingVertical // ignore: cast_nullable_to_non_nullable
              as double,
      paddingHorizontal: null == paddingHorizontal
          ? _value.paddingHorizontal
          : paddingHorizontal // ignore: cast_nullable_to_non_nullable
              as double,
      borderRadius: null == borderRadius
          ? _value.borderRadius
          : borderRadius // ignore: cast_nullable_to_non_nullable
              as double,
      alignment: null == alignment
          ? _value.alignment
          : alignment // ignore: cast_nullable_to_non_nullable
              as String,
      bold: null == bold
          ? _value.bold
          : bold // ignore: cast_nullable_to_non_nullable
              as bool,
      width: null == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as String,
      marginTop: null == marginTop
          ? _value.marginTop
          : marginTop // ignore: cast_nullable_to_non_nullable
              as double,
      marginBottom: null == marginBottom
          ? _value.marginBottom
          : marginBottom // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ButtonComponentStyleImplCopyWith<$Res>
    implements $ButtonComponentStyleCopyWith<$Res> {
  factory _$$ButtonComponentStyleImplCopyWith(_$ButtonComponentStyleImpl value,
          $Res Function(_$ButtonComponentStyleImpl) then) =
      __$$ButtonComponentStyleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String backgroundColor,
      String textColor,
      double fontSize,
      double paddingVertical,
      double paddingHorizontal,
      double borderRadius,
      String alignment,
      bool bold,
      String width,
      double marginTop,
      double marginBottom});
}

/// @nodoc
class __$$ButtonComponentStyleImplCopyWithImpl<$Res>
    extends _$ButtonComponentStyleCopyWithImpl<$Res, _$ButtonComponentStyleImpl>
    implements _$$ButtonComponentStyleImplCopyWith<$Res> {
  __$$ButtonComponentStyleImplCopyWithImpl(_$ButtonComponentStyleImpl _value,
      $Res Function(_$ButtonComponentStyleImpl) _then)
      : super(_value, _then);

  /// Create a copy of ButtonComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? backgroundColor = null,
    Object? textColor = null,
    Object? fontSize = null,
    Object? paddingVertical = null,
    Object? paddingHorizontal = null,
    Object? borderRadius = null,
    Object? alignment = null,
    Object? bold = null,
    Object? width = null,
    Object? marginTop = null,
    Object? marginBottom = null,
  }) {
    return _then(_$ButtonComponentStyleImpl(
      backgroundColor: null == backgroundColor
          ? _value.backgroundColor
          : backgroundColor // ignore: cast_nullable_to_non_nullable
              as String,
      textColor: null == textColor
          ? _value.textColor
          : textColor // ignore: cast_nullable_to_non_nullable
              as String,
      fontSize: null == fontSize
          ? _value.fontSize
          : fontSize // ignore: cast_nullable_to_non_nullable
              as double,
      paddingVertical: null == paddingVertical
          ? _value.paddingVertical
          : paddingVertical // ignore: cast_nullable_to_non_nullable
              as double,
      paddingHorizontal: null == paddingHorizontal
          ? _value.paddingHorizontal
          : paddingHorizontal // ignore: cast_nullable_to_non_nullable
              as double,
      borderRadius: null == borderRadius
          ? _value.borderRadius
          : borderRadius // ignore: cast_nullable_to_non_nullable
              as double,
      alignment: null == alignment
          ? _value.alignment
          : alignment // ignore: cast_nullable_to_non_nullable
              as String,
      bold: null == bold
          ? _value.bold
          : bold // ignore: cast_nullable_to_non_nullable
              as bool,
      width: null == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as String,
      marginTop: null == marginTop
          ? _value.marginTop
          : marginTop // ignore: cast_nullable_to_non_nullable
              as double,
      marginBottom: null == marginBottom
          ? _value.marginBottom
          : marginBottom // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ButtonComponentStyleImpl implements _ButtonComponentStyle {
  const _$ButtonComponentStyleImpl(
      {this.backgroundColor = '#007bff',
      this.textColor = '#ffffff',
      this.fontSize = 16,
      this.paddingVertical = 12,
      this.paddingHorizontal = 24,
      this.borderRadius = 4,
      this.alignment = 'center',
      this.bold = false,
      this.width = 'auto',
      this.marginTop = 20,
      this.marginBottom = 20});

  factory _$ButtonComponentStyleImpl.fromJson(Map<String, dynamic> json) =>
      _$$ButtonComponentStyleImplFromJson(json);

  @override
  @JsonKey()
  final String backgroundColor;
  @override
  @JsonKey()
  final String textColor;
  @override
  @JsonKey()
  final double fontSize;
  @override
  @JsonKey()
  final double paddingVertical;
  @override
  @JsonKey()
  final double paddingHorizontal;
  @override
  @JsonKey()
  final double borderRadius;
  @override
  @JsonKey()
  final String alignment;
  @override
  @JsonKey()
  final bool bold;
  @override
  @JsonKey()
  final String width;
  @override
  @JsonKey()
  final double marginTop;
  @override
  @JsonKey()
  final double marginBottom;

  @override
  String toString() {
    return 'ButtonComponentStyle(backgroundColor: $backgroundColor, textColor: $textColor, fontSize: $fontSize, paddingVertical: $paddingVertical, paddingHorizontal: $paddingHorizontal, borderRadius: $borderRadius, alignment: $alignment, bold: $bold, width: $width, marginTop: $marginTop, marginBottom: $marginBottom)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ButtonComponentStyleImpl &&
            (identical(other.backgroundColor, backgroundColor) ||
                other.backgroundColor == backgroundColor) &&
            (identical(other.textColor, textColor) ||
                other.textColor == textColor) &&
            (identical(other.fontSize, fontSize) ||
                other.fontSize == fontSize) &&
            (identical(other.paddingVertical, paddingVertical) ||
                other.paddingVertical == paddingVertical) &&
            (identical(other.paddingHorizontal, paddingHorizontal) ||
                other.paddingHorizontal == paddingHorizontal) &&
            (identical(other.borderRadius, borderRadius) ||
                other.borderRadius == borderRadius) &&
            (identical(other.alignment, alignment) ||
                other.alignment == alignment) &&
            (identical(other.bold, bold) || other.bold == bold) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.marginTop, marginTop) ||
                other.marginTop == marginTop) &&
            (identical(other.marginBottom, marginBottom) ||
                other.marginBottom == marginBottom));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      backgroundColor,
      textColor,
      fontSize,
      paddingVertical,
      paddingHorizontal,
      borderRadius,
      alignment,
      bold,
      width,
      marginTop,
      marginBottom);

  /// Create a copy of ButtonComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ButtonComponentStyleImplCopyWith<_$ButtonComponentStyleImpl>
      get copyWith =>
          __$$ButtonComponentStyleImplCopyWithImpl<_$ButtonComponentStyleImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ButtonComponentStyleImplToJson(
      this,
    );
  }
}

abstract class _ButtonComponentStyle implements ButtonComponentStyle {
  const factory _ButtonComponentStyle(
      {final String backgroundColor,
      final String textColor,
      final double fontSize,
      final double paddingVertical,
      final double paddingHorizontal,
      final double borderRadius,
      final String alignment,
      final bool bold,
      final String width,
      final double marginTop,
      final double marginBottom}) = _$ButtonComponentStyleImpl;

  factory _ButtonComponentStyle.fromJson(Map<String, dynamic> json) =
      _$ButtonComponentStyleImpl.fromJson;

  @override
  String get backgroundColor;
  @override
  String get textColor;
  @override
  double get fontSize;
  @override
  double get paddingVertical;
  @override
  double get paddingHorizontal;
  @override
  double get borderRadius;
  @override
  String get alignment;
  @override
  bool get bold;
  @override
  String get width;
  @override
  double get marginTop;
  @override
  double get marginBottom;

  /// Create a copy of ButtonComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ButtonComponentStyleImplCopyWith<_$ButtonComponentStyleImpl>
      get copyWith => throw _privateConstructorUsedError;
}

DividerComponentStyle _$DividerComponentStyleFromJson(
    Map<String, dynamic> json) {
  return _DividerComponentStyle.fromJson(json);
}

/// @nodoc
mixin _$DividerComponentStyle {
  String get color => throw _privateConstructorUsedError;
  double get thickness => throw _privateConstructorUsedError;
  double get marginTop => throw _privateConstructorUsedError;
  double get marginBottom => throw _privateConstructorUsedError;
  String get style => throw _privateConstructorUsedError;

  /// Serializes this DividerComponentStyle to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DividerComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DividerComponentStyleCopyWith<DividerComponentStyle> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DividerComponentStyleCopyWith<$Res> {
  factory $DividerComponentStyleCopyWith(DividerComponentStyle value,
          $Res Function(DividerComponentStyle) then) =
      _$DividerComponentStyleCopyWithImpl<$Res, DividerComponentStyle>;
  @useResult
  $Res call(
      {String color,
      double thickness,
      double marginTop,
      double marginBottom,
      String style});
}

/// @nodoc
class _$DividerComponentStyleCopyWithImpl<$Res,
        $Val extends DividerComponentStyle>
    implements $DividerComponentStyleCopyWith<$Res> {
  _$DividerComponentStyleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DividerComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? color = null,
    Object? thickness = null,
    Object? marginTop = null,
    Object? marginBottom = null,
    Object? style = null,
  }) {
    return _then(_value.copyWith(
      color: null == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as String,
      thickness: null == thickness
          ? _value.thickness
          : thickness // ignore: cast_nullable_to_non_nullable
              as double,
      marginTop: null == marginTop
          ? _value.marginTop
          : marginTop // ignore: cast_nullable_to_non_nullable
              as double,
      marginBottom: null == marginBottom
          ? _value.marginBottom
          : marginBottom // ignore: cast_nullable_to_non_nullable
              as double,
      style: null == style
          ? _value.style
          : style // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DividerComponentStyleImplCopyWith<$Res>
    implements $DividerComponentStyleCopyWith<$Res> {
  factory _$$DividerComponentStyleImplCopyWith(
          _$DividerComponentStyleImpl value,
          $Res Function(_$DividerComponentStyleImpl) then) =
      __$$DividerComponentStyleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String color,
      double thickness,
      double marginTop,
      double marginBottom,
      String style});
}

/// @nodoc
class __$$DividerComponentStyleImplCopyWithImpl<$Res>
    extends _$DividerComponentStyleCopyWithImpl<$Res,
        _$DividerComponentStyleImpl>
    implements _$$DividerComponentStyleImplCopyWith<$Res> {
  __$$DividerComponentStyleImplCopyWithImpl(_$DividerComponentStyleImpl _value,
      $Res Function(_$DividerComponentStyleImpl) _then)
      : super(_value, _then);

  /// Create a copy of DividerComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? color = null,
    Object? thickness = null,
    Object? marginTop = null,
    Object? marginBottom = null,
    Object? style = null,
  }) {
    return _then(_$DividerComponentStyleImpl(
      color: null == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as String,
      thickness: null == thickness
          ? _value.thickness
          : thickness // ignore: cast_nullable_to_non_nullable
              as double,
      marginTop: null == marginTop
          ? _value.marginTop
          : marginTop // ignore: cast_nullable_to_non_nullable
              as double,
      marginBottom: null == marginBottom
          ? _value.marginBottom
          : marginBottom // ignore: cast_nullable_to_non_nullable
              as double,
      style: null == style
          ? _value.style
          : style // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DividerComponentStyleImpl implements _DividerComponentStyle {
  const _$DividerComponentStyleImpl(
      {this.color = '#cccccc',
      this.thickness = 1,
      this.marginTop = 20,
      this.marginBottom = 20,
      this.style = 'solid'});

  factory _$DividerComponentStyleImpl.fromJson(Map<String, dynamic> json) =>
      _$$DividerComponentStyleImplFromJson(json);

  @override
  @JsonKey()
  final String color;
  @override
  @JsonKey()
  final double thickness;
  @override
  @JsonKey()
  final double marginTop;
  @override
  @JsonKey()
  final double marginBottom;
  @override
  @JsonKey()
  final String style;

  @override
  String toString() {
    return 'DividerComponentStyle(color: $color, thickness: $thickness, marginTop: $marginTop, marginBottom: $marginBottom, style: $style)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DividerComponentStyleImpl &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.thickness, thickness) ||
                other.thickness == thickness) &&
            (identical(other.marginTop, marginTop) ||
                other.marginTop == marginTop) &&
            (identical(other.marginBottom, marginBottom) ||
                other.marginBottom == marginBottom) &&
            (identical(other.style, style) || other.style == style));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, color, thickness, marginTop, marginBottom, style);

  /// Create a copy of DividerComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DividerComponentStyleImplCopyWith<_$DividerComponentStyleImpl>
      get copyWith => __$$DividerComponentStyleImplCopyWithImpl<
          _$DividerComponentStyleImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DividerComponentStyleImplToJson(
      this,
    );
  }
}

abstract class _DividerComponentStyle implements DividerComponentStyle {
  const factory _DividerComponentStyle(
      {final String color,
      final double thickness,
      final double marginTop,
      final double marginBottom,
      final String style}) = _$DividerComponentStyleImpl;

  factory _DividerComponentStyle.fromJson(Map<String, dynamic> json) =
      _$DividerComponentStyleImpl.fromJson;

  @override
  String get color;
  @override
  double get thickness;
  @override
  double get marginTop;
  @override
  double get marginBottom;
  @override
  String get style;

  /// Create a copy of DividerComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DividerComponentStyleImplCopyWith<_$DividerComponentStyleImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SocialLink _$SocialLinkFromJson(Map<String, dynamic> json) {
  return _SocialLink.fromJson(json);
}

/// @nodoc
mixin _$SocialLink {
  String get platform => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;

  /// Serializes this SocialLink to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SocialLink
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SocialLinkCopyWith<SocialLink> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SocialLinkCopyWith<$Res> {
  factory $SocialLinkCopyWith(
          SocialLink value, $Res Function(SocialLink) then) =
      _$SocialLinkCopyWithImpl<$Res, SocialLink>;
  @useResult
  $Res call({String platform, String url});
}

/// @nodoc
class _$SocialLinkCopyWithImpl<$Res, $Val extends SocialLink>
    implements $SocialLinkCopyWith<$Res> {
  _$SocialLinkCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SocialLink
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? platform = null,
    Object? url = null,
  }) {
    return _then(_value.copyWith(
      platform: null == platform
          ? _value.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SocialLinkImplCopyWith<$Res>
    implements $SocialLinkCopyWith<$Res> {
  factory _$$SocialLinkImplCopyWith(
          _$SocialLinkImpl value, $Res Function(_$SocialLinkImpl) then) =
      __$$SocialLinkImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String platform, String url});
}

/// @nodoc
class __$$SocialLinkImplCopyWithImpl<$Res>
    extends _$SocialLinkCopyWithImpl<$Res, _$SocialLinkImpl>
    implements _$$SocialLinkImplCopyWith<$Res> {
  __$$SocialLinkImplCopyWithImpl(
      _$SocialLinkImpl _value, $Res Function(_$SocialLinkImpl) _then)
      : super(_value, _then);

  /// Create a copy of SocialLink
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? platform = null,
    Object? url = null,
  }) {
    return _then(_$SocialLinkImpl(
      platform: null == platform
          ? _value.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SocialLinkImpl implements _SocialLink {
  const _$SocialLinkImpl({required this.platform, required this.url});

  factory _$SocialLinkImpl.fromJson(Map<String, dynamic> json) =>
      _$$SocialLinkImplFromJson(json);

  @override
  final String platform;
  @override
  final String url;

  @override
  String toString() {
    return 'SocialLink(platform: $platform, url: $url)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SocialLinkImpl &&
            (identical(other.platform, platform) ||
                other.platform == platform) &&
            (identical(other.url, url) || other.url == url));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, platform, url);

  /// Create a copy of SocialLink
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SocialLinkImplCopyWith<_$SocialLinkImpl> get copyWith =>
      __$$SocialLinkImplCopyWithImpl<_$SocialLinkImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SocialLinkImplToJson(
      this,
    );
  }
}

abstract class _SocialLink implements SocialLink {
  const factory _SocialLink(
      {required final String platform,
      required final String url}) = _$SocialLinkImpl;

  factory _SocialLink.fromJson(Map<String, dynamic> json) =
      _$SocialLinkImpl.fromJson;

  @override
  String get platform;
  @override
  String get url;

  /// Create a copy of SocialLink
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SocialLinkImplCopyWith<_$SocialLinkImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SocialComponentStyle _$SocialComponentStyleFromJson(Map<String, dynamic> json) {
  return _SocialComponentStyle.fromJson(json);
}

/// @nodoc
mixin _$SocialComponentStyle {
  double get iconSize => throw _privateConstructorUsedError;
  String get alignment => throw _privateConstructorUsedError;
  double get spacing => throw _privateConstructorUsedError;
  double get marginTop => throw _privateConstructorUsedError;
  double get marginBottom => throw _privateConstructorUsedError;

  /// Serializes this SocialComponentStyle to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SocialComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SocialComponentStyleCopyWith<SocialComponentStyle> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SocialComponentStyleCopyWith<$Res> {
  factory $SocialComponentStyleCopyWith(SocialComponentStyle value,
          $Res Function(SocialComponentStyle) then) =
      _$SocialComponentStyleCopyWithImpl<$Res, SocialComponentStyle>;
  @useResult
  $Res call(
      {double iconSize,
      String alignment,
      double spacing,
      double marginTop,
      double marginBottom});
}

/// @nodoc
class _$SocialComponentStyleCopyWithImpl<$Res,
        $Val extends SocialComponentStyle>
    implements $SocialComponentStyleCopyWith<$Res> {
  _$SocialComponentStyleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SocialComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? iconSize = null,
    Object? alignment = null,
    Object? spacing = null,
    Object? marginTop = null,
    Object? marginBottom = null,
  }) {
    return _then(_value.copyWith(
      iconSize: null == iconSize
          ? _value.iconSize
          : iconSize // ignore: cast_nullable_to_non_nullable
              as double,
      alignment: null == alignment
          ? _value.alignment
          : alignment // ignore: cast_nullable_to_non_nullable
              as String,
      spacing: null == spacing
          ? _value.spacing
          : spacing // ignore: cast_nullable_to_non_nullable
              as double,
      marginTop: null == marginTop
          ? _value.marginTop
          : marginTop // ignore: cast_nullable_to_non_nullable
              as double,
      marginBottom: null == marginBottom
          ? _value.marginBottom
          : marginBottom // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SocialComponentStyleImplCopyWith<$Res>
    implements $SocialComponentStyleCopyWith<$Res> {
  factory _$$SocialComponentStyleImplCopyWith(_$SocialComponentStyleImpl value,
          $Res Function(_$SocialComponentStyleImpl) then) =
      __$$SocialComponentStyleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {double iconSize,
      String alignment,
      double spacing,
      double marginTop,
      double marginBottom});
}

/// @nodoc
class __$$SocialComponentStyleImplCopyWithImpl<$Res>
    extends _$SocialComponentStyleCopyWithImpl<$Res, _$SocialComponentStyleImpl>
    implements _$$SocialComponentStyleImplCopyWith<$Res> {
  __$$SocialComponentStyleImplCopyWithImpl(_$SocialComponentStyleImpl _value,
      $Res Function(_$SocialComponentStyleImpl) _then)
      : super(_value, _then);

  /// Create a copy of SocialComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? iconSize = null,
    Object? alignment = null,
    Object? spacing = null,
    Object? marginTop = null,
    Object? marginBottom = null,
  }) {
    return _then(_$SocialComponentStyleImpl(
      iconSize: null == iconSize
          ? _value.iconSize
          : iconSize // ignore: cast_nullable_to_non_nullable
              as double,
      alignment: null == alignment
          ? _value.alignment
          : alignment // ignore: cast_nullable_to_non_nullable
              as String,
      spacing: null == spacing
          ? _value.spacing
          : spacing // ignore: cast_nullable_to_non_nullable
              as double,
      marginTop: null == marginTop
          ? _value.marginTop
          : marginTop // ignore: cast_nullable_to_non_nullable
              as double,
      marginBottom: null == marginBottom
          ? _value.marginBottom
          : marginBottom // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SocialComponentStyleImpl implements _SocialComponentStyle {
  const _$SocialComponentStyleImpl(
      {this.iconSize = 32,
      this.alignment = 'center',
      this.spacing = 8,
      this.marginTop = 20,
      this.marginBottom = 20});

  factory _$SocialComponentStyleImpl.fromJson(Map<String, dynamic> json) =>
      _$$SocialComponentStyleImplFromJson(json);

  @override
  @JsonKey()
  final double iconSize;
  @override
  @JsonKey()
  final String alignment;
  @override
  @JsonKey()
  final double spacing;
  @override
  @JsonKey()
  final double marginTop;
  @override
  @JsonKey()
  final double marginBottom;

  @override
  String toString() {
    return 'SocialComponentStyle(iconSize: $iconSize, alignment: $alignment, spacing: $spacing, marginTop: $marginTop, marginBottom: $marginBottom)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SocialComponentStyleImpl &&
            (identical(other.iconSize, iconSize) ||
                other.iconSize == iconSize) &&
            (identical(other.alignment, alignment) ||
                other.alignment == alignment) &&
            (identical(other.spacing, spacing) || other.spacing == spacing) &&
            (identical(other.marginTop, marginTop) ||
                other.marginTop == marginTop) &&
            (identical(other.marginBottom, marginBottom) ||
                other.marginBottom == marginBottom));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, iconSize, alignment, spacing, marginTop, marginBottom);

  /// Create a copy of SocialComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SocialComponentStyleImplCopyWith<_$SocialComponentStyleImpl>
      get copyWith =>
          __$$SocialComponentStyleImplCopyWithImpl<_$SocialComponentStyleImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SocialComponentStyleImplToJson(
      this,
    );
  }
}

abstract class _SocialComponentStyle implements SocialComponentStyle {
  const factory _SocialComponentStyle(
      {final double iconSize,
      final String alignment,
      final double spacing,
      final double marginTop,
      final double marginBottom}) = _$SocialComponentStyleImpl;

  factory _SocialComponentStyle.fromJson(Map<String, dynamic> json) =
      _$SocialComponentStyleImpl.fromJson;

  @override
  double get iconSize;
  @override
  String get alignment;
  @override
  double get spacing;
  @override
  double get marginTop;
  @override
  double get marginBottom;

  /// Create a copy of SocialComponentStyle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SocialComponentStyleImplCopyWith<_$SocialComponentStyleImpl>
      get copyWith => throw _privateConstructorUsedError;
}
