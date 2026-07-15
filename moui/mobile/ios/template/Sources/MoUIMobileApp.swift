import MoUIMobileShell
import SwiftUI

@main
struct MoUIMobileApp: App {
  @UIApplicationDelegateAdaptor(MOUIMobileApplicationDelegate.self)
  private var applicationDelegate

  var body: some Scene {
    WindowGroup {
      MOUIMobileRootView(configuration: .generated)
    }
  }
}
