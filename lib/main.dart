import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bluebubbles/app/components/custom/custom_error_box.dart';
import 'package:bluebubbles/helpers/backend/startup_tasks.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/network/http_overrides.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/utils/window_effects.dart';
import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/startup/failure_to_start.dart';
import 'package:bluebubbles/app/layouts/setup/setup_view.dart';
import 'package:bluebubbles/app/layouts/startup/splash_screen.dart';
import 'package:bluebubbles/app/layouts/startup/myd_loading_screen.dart';
import 'package:bluebubbles/app/layouts/startup/password_screen.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/screens/crm/bulk_message_screen.dart';
import 'package:bluebubbles/screens/crm/meetings_screen.dart';
import 'package:bluebubbles/screens/crm/members_list_screen.dart';
import 'package:bluebubbles/screens/dashboard/dashboard_screen.dart';
import 'package:collection/collection.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' hide Priority;
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:get/get.dart';
import 'package:google_ml_kit/google_ml_kit.dart' hide Message;
import 'package:intl/date_symbol_data_local.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:path/path.dart' show join;
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:secure_application/secure_application.dart';
import 'package:system_tray/system_tray.dart' as st;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:tray_manager/tray_manager.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

bool isAuthing = false;
final systemTray = st.SystemTray();
final LocalNotifier localNotifier = LocalNotifier();

@pragma('vm:entry-point')
//ignore: prefer_void_to_null
Future<Null> main(List<String> arguments) async {
  await initApp(false, arguments);
}

@pragma('vm:entry-point')
// ignore: prefer_void_to_null
Future<Null> bubble() async {
  await initApp(true, []);
}

//ignore: prefer_void_to_null
Future<Null> initApp(bool bubble, List<String> arguments) async {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await dotenv.load(fileName: '.env', isOptional: true);

      if (CRMConfig.crmEnabled) {
        try {
          await CRMSupabaseService().initialize();
          Logger.info('CRM system initialized');
        } catch (e, s) {
          Logger.warn('CRM system failed to initialize: $e', trace: s);
        }
      }

      await StartupTasks.initStartupServices(isBubble: bubble);

      /* ----- RANDOM STUFF INITIALIZATION ----- */
      HttpOverrides.global = BadCertOverride();
      dynamic exception;
      StackTrace? stacktrace;

      FlutterError.onError = (details) {
        Logger.error("Rendering Error: ${details.exceptionAsString()}", error: details.exception, trace: details.stack);
      };

      try {
        // Once all the services are initialized, we need to perform some
        // startup tasks to ensure that the app has the information it needs.
        StartupTasks.onStartup().then((_) {
          Logger.info("Startup tasks completed");
        }).catchError((e, s) {
          Logger.error("Failed to complete startup tasks!", error: e, trace: s);
        });

        /* ----- DATE FORMATTING INITIALIZATION ----- */
        await initializeDateFormatting();

        /* ----- MEDIAKIT INITIALIZATION ----- */
        MediaKit.ensureInitialized();

        /* ----- SPLASH SCREEN INITIALIZATION ----- */
        if (!ss.settings.finishedSetup.value && !kIsWeb && !kIsDesktop) {
          runApp(MaterialApp(
              home: SplashScreen(shouldNavigate: false),
              theme: ThemeData(
                colorScheme: ColorScheme.fromSwatch(
                    backgroundColor:
                        PlatformDispatcher.instance.platformBrightness == Brightness.dark ? Colors.black : Colors.white),
              )));
        }

        /* ----- ANDROID SPECIFIC INITIALIZATION ----- */
        if (!kIsWeb && !kIsDesktop) {
          /* ----- TIME ZONE INITIALIZATION ----- */
          tz.initializeTimeZones();
          try {
            tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
          } catch (_) {}

          /* ----- MLKIT INITIALIZATION ----- */
          if (!await EntityExtractorModelManager().isModelDownloaded(EntityExtractorLanguage.english.name)) {
            EntityExtractorModelManager().downloadModel(EntityExtractorLanguage.english.name, isWifiRequired: false);
          }
        }

        /* ----- DESKTOP SPECIFIC INITIALIZATION ----- */
        if (kIsDesktop) {
          /* ----- WINDOW INITIALIZATION ----- */
          await windowManager.ensureInitialized();
          await windowManager.setPreventClose(ss.settings.closeToTray.value);
          await windowManager.setTitle('Missouri Young Democrats CRM');
          await Window.initialize();
          if (Platform.isWindows) {
            await Window.hideWindowControls();
          } else if (Platform.isLinux) {
            await windowManager
                .setTitleBarStyle(ss.settings.useCustomTitleBar.value ? TitleBarStyle.hidden : TitleBarStyle.normal);
          }
          windowManager.addListener(DesktopWindowListener.instance);
          doWhenWindowReady(() async {
            await windowManager.setMinimumSize(const Size(300, 300));
            Display primary = await ScreenRetriever.instance.getPrimaryDisplay();

            Size size = await windowManager.getSize();
            double width = ss.prefs.getDouble("window-width") ?? size.width;
            double height = ss.prefs.getDouble("window-height") ?? size.height;

            width = width.clamp(300, max(300, primary.size.width));
            height = height.clamp(300, max(300, primary.size.height));
            await windowManager.setSize(Size(width, height));
            await ss.prefs.setDouble("window-width", width);
            await ss.prefs.setDouble("window-height", height);

            await windowManager.setAlignment(Alignment.center);
            Offset offset = await windowManager.getPosition();
            double? posX = ss.prefs.getDouble("window-x") ?? offset.dx;
            double? posY = ss.prefs.getDouble("window-y") ?? offset.dy;

            posX = posX.clamp(0, max(0, primary.size.width - width));
            posY = posY.clamp(0, max(0, primary.size.height - height));
            await windowManager.setPosition(Offset(posX, posY), animate: true);
            await ss.prefs.setDouble("window-x", posX);
            await ss.prefs.setDouble("window-y", posY);

            await windowManager.setTitle('Missouri Young Democrats CRM');
            if (arguments.firstOrNull != "minimized") {
              await windowManager.show();
            }
            if (!(ss.canAuthenticate && ss.settings.shouldSecure.value)) {
              chats.init();
              socket;
            }
          });
        }

        /* ----- EMOJI FONT INITIALIZATION ----- */
        fs.checkFont();
      } catch (e, s) {
        Logger.error("Failure during app initialization!", error: e, trace: s);
        exception = e;
        stacktrace = s;
      }

      if (exception == null) {
        /* ----- THEME INITIALIZATION ----- */
        ThemeData light = ThemeStruct.getLightTheme().data;
        ThemeData dark = ThemeStruct.getDarkTheme().data;

        final tuple = ts.getStructsFromData(light, dark);
        light = tuple.item1;
        dark = tuple.item2;

        runApp(Main(
          lightTheme: light,
          darkTheme: dark,
        ));
      } else {
        runApp(FailureToStart(e: exception, s: stacktrace));
        throw Exception("$exception $stacktrace");
      }
    },
    (dynamic error, StackTrace stackTrace) {
      Logger.error("Unhandled Exception", trace: stackTrace, error: error);
    }
  );
}

class DesktopWindowListener extends WindowListener {
  DesktopWindowListener._();

  static final DesktopWindowListener instance = DesktopWindowListener._();

  @override
  void onWindowFocus() {
    ls.open();
  }

  @override
  void onWindowBlur() {
    ls.close();
  }

  @override
  void onWindowResized() async {
    Size size = await windowManager.getSize();
    await ss.prefs.setDouble("window-width", size.width);
    await ss.prefs.setDouble("window-height", size.height);
  }

  @override
  void onWindowMoved() async {
    Offset offset = await windowManager.getPosition();
    await ss.prefs.setDouble("window-x", offset.dx);
    await ss.prefs.setDouble("window-y", offset.dy);
  }

  @override
  void onWindowEvent(String eventName) async {
    switch (eventName) {
      case "hide":
        await setSystemTrayContextMenu(windowHidden: true);
        break;
      case "show":
        await setSystemTrayContextMenu(windowHidden: false);
        break;
    }
  }

  @override
  void onWindowClose() async {
    if (await windowManager.isPreventClose()) {
      await windowManager.hide();
    }
  }
}

class Main extends StatelessWidget {
  final ThemeData darkTheme;
  final ThemeData lightTheme;

  const Main({super.key, required this.lightTheme, required this.darkTheme});

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: lightTheme.copyWith(
          textSelectionTheme: TextSelectionThemeData(selectionColor: lightTheme.colorScheme.primary)),
      dark:
          darkTheme.copyWith(textSelectionTheme: TextSelectionThemeData(selectionColor: darkTheme.colorScheme.primary)),
      initial: AdaptiveThemeMode.system,
      builder: (theme, darkTheme) => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Missouri Young Democrats CRM',
        theme: theme.copyWith(appBarTheme: theme.appBarTheme.copyWith(elevation: 0.0)),
        darkTheme: darkTheme.copyWith(appBarTheme: darkTheme.appBarTheme.copyWith(elevation: 0.0)),
        navigatorKey: ns.key,
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          // Specifically for GNU/Linux & Android-x86 family, where touch isn't interpreted as a drag device by Flutter apparently.
          dragDevices: Platform.isLinux || Platform.isAndroid ? PointerDeviceKind.values.toSet() : null,
          // Prevent scrolling with multiple fingers accelerating the scrolling
          multitouchDragStrategy: MultitouchDragStrategy.latestPointer,
        ),
        home: PasswordScreen(child: Home()),
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.comma): const OpenSettingsIntent(),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.keyN): const OpenNewChatCreatorIntent(),
          if (kIsDesktop)
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const OpenNewChatCreatorIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF): const OpenSearchIntent(),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.keyR): const ReplyRecentIntent(),
          if (kIsDesktop) LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyR): const ReplyRecentIntent(),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.keyG): const StartIncrementalSyncIntent(),
          if (kIsDesktop)
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyR):
                const StartIncrementalSyncIntent(),
          if (kIsDesktop)
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyG): const StartIncrementalSyncIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.exclamation):
              const HeartRecentIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.at):
              const LikeRecentIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.numberSign):
              const DislikeRecentIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.dollar):
              const LaughRecentIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.percent):
              const EmphasizeRecentIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.caret):
              const QuestionRecentIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowDown): const OpenNextChatIntent(),
          if (kIsDesktop) LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.tab): const OpenNextChatIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowUp): const OpenPreviousChatIntent(),
          if (kIsDesktop)
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.tab):
                const OpenPreviousChatIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyI): const OpenChatDetailsIntent(),
          LogicalKeySet(LogicalKeyboardKey.escape): const GoBackIntent(),
        },
        builder: (context, child) => SafeArea(
          top: false,
          bottom: false,
          child: SecureApplication(
            child: Builder(
              builder: (context) {
                if (ss.canAuthenticate && (!ls.isAlive || !StartupTasks.uiReady.isCompleted)) {
                  if (ss.settings.shouldSecure.value) {
                    SecureApplicationProvider.of(context, listen: false)!.lock();
                    if (ss.settings.securityLevel.value == SecurityLevel.locked_and_secured) {
                      SecureApplicationProvider.of(context, listen: false)!.secure();
                    }
                  }
                }
                return TitleBarWrapper(
                  child: SecureGate(
                    blurr: 5,
                    opacity: 0,
                    lockedBuilder: (context, controller) {
                      final localAuth = LocalAuthentication();
                      if (!isAuthing) {
                        isAuthing = true;
                        localAuth
                            .authenticate(
                                localizedReason: 'Please authenticate to unlock the Missouri Young Democrats hub',
                                options: const AuthenticationOptions(stickyAuth: true))
                            .then((result) {
                          isAuthing = false;
                          if (result) {
                            SecureApplicationProvider.of(context, listen: false)!.authSuccess(unlock: true);
                            if (kIsDesktop) {
                              Future.delayed(Duration.zero, () {
                                chats.init();
                                socket;
                              });
                            }
                          }
                        });
                      }
                      return Container(
                        color: context.theme.colorScheme.background,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                child: Text(
                                  "The Missouri Young Democrats hub is currently locked. Please unlock to access your messages.",
                                  style: context.theme.textTheme.titleLarge,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Container(height: 20.0),
                              ClipOval(
                                child: Material(
                                  color: context.theme.colorScheme.primary, // button color
                                  child: InkWell(
                                    child: SizedBox(
                                        width: 60,
                                        height: 60,
                                        child: Icon(Icons.lock_open, color: context.theme.colorScheme.onPrimary)),
                                    onTap: () async {
                                      final localAuth = LocalAuthentication();
                                      bool didAuthenticate = await localAuth.authenticate(
                                          localizedReason: 'Please authenticate to unlock the Missouri Young Democrats hub',
                                          options: const AuthenticationOptions(stickyAuth: true));
                                      if (didAuthenticate) {
                                        controller!.authSuccess(unlock: true);
                                        if (kIsDesktop) {
                                          Future.delayed(Duration.zero, () {
                                            chats.init();
                                            socket;
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: child ?? Container(),
                  ),
                );
              },
            ),
          ),
        ),
        defaultTransition: Transition.cupertino,
      ),
    );
  }
}

class Home extends StatefulWidget {
  Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

enum _HomeSection { dashboard, members, chapters, meetings, conversations }

class _HomeState extends OptimizedState<Home> with WidgetsBindingObserver, TrayListener {
  bool serverCompatible = true;
  bool fullyLoaded = false;
  _HomeSection _currentSection = _HomeSection.dashboard;
  final PageStorageBucket _bucket = PageStorageBucket();

  @override
  void initState() {
    super.initState();

    // Bind the lifecycle events
    WidgetsBinding.instance.addObserver(this);

    /* ----- APP REFRESH LISTENER INITIALIZATION ----- */
    eventDispatcher.stream.listen((event) {
      if (event.item1 == 'refresh-all') {
        setState(() {});
      }
    });

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      StartupTasks.uiReady.complete();

      if (!ls.isBubble && !kIsWeb && !kIsDesktop) {
        ls.createFakePort();
      }

      ErrorWidget.builder = (FlutterErrorDetails error) {
        Logger.error("An unexpected error occurred when rendering.", error: error.exception, trace: error.stack);
        return CustomErrorWidget(
          "An unexpected error occurred when rendering.",
        );
      };
      /* ----- SERVER VERSION CHECK ----- */
      if (kIsWeb && ss.settings.finishedSetup.value) {
        int version = (await ss.getServerDetails()).item4;
        if (version < 42) {
          setState(() {
            serverCompatible = false;
          });
        }

        /* ----- CTRL-F OVERRIDE ----- */
        html.document.onKeyDown.listen((e) {
          if (e.keyCode == 114 || (e.ctrlKey && e.keyCode == 70)) {
            e.preventDefault();
          }
        });
      }

      if (kIsDesktop) {
        if (Platform.isWindows) {
          /* ----- CONTACT IMAGE CACHE DELETION ----- */
          Directory temp = Directory(join(fs.appDocDir.path, "temp"));
          if (await temp.exists()) await temp.delete(recursive: true);

          /* ----- BADGE ICON LISTENER ----- */
          GlobalChatService.unreadCount.listen((count) async {
            if (count == 0) {
                await WindowsTaskbar.resetOverlayIcon();
              } else if (count <= 9) {
                await WindowsTaskbar.setOverlayIcon(ThumbnailToolbarAssetIcon('assets/badges/badge-$count.ico'));
              } else {
                await WindowsTaskbar.setOverlayIcon(ThumbnailToolbarAssetIcon('assets/badges/badge-10.ico'));
              }
          });

          /* ----- WINDOW EFFECT INITIALIZATION ----- */
          eventDispatcher.stream.listen((event) async {
            if (event.item1 == 'theme-update') {
              EasyDebounce.debounce('window-effect', const Duration(milliseconds: 500), () async {
                if (mounted) {
                  await WindowEffects.setEffect(color: context.theme.colorScheme.background);
                }
              });
            }
          });

          Future(() => eventDispatcher.emit("theme-update", null));
        }

        /* ----- SYSTEM TRAY INITIALIZATION ----- */
        await initSystemTray();
        if (Platform.isWindows) {
          systemTray.registerSystemTrayEventHandler((eventName) {
            if (eventName == st.kSystemTrayEventClick) {
              onTrayIconMouseDown();
            } else if (eventName == st.kSystemTrayEventRightClick) {
              onTrayIconRightMouseDown();
            }
          });
        } else {
          trayManager.addListener(this);
        }

        /* ----- NOTIFICATIONS INITIALIZATION ----- */
        await localNotifier.setup(appName: "Missouri Young Democrats CRM");
      }

      if (!ss.settings.finishedSetup.value) {
        setState(() {
          fullyLoaded = true;
        });
      } else if ((fs.androidInfo?.version.sdkInt ?? 0) >= 33) {
        Permission.notification.request();
      }
    });
  }

  @override
  void onTrayIconMouseDown() async {
    await windowManager.show();
  }

  @override
  void onTrayIconRightMouseDown() async {
    if (Platform.isWindows) {
      await systemTray.popUpContextMenu();
    } else {
      await trayManager.popUpContextMenu();
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show_app':
        await windowManager.show();
        break;
      case 'hide_app':
        await windowManager.hide();
        break;
      case 'close_app':
        if (await windowManager.isPreventClose()) {
          await windowManager.setPreventClose(false);
        }
        await windowManager.close();
        break;
    }
  }

  @override
  void dispose() {
    // Clean up observer when app is fully closed
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(DesktopWindowListener.instance);
    if (Platform.isLinux) {
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  /// Just in case the theme doesn't change automatically
  /// Workaround for adaptive_theme issue #32
  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (AdaptiveTheme.maybeOf(context)?.mode == AdaptiveThemeMode.system) {
      if (AdaptiveTheme.maybeOf(context)?.brightness == Brightness.light) {
        AdaptiveTheme.maybeOf(context)?.setLight();
      } else {
        AdaptiveTheme.maybeOf(context)?.setDark();
      }
      AdaptiveTheme.maybeOf(context)?.setSystem();
    }
  }

  /// Render
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: ss.settings.immersiveMode.value
          ? Colors.transparent
          : context.theme.colorScheme.background, // navigation bar color
      systemNavigationBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      statusBarColor: Colors.transparent, // status bar color
      statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
    ));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value
            ? Colors.transparent
            : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness.opposite,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Actions(
        actions: {
          OpenSettingsIntent: OpenSettingsAction(context),
          OpenNewChatCreatorIntent: OpenNewChatCreatorAction(context),
          OpenSearchIntent: OpenSearchAction(context),
          OpenNextChatIntent: OpenNextChatAction(context),
          OpenPreviousChatIntent: OpenPreviousChatAction(context),
          StartIncrementalSyncIntent: StartIncrementalSyncAction(),
          GoBackIntent: GoBackAction(context),
        },
        child: Obx(() {
          if (!ss.settings.finishedSetup.value) {
            return const MYDLoadingScreen();
          }

          return Scaffold(
            backgroundColor: context.theme.colorScheme.background.themeOpacity(context),
            body: Builder(
              builder: (BuildContext context) {
                if (!serverCompatible && kIsWeb) {
                  return const FailureToStart(
                    otherTitle: "Server version too low, please upgrade!",
                    e: "Required Server Version: v0.2.0",
                  );
                }

                return _buildShell(context);
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildShell(BuildContext context) {
    final theme = Theme.of(context);
    final bool crmReady = CRMConfig.crmEnabled && CRMSupabaseService().isInitialized;

    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        children: [
          _buildTopBar(context, crmReady),
          Expanded(
            child: Container(
              color: theme.colorScheme.background,
              child: PageStorage(
                bucket: _bucket,
                child: IndexedStack(
                  index: _currentSection.index,
                  children: [
                    const DashboardScreen(key: PageStorageKey('dashboard-view')),
                    const MembersListScreen(key: PageStorageKey('members-view'), embed: true),
                    const MembersListScreen(
                      key: PageStorageKey('chapters-view'),
                      embed: true,
                      showChaptersOnly: true,
                    ),
                    const MeetingsScreen(key: PageStorageKey('meetings-view')),
                    ConversationList(
                      key: const PageStorageKey('conversations-view'),
                      showArchivedChats: false,
                      showUnknownSenders: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool crmReady) {
    final theme = Theme.of(context);
    final navButtons = [
      _buildNavButton(context, _HomeSection.dashboard, 'Dashboard', Icons.dashboard_outlined),
      _buildNavButton(context, _HomeSection.members, 'Members', Icons.groups_outlined, enabled: crmReady),
      _buildNavButton(context, _HomeSection.chapters, 'Chapters', Icons.account_tree_outlined, enabled: crmReady),
      _buildNavButton(context, _HomeSection.meetings, 'Meetings', Icons.video_camera_front_outlined, enabled: crmReady),
      _buildNavButton(context, _HomeSection.conversations, 'Conversations', Icons.chat_bubble_outline),
    ];

    final newMessageButton = ElevatedButton.icon(
      onPressed: () => _openNewMessage(context),
      icon: const Icon(Icons.add_comment),
      label: const Text('New Message'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );

    final settingsButton = Tooltip(
      message: 'Settings',
      child: IconButton(
        onPressed: () => Actions.invoke(context, const OpenSettingsIntent()),
        icon: const Icon(Icons.settings_outlined),
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: MediaQuery.of(context).size.width < 600 ? 8 : 18,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compact = constraints.maxWidth < 900;
          final bool mobile = constraints.maxWidth < 600;
          final navChildren = [
            ...navButtons,
            newMessageButton,
            settingsButton,
          ];

          final navigation = Wrap(
            spacing: mobile ? 6 : 12,
            runSpacing: mobile ? 6 : 12,
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: navChildren,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBranding(theme, mobile: mobile),
                SizedBox(height: mobile ? 6 : 12),
                navigation,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildBranding(theme),
              const Spacer(),
              navigation,
            ],
          );
        },
      ),
    );
  }

  Widget _buildBranding(ThemeData theme, {bool mobile = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _setSection(_HomeSection.dashboard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: mobile ? 40 : 60,
            width: mobile ? 150 : 220,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: mobile ? 0 : 4),
              child: Image.asset(
                'assets/images/text-logo-1320x440.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(
    BuildContext context,
    _HomeSection section,
    String label,
    IconData icon, {
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final bool isSelected = _currentSection == section;
    final bool mobile = MediaQuery.of(context).size.width < 600;

    return TextButton.icon(
      onPressed: enabled ? () => _setSection(section) : null,
      icon: Icon(icon, size: mobile ? 16 : 18),
      label: Text(label, style: mobile ? theme.textTheme.bodySmall : null),
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return theme.colorScheme.surfaceVariant.withOpacity(0.3);
          }
          return isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceVariant.withOpacity(0.7);
        }),
        foregroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return theme.disabledColor;
          }
          return isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
        }),
        padding: MaterialStateProperty.all(
          EdgeInsets.symmetric(
            horizontal: mobile ? 10 : 18,
            vertical: mobile ? 8 : 12,
          ),
        ),
        shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
      ),
    );
  }

  void _setSection(_HomeSection section) {
    if (_currentSection == section) return;
    setState(() => _currentSection = section);
  }

  void _openNewMessage(BuildContext context) async {
    final selection = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Single Message'),
              subtitle: const Text('Compose a conversation with one member'),
              onTap: () => Navigator.pop(context, 0),
            ),
            ListTile(
              leading: const Icon(Icons.groups),
              title: const Text('Member Outreach'),
              subtitle: const Text('Send individual messages to a filtered group'),
              onTap: () => Navigator.pop(context, 1),
            ),
          ],
        ),
      ),
    );

    if (selection == 0) {
      await Navigator.of(context, rootNavigator: true).push(
        ThemeSwitcher.buildPageRoute(
          builder: (context) => TitleBarWrapper(child: ChatCreator()),
        ),
      );
    } else if (selection == 1) {
      if (!CRMConfig.crmEnabled || !CRMSupabaseService().isInitialized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CRM Supabase is not configured.')),
        );
        return;
      }

      await Navigator.of(context).push(ThemeSwitcher.buildPageRoute(
        builder: (context) => TitleBarWrapper(child: BulkMessageScreen()),
      ));
    }
  }
}

Future<void> initSystemTray() async {
  if (Platform.isWindows) {
    await systemTray.initSystemTray(
      iconPath: 'assets/icon/icon.ico',
      toolTip: "Missouri Young Democrats CRM",
    );
  } else {
    String path;
    if (isFlatpak) {
      path = 'app.bluebubbles.BlueBubbles';
    } else if (isSnap) {
      path = p.joinAll([p.dirname(Platform.resolvedExecutable), 'data/flutter_assets/assets/icon', 'icon.png']);
    } else {
      path = 'assets/icon/icon.png';
    }

    await trayManager.setIcon(path);
  }

  await setSystemTrayContextMenu(windowHidden: !appWindow.isVisible);
}

Future<void> setSystemTrayContextMenu({bool windowHidden = false}) async {
  if (Platform.isWindows) {
    st.Menu menu = st.Menu();
    menu.buildFrom([
      st.MenuItemLabel(
        label: windowHidden ? 'Show App' : 'Hide App',
        onClicked: (st.MenuItemBase menuItem) async {
          if (windowHidden) {
            await windowManager.show();
          } else {
            await windowManager.hide();
          }
        },
      ),
      st.MenuSeparator(),
      st.MenuItemLabel(
        label: 'Close App',
        onClicked: (_) async {
          if (await windowManager.isPreventClose()) {
            await windowManager.setPreventClose(false);
          }
          await windowManager.close();
        },
      ),
    ]);

    await systemTray.setContextMenu(menu);
  } else {
    await trayManager.setContextMenu(Menu(
      items: [
        MenuItem(label: windowHidden ? 'Show App' : 'Hide App', key: windowHidden ? 'show_app' : 'hide_app'),
        MenuItem.separator(),
        MenuItem(label: 'Close App', key: 'close_app'),
      ],
    ));
  }
}
