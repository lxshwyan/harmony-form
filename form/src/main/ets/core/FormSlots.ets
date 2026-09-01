import { HmFormTheme } from '../theme/HmFormTheme';

/** Stable state and action exposed to a custom submit Builder. */
export class HmFormSubmitSlotContext {
  readonly submitting: boolean;
  readonly label: string;
  readonly description: string;
  readonly theme: HmFormTheme;
  readonly submit: () => void;

  constructor(submitting: boolean, label: string, description: string, theme: HmFormTheme,
    submit: () => void) {
    this.submitting = submitting;
    this.label = label;
    this.description = description;
    this.theme = theme;
    this.submit = submit;
  }
}
