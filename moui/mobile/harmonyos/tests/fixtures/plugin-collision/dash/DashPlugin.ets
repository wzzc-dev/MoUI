import { MoUIPlugin, MoUIPluginRegistry } from '../../moui/MoUIPlugins';

export class DashPlugin implements MoUIPlugin {
  readonly id: string = 'dev.fixture.a-b';
  readonly marker: string = 'plugin-id-with-dash';

  install(_registry: MoUIPluginRegistry): void {
  }
}
