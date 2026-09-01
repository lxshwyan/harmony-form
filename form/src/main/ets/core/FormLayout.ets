/** Optional responsive grid configuration for HmFormView. */
export interface HmFormLayoutOptions {
  breakpoint?: string;
  columnGap?: number;
  rowGap?: number;
}

/** Immutable 12-column layout. Fields stay full-width below breakpoint. */
export class HmFormLayout {
  readonly breakpoint: string;
  readonly columnGap: number;
  readonly rowGap: number;

  constructor(options?: HmFormLayoutOptions) {
    this.breakpoint = options?.breakpoint ?? '600vp';
    this.columnGap = options?.columnGap ?? 16;
    this.rowGap = options?.rowGap ?? 16;
    this.validate();
  }

  static responsive(): HmFormLayout {
    return new HmFormLayout();
  }

  private validate(): void {
    if (!/^([1-9]\d*)(\.\d+)?vp$/.test(this.breakpoint)) {
      throw new Error(`HmFormLayout breakpoint must be a positive vp length: ${this.breakpoint}`);
    }
    if (this.columnGap < 0 || this.rowGap < 0) {
      throw new Error('HmFormLayout gaps must not be negative');
    }
  }
}
