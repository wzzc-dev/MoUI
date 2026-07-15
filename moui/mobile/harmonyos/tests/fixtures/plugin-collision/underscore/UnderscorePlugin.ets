import { MoUIPlugin, MoUIPluginRegistry } from '../../moui/MoUIPlugins';

export class UnderscorePlugin implements MoUIPlugin {
  readonly id: string = 'dev.fixture.a_b';
  readonly marker: string = 'plugin-id-with-underscore';

  install(_registry: MoUIPluginRegistry): void {
  }
}
