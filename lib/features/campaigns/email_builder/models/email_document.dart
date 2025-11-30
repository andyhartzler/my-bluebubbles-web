import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:flutter/material.dart';

import 'email_component.dart';

part 'email_document.freezed.dart';
part 'email_document.g.dart';

@freezed
class EmailDocument with _$EmailDocument {
  const factory EmailDocument({
    @Default([]) List<EmailSection> sections,
    @Default(EmailSettings()) EmailSettings settings,
    @Default({}) Map<String, dynamic> theme,
    DateTime? lastModified,
  }) = _EmailDocument;

  factory EmailDocument.empty() {
    return EmailDocument(
      sections: const [],
      settings: const EmailSettings(),
      theme: const {},
      lastModified: DateTime.now(),
    );
  }

  factory EmailDocument.fromJson(Map<String, dynamic> json) =>
      _$EmailDocumentFromJson(json);
}

@freezed
class EmailSettings with _$EmailSettings {
  const factory EmailSettings({
    @Default(600) int maxWidth,
    @Default('#ffffff') String backgroundColor,
    @Default('#000000') String textColor,
    @Default('Arial, sans-serif') String fontFamily,
    @Default(16) int fontSize,
    @Default(24) int lineHeight,
    @Default(20) int padding,
  }) = _EmailSettings;

  factory EmailSettings.fromJson(Map<String, dynamic> json) =>
      _$EmailSettingsFromJson(json);
}

@freezed
class EmailSection with _$EmailSection {
  const factory EmailSection({
    required String id,
    @Default([]) List<EmailColumn> columns,
    @Default(SectionStyle()) SectionStyle style,
  }) = _EmailSection;

  factory EmailSection.fromJson(Map<String, dynamic> json) =>
      _$EmailSectionFromJson(json);
}

@freezed
class SectionStyle with _$SectionStyle {
  const factory SectionStyle({
    @Default('#ffffff') String backgroundColor,
    @Default(20) double paddingTop,
    @Default(20) double paddingBottom,
    @Default(20) double paddingLeft,
    @Default(20) double paddingRight,
    String? backgroundImage,
    @Default('cover') String backgroundSize,
  }) = _SectionStyle;

  factory SectionStyle.fromJson(Map<String, dynamic> json) =>
      _$SectionStyleFromJson(json);
}

@freezed
class EmailColumn with _$EmailColumn {
  const factory EmailColumn({
    required String id,
    @Default(1) int flex,
    @Default([]) List<EmailComponent> components,
    @Default(ColumnStyle()) ColumnStyle style,
  }) = _EmailColumn;

  factory EmailColumn.fromJson(Map<String, dynamic> json) =>
      _$EmailColumnFromJson(json);
}

@freezed
class ColumnStyle with _$ColumnStyle {
  const factory ColumnStyle({
    @Default('#ffffff') String backgroundColor,
    @Default(10) double padding,
    @Default(0) double borderRadius,
    String? borderColor,
    @Default(0) double borderWidth,
  }) = _ColumnStyle;

  factory ColumnStyle.fromJson(Map<String, dynamic> json) =>
      _$ColumnStyleFromJson(json);
}
