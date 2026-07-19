import MoUIShellShell
import SwiftUI

@main
struct MoUIShellApp: App {
  @UIApplicationDelegateAdaptor(MOUIShellApplicationDelegate.self)
  private var applicationDelegate

  var body: some Scene {
    WindowGroup {
      MOUIShellRootView(configuration: .generated)
    }
  }
}
