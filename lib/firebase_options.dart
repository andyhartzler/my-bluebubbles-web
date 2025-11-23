// GENERATED file to satisfy build requirements.
//
// These Firebase options intentionally read from compile-time environment
// variables so that deployments (Netlify, CI, local) can inject credentials
// without regenerating the file. Ensure the expected FIREBASE_* environment
// variables are provided in the build environment.
// ignore_for_file: constant_identifier_names, lines_longer_than_80_chars

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_WEB_API_KEY', defaultValue: ''),
    appId: String.fromEnvironment('FIREBASE_WEB_APP_ID', defaultValue: ''),
    messagingSenderId:
        String.fromEnvironment('FIREBASE_WEB_MESSAGING_SENDER_ID', defaultValue: ''),
    projectId: String.fromEnvironment('FIREBASE_WEB_PROJECT_ID', defaultValue: ''),
    authDomain: String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN', defaultValue: ''),
    storageBucket:
        String.fromEnvironment('FIREBASE_WEB_STORAGE_BUCKET', defaultValue: ''),
    measurementId:
        String.fromEnvironment('FIREBASE_WEB_MEASUREMENT_ID', defaultValue: ''),
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_ANDROID_API_KEY', defaultValue: ''),
    appId: String.fromEnvironment('FIREBASE_ANDROID_APP_ID', defaultValue: ''),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_ANDROID_MESSAGING_SENDER_ID',
      defaultValue: '',
    ),
    projectId: String.fromEnvironment('FIREBASE_ANDROID_PROJECT_ID', defaultValue: ''),
    storageBucket:
        String.fromEnvironment('FIREBASE_ANDROID_STORAGE_BUCKET', defaultValue: ''),
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_IOS_API_KEY', defaultValue: ''),
    appId: String.fromEnvironment('FIREBASE_IOS_APP_ID', defaultValue: ''),
    messagingSenderId:
        String.fromEnvironment('FIREBASE_IOS_MESSAGING_SENDER_ID', defaultValue: ''),
    projectId: String.fromEnvironment('FIREBASE_IOS_PROJECT_ID', defaultValue: ''),
    storageBucket:
        String.fromEnvironment('FIREBASE_IOS_STORAGE_BUCKET', defaultValue: ''),
    iosClientId:
        String.fromEnvironment('FIREBASE_IOS_CLIENT_ID', defaultValue: ''),
    iosBundleId:
        String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID', defaultValue: ''),
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_MACOS_API_KEY', defaultValue: ''),
    appId: String.fromEnvironment('FIREBASE_MACOS_APP_ID', defaultValue: ''),
    messagingSenderId:
        String.fromEnvironment('FIREBASE_MACOS_MESSAGING_SENDER_ID', defaultValue: ''),
    projectId: String.fromEnvironment('FIREBASE_MACOS_PROJECT_ID', defaultValue: ''),
    storageBucket:
        String.fromEnvironment('FIREBASE_MACOS_STORAGE_BUCKET', defaultValue: ''),
    iosClientId:
        String.fromEnvironment('FIREBASE_MACOS_CLIENT_ID', defaultValue: ''),
    iosBundleId:
        String.fromEnvironment('FIREBASE_MACOS_BUNDLE_ID', defaultValue: ''),
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_WINDOWS_API_KEY', defaultValue: ''),
    appId: String.fromEnvironment('FIREBASE_WINDOWS_APP_ID', defaultValue: ''),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_WINDOWS_MESSAGING_SENDER_ID',
      defaultValue: '',
    ),
    projectId: String.fromEnvironment('FIREBASE_WINDOWS_PROJECT_ID', defaultValue: ''),
    storageBucket:
        String.fromEnvironment('FIREBASE_WINDOWS_STORAGE_BUCKET', defaultValue: ''),
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_LINUX_API_KEY', defaultValue: ''),
    appId: String.fromEnvironment('FIREBASE_LINUX_APP_ID', defaultValue: ''),
    messagingSenderId:
        String.fromEnvironment('FIREBASE_LINUX_MESSAGING_SENDER_ID', defaultValue: ''),
    projectId: String.fromEnvironment('FIREBASE_LINUX_PROJECT_ID', defaultValue: ''),
    storageBucket:
        String.fromEnvironment('FIREBASE_LINUX_STORAGE_BUCKET', defaultValue: ''),
  );
}
