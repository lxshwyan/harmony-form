import { FormFieldSpec, FormFieldType } from './FormField';
import { HmFormTheme } from '../theme/HmFormTheme';

/** Stable public state and events available to a custom field renderer. */
export class HmFormFieldRenderContext {
  readonly field: FormFieldSpec;
  readonly value: Object | undefined;
  readonly error: string | undefined;
  readonly validating: boolean;
  readonly disabled: boolean;
  readonly inputId: string;
  readonly description: string;
  readonly theme: HmFormTheme;
  readonly change: (value: Object | undefined) => void;
  readonly blur: () => void;

  constructor(field: FormFieldSpec, value: Object | undefined, error: string | undefined, validating: boolean,
    disabled: boolean, inputId: string, description: string, theme: HmFormTheme,
    change: (value: Object | undefined) => void, blur: () => void) {
    this.field = field;
    this.value = Array.isArray(value) ? (value as Array<Object>).slice() : value;
    this.error = error;
    this.validating = validating;
    this.disabled = disabled;
    this.inputId = inputId;
    this.description = description;
    this.theme = theme;
    this.change = change;
    this.blur = blur;
  }
}

/** A transferable global @Builder wrapped with ArkUI wrapBuilder(). */
export type HmFormFieldRenderer = WrappedBuilder<[HmFormFieldRenderContext]>;

/** Per-form custom renderer registry. Build it before passing it to HmFormView. */
export class HmFormRendererRegistry {
  private readonly renderers: Map<string, HmFormFieldRenderer> = new Map<string, HmFormFieldRenderer>();

  register(type: string, renderer: HmFormFieldRenderer): HmFormRendererRegistry {
    if (!FormFieldType.isCustom(type)) {
      throw new Error(`Custom renderer type must use FormFieldType.custom(): ${type}`);
    }
    if (this.renderers.has(type)) {
      throw new Error(`Duplicate custom form renderer: ${type}`);
    }
    this.renderers.set(type, renderer);
    return this;
  }

  has(type: string): boolean {
    return this.renderers.has(type);
  }

  private renderer(type: string): HmFormFieldRenderer {
    const renderer = this.renderers.get(type);
    if (renderer === undefined) {
      throw new Error(`Missing custom form renderer: ${type}`);
    }
    return renderer;
  }

  matching(type: string): HmFormFieldRenderer[] {
    return [this.renderer(type)];
  }

  assertFields(fields: FormFieldSpec[]): void {
    for (const field of fields) {
      if (FormFieldType.isCustom(field.type) && !this.renderers.has(field.type)) {
        throw new Error(`Missing custom form renderer: ${field.type}`);
      }
    }
  }
}
