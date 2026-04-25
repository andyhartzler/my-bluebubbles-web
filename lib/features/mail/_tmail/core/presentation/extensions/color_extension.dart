import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

// ============================================================================
// MOYD BRAND OVERRIDE (audit 2026-04-25)
// ----------------------------------------------------------------------------
// tmail's MailboxDashBoardView is mounted under a Theme override at
// MailScreen scope (`lib/features/mail/screens/mail_screen.dart`) that maps
// `colorScheme.primary` -> BrandColors.unityBlue. That override only catches
// widgets reading from `Theme.of(context)`. Many tmail widgets reference
// `AppColor.<name>` constants directly (~250 call sites across the
// dashboard / mailbox / thread / thread_detail / email / composer / base /
// search feature dirs), bypassing the override entirely.
//
// Rather than touching ~250 call sites (and reintroducing drift on every
// fork-resync), we surgically remap the *brand-bearing* constants here at
// their declaration site. This keeps every read-path correct without
// stripping any widget that relies on the constant.
//
// Mapping rule of thumb:
//   - "primary blue" (#007AFF / #0A84FF / #3840F7 / #182952) -> unityBlue
//   - "secondary / link blue" (#208BFF / #297EF2 / etc.)     -> momentumBlue
//   - "accent purple" used decoratively                      -> sunriseGold
//   - "decorative warm/red" (avatar, AI tag) used as chrome  -> unityBlue
//   - Semantic state colors (red errors, orange warnings,
//     green success, calendar update/maybe banners)          -> LEFT ALONE
//   - Pale tint colors (DFEEFF, EBF4FF, E3F1FF) used as
//     selected-row highlight                                 -> LEFT ALONE
//     (they read fine against navy/gold and replacing them
//      with unityBlue would hide the highlight)
// ============================================================================

extension AppColor on Color {
  // Primary brand blue. Was Color(0xFF007AFF) (Linagora iOS-blue).
  // Remapped to MOYD navy. Cascades to text-buttons, focused borders,
  // dialog action buttons, expand-mailbox arrow, send-button, and 60+
  // other call sites that use `AppColor.primaryColor` directly.
  static const primaryColor = BrandColors.unityBlue;
  static const primaryDarkColor = Color(0xFF1C1C1C);
  static const primaryLightColor = Color(0xFFFFFFFF);
  static const primarySelectedColor = Color(0xFFDFEEFF);
  static const baseTextColor = Color(0xFF7E869B);
  static const textFieldTextColor = Color(0xFF7E869B);
  static const textFieldLabelColor = Color(0xFF7E869B);
  static const textFieldHintColor = Color(0xFF757575);
  static const textFieldBorderColor = Color(0xfff2f3f5);
  // Was Color(0xFF007AFF). Focused text-field underline -> navy.
  static const textFieldFocusedBorderColor = BrandColors.unityBlue;
  static const loginTextFieldBorderColor = Color(0xFFF2F3F5);
  static const textFieldErrorBorderColor = Color(0xffE64646);
  static const loginTextFieldErrorBorder = Color(0xffE64646);
  // Was Color(0xFF007AFF). Login form focus ring -> navy.
  static const loginTextFieldFocusedBorder = BrandColors.unityBlue;
  static const loginTextFieldHintColor = Color(0xff818C99);
  static const loginTextFieldBackgroundColor = Color(0xFFF2F3F5);
  // Was Color(0xFF3840F7) (Linagora indigo). Generic "app" accent -> navy.
  static const appColor = BrandColors.unityBlue;
  // Was Color(0xFF182952) (Linagora deep navy). Display-name color -> navy.
  static const nameUserColor = BrandColors.unityBlue;
  static const userInformationBackgroundColor = Color(0xFFF5F5F7);
  static const searchBorderColor = Color(0xFFEAEAEA);
  static const searchHintTextColor = Color(0xFF7E869B);
  // Was Color(0xFFE6E5FF) (very pale Linagora indigo tint). Selected
  // mailbox background -> faint navy tint that reads on light surfaces.
  static const mailboxSelectedBackgroundColor = Color(0xFFE0E6F0);
  static const mailboxBackgroundColor = Color(0xFFFFFFFF);
  // Was Color(0xFF3840F7). Selected mailbox label color -> navy.
  static const mailboxSelectedTextColor = BrandColors.unityBlue;
  // Was Color(0xFF182952). Default mailbox label color -> navy.
  static const mailboxTextColor = BrandColors.unityBlue;
  // Was Color(0xFF162546). Container chrome -> navy.
  static const emailMailboxContainColor = BrandColors.unityBlue;
  // Was Color(0xFF182952). Selected mailbox unread-count -> navy.
  static const mailboxSelectedTextNumberColor = BrandColors.unityBlue;
  // Was Color(0xFF3840F7). Selected mailbox icon -> navy.
  static const mailboxSelectedIconColor = BrandColors.unityBlue;
  static const mailboxIconColor = Color(0xFF7E869B);
  static const storageBackgroundColor = Color(0xFFF5F5F7);
  static const storageTitleColor = Color(0xFF7E869B);
  // Was Color(0xFF101D43). Storage max-size label -> navy.
  static const storageMaxSizeColor = BrandColors.unityBlue;
  // Was Color(0xFF2D0CFF) (deep Linagora violet). Used in storage progress
  // bar fill -> navy so the progress bar reads as a brand element.
  static const storageUseSizeColor = BrandColors.unityBlue;
  static const myFolderTitleColor = Color(0xFF7E869B);
  // Was Color(0xFF182952). App bar title color -> navy.
  static const titleAppBarMailboxListMail = BrandColors.unityBlue;
  // Was Color(0xFF3840F7). Mailbox unread counter -> navy.
  static const counterMailboxColor = BrandColors.unityBlue;
  static const backgroundCounterMailboxColor = Color(0xFFE3E1FD);
  static const backgroundCounterMailboxSelectedColor = Color(0x17313131);
  static const bgMailboxListMail = Color(0xFFFBFBFF);
  static const bgMessenger = Color(0xFFF2F2F5);
  // Was Color(0xFF182952). Default text-button color -> navy.
  static const textButtonColor = BrandColors.unityBlue;
  static const attachmentFileBorderColor = Color(0x1F000000);
  static const attachmentFileNameColor = Color(0xFF000000);
  static const attachmentFileSizeColor = Color(0xFF818C99);
  static const avatarColor = Color(0xFFF8F8F8);
  // Was Color(0xFF3840F7). Avatar initials color -> navy.
  static const avatarTextColor = BrandColors.unityBlue;
  // Was Color(0xFF182952). Unread sent-time -> navy bold text.
  static const sentTimeTextColorUnRead = BrandColors.unityBlue;
  // Was Color(0xFF3840F7). Unread subject text (load-bearing -- the bold
  // navy/indigo of unread rows in the inbox list) -> navy.
  static const subjectEmailTextColorUnRead = BrandColors.unityBlue;
  static const dividerColor = Color(0xFFEAEAEA);
  static const bgComposer = Color(0xFFFBFBFF);
  static const emailAddressChipColor = Color(0x0D001C3D);
  // Was Color(0xFF007AFF). Send-email button enabled state -> navy.
  static const enableSendEmailButtonColor = BrandColors.unityBlue;
  static const disableSendEmailButtonColor = Color(0xFFA9B4C2);
  static const borderLeftEmailContentColor = Color(0xFFEFEFEF);
  static const toastWarningBackgroundColor = Color(0xFFFFC107);
  static const toastSuccessBackgroundColor = Color(0xFF4BB34B);
  static const toastErrorBackgroundColor = Color(0xFFE64646);
  static const toastWithActionBackgroundColor = Color(0xFF3F3F3F);
  static const buttonActionToastWithActionColor = Color(0xFF7ADCF8);
  static const backgroundCountAttachment = Color(0x681C1C1C);
  static const bgStatusResultSearch = Color(0xFFF5F5F7);
  static const colorNameEmail = Color(0xFF000000);
  static const colorContentEmail = Color(0xFF6D7885);
  // Was Color(0xFF007AFF). Generic text-button color (action bar, dialogs,
  // 12 call sites) -> navy.
  static const colorTextButton = BrandColors.unityBlue;
  static const colorHintSearchBar = Color(0xFF818C99);
  static const colorBgSearchBar = Color(0x99EBEDF0);
  static const colorBgIdentityButton = Color(0x00EBEDF0);
  static const colorShadowBgContentEmail = Color(0x14000000);
  static const colorDividerMailbox = Color(0x1F000000);
  static const colorCollapseMailbox = Color(0xFFB8C1CC);
  // Was Color(0xFF007AFF). Expanded-mailbox arrow -> navy.
  static const colorExpandMailbox = BrandColors.unityBlue;
  static const colorBgMailbox = Color(0xFFF7F7F7);
  static const colorFilterMessageDisabled = Color(0xFF99A2AD);
  // Was Color(0xFF007AFF). Active filter pill text -> navy.
  static const colorFilterMessageEnabled = BrandColors.unityBlue;
  static const colorDefaultCupertinoActionSheet = Color(0x66000000);
  static const colorDisableMailboxCreateButton = Color(0x2E3C3C43);
  static const colorInputBorderErrorVerifyName = Color(0xFFE64646);
  static const colorInputBorderCreateMailbox = Color(0x1F000000);
  static const colorInputBackgroundErrorVerifyName = Color(0xFFFAEBEB);
  static const colorInputBackgroundCreateMailbox = Color(0xFFF2F3F5);
  static const colorHintInputCreateMailbox = Color(0xFFA9B4C2);
  static const colorMessageConfirmDialog = Color(0xFF6D7885);
  static const colorActionDeleteConfirmDialog = Color(0xFFE64646);
  // Was Color(0xFF007AFF). Dialog "cancel"/affirm action color -> navy.
  static const colorActionCancelDialog = BrandColors.unityBlue;
  static const colorMessageDialog = Color(0xFF222222);
  static const colorConfirmActionDialog = Color(0xFFF2F2F2);
  static const colorEmailAddress = Color(0xFF333333);
  static const colorHintEmailAddressInput = Color(0x993C3C43);
  static const colorDividerComposer = Color(0xFFC6C6C8);
  static const colorDividerEmailView = Color(0xFFD7D8D9);
  static const colorButton = Color(0xFF959DAD);
  static const colorTime = Color(0xFF92A1B4);
  static const colorEmailAddressTag = Color(0xFFF4F4F4);
  static const colorLineLeftEmailView = Color(0x2999A2AD);
  static const colorShadowComposer = Color(0x1F000000);
  static const colorBottomBarComposer = Color(0x5CEBEDF0);
  static const colorShadowComposerFullScreen = Color(0x33000000);
  static const colorCancelButton = Color(0xFFF2F2F2);
  static const colorTextButtonHeaderThread = Color(0xFF686E76);
  static const colorTextSettingDescriptions = colorTextButtonHeaderThread;
  static const colorButtonHeaderThread = Color(0x99EBEDF0);
  static const colorBorderBodyThread = Color(0x5CB8C1CC);
  static const colorBgDesktop = Color(0xFFF3F6F9);
  static const colorItemEmailSelectedDesktop = Color(0xFFDFEEFF);
  // Was Color(0xFFDE5E5E) (Linagora coral red). Default avatar background
  // when no per-recipient color is computed -> navy. The avatarTextColor is
  // also remapped to navy above; the runtime decorates avatars with white
  // text on this background. Leaving it as red bled "Linagora red" through
  // every email row that didn't have a custom palette entry.
  static const colorAvatar = BrandColors.unityBlue;
  static const colorFocusButton = Color(0x14818C99);
  static const colorBorderEmailAddressInvalid = Color(0xFFFF3347);
  static const colorBorderIdentityInfo = Color(0xFFE7E8EC);
  static const colorBgMailboxSelected = Color(0x99E4E8EC);
  static const colorLoading = Color(0x2999A2AD);
  static const colorBgMenuItemDropDownSelected = Color(0x80DEE2E7);
  static const colorButtonCancelDialog = Color(0x0D000000);
  // Was Color(0x99007AFF) (semi-transparent Linagora blue glow under
  // composer's send button). 0x99 alpha (60%) on unityBlue (0x273351) ->
  // 0x99273351 to keep the glow but dressed in MOIBlue navy.
  static const colorShadowComposerButton = Color(0x99273351);
  static const colorBackgroundTagFilter = Color(0xFF6D7885);
  static const colorDefaultRichTextButton = Color(0xFF99A2AD);
  static const colorStyleBlockQuote = Color(0xFFEEEEEE);
  static const colorBorderStyleCode = Color(0xFFCCCCCC);
  static const colorBackgroundStyleCode = Color(0xFFF5F5F5);
  static const colorBorderWrapIconStyleCode = Color(0xFFE4E4E4);
  static const colorBackgroundWrapIconStyleCode = Color(0xFFF2F3F5);
  static const colorBackgroundSnackBar = Color(0xFF343438);
  static const colorBackgroundFieldConditionRulesFilter = Color(0xFFF2F3F5);
  static const colorDeletePermanentlyButton = Color(0xffE64646);
  static const colorBackgroundNotificationVacationSetting= Color(0xFFFFF5C2);
  static const colorDivider = Color(0xFFE7E8EC);
  static const colorCloseButton = Color(0xFF818C99);
  static const colorDropShadow = Color(0x0F000000);
  static const colorBackgroundKeyboard = Color(0xFFD2D5DC);
  static const colorBackgroundKeyboardAndroid = Color(0xFFF2F0F4);
  static const colorShadowLayerBottom = Color(0x29000000);
  static const colorShadowLayerTop = Color(0x1F000000);
  static const colorDividerHorizontal = Color(0x1F000000);
  static const colorEmailAddressFull = Color(0xFF818C99);
  static const colorDividerDestinationPicker = Color(0x1F000000);
  static const colorItemAlreadySelected = Color(0xFF818C99);
  static const colorItemSelected = Color(0xFFF2F3F5);
  static const colorBorderSettingContentWeb = Color(0xFFE7E8EC);
  static const colorDividerHeaderSetting = Color(0xFFE4E4E4);
  static const colorSettingExplanation = Color(0xFF818C99);
  static const colorBackgroundContactTagItem = Color(0xFFDCE0E5);
  static const colorDeleteContactIcon = Color(0xFFAEB7C2);
  static const colorItemRecipientSelected = Color(0xFFDFEEFF);
  static const colorBackgroundQuotasWarning = Color(0xFFFFC107);
  static const colorQuotaWarning = Color(0xFFF05C44);
  static const colorQuotaError = Color(0xffE64646);
  static const colorCreateNewIdentityButton = Color(0xFFEBEDF0);
  static const colorSpamReportBannerBackground = Color(0xFFBFDEFF);
  static const colorSpamReportBannerStrokeBorder = Color(0x1F000000);
  static const colorSpamReportBannerLabelColor = Color(0xFF626D7A);
  static const colorSpamReportBannerButtonBackground = Color(0xFFEBEDF0);
  static const colorSubtitle = Color(0xFF6D7885);
  static const searchInputBackground = Color(0xFFE0E9F1);
  static const colorMailboxHovered = Color(0xFFEBEDF0);
  static const colorMailboxPath = Color(0xFF818C99);
  static const colorIconUnSubscribedMailbox = Color(0xFFAEB7C2);
  static const colorTitleAUnSubscribedMailbox = Color(0xFF818C99);
  static const colorTitleSendingItem = Color(0xFF818C99);
  static const colorBannerMessageSendingQueue = Color(0xFFF7F8FA);
  static const colorDeliveringState = Color(0xFFAEB7C2);
  static const colorErrorState = Color(0xFFE64646);
  static const colorBackgroundErrorState = Color(0xFFFAEBEB);
  static const colorBackgroundDeliveringState = Color(0xFFF2F3F5);
  static const colorNetworkConnectionBannerBackground = Color(0x99EBEDF0);
  static const colorNetworkConnectionLabel = Color(0xFF818C99);
  static const colorCalendarEventRead = Color(0xFF818C99);
  static const colorCalendarEventUnread = Color(0xFF1C1B1F);
  static const colorMaybeEventActionText = Color(0xFFFFC107);
  static const colorMaybeEventActionBanner = Color(0xFFFFF5C2);
  // Was Color(0xFF007AFF). Calendar "invited" action text -> navy.
  // (Calendar updated/maybe/canceled action text + banners deliberately
  //  left as semantic green/orange/red below.)
  static const colorInvitedEventActionText = BrandColors.unityBlue;
  static const colorInvitedEventActionBanner = Color(0xFFEBF4FF);
  static const colorUpdatedEventActionText = Color(0xFF4BB34B);
  static const colorUpdatedEventActionBanner = Color(0xFFECF8E5);
  static const colorCanceledEventActionText = Color(0xFFFF3347);
  static const colorCanceledEventActionBanner = Color(0xFFF5EBEB);
  static const colorSubTitleEventActionText = Color(0xFF939393);
  static const colorCalendarEventInformationBackground = Color(0x0A000000);
  static const colorCalendarEventInformationStroke = Color(0x1F000000);
  static const colorShadowCalendarDateIcon = Color(0x26000000);
  static const colorOrganizerMailto = Color(0xFFB3B3B3);
  static const colorMailto = Color(0xFFB3B3B3);
  static const colorEventDescriptionBackground = Color(0x05000000);
  static const colorLabelQuotas = Color(0xFF818C99);
  static const colorLabelCancelButton = Color(0xFFAEB7C2);
  static const colorCreateFiltersButton = Color(0xFFF3F3F7);
  static const colorTextBody = Color(0xFF818C99);
  static const colorClosePopupDialogButton = Color(0xFFAEB7C2);
  static const colorCancelPopupDialogButton = Color(0xFFEBEDF0);
  static const colorRemoveRuleFilterConditionButton = Color(0xFFE6E8EC);
  static const colorComposerShadowTop = Color(0x28000000);
  static const colorComposerShadowBottom = Color(0x1E000000);
  static const colorComposerAppBar = Color(0xFFF4F4F4);
  static const colorLabelComposer = Color(0xFF8B9CAF);
  static const colorLineComposer = Color(0xFFF4F4F4);
  static const colorPrefixButtonComposer = Color(0xFF8B9CAF);
  static const colorRichButtonComposer = Color(0xFFAEAEC0);
  static const colorSelected = Color(0xFFE3F1FF);
  static const colorAttachmentBorder = Color(0xFFE5ECF3);
  static const colorProgressLoadingBackground = Color(0xFFE3F1FF);
  static const colorDropZoneBackground = Color(0xFFF6FAFF);
  static const colorDropZoneBorder = Color(0xFF46A2FF);
  static const colorLabelRichText = Color(0xFFADADC0);
  static const dropdownButtonBorderColor = Color(0xFFCFD7E2);
  static const dropdownLabelButtonBackgroundColor = Color(0xFFF4F4F4);
  static const colorLabelMoreAttachmentsButton = Color(0xFF71767C);
  static const colorButtonBorder = Color(0xFFD5D7E0);
  static const colorScrollbarTrackColor = Color(0xFFF4EFF4);
  static const colorScrollbarThumbColor = Color(0xFFD8E1EB);
  static const colorDropDownTitleComposer = Color(0xFF79747E);
  static const colorDropDownItemTitleComposer = Color(0xFF0A0A0A);
  static const messageDialogColor = Color(0xFF8C9CAF);
  static const messageDialogHighlightColor = Color(0xFF37383A);
  static const labelColor = Color(0xFF71767C);
  static const thumbScrollbarColor = Color(0xFFC1C1C1);
  static const loginViewShadowColor = Color(0x3DBCBCBC);
  static const colorEmailTileCheckboxUnhover = Color(0xFFAEB7C2);
  static const colorSearchFilterButton = Color(0xFFECEEF1);
  static const colorSearchFilterTitle = Color(0xFF686E76);
  static const colorSearchFilterIcon = Color(0xFF686E76);
  static const colorSuggestionSearchFilterButton = Color(0xFFEBEDF0);
  static const colorFilterMessageButton = Color(0xFFEBEDF0);
  static const colorFilterMessageIcon = Color(0xFF686E76);
  static const colorFilterMessageTitle = Color(0xFF686E76);
  static const colorMobileSearchFilterButton = Color(0xFFEBEDF0);
  static const colorContactViewClearFilterButton = Color(0x001C3D0D);
  static const steelGrayA540 = Color(0xFF55687D);
  static const steelGray200 = Color(0xFFAEB7C2);
  static const steelGray80 = Color(0xFFE7E8EC);
  // Was Color(0xFF208BFF). Used for action-pill text + secondary buttons
  // ("blue700"). Map to MOYD's accent momentumBlue so non-primary affordances
  // (links, info pills) read as the lighter brand blue rather than iOS blue.
  static const blue700 = BrandColors.momentumBlue;
  static const steelGray400 = Color(0xFF818C99);
  static const steelGray600 = Color(0xFF4E5966);
  static const blue100 = Color(0xFFDFEEFF);
  static const blue400 = Color(0xFF80BDFF);
  // Was Color(0xFF0F76E7). Hover/pressed link blue -> momentumBlue.
  static const blue900 = BrandColors.momentumBlue;
  static const m3Tertiary = Color(0xFF8C9CAF);
  static const m3Tertiary60 = Color(0xFFD8E1EB);
  static const m3Tertiary70 = Color(0xFFE5ECF3);
  static const m3Tertiary20 = Color(0xFF71767C);
  static const m3Neutral70 = Color(0xFFAEAAAE);
  static const m3Neutral90 = Color(0xFFE6E1E5);
  static const m3Neutral40 = Color(0xFF605D62);
  // Was Color(0xFF5C9CE6). M3 secondary blue -> momentumBlue.
  static const m3SysLightSecondaryBlue = BrandColors.momentumBlue;
  // Was Color(0xFF0157AD). M3 primary surface blue -> navy.
  static const m3SysLight = BrandColors.unityBlue;
  static const m3SysOutline = Color(0xFFAEAEC0);
  static const grayBackgroundColor = Color(0xFFF3F6F9);
  static const m3SurfaceBackground = Color(0xFF1C1B1F);
  static const warningColor = Color(0xFFFFC107);
  // Was Color(0xFF0A84FF). Generic "primary main" used as foreground for
  // action affordances + selected highlights (18 call sites) -> navy.
  static const primaryMain = BrandColors.unityBlue;
  static const m3LayerDarkOutline = Color(0xFF938F99);
  static const blackAlpha40 = Color.fromRGBO(0, 0, 0, 0.4);
  static const blackAlpha20 = Color.fromRGBO(0, 0, 0, 0.2);
  static const textPrimary = Color(0xFF424244);
  // Was Color(0xFF297EF2). Generic folder/label icon tint -> momentumBlue.
  // (User-specific role icons -- inbox/drafts/sent/trash -- use SVG asset
  //  paths with their own internal colors, not this constant, so they are
  //  NOT affected by this remap.)
  static const iconFolder = BrandColors.momentumBlue;
  static const folderDivider = Color(0xFFE4E8EC);
  static const gray424244 = Color(0xFF424244);
  static const gray777778 = Color(0xFF777778);
  static const gray200 = Color(0xFFCCCCCC);
  static const lightGrayF4F4F4 = Color(0xFFF4F4F4);
  static const gray959DAD = Color(0xFF959DAD);
  static const gray9AA7B6 = Color(0xFF9AA7B6);
  static const gray9B9B9B = Color(0xFF9B9B9B);
  static const redFF3347 = Color(0xFFFF3347);
  static const gray686E76 = Color(0xFF686E76);
  static const gray900 = Color(0xFF222222);
  static const gray400 = Color(0xFF939393);
  static const lightGrayEBEDF0 = Color(0xFFEBEDF0);
  static const gray99A2AD = Color(0xFF99A2AD);
  static const textSecondary = Color(0xFF1C1B1F);
  static const profileMenuDivider = Color(0xFF1D192B);
  static const popupMenuItemHovered = Color(0xFFF8F8F8);
  static const secondaryContrastText = Color(0xFFFFFFFF);
  // Was Color(0xFF007AFF). LinShare attachment integration accent -> navy.
  static const primaryLinShare = BrandColors.unityBlue;
  static const lightGrayEAEDF2 = Color(0xFFEAEDF2);
  static const lightIconTertiary = Color(0xFFB8C1CC);
  static const gray6D7885 = Color(0xFF6D7885);
  // Was Color(0xFF0A84FF). M3 primary -> navy.
  static const m3Primary = BrandColors.unityBlue;
  static const m3Primary95 = Color(0xFFE3F1FF);
  static const gray49454F = Color(0xFF49454F);
  // Was Color(0xFF00B7FF) (Linagora cyan-blue). -> momentumBlue.
  static const blue00B7FF = BrandColors.momentumBlue;
  static const blueD2E9FF = Color(0xFFD2E9FF);
  static const grayCDCDCD = Color(0xFFCDCDCD);
  static const lightGrayF9FAFB = Color(0xFFF9FAFB);
  static const black4D4D4D = Color(0xFF4D4D4D);
  static const black1A1A1A = Color(0xFF1A1A1A);
  static const green166534 = Color(0xFF166534);
  static const lightGreenF0FDF4 = Color(0xFFF0FDF4);
  static const lightGreenBBF7D0 = Color(0xFFBBF7D0);
  static const lightBlueEFF6FF = Color(0xFFEFF6FF);
  static const lightBlueBFDBFE = Color(0xFFBFDBFE);
  static const lightGrayF6FAFF = Color(0xFFF6FAFF);
  static const lightGrayF7F6F9 = Color(0xFFF7F6F9);
  // Was Color(0xFF25AEFE). Cyan accent -> momentumBlue.
  static const blue25AEFE = BrandColors.momentumBlue;
  // Was Color(0xFF7E57E3) (Linagora purple). AI/Scribe tag is decorative,
  // not semantic -> remap to sunriseGold so the AI affordance reads as the
  // MOYD accent instead of off-brand purple.
  static const aiActionTag = BrandColors.sunriseGold;

  static const mapGradientColor = [
    [Color(0xFF21D4FD), Color(0xFFB721FF)],
    [Color(0xFF38F9D7), Color(0xFF43E97B)],
    [Color(0xFF11E6F0), Color(0xFF4FACFE)],
    [Color(0xFFE88395), Color(0xFFEF9C8F)],
    [Color(0xFF8DDAD5), Color(0xFF00CDAC)],
    [Color(0xFFE4ABF0), Color(0xFFD96EED)],
    [Color(0xFFF0FF00), Color(0xFF58CFFB)],
    [Color(0xFFEFC0D7), Color(0xFF1AD5E4)],
    [Color(0xFFFFD26F), Color(0xFF3677FF)],
    [Color(0xFF87A6F8), Color(0xFF645FF6)],
  ];

  int toInt() {
    // Flutter <3.27 Color exposes alpha/red/green/blue as int 0-255.
    // (Flutter 3.27+ adds 0.0-1.0 component getters a/r/g/b — patched
    //  for our Flutter 3.24.4 baseline during the tmail fork.)
    return (alpha << 24) | (red << 16) | (green << 8) | blue;
  }

  String toHexTriplet() => '#${(toInt() & 0xFFFFFF)
      .toRadixString(16)
      .padLeft(6, '0')
      .toUpperCase()}';

  static List<Color> get listColorsPicker {
    return [
      ...Colors.grey.listShadeColors,
      ...listMaterialColors.map((color) => color.shade900).toList(),
      ...listMaterialColors.map((color) => color.shade800).toList(),
      ...listMaterialColors.map((color) => color.shade700).toList(),
      ...listMaterialColors.map((color) => color.shade600).toList(),
      ...listMaterialColors.map((color) => color.shade500).toList(),
      ...listMaterialColors.map((color) => color.shade400).toList(),
      ...listMaterialColors.map((color) => color.shade300).toList(),
      ...listMaterialColors.map((color) => color.shade200).toList(),
      ...listMaterialColors.map((color) => color.shade100).toList(),
      ...listMaterialColors.map((color) => color.shade50).toList(),
    ];
  }

  static List<MaterialColor> get listMaterialColors {
    return [
      Colors.cyan,
      Colors.blue,
      Colors.deepPurple,
      Colors.purple,
      Colors.pink,
      Colors.red,
      Colors.deepOrange,
      Colors.orange,
      Colors.amber,
      Colors.yellow,
      Colors.lime,
      Colors.green
    ];
  }
}

extension ColorNullableExtension on Color? {
  ColorFilter? asFilter({BlendMode? blendMode}) {
    if (this == null) {
      return null;
    } else {
      return ColorFilter.mode(this!, blendMode ?? BlendMode.srcIn);
    }
  }
}

extension MaterialColorExtension on MaterialColor {

  List<Color> get listShadeColors {
    return [
      const Color(0xFFFFFFFF),
      const Color(0xFFFCFCFC),
      shade50,
      shade100,
      shade200,
      shade300,
      shade400,
      shade500,
      shade600,
      shade700,
      shade800,
      shade900
    ];
  }
}