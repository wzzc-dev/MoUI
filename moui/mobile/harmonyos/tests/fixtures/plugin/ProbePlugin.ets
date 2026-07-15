import { FrameNode, NodeController, UIContext } from '@kit.ArkUI';

import {
  MoUIHostServiceCompletion,
  MoUIHostServiceHandler,
  MoUIHostServiceRequest,
  MoUIHostServiceTask,
  MoUIPlatformViewEventSink,
  MoUIPlatformViewFactory,
  MoUIPlatformViewPlacement,
  MoUIPlugin,
  MoUIPluginRegistry
} from '../../moui/MoUIPlugins';

class ProbeNodeController extends NodeController {
  makeNode(_uiContext: UIContext): FrameNode | null {
    return null;
  }
}

class ProbePlatformViewFactory implements MoUIPlatformViewFactory {
  create(_id: string, events: MoUIPlatformViewEventSink): NodeController {
    events.send('created');
    return new ProbeNodeController();
  }

  update(_controller: NodeController, _placement: MoUIPlatformViewPlacement): void {
  }

  dispose(_controller: NodeController): void {
  }
}

class ProbeHostServiceTask implements MoUIHostServiceTask {
  cancel(): void {
  }
}

class ProbeHostServiceHandler implements MoUIHostServiceHandler {
  handle(request: MoUIHostServiceRequest, completion: MoUIHostServiceCompletion): MoUIHostServiceTask | undefined {
    completion.ok(`${request.operation}:${request.payload}`);
    return new ProbeHostServiceTask();
  }
}

export class ProbePlugin implements MoUIPlugin {
  readonly id: string = 'dev.fixture.harmony-probe';

  install(registry: MoUIPluginRegistry): void {
    registry.registerPlatformView('dev.fixture.probe-view', new ProbePlatformViewFactory());
    registry.registerHostService('dev.fixture.echo', new ProbeHostServiceHandler());
  }
}
