import { FormFieldSpec } from './FormField';
import { FormSectionSpec, FormStepSpec, FormStructureController } from './FormStructure';
import { HmFormTheme } from '../theme/HmFormTheme';

/** Immutable validation error with optional form-structure location metadata. */
export class HmFormErrorSummaryItem {
  readonly name: string;
  readonly label: string;
  readonly message: string;
  readonly sectionId: string;
  readonly sectionTitle: string;
  readonly stepId: string;
  readonly stepTitle: string;

  constructor(name: string, label: string, message: string, section?: FormSectionSpec, step?: FormStepSpec) {
    this.name = name;
    this.label = label;
    this.message = message;
    this.sectionId = section?.id ?? '';
    this.sectionTitle = section?.title ?? '';
    this.stepId = step?.id ?? '';
    this.stepTitle = step?.title ?? '';
  }

  location(): string {
    if (this.stepTitle !== '' && this.sectionTitle !== '') return `${this.stepTitle} / ${this.sectionTitle}`;
    if (this.stepTitle !== '') return this.stepTitle;
    return this.sectionTitle;
  }
}

/** Stable state and action exposed to a custom error-summary Builder. */
export class HmFormErrorSummaryContext {
  readonly items: HmFormErrorSummaryItem[];
  readonly title: string;
  readonly description: string;
  readonly theme: HmFormTheme;
  readonly activate: (name: string) => void;

  constructor(items: HmFormErrorSummaryItem[], title: string, description: string, theme: HmFormTheme,
    activate: (name: string) => void) {
    this.items = items.slice();
    this.title = title;
    this.description = description;
    this.theme = theme;
    this.activate = activate;
  }
}

/** Builds a defensive summary in field-definition order, ignoring unknown errors. */
export function buildFormErrorSummaryItems(fields: FormFieldSpec[], errors: Record<string, string>,
  structure?: FormStructureController): HmFormErrorSummaryItem[] {
  const result: HmFormErrorSummaryItem[] = [];
  for (const field of fields) {
    const message = errors[field.name];
    if (message === undefined) continue;
    const section = structure?.sectionForField(field.name);
    result.push(new HmFormErrorSummaryItem(field.name, field.label, message, section,
      structure?.stepForField(field.name)));
  }
  return result;
}
