//
// Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <webos_native_player/webos_native_player_plugin.h>
#include <shared_preferences_webos/shared_preferences_webos_plugin.h>
#include <video_player_webos/video_player_web_os_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  WebosNativePlayerPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WebosNativePlayerPlugin"));
  SharedPreferencesWebosPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("SharedPreferencesWebosPlugin"));
  VideoPlayerWebOsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("VideoPlayerWebOsPlugin"));
}
