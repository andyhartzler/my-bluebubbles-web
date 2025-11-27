// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_component.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TextComponentImpl _$$TextComponentImplFromJson(Map<String, dynamic> json) =>
    _$TextComponentImpl(
      id: json['id'] as String,
      content: json['content'] as String? ?? '',
      style: json['style'] == null
          ? const TextComponentStyle()
          : TextComponentStyle.fromJson(json['style'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$TextComponentImplToJson(_$TextComponentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'content': instance.content,
      'style': instance.style,
      'runtimeType': instance.$type,
    };

_$ImageComponentImpl _$$ImageComponentImplFromJson(Map<String, dynamic> json) =>
    _$ImageComponentImpl(
      id: json['id'] as String,
      url: json['url'] as String,
      alt: json['alt'] as String?,
      link: json['link'] as String?,
      style: json['style'] == null
          ? const ImageComponentStyle()
          : ImageComponentStyle.fromJson(json['style'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$ImageComponentImplToJson(
        _$ImageComponentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'alt': instance.alt,
      'link': instance.link,
      'style': instance.style,
      'runtimeType': instance.$type,
    };

_$ButtonComponentImpl _$$ButtonComponentImplFromJson(
        Map<String, dynamic> json) =>
    _$ButtonComponentImpl(
      id: json['id'] as String,
      text: json['text'] as String,
      url: json['url'] as String,
      style: json['style'] == null
          ? const ButtonComponentStyle()
          : ButtonComponentStyle.fromJson(
              json['style'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$ButtonComponentImplToJson(
        _$ButtonComponentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'url': instance.url,
      'style': instance.style,
      'runtimeType': instance.$type,
    };

_$DividerComponentImpl _$$DividerComponentImplFromJson(
        Map<String, dynamic> json) =>
    _$DividerComponentImpl(
      id: json['id'] as String,
      style: json['style'] == null
          ? const DividerComponentStyle()
          : DividerComponentStyle.fromJson(
              json['style'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$DividerComponentImplToJson(
        _$DividerComponentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'style': instance.style,
      'runtimeType': instance.$type,
    };

_$SpacerComponentImpl _$$SpacerComponentImplFromJson(
        Map<String, dynamic> json) =>
    _$SpacerComponentImpl(
      id: json['id'] as String,
      height: (json['height'] as num?)?.toDouble() ?? 40,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$SpacerComponentImplToJson(
        _$SpacerComponentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'height': instance.height,
      'runtimeType': instance.$type,
    };

_$SocialComponentImpl _$$SocialComponentImplFromJson(
        Map<String, dynamic> json) =>
    _$SocialComponentImpl(
      id: json['id'] as String,
      links: (json['links'] as List<dynamic>?)
              ?.map((e) => SocialLink.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      style: json['style'] == null
          ? const SocialComponentStyle()
          : SocialComponentStyle.fromJson(
              json['style'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$SocialComponentImplToJson(
        _$SocialComponentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'links': instance.links,
      'style': instance.style,
      'runtimeType': instance.$type,
    };

_$TextComponentStyleImpl _$$TextComponentStyleImplFromJson(
        Map<String, dynamic> json) =>
    _$TextComponentStyleImpl(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16,
      color: json['color'] as String? ?? '#000000',
      alignment: json['alignment'] as String? ?? 'left',
      bold: json['bold'] as bool? ?? false,
      italic: json['italic'] as bool? ?? false,
      underline: json['underline'] as bool? ?? false,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.5,
      paddingTop: (json['paddingTop'] as num?)?.toDouble() ?? 0,
      paddingBottom: (json['paddingBottom'] as num?)?.toDouble() ?? 0,
      fontFamily: json['fontFamily'] as String?,
    );

Map<String, dynamic> _$$TextComponentStyleImplToJson(
        _$TextComponentStyleImpl instance) =>
    <String, dynamic>{
      'fontSize': instance.fontSize,
      'color': instance.color,
      'alignment': instance.alignment,
      'bold': instance.bold,
      'italic': instance.italic,
      'underline': instance.underline,
      'lineHeight': instance.lineHeight,
      'paddingTop': instance.paddingTop,
      'paddingBottom': instance.paddingBottom,
      'fontFamily': instance.fontFamily,
    };

_$ImageComponentStyleImpl _$$ImageComponentStyleImplFromJson(
        Map<String, dynamic> json) =>
    _$ImageComponentStyleImpl(
      width: json['width'] as String? ?? '100%',
      height: json['height'] as String?,
      alignment: json['alignment'] as String? ?? 'center',
      borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 0,
      paddingTop: (json['paddingTop'] as num?)?.toDouble() ?? 0,
      paddingBottom: (json['paddingBottom'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$$ImageComponentStyleImplToJson(
        _$ImageComponentStyleImpl instance) =>
    <String, dynamic>{
      'width': instance.width,
      'height': instance.height,
      'alignment': instance.alignment,
      'borderRadius': instance.borderRadius,
      'paddingTop': instance.paddingTop,
      'paddingBottom': instance.paddingBottom,
    };

_$ButtonComponentStyleImpl _$$ButtonComponentStyleImplFromJson(
        Map<String, dynamic> json) =>
    _$ButtonComponentStyleImpl(
      backgroundColor: json['backgroundColor'] as String? ?? '#007bff',
      textColor: json['textColor'] as String? ?? '#ffffff',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16,
      paddingVertical: (json['paddingVertical'] as num?)?.toDouble() ?? 12,
      paddingHorizontal: (json['paddingHorizontal'] as num?)?.toDouble() ?? 24,
      borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 4,
      alignment: json['alignment'] as String? ?? 'center',
      bold: json['bold'] as bool? ?? false,
      width: json['width'] as String? ?? 'auto',
      marginTop: (json['marginTop'] as num?)?.toDouble() ?? 20,
      marginBottom: (json['marginBottom'] as num?)?.toDouble() ?? 20,
    );

Map<String, dynamic> _$$ButtonComponentStyleImplToJson(
        _$ButtonComponentStyleImpl instance) =>
    <String, dynamic>{
      'backgroundColor': instance.backgroundColor,
      'textColor': instance.textColor,
      'fontSize': instance.fontSize,
      'paddingVertical': instance.paddingVertical,
      'paddingHorizontal': instance.paddingHorizontal,
      'borderRadius': instance.borderRadius,
      'alignment': instance.alignment,
      'bold': instance.bold,
      'width': instance.width,
      'marginTop': instance.marginTop,
      'marginBottom': instance.marginBottom,
    };

_$DividerComponentStyleImpl _$$DividerComponentStyleImplFromJson(
        Map<String, dynamic> json) =>
    _$DividerComponentStyleImpl(
      color: json['color'] as String? ?? '#cccccc',
      thickness: (json['thickness'] as num?)?.toDouble() ?? 1,
      marginTop: (json['marginTop'] as num?)?.toDouble() ?? 20,
      marginBottom: (json['marginBottom'] as num?)?.toDouble() ?? 20,
      style: json['style'] as String? ?? 'solid',
    );

Map<String, dynamic> _$$DividerComponentStyleImplToJson(
        _$DividerComponentStyleImpl instance) =>
    <String, dynamic>{
      'color': instance.color,
      'thickness': instance.thickness,
      'marginTop': instance.marginTop,
      'marginBottom': instance.marginBottom,
      'style': instance.style,
    };

_$SocialLinkImpl _$$SocialLinkImplFromJson(Map<String, dynamic> json) =>
    _$SocialLinkImpl(
      platform: json['platform'] as String,
      url: json['url'] as String,
    );

Map<String, dynamic> _$$SocialLinkImplToJson(_$SocialLinkImpl instance) =>
    <String, dynamic>{
      'platform': instance.platform,
      'url': instance.url,
    };

_$SocialComponentStyleImpl _$$SocialComponentStyleImplFromJson(
        Map<String, dynamic> json) =>
    _$SocialComponentStyleImpl(
      iconSize: (json['iconSize'] as num?)?.toDouble() ?? 32,
      alignment: json['alignment'] as String? ?? 'center',
      spacing: (json['spacing'] as num?)?.toDouble() ?? 8,
      marginTop: (json['marginTop'] as num?)?.toDouble() ?? 20,
      marginBottom: (json['marginBottom'] as num?)?.toDouble() ?? 20,
    );

Map<String, dynamic> _$$SocialComponentStyleImplToJson(
        _$SocialComponentStyleImpl instance) =>
    <String, dynamic>{
      'iconSize': instance.iconSize,
      'alignment': instance.alignment,
      'spacing': instance.spacing,
      'marginTop': instance.marginTop,
      'marginBottom': instance.marginBottom,
    };
