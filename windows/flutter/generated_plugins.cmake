#
# Generated file, do not edit.
#

list(APPEND FLUTTER_PLUGIN_LIST
  app_links
  connectivity_plus
  desktop_drop
  desktop_webview_window
  dynamic_color
  emoji_picker_flutter
  file_selector_windows
  firebase_core
  flutter_inappwebview_windows
  flutter_secure_storage_windows
  geolocator_windows
  irondash_engine_context
  maps_launcher
  media_kit_libs_windows_video
  media_kit_video
  objectbox_flutter_libs
  pasteboard
  printing
  record_windows
  secure_application
  share_plus
  super_native_extensions
  url_launcher_windows
  window_to_front
)

list(APPEND FLUTTER_FFI_PLUGIN_LIST
  jni
  media_kit_native_event_loop
)

set(PLUGIN_BUNDLED_LIBRARIES)

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${plugin}/windows plugins/${plugin})
  target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${plugin}_bundled_libraries})
endforeach(plugin)

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${ffi_plugin}/windows plugins/${ffi_plugin})
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${ffi_plugin}_bundled_libraries})
endforeach(ffi_plugin)
