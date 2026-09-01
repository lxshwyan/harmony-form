import { describe, it, expect } from '@ohos/hypium';
import { HmFormTheme } from '../main/ets/theme/HmFormTheme';

export default function hmFormThemeTest(): void {
  describe('HmFormTheme public tokens', (): void => {
    it('provides accessible light and dark presets', 0, (): void => {
      const light = HmFormTheme.light();
      const dark = HmFormTheme.dark();

      expect(light.surfaceColor).assertEqual('#FFFFFF');
      expect(dark.surfaceColor).assertEqual('#202124');
      expect(light.controlMinHeight).assertEqual(48);
      expect(dark.controlMinHeight).assertEqual(48);
      expect(light.textColor === dark.textColor).assertFalse();
    });

    it('allows focused token overrides without mutating presets', 0, (): void => {
      const custom = new HmFormTheme({
        'primaryColor': '#00AA66',
        'controlMinHeight': 56,
        'borderRadius': 12
      });

      expect(custom.primaryColor).assertEqual('#00AA66');
      expect(custom.controlMinHeight).assertEqual(56);
      expect(custom.borderRadius).assertEqual(12);
      expect(HmFormTheme.light().primaryColor).assertEqual('#3275F6');
    });
  });
}
