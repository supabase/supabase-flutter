//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import app_links
import device_info_plus
import package_info_plus
import passkeys_darwin
import shared_preferences_foundation
import ua_client_hints
import url_launcher_macos

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  AppLinksMacosPlugin.register(with: registry.registrar(forPlugin: "AppLinksMacosPlugin"))
  DeviceInfoPlusMacosPlugin.register(with: registry.registrar(forPlugin: "DeviceInfoPlusMacosPlugin"))
  FPPPackageInfoPlusPlugin.register(with: registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin"))
  PasskeysPlugin.register(with: registry.registrar(forPlugin: "PasskeysPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
  UAClientHintsPlugin.register(with: registry.registrar(forPlugin: "UAClientHintsPlugin"))
  UrlLauncherPlugin.register(with: registry.registrar(forPlugin: "UrlLauncherPlugin"))
}
