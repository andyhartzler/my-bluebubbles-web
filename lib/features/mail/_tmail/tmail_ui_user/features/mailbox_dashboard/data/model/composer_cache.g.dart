// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'composer_cache.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ComposerCache _$ComposerCacheFromJson(Map<String, dynamic> json) =>
    ComposerCache(
      email: json['email'] == null
          ? null
          : Email.fromJson(json['email'] as Map<String, dynamic>),
      hasRequestReadReceipt: json['hasRequestReadReceipt'] as bool?,
      isMarkAsImportant: json['isMarkAsImportant'] as bool?,
      displayMode: $enumDecodeNullable(
              _$ScreenDisplayModeEnumMap, json['displayMode']) ??
          ScreenDisplayMode.normal,
      composerIndex: (json['composerIndex'] as num?)?.toInt(),
      composerId: json['composerId'] as String?,
      draftHash: (json['draftHash'] as num?)?.toInt(),
      actionType:
          $enumDecodeNullable(_$EmailActionTypeEnumMap, json['actionType']),
      draftEmailId: const EmailIdNullableConverter()
          .fromJson(json['draftEmailId'] as String?),
      templateEmailId: const EmailIdNullableConverter()
          .fromJson(json['templateEmailId'] as String?),
    );

Map<String, dynamic> _$ComposerCacheToJson(ComposerCache instance) =>
    <String, dynamic>{
      if (instance.email?.toJson() case final value?) 'email': value,
      if (instance.hasRequestReadReceipt case final value?)
        'hasRequestReadReceipt': value,
      if (instance.isMarkAsImportant case final value?)
        'isMarkAsImportant': value,
      'displayMode': _$ScreenDisplayModeEnumMap[instance.displayMode]!,
      if (instance.composerIndex case final value?) 'composerIndex': value,
      if (instance.composerId case final value?) 'composerId': value,
      if (instance.draftHash case final value?) 'draftHash': value,
      if (_$EmailActionTypeEnumMap[instance.actionType] case final value?)
        'actionType': value,
      if (const EmailIdNullableConverter().toJson(instance.draftEmailId)
          case final value?)
        'draftEmailId': value,
      if (const EmailIdNullableConverter().toJson(instance.templateEmailId)
          case final value?)
        'templateEmailId': value,
    };

const _$ScreenDisplayModeEnumMap = {
  ScreenDisplayMode.fullScreen: 'fullScreen',
  ScreenDisplayMode.minimize: 'minimize',
  ScreenDisplayMode.normal: 'normal',
  ScreenDisplayMode.hidden: 'hidden',
};

const _$EmailActionTypeEnumMap = {
  EmailActionType.reply: 'reply',
  EmailActionType.replyToList: 'replyToList',
  EmailActionType.forward: 'forward',
  EmailActionType.replyAll: 'replyAll',
  EmailActionType.labelAs: 'labelAs',
  EmailActionType.compose: 'compose',
  EmailActionType.markAsRead: 'markAsRead',
  EmailActionType.markAsUnread: 'markAsUnread',
  EmailActionType.markAsStarred: 'markAsStarred',
  EmailActionType.unMarkAsStarred: 'unMarkAsStarred',
  EmailActionType.moveToMailbox: 'moveToMailbox',
  EmailActionType.editDraft: 'editDraft',
  EmailActionType.editSendingEmail: 'editSendingEmail',
  EmailActionType.composeFromContentShared: 'composeFromContentShared',
  EmailActionType.composeFromFileShared: 'composeFromFileShared',
  EmailActionType.composeFromEmailAddress: 'composeFromEmailAddress',
  EmailActionType.composeFromMailtoUri: 'composeFromMailtoUri',
  EmailActionType.editAsNewEmail: 'editAsNewEmail',
  EmailActionType.reopenComposerBrowser: 'reopenComposerBrowser',
  EmailActionType.moveToTrash: 'moveToTrash',
  EmailActionType.deletePermanently: 'deletePermanently',
  EmailActionType.preview: 'preview',
  EmailActionType.selection: 'selection',
  EmailActionType.moveToSpam: 'moveToSpam',
  EmailActionType.unSpam: 'unSpam',
  EmailActionType.openInNewTab: 'openInNewTab',
  EmailActionType.createRule: 'createRule',
  EmailActionType.unsubscribe: 'unsubscribe',
  EmailActionType.composeFromUnsubscribeMailtoLink:
      'composeFromUnsubscribeMailtoLink',
  EmailActionType.archiveMessage: 'archiveMessage',
  EmailActionType.printAll: 'printAll',
  EmailActionType.downloadMessageAsEML: 'downloadMessageAsEML',
};
