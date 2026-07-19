import { MoUIPluginRegistry } from './MoUIPlugins';

export function installGeneratedPlugins(): void {
  MoUIPluginRegistry.shared.install([]);
}
