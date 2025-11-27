// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EmailDocumentImpl _$$EmailDocumentImplFromJson(Map<String, dynamic> json) =>
    _$EmailDocumentImpl(
      sections: (json['sections'] as List<dynamic>?)
              ?.map((e) => EmailSection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      settings: json['settings'] == null
          ? const EmailSettings()
          : EmailSettings.fromJson(json['settings'] as Map<String, dynamic>),
      theme: json['theme'] as Map<String, dynamic>? ?? const {},
      lastModified: json['lastModified'] == null
          ? null
          : DateTime.parse(json['lastModified'] as String),
    );

Map<String, dynamic> _$$EmailDocumentImplToJson(_$EmailDocumentImpl instance) =>
    <String, dynamic>{
      'sections': instance.sections,
      'settings': instance.settings,
      'theme': instance.theme,
      'lastModified': instance.lastModified?.toIso8601String(),
    };

_$EmailSettingsImpl _$$EmailSettingsImplFromJson(Map<String, dynamic> json) =>
    _$EmailSettingsImpl(
      maxWidth: (json['maxWidth'] as num?)?.toInt() ?? 600,
      backgroundColor: json['backgroundColor'] as String? ?? '#ffffff',
      textColor: json['textColor'] as String? ?? '#000000',
      fontFamily: json['fontFamily'] as String? ?? 'Arial, sans-serif',
      fontSize: (json['fontSize'] as num?)?.toInt() ?? 16,
      lineHeight: (json['lineHeight'] as num?)?.toInt() ?? 24,
      padding: (json['padding'] as num?)?.toInt() ?? 20,
    );

Map<String, dynamic> _$$EmailSettingsImplToJson(_$EmailSettingsImpl instance) =>
    <String, dynamic>{
      'maxWidth': instance.maxWidth,
      'backgroundColor': instance.backgroundColor,
      'textColor': instance.textColor,
      'fontFamily': instance.fontFamily,
      'fontSize': instance.fontSize,
      'lineHeight': instance.lineHeight,
      'padding': instance.padding,
    };

_$EmailSectionImpl _$$EmailSectionImplFromJson(Map<String, dynamic> json) =>
    _$EmailSectionImpl(
      id: json['id'] as String,
      columns: (json['columns'] as List<dynamic>?)
              ?.map((e) => EmailColumn.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      style: json['style'] == null
          ? const SectionStyle()
          : SectionStyle.fromJson(json['style'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$EmailSectionImplToJson(_$EmailSectionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'columns': instance.columns,
      'style': instance.style,
    };

_$SectionStyleImpl _$$SectionStyleImplFromJson(Map<String, dynamic> json) =>
    _$SectionStyleImpl(
      backgroundColor: json['backgroundColor'] as String? ?? '#ffffff',
      paddingTop: (json['paddingTop'] as num?)?.toDouble() ?? 20,
      paddingBottom: (json['paddingBottom'] as num?)?.toDouble() ?? 20,
      paddingLeft: (json['paddingLeft'] as num?)?.toDouble() ?? 20,
      paddingRight: (json['paddingRight'] as num?)?.toDouble() ?? 20,
      backgroundImage: json['backgroundImage'] as String?,
      backgroundSize: json['backgroundSize'] as String? ?? 'cover',
    );

Map<String, dynamic> _$$SectionStyleImplToJson(_$SectionStyleImpl instance) =>
    <String, dynamic>{
      'backgroundColor': instance.backgroundColor,
      'paddingTop': instance.paddingTop,
      'paddingBottom': instance.paddingBottom,
      'paddingLeft': instance.paddingLeft,
      'paddingRight': instance.paddingRight,
      'backgroundImage': instance.backgroundImage,
      'backgroundSize': instance.backgroundSize,
    };

_$EmailColumnImpl _$$EmailColumnImplFromJson(Map<String, dynamic> json) =>
    _$EmailColumnImpl(
      id: json['id'] as String,
      flex: (json['flex'] as num?)?.toInt() ?? 1,
      components: (json['components'] as List<dynamic>?)
              ?.map((e) => EmailComponent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      style: json['style'] == null
          ? const ColumnStyle()
          : ColumnStyle.fromJson(json['style'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$EmailColumnImplToJson(_$EmailColumnImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'flex': instance.flex,
      'components': instance.components,
      'style': instance.style,
    };

_$ColumnStyleImpl _$$ColumnStyleImplFromJson(Map<String, dynamic> json) =>
    _$ColumnStyleImpl(
      backgroundColor: json['backgroundColor'] as String? ?? '#ffffff',
      padding: (json['padding'] as num?)?.toDouble() ?? 10,
      borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 0,
      borderColor: json['borderColor'] as String?,
      borderWidth: (json['borderWidth'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$$ColumnStyleImplToJson(_$ColumnStyleImpl instance) =>
    <String, dynamic>{
      'backgroundColor': instance.backgroundColor,
      'padding': instance.padding,
      'borderRadius': instance.borderRadius,
      'borderColor': instance.borderColor,
      'borderWidth': instance.borderWidth,
    };
