// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'email_document.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

EmailDocument _$EmailDocumentFromJson(Map<String, dynamic> json) {
  return _EmailDocument.fromJson(json);
}

/// @nodoc
mixin _$EmailDocument {
  List<EmailSection> get sections => throw _privateConstructorUsedError;
  EmailSettings get settings => throw _privateConstructorUsedError;
  Map<String, dynamic> get theme => throw _privateConstructorUsedError;
  DateTime? get lastModified => throw _privateConstructorUsedError;

  /// Serializes this EmailDocument to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EmailDocument
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EmailDocumentCopyWith<EmailDocument> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmailDocumentCopyWith<$Res> {
  factory $EmailDocumentCopyWith(
          EmailDocument value, $Res Function(EmailDocument) then) =
      _$EmailDocumentCopyWithImpl<$Res, EmailDocument>;
  @useResult
  $Res call(
      {List<EmailSection> sections,
      EmailSettings settings,
      Map<String, dynamic> theme,
      DateTime? lastModified});

  $EmailSettingsCopyWith<$Res> get settings;
}

/// @nodoc
class _$EmailDocumentCopyWithImpl<$Res, $Val extends EmailDocument>
    implements $EmailDocumentCopyWith<$Res> {
  _$EmailDocumentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EmailDocument
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sections = null,
    Object? settings = null,
    Object? theme = null,
    Object? lastModified = freezed,
  }) {
    return _then(_value.copyWith(
      sections: null == sections
          ? _value.sections
          : sections // ignore: cast_nullable_to_non_nullable
              as List<EmailSection>,
      settings: null == settings
          ? _value.settings
          : settings // ignore: cast_nullable_to_non_nullable
              as EmailSettings,
      theme: null == theme
          ? _value.theme
          : theme // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      lastModified: freezed == lastModified
          ? _value.lastModified
          : lastModified // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }

  /// Create a copy of EmailDocument
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EmailSettingsCopyWith<$Res> get settings {
    return $EmailSettingsCopyWith<$Res>(_value.settings, (value) {
      return _then(_value.copyWith(settings: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$EmailDocumentImplCopyWith<$Res>
    implements $EmailDocumentCopyWith<$Res> {
  factory _$$EmailDocumentImplCopyWith(
          _$EmailDocumentImpl value, $Res Function(_$EmailDocumentImpl) then) =
      __$$EmailDocumentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<EmailSection> sections,
      EmailSettings settings,
      Map<String, dynamic> theme,
      DateTime? lastModified});

  @override
  $EmailSettingsCopyWith<$Res> get settings;
}

/// @nodoc
class __$$EmailDocumentImplCopyWithImpl<$Res>
    extends _$EmailDocumentCopyWithImpl<$Res, _$EmailDocumentImpl>
    implements _$$EmailDocumentImplCopyWith<$Res> {
  __$$EmailDocumentImplCopyWithImpl(
      _$EmailDocumentImpl _value, $Res Function(_$EmailDocumentImpl) _then)
      : super(_value, _then);

  /// Create a copy of EmailDocument
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sections = null,
    Object? settings = null,
    Object? theme = null,
    Object? lastModified = freezed,
  }) {
    return _then(_$EmailDocumentImpl(
      sections: null == sections
          ? _value._sections
          : sections // ignore: cast_nullable_to_non_nullable
              as List<EmailSection>,
      settings: null == settings
          ? _value.settings
          : settings // ignore: cast_nullable_to_non_nullable
              as EmailSettings,
      theme: null == theme
          ? _value._theme
          : theme // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      lastModified: freezed == lastModified
          ? _value.lastModified
          : lastModified // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EmailDocumentImpl implements _EmailDocument {
  const _$EmailDocumentImpl(
      {final List<EmailSection> sections = const [],
      this.settings = const EmailSettings(),
      final Map<String, dynamic> theme = const {},
      this.lastModified})
      : _sections = sections,
        _theme = theme;

  factory _$EmailDocumentImpl.fromJson(Map<String, dynamic> json) =>
      _$$EmailDocumentImplFromJson(json);

  final List<EmailSection> _sections;
  @override
  @JsonKey()
  List<EmailSection> get sections {
    if (_sections is EqualUnmodifiableListView) return _sections;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sections);
  }

  @override
  @JsonKey()
  final EmailSettings settings;
  final Map<String, dynamic> _theme;
  @override
  @JsonKey()
  Map<String, dynamic> get theme {
    if (_theme is EqualUnmodifiableMapView) return _theme;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_theme);
  }

  @override
  final DateTime? lastModified;

  @override
  String toString() {
    return 'EmailDocument(sections: $sections, settings: $settings, theme: $theme, lastModified: $lastModified)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmailDocumentImpl &&
            const DeepCollectionEquality().equals(other._sections, _sections) &&
            (identical(other.settings, settings) ||
                other.settings == settings) &&
            const DeepCollectionEquality().equals(other._theme, _theme) &&
            (identical(other.lastModified, lastModified) ||
                other.lastModified == lastModified));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_sections),
      settings,
      const DeepCollectionEquality().hash(_theme),
      lastModified);

  /// Create a copy of EmailDocument
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EmailDocumentImplCopyWith<_$EmailDocumentImpl> get copyWith =>
      __$$EmailDocumentImplCopyWithImpl<_$EmailDocumentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EmailDocumentImplToJson(
      this,
    );
  }
}

abstract class _EmailDocument implements EmailDocument {
  const factory _EmailDocument(
      {final List<EmailSection> sections,
      final EmailSettings settings,
      final Map<String, dynamic> theme,
      final DateTime? lastModified}) = _$EmailDocumentImpl;

  factory _EmailDocument.fromJson(Map<String, dynamic> json) =
      _$EmailDocumentImpl.fromJson;

  @override
  List<EmailSection> get sections;
  @override
  EmailSettings get settings;
  @override
  Map<String, dynamic> get theme;
  @override
  DateTime? get lastModified;

  /// Create a copy of EmailDocument
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EmailDocumentImplCopyWith<_$EmailDocumentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

EmailSettings _$EmailSettingsFromJson(Map<String, dynamic> json) {
  return _EmailSettings.fromJson(json);
}

/// @nodoc
mixin _$EmailSettings {
  int get maxWidth => throw _privateConstructorUsedError;
  String get backgroundColor => throw _privateConstructorUsedError;
  String get textColor => throw _privateConstructorUsedError;
  String get fontFamily => throw _privateConstructorUsedError;
  int get fontSize => throw _privateConstructorUsedError;
  int get lineHeight => throw _privateConstructorUsedError;
  int get padding => throw _privateConstructorUsedError;

  /// Serializes this EmailSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EmailSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EmailSettingsCopyWith<EmailSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmailSettingsCopyWith<$Res> {
  factory $EmailSettingsCopyWith(
          EmailSettings value, $Res Function(EmailSettings) then) =
      _$EmailSettingsCopyWithImpl<$Res, EmailSettings>;
  @useResult
  $Res call(
      {int maxWidth,
      String backgroundColor,
      String textColor,
      String fontFamily,
      int fontSize,
      int lineHeight,
      int padding});
}

/// @nodoc
class _$EmailSettingsCopyWithImpl<$Res, $Val extends EmailSettings>
    implements $EmailSettingsCopyWith<$Res> {
  _$EmailSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EmailSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? maxWidth = null,
    Object? backgroundColor = null,
    Object? textColor = null,
    Object? fontFamily = null,
    Object? fontSize = null,
    Object? lineHeight = null,
    Object? padding = null,
  }) {
    return _then(_value.copyWith(
      maxWidth: null == maxWidth
          ? _value.maxWidth
          : maxWidth // ignore: cast_nullable_to_non_nullable
              as int,
      backgroundColor: null == backgroundColor
          ? _value.backgroundColor
          : backgroundColor // ignore: cast_nullable_to_non_nullable
              as String,
      textColor: null == textColor
          ? _value.textColor
          : textColor // ignore: cast_nullable_to_non_nullable
              as String,
      fontFamily: null == fontFamily
          ? _value.fontFamily
          : fontFamily // ignore: cast_nullable_to_non_nullable
              as String,
      fontSize: null == fontSize
          ? _value.fontSize
          : fontSize // ignore: cast_nullable_to_non_nullable
              as int,
      lineHeight: null == lineHeight
          ? _value.lineHeight
          : lineHeight // ignore: cast_nullable_to_non_nullable
              as int,
      padding: null == padding
          ? _value.padding
          : padding // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EmailSettingsImplCopyWith<$Res>
    implements $EmailSettingsCopyWith<$Res> {
  factory _$$EmailSettingsImplCopyWith(
          _$EmailSettingsImpl value, $Res Function(_$EmailSettingsImpl) then) =
      __$$EmailSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int maxWidth,
      String backgroundColor,
      String textColor,
      String fontFamily,
      int fontSize,
      int lineHeight,
      int padding});
}

/// @nodoc
class __$$EmailSettingsImplCopyWithImpl<$Res>
    extends _$EmailSettingsCopyWithImpl<$Res, _$EmailSettingsImpl>
    implements _$$EmailSettingsImplCopyWith<$Res> {
  __$$EmailSettingsImplCopyWithImpl(
      _$EmailSettingsImpl _value, $Res Function(_$EmailSettingsImpl) _then)
      : super(_value, _then);

  /// Create a copy of EmailSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? maxWidth = null,
    Object? backgroundColor = null,
    Object? textColor = null,
    Object? fontFamily = null,
    Object? fontSize = null,
    Object? lineHeight = null,
    Object? padding = null,
  }) {
    return _then(_$EmailSettingsImpl(
      maxWidth: null == maxWidth
          ? _value.maxWidth
          : maxWidth // ignore: cast_nullable_to_non_nullable
              as int,
      backgroundColor: null == backgroundColor
          ? _value.backgroundColor
          : backgroundColor // ignore: cast_nullable_to_non_nullable
              as String,
      textColor: null == textColor
          ? _value.textColor
          : textColor // ignore: cast_nullable_to_non_nullable
              as String,
      fontFamily: null == fontFamily
          ? _value.fontFamily
          : fontFamily // ignore: cast_nullable_to_non_nullable
              as String,
      fontSize: null == fontSize
          ? _value.fontSize
          : fontSize // ignore: cast_nullable_to_non_nullable
              as int,
      lineHeight: null == lineHeight
          ? _value.lineHeight
          : lineHeight // ignore: cast_nullable_to_non_nullable
              as int,
      padding: null == padding
          ? _value.padding
          : padding // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EmailSettingsImpl implements _EmailSettings {
  const _$EmailSettingsImpl(
      {this.maxWidth = 600,
      this.backgroundColor = '#ffffff',
      this.textColor = '#000000',
      this.fontFamily = 'Arial, sans-serif',
      this.fontSize = 16,
      this.lineHeight = 24,
      this.padding = 20});

  factory _$EmailSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$EmailSettingsImplFromJson(json);

  @override
  @JsonKey()
  final int maxWidth;
  @override
  @JsonKey()
  final String backgroundColor;
  @override
  @JsonKey()
  final String textColor;
  @override
  @JsonKey()
  final String fontFamily;
  @override
  @JsonKey()
  final int fontSize;
  @override
  @JsonKey()
  final int lineHeight;
  @override
  @JsonKey()
  final int padding;

  @override
  String toString() {
    return 'EmailSettings(maxWidth: $maxWidth, backgroundColor: $backgroundColor, textColor: $textColor, fontFamily: $fontFamily, fontSize: $fontSize, lineHeight: $lineHeight, padding: $padding)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmailSettingsImpl &&
            (identical(other.maxWidth, maxWidth) ||
                other.maxWidth == maxWidth) &&
            (identical(other.backgroundColor, backgroundColor) ||
                other.backgroundColor == backgroundColor) &&
            (identical(other.textColor, textColor) ||
                other.textColor == textColor) &&
            (identical(other.fontFamily, fontFamily) ||
                other.fontFamily == fontFamily) &&
            (identical(other.fontSize, fontSize) ||
                other.fontSize == fontSize) &&
            (identical(other.lineHeight, lineHeight) ||
                other.lineHeight == lineHeight) &&
            (identical(other.padding, padding) || other.padding == padding));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, maxWidth, backgroundColor,
      textColor, fontFamily, fontSize, lineHeight, padding);

  /// Create a copy of EmailSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EmailSettingsImplCopyWith<_$EmailSettingsImpl> get copyWith =>
      __$$EmailSettingsImplCopyWithImpl<_$EmailSettingsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EmailSettingsImplToJson(
      this,
    );
  }
}

abstract class _EmailSettings implements EmailSettings {
  const factory _EmailSettings(
      {final int maxWidth,
      final String backgroundColor,
      final String textColor,
      final String fontFamily,
      final int fontSize,
      final int lineHeight,
      final int padding}) = _$EmailSettingsImpl;

  factory _EmailSettings.fromJson(Map<String, dynamic> json) =
      _$EmailSettingsImpl.fromJson;

  @override
  int get maxWidth;
  @override
  String get backgroundColor;
  @override
  String get textColor;
  @override
  String get fontFamily;
  @override
  int get fontSize;
  @override
  int get lineHeight;
  @override
  int get padding;

  /// Create a copy of EmailSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EmailSettingsImplCopyWith<_$EmailSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

EmailSection _$EmailSectionFromJson(Map<String, dynamic> json) {
  return _EmailSection.fromJson(json);
}

/// @nodoc
mixin _$EmailSection {
  String get id => throw _privateConstructorUsedError;
  List<EmailColumn> get columns => throw _privateConstructorUsedError;
  SectionStyle get style => throw _privateConstructorUsedError;

  /// Serializes this EmailSection to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EmailSection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EmailSectionCopyWith<EmailSection> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmailSectionCopyWith<$Res> {
  factory $EmailSectionCopyWith(
          EmailSection value, $Res Function(EmailSection) then) =
      _$EmailSectionCopyWithImpl<$Res, EmailSection>;
  @useResult
  $Res call({String id, List<EmailColumn> columns, SectionStyle style});

  $SectionStyleCopyWith<$Res> get style;
}

/// @nodoc
class _$EmailSectionCopyWithImpl<$Res, $Val extends EmailSection>
    implements $EmailSectionCopyWith<$Res> {
  _$EmailSectionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EmailSection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? columns = null,
    Object? style = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      columns: null == columns
          ? _value.columns
          : columns // ignore: cast_nullable_to_non_nullable
              as List<EmailColumn>,
      style: null == style
          ? _value.style
          : style // ignore: cast_nullable_to_non_nullable
              as SectionStyle,
    ) as $Val);
  }

  /// Create a copy of EmailSection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SectionStyleCopyWith<$Res> get style {
    return $SectionStyleCopyWith<$Res>(_value.style, (value) {
      return _then(_value.copyWith(style: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$EmailSectionImplCopyWith<$Res>
    implements $EmailSectionCopyWith<$Res> {
  factory _$$EmailSectionImplCopyWith(
          _$EmailSectionImpl value, $Res Function(_$EmailSectionImpl) then) =
      __$$EmailSectionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, List<EmailColumn> columns, SectionStyle style});

  @override
  $SectionStyleCopyWith<$Res> get style;
}

/// @nodoc
class __$$EmailSectionImplCopyWithImpl<$Res>
    extends _$EmailSectionCopyWithImpl<$Res, _$EmailSectionImpl>
    implements _$$EmailSectionImplCopyWith<$Res> {
  __$$EmailSectionImplCopyWithImpl(
      _$EmailSectionImpl _value, $Res Function(_$EmailSectionImpl) _then)
      : super(_value, _then);

  /// Create a copy of EmailSection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? columns = null,
    Object? style = null,
  }) {
    return _then(_$EmailSectionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      columns: null == columns
          ? _value._columns
          : columns // ignore: cast_nullable_to_non_nullable
              as List<EmailColumn>,
      style: null == style
          ? _value.style
          : style // ignore: cast_nullable_to_non_nullable
              as SectionStyle,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EmailSectionImpl implements _EmailSection {
  const _$EmailSectionImpl(
      {required this.id,
      final List<EmailColumn> columns = const [],
      this.style = const SectionStyle()})
      : _columns = columns;

  factory _$EmailSectionImpl.fromJson(Map<String, dynamic> json) =>
      _$$EmailSectionImplFromJson(json);

  @override
  final String id;
  final List<EmailColumn> _columns;
  @override
  @JsonKey()
  List<EmailColumn> get columns {
    if (_columns is EqualUnmodifiableListView) return _columns;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_columns);
  }

  @override
  @JsonKey()
  final SectionStyle style;

  @override
  String toString() {
    return 'EmailSection(id: $id, columns: $columns, style: $style)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmailSectionImpl &&
            (identical(other.id, id) || other.id == id) &&
            const DeepCollectionEquality().equals(other._columns, _columns) &&
            (identical(other.style, style) || other.style == style));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, const DeepCollectionEquality().hash(_columns), style);

  /// Create a copy of EmailSection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EmailSectionImplCopyWith<_$EmailSectionImpl> get copyWith =>
      __$$EmailSectionImplCopyWithImpl<_$EmailSectionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EmailSectionImplToJson(
      this,
    );
  }
}

abstract class _EmailSection implements EmailSection {
  const factory _EmailSection(
      {required final String id,
      final List<EmailColumn> columns,
      final SectionStyle style}) = _$EmailSectionImpl;

  factory _EmailSection.fromJson(Map<String, dynamic> json) =
      _$EmailSectionImpl.fromJson;

  @override
  String get id;
  @override
  List<EmailColumn> get columns;
  @override
  SectionStyle get style;

  /// Create a copy of EmailSection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EmailSectionImplCopyWith<_$EmailSectionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SectionStyle _$SectionStyleFromJson(Map<String, dynamic> json) {
  return _SectionStyle.fromJson(json);
}

/// @nodoc
mixin _$SectionStyle {
  String get backgroundColor => throw _privateConstructorUsedError;
  double get paddingTop => throw _privateConstructorUsedError;
  double get paddingBottom => throw _privateConstructorUsedError;
  double get paddingLeft => throw _privateConstructorUsedError;
  double get paddingRight => throw _privateConstructorUsedError;
  String? get backgroundImage => throw _privateConstructorUsedError;
  String get backgroundSize => throw _privateConstructorUsedError;

  /// Serializes this SectionStyle to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SectionStyle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SectionStyleCopyWith<SectionStyle> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SectionStyleCopyWith<$Res> {
  factory $SectionStyleCopyWith(
          SectionStyle value, $Res Function(SectionStyle) then) =
      _$SectionStyleCopyWithImpl<$Res, SectionStyle>;
  @useResult
  $Res call(
      {String backgroundColor,
      double paddingTop,
      double paddingBottom,
      double paddingLeft,
      double paddingRight,
      String? backgroundImage,
      String backgroundSize});
}

/// @nodoc
class _$SectionStyleCopyWithImpl<$Res, $Val extends SectionStyle>
    implements $SectionStyleCopyWith<$Res> {
  _$SectionStyleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SectionStyle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? backgroundColor = null,
    Object? paddingTop = null,
    Object? paddingBottom = null,
    Object? paddingLeft = null,
    Object? paddingRight = null,
    Object? backgroundImage = freezed,
    Object? backgroundSize = null,
  }) {
    return _then(_value.copyWith(
      backgroundColor: null == backgroundColor
          ? _value.backgroundColor
          : backgroundColor // ignore: cast_nullable_to_non_nullable
              as String,
      paddingTop: null == paddingTop
          ? _value.paddingTop
          : paddingTop // ignore: cast_nullable_to_non_nullable
              as double,
      paddingBottom: null == paddingBottom
          ? _value.paddingBottom
          : paddingBottom // ignore: cast_nullable_to_non_nullable
              as double,
      paddingLeft: null == paddingLeft
          ? _value.paddingLeft
          : paddingLeft // ignore: cast_nullable_to_non_nullable
              as double,
      paddingRight: null == paddingRight
          ? _value.paddingRight
          : paddingRight // ignore: cast_nullable_to_non_nullable
              as double,
      backgroundImage: freezed == backgroundImage
          ? _value.backgroundImage
          : backgroundImage // ignore: cast_nullable_to_non_nullable
              as String?,
      backgroundSize: null == backgroundSize
          ? _value.backgroundSize
          : backgroundSize // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SectionStyleImplCopyWith<$Res>
    implements $SectionStyleCopyWith<$Res> {
  factory _$$SectionStyleImplCopyWith(
          _$SectionStyleImpl value, $Res Function(_$SectionStyleImpl) then) =
      __$$SectionStyleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String backgroundColor,
      double paddingTop,
      double paddingBottom,
      double paddingLeft,
      double paddingRight,
      String? backgroundImage,
      String backgroundSize});
}

/// @nodoc
class __$$SectionStyleImplCopyWithImpl<$Res>
    extends _$SectionStyleCopyWithImpl<$Res, _$SectionStyleImpl>
    implements _$$SectionStyleImplCopyWith<$Res> {
  __$$SectionStyleImplCopyWithImpl(
      _$SectionStyleImpl _value, $Res Function(_$SectionStyleImpl) _then)
      : super(_value, _then);

  /// Create a copy of SectionStyle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? backgroundColor = null,
    Object? paddingTop = null,
    Object? paddingBottom = null,
    Object? paddingLeft = null,
    Object? paddingRight = null,
    Object? backgroundImage = freezed,
    Object? backgroundSize = null,
  }) {
    return _then(_$SectionStyleImpl(
      backgroundColor: null == backgroundColor
          ? _value.backgroundColor
          : backgroundColor // ignore: cast_nullable_to_non_nullable
              as String,
      paddingTop: null == paddingTop
          ? _value.paddingTop
          : paddingTop // ignore: cast_nullable_to_non_nullable
              as double,
      paddingBottom: null == paddingBottom
          ? _value.paddingBottom
          : paddingBottom // ignore: cast_nullable_to_non_nullable
              as double,
      paddingLeft: null == paddingLeft
          ? _value.paddingLeft
          : paddingLeft // ignore: cast_nullable_to_non_nullable
              as double,
      paddingRight: null == paddingRight
          ? _value.paddingRight
          : paddingRight // ignore: cast_nullable_to_non_nullable
              as double,
      backgroundImage: freezed == backgroundImage
          ? _value.backgroundImage
          : backgroundImage // ignore: cast_nullable_to_non_nullable
              as String?,
      backgroundSize: null == backgroundSize
          ? _value.backgroundSize
          : backgroundSize // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SectionStyleImpl implements _SectionStyle {
  const _$SectionStyleImpl(
      {this.backgroundColor = '#ffffff',
      this.paddingTop = 20,
      this.paddingBottom = 20,
      this.paddingLeft = 20,
      this.paddingRight = 20,
      this.backgroundImage,
      this.backgroundSize = 'cover'});

  factory _$SectionStyleImpl.fromJson(Map<String, dynamic> json) =>
      _$$SectionStyleImplFromJson(json);

  @override
  @JsonKey()
  final String backgroundColor;
  @override
  @JsonKey()
  final double paddingTop;
  @override
  @JsonKey()
  final double paddingBottom;
  @override
  @JsonKey()
  final double paddingLeft;
  @override
  @JsonKey()
  final double paddingRight;
  @override
  final String? backgroundImage;
  @override
  @JsonKey()
  final String backgroundSize;

  @override
  String toString() {
    return 'SectionStyle(backgroundColor: $backgroundColor, paddingTop: $paddingTop, paddingBottom: $paddingBottom, paddingLeft: $paddingLeft, paddingRight: $paddingRight, backgroundImage: $backgroundImage, backgroundSize: $backgroundSize)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SectionStyleImpl &&
            (identical(other.backgroundColor, backgroundColor) ||
                other.backgroundColor == backgroundColor) &&
            (identical(other.paddingTop, paddingTop) ||
                other.paddingTop == paddingTop) &&
            (identical(other.paddingBottom, paddingBottom) ||
                other.paddingBottom == paddingBottom) &&
            (identical(other.paddingLeft, paddingLeft) ||
                other.paddingLeft == paddingLeft) &&
            (identical(other.paddingRight, paddingRight) ||
                other.paddingRight == paddingRight) &&
            (identical(other.backgroundImage, backgroundImage) ||
                other.backgroundImage == backgroundImage) &&
            (identical(other.backgroundSize, backgroundSize) ||
                other.backgroundSize == backgroundSize));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      backgroundColor,
      paddingTop,
      paddingBottom,
      paddingLeft,
      paddingRight,
      backgroundImage,
      backgroundSize);

  /// Create a copy of SectionStyle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SectionStyleImplCopyWith<_$SectionStyleImpl> get copyWith =>
      __$$SectionStyleImplCopyWithImpl<_$SectionStyleImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SectionStyleImplToJson(
      this,
    );
  }
}

abstract class _SectionStyle implements SectionStyle {
  const factory _SectionStyle(
      {final String backgroundColor,
      final double paddingTop,
      final double paddingBottom,
      final double paddingLeft,
      final double paddingRight,
      final String? backgroundImage,
      final String backgroundSize}) = _$SectionStyleImpl;

  factory _SectionStyle.fromJson(Map<String, dynamic> json) =
      _$SectionStyleImpl.fromJson;

  @override
  String get backgroundColor;
  @override
  double get paddingTop;
  @override
  double get paddingBottom;
  @override
  double get paddingLeft;
  @override
  double get paddingRight;
  @override
  String? get backgroundImage;
  @override
  String get backgroundSize;

  /// Create a copy of SectionStyle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SectionStyleImplCopyWith<_$SectionStyleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

EmailColumn _$EmailColumnFromJson(Map<String, dynamic> json) {
  return _EmailColumn.fromJson(json);
}

/// @nodoc
mixin _$EmailColumn {
  String get id => throw _privateConstructorUsedError;
  int get flex => throw _privateConstructorUsedError;
  List<EmailComponent> get components => throw _privateConstructorUsedError;
  ColumnStyle get style => throw _privateConstructorUsedError;

  /// Serializes this EmailColumn to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EmailColumn
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EmailColumnCopyWith<EmailColumn> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmailColumnCopyWith<$Res> {
  factory $EmailColumnCopyWith(
          EmailColumn value, $Res Function(EmailColumn) then) =
      _$EmailColumnCopyWithImpl<$Res, EmailColumn>;
  @useResult
  $Res call(
      {String id,
      int flex,
      List<EmailComponent> components,
      ColumnStyle style});

  $ColumnStyleCopyWith<$Res> get style;
}

/// @nodoc
class _$EmailColumnCopyWithImpl<$Res, $Val extends EmailColumn>
    implements $EmailColumnCopyWith<$Res> {
  _$EmailColumnCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EmailColumn
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? flex = null,
    Object? components = null,
    Object? style = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      flex: null == flex
          ? _value.flex
          : flex // ignore: cast_nullable_to_non_nullable
              as int,
      components: null == components
          ? _value.components
          : components // ignore: cast_nullable_to_non_nullable
              as List<EmailComponent>,
      style: null == style
          ? _value.style
          : style // ignore: cast_nullable_to_non_nullable
              as ColumnStyle,
    ) as $Val);
  }

  /// Create a copy of EmailColumn
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ColumnStyleCopyWith<$Res> get style {
    return $ColumnStyleCopyWith<$Res>(_value.style, (value) {
      return _then(_value.copyWith(style: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$EmailColumnImplCopyWith<$Res>
    implements $EmailColumnCopyWith<$Res> {
  factory _$$EmailColumnImplCopyWith(
          _$EmailColumnImpl value, $Res Function(_$EmailColumnImpl) then) =
      __$$EmailColumnImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      int flex,
      List<EmailComponent> components,
      ColumnStyle style});

  @override
  $ColumnStyleCopyWith<$Res> get style;
}

/// @nodoc
class __$$EmailColumnImplCopyWithImpl<$Res>
    extends _$EmailColumnCopyWithImpl<$Res, _$EmailColumnImpl>
    implements _$$EmailColumnImplCopyWith<$Res> {
  __$$EmailColumnImplCopyWithImpl(
      _$EmailColumnImpl _value, $Res Function(_$EmailColumnImpl) _then)
      : super(_value, _then);

  /// Create a copy of EmailColumn
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? flex = null,
    Object? components = null,
    Object? style = null,
  }) {
    return _then(_$EmailColumnImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      flex: null == flex
          ? _value.flex
          : flex // ignore: cast_nullable_to_non_nullable
              as int,
      components: null == components
          ? _value._components
          : components // ignore: cast_nullable_to_non_nullable
              as List<EmailComponent>,
      style: null == style
          ? _value.style
          : style // ignore: cast_nullable_to_non_nullable
              as ColumnStyle,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EmailColumnImpl implements _EmailColumn {
  const _$EmailColumnImpl(
      {required this.id,
      this.flex = 1,
      final List<EmailComponent> components = const [],
      this.style = const ColumnStyle()})
      : _components = components;

  factory _$EmailColumnImpl.fromJson(Map<String, dynamic> json) =>
      _$$EmailColumnImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final int flex;
  final List<EmailComponent> _components;
  @override
  @JsonKey()
  List<EmailComponent> get components {
    if (_components is EqualUnmodifiableListView) return _components;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_components);
  }

  @override
  @JsonKey()
  final ColumnStyle style;

  @override
  String toString() {
    return 'EmailColumn(id: $id, flex: $flex, components: $components, style: $style)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmailColumnImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.flex, flex) || other.flex == flex) &&
            const DeepCollectionEquality()
                .equals(other._components, _components) &&
            (identical(other.style, style) || other.style == style));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, flex,
      const DeepCollectionEquality().hash(_components), style);

  /// Create a copy of EmailColumn
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EmailColumnImplCopyWith<_$EmailColumnImpl> get copyWith =>
      __$$EmailColumnImplCopyWithImpl<_$EmailColumnImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EmailColumnImplToJson(
      this,
    );
  }
}

abstract class _EmailColumn implements EmailColumn {
  const factory _EmailColumn(
      {required final String id,
      final int flex,
      final List<EmailComponent> components,
      final ColumnStyle style}) = _$EmailColumnImpl;

  factory _EmailColumn.fromJson(Map<String, dynamic> json) =
      _$EmailColumnImpl.fromJson;

  @override
  String get id;
  @override
  int get flex;
  @override
  List<EmailComponent> get components;
  @override
  ColumnStyle get style;

  /// Create a copy of EmailColumn
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EmailColumnImplCopyWith<_$EmailColumnImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ColumnStyle _$ColumnStyleFromJson(Map<String, dynamic> json) {
  return _ColumnStyle.fromJson(json);
}

/// @nodoc
mixin _$ColumnStyle {
  String get backgroundColor => throw _privateConstructorUsedError;
  double get padding => throw _privateConstructorUsedError;
  double get borderRadius => throw _privateConstructorUsedError;
  String? get borderColor => throw _privateConstructorUsedError;
  double get borderWidth => throw _privateConstructorUsedError;

  /// Serializes this ColumnStyle to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ColumnStyle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ColumnStyleCopyWith<ColumnStyle> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ColumnStyleCopyWith<$Res> {
  factory $ColumnStyleCopyWith(
          ColumnStyle value, $Res Function(ColumnStyle) then) =
      _$ColumnStyleCopyWithImpl<$Res, ColumnStyle>;
  @useResult
  $Res call(
      {String backgroundColor,
      double padding,
      double borderRadius,
      String? borderColor,
      double borderWidth});
}

/// @nodoc
class _$ColumnStyleCopyWithImpl<$Res, $Val extends ColumnStyle>
    implements $ColumnStyleCopyWith<$Res> {
  _$ColumnStyleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ColumnStyle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? backgroundColor = null,
    Object? padding = null,
    Object? borderRadius = null,
    Object? borderColor = freezed,
    Object? borderWidth = null,
  }) {
    return _then(_value.copyWith(
      backgroundColor: null == backgroundColor
          ? _value.backgroundColor
          : backgroundColor // ignore: cast_nullable_to_non_nullable
              as String,
      padding: null == padding
          ? _value.padding
          : padding // ignore: cast_nullable_to_non_nullable
              as double,
      borderRadius: null == borderRadius
          ? _value.borderRadius
          : borderRadius // ignore: cast_nullable_to_non_nullable
              as double,
      borderColor: freezed == borderColor
          ? _value.borderColor
          : borderColor // ignore: cast_nullable_to_non_nullable
              as String?,
      borderWidth: null == borderWidth
          ? _value.borderWidth
          : borderWidth // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ColumnStyleImplCopyWith<$Res>
    implements $ColumnStyleCopyWith<$Res> {
  factory _$$ColumnStyleImplCopyWith(
          _$ColumnStyleImpl value, $Res Function(_$ColumnStyleImpl) then) =
      __$$ColumnStyleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String backgroundColor,
      double padding,
      double borderRadius,
      String? borderColor,
      double borderWidth});
}

/// @nodoc
class __$$ColumnStyleImplCopyWithImpl<$Res>
    extends _$ColumnStyleCopyWithImpl<$Res, _$ColumnStyleImpl>
    implements _$$ColumnStyleImplCopyWith<$Res> {
  __$$ColumnStyleImplCopyWithImpl(
      _$ColumnStyleImpl _value, $Res Function(_$ColumnStyleImpl) _then)
      : super(_value, _then);

  /// Create a copy of ColumnStyle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? backgroundColor = null,
    Object? padding = null,
    Object? borderRadius = null,
    Object? borderColor = freezed,
    Object? borderWidth = null,
  }) {
    return _then(_$ColumnStyleImpl(
      backgroundColor: null == backgroundColor
          ? _value.backgroundColor
          : backgroundColor // ignore: cast_nullable_to_non_nullable
              as String,
      padding: null == padding
          ? _value.padding
          : padding // ignore: cast_nullable_to_non_nullable
              as double,
      borderRadius: null == borderRadius
          ? _value.borderRadius
          : borderRadius // ignore: cast_nullable_to_non_nullable
              as double,
      borderColor: freezed == borderColor
          ? _value.borderColor
          : borderColor // ignore: cast_nullable_to_non_nullable
              as String?,
      borderWidth: null == borderWidth
          ? _value.borderWidth
          : borderWidth // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ColumnStyleImpl implements _ColumnStyle {
  const _$ColumnStyleImpl(
      {this.backgroundColor = '#ffffff',
      this.padding = 10,
      this.borderRadius = 0,
      this.borderColor,
      this.borderWidth = 0});

  factory _$ColumnStyleImpl.fromJson(Map<String, dynamic> json) =>
      _$$ColumnStyleImplFromJson(json);

  @override
  @JsonKey()
  final String backgroundColor;
  @override
  @JsonKey()
  final double padding;
  @override
  @JsonKey()
  final double borderRadius;
  @override
  final String? borderColor;
  @override
  @JsonKey()
  final double borderWidth;

  @override
  String toString() {
    return 'ColumnStyle(backgroundColor: $backgroundColor, padding: $padding, borderRadius: $borderRadius, borderColor: $borderColor, borderWidth: $borderWidth)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ColumnStyleImpl &&
            (identical(other.backgroundColor, backgroundColor) ||
                other.backgroundColor == backgroundColor) &&
            (identical(other.padding, padding) || other.padding == padding) &&
            (identical(other.borderRadius, borderRadius) ||
                other.borderRadius == borderRadius) &&
            (identical(other.borderColor, borderColor) ||
                other.borderColor == borderColor) &&
            (identical(other.borderWidth, borderWidth) ||
                other.borderWidth == borderWidth));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, backgroundColor, padding,
      borderRadius, borderColor, borderWidth);

  /// Create a copy of ColumnStyle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ColumnStyleImplCopyWith<_$ColumnStyleImpl> get copyWith =>
      __$$ColumnStyleImplCopyWithImpl<_$ColumnStyleImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ColumnStyleImplToJson(
      this,
    );
  }
}

abstract class _ColumnStyle implements ColumnStyle {
  const factory _ColumnStyle(
      {final String backgroundColor,
      final double padding,
      final double borderRadius,
      final String? borderColor,
      final double borderWidth}) = _$ColumnStyleImpl;

  factory _ColumnStyle.fromJson(Map<String, dynamic> json) =
      _$ColumnStyleImpl.fromJson;

  @override
  String get backgroundColor;
  @override
  double get padding;
  @override
  double get borderRadius;
  @override
  String? get borderColor;
  @override
  double get borderWidth;

  /// Create a copy of ColumnStyle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ColumnStyleImplCopyWith<_$ColumnStyleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
