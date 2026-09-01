/** Public, host-controlled visual tokens used by HmFormView. */
export interface HmFormThemeOptions {
  textColor?: string;
  secondaryTextColor?: string;
  placeholderColor?: string;
  surfaceColor?: string;
  disabledTextColor?: string;
  disabledSurfaceColor?: string;
  borderColor?: string;
  errorColor?: string;
  validatingColor?: string;
  primaryColor?: string;
  controlMinHeight?: number;
  textAreaMinHeight?: number;
  borderRadius?: number;
}

/**
 * Stable theme value object. Replace the instance in the host to switch themes.
 * Colors intentionally use portable ArkUI color strings across HAR boundaries.
 */
export class HmFormTheme {
  readonly textColor: string;
  readonly secondaryTextColor: string;
  readonly placeholderColor: string;
  readonly surfaceColor: string;
  readonly disabledTextColor: string;
  readonly disabledSurfaceColor: string;
  readonly borderColor: string;
  readonly errorColor: string;
  readonly validatingColor: string;
  readonly primaryColor: string;
  readonly controlMinHeight: number;
  readonly textAreaMinHeight: number;
  readonly borderRadius: number;

  constructor(options: HmFormThemeOptions = {}) {
    this.textColor = options.textColor === undefined ? '#3B3B3B' : options.textColor;
    this.secondaryTextColor = options.secondaryTextColor === undefined ? '#777777' : options.secondaryTextColor;
    this.placeholderColor = options.placeholderColor === undefined ? '#999999' : options.placeholderColor;
    this.surfaceColor = options.surfaceColor === undefined ? '#FFFFFF' : options.surfaceColor;
    this.disabledTextColor = options.disabledTextColor === undefined ? '#999999' : options.disabledTextColor;
    this.disabledSurfaceColor = options.disabledSurfaceColor === undefined ? '#F2F3F5' : options.disabledSurfaceColor;
    this.borderColor = options.borderColor === undefined ? '#D9D9D9' : options.borderColor;
    this.errorColor = options.errorColor === undefined ? '#E84026' : options.errorColor;
    this.validatingColor = options.validatingColor === undefined ? '#3275F6' : options.validatingColor;
    this.primaryColor = options.primaryColor === undefined ? '#3275F6' : options.primaryColor;
    this.controlMinHeight = options.controlMinHeight === undefined ? 48 : options.controlMinHeight;
    this.textAreaMinHeight = options.textAreaMinHeight === undefined ? 96 : options.textAreaMinHeight;
    this.borderRadius = options.borderRadius === undefined ? 8 : options.borderRadius;
  }

  static light(): HmFormTheme {
    return new HmFormTheme();
  }

  static dark(): HmFormTheme {
    return new HmFormTheme({
      'textColor': '#F2F3F5',
      'secondaryTextColor': '#B8BCC4',
      'placeholderColor': '#8A9099',
      'surfaceColor': '#202124',
      'disabledTextColor': '#777D87',
      'disabledSurfaceColor': '#2A2C30',
      'borderColor': '#555A63',
      'errorColor': '#FF776D',
      'validatingColor': '#75A7FF',
      'primaryColor': '#75A7FF'
    });
  }
}
