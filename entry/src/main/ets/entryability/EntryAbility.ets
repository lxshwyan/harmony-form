import { UIAbility } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(windowStage: window.WindowStage): void {
    try {
      windowStage.loadContent('pages/Index', (error: BusinessError): void => {
        if (error.code !== 0) {
          hilog.error(DOMAIN, 'HmkitFormDemo', 'Failed to load page: %{public}s', error.message);
        }
      });
    } catch (error) {
      const businessError = error as BusinessError;
      hilog.error(DOMAIN, 'HmkitFormDemo', 'loadContent threw: %{public}s', businessError.message);
    }
  }
}
