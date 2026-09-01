import { AnySchema, FormFieldOptions } from '@hmkit/validator';
import { validateFormPath } from './FormPath';

/** Built-in field renderers with explicit display/model adapters. */
export class FormFieldType {
  static readonly CUSTOM_PREFIX: string = 'custom:';
  static readonly TEXT: string = 'text';
  static readonly NUMBER: string = 'number';
  static readonly TEXTAREA: string = 'textarea';
  static readonly SELECT: string = 'select';
  static readonly RADIO: string = 'radio';
  static readonly CHECKBOX: string = 'checkbox';
  static readonly SWITCH: string = 'switch';
  static readonly DATE: string = 'date';

  static custom(name: string): string {
    const normalized = name.trim();
    if (normalized === '' || !/^[A-Za-z][A-Za-z0-9._-]*$/.test(normalized)) {
      throw new Error(`Invalid custom form field type: ${name}`);
    }
    return `${FormFieldType.CUSTOM_PREFIX}${normalized}`;
  }

  static isCustom(type: string): boolean {
    const name = type.startsWith(FormFieldType.CUSTOM_PREFIX)
      ? type.substring(FormFieldType.CUSTOM_PREFIX.length)
      : '';
    return name !== '' && /^[A-Za-z][A-Za-z0-9._-]*$/.test(name);
  }
}

/** Stable field-level Builder slot names. */
export class FormFieldSlot {
  static readonly PREFIX: string = 'prefix';
  static readonly SUFFIX: string = 'suffix';
  static readonly LABEL: string = 'label';
  static readonly HELP: string = 'help';
  static readonly ERROR: string = 'error';
}

/** Portable TextInput keyboard choices exposed without leaking ArkUI enums across HAR boundaries. */
export class FormTextInputType {
  static readonly NORMAL: string = 'normal';
  static readonly NUMBER: string = 'number';
  static readonly PHONE: string = 'phone';
  static readonly EMAIL: string = 'email';
  static readonly PASSWORD: string = 'password';
}

/** A condition over the current flat form model. */
export type FormCondition = (values: Record<string, Object>) => boolean;

/** Business option. label is rendered by ArkUI while value is stored in the form model. */
export class FormSelectOption {
  readonly label: string;
  readonly value: string;

  constructor(label: string, value: string) {
    this.label = label;
    this.value = value;
  }
}

/** Runtime source for remotely supplied Select/Radio/Checkbox options. */
export type FormOptionsLoader = () => Promise<FormSelectOption[]>;

/** Optional visual behavior. Validation rules stay in schema/validationOptions. */
export interface FormFieldUIOptions {
  help?: string;
  disabled?: boolean;
  maxLength?: number;
  options?: FormSelectOption[];
  dependencies?: string[];
  visibleWhen?: FormCondition;
  disabledWhen?: FormCondition;
  startDate?: Date;
  endDate?: Date;
  slots?: string[];
  span?: number;
  optionsLoader?: FormOptionsLoader;
  keepAlive?: boolean;
  inputType?: string;
}

/** Stable, explicit UI metadata. Validation semantics remain inside schema. */
export class FormFieldSpec {
  readonly name: string;
  readonly type: string;
  readonly label: string;
  readonly placeholder: string;
  readonly schema: AnySchema<Object | null>;
  readonly validationOptions: FormFieldOptions;
  readonly help: string;
  readonly disabled: boolean;
  readonly maxLength: number | undefined;
  readonly options: FormSelectOption[];
  readonly dependencies: string[];
  readonly visibleWhen: FormCondition | undefined;
  readonly disabledWhen: FormCondition | undefined;
  readonly startDate: Date;
  readonly endDate: Date;
  readonly slots: string[];
  readonly span: number;
  readonly optionsLoader: FormOptionsLoader | undefined;
  readonly keepAlive: boolean;
  readonly inputType: string;

  constructor(name: string, type: string, label: string, schema: AnySchema<Object | null>, placeholder?: string,
    validationOptions?: FormFieldOptions, uiOptions?: FormFieldUIOptions) {
    this.validateIdentity(name, type);
    this.name = name;
    this.type = type;
    this.label = label;
    this.schema = schema;
    this.placeholder = placeholder ?? '';
    this.validationOptions = validationOptions ?? { dependencies: [] };
    this.help = uiOptions?.help ?? '';
    this.disabled = uiOptions?.disabled ?? false;
    this.maxLength = uiOptions?.maxLength;
    this.options = uiOptions?.options === undefined ? [] : uiOptions.options.slice();
    this.dependencies = uiOptions?.dependencies === undefined ? [] : uiOptions.dependencies.slice();
    this.visibleWhen = uiOptions?.visibleWhen;
    this.disabledWhen = uiOptions?.disabledWhen;
    this.startDate = uiOptions?.startDate === undefined
      ? new Date(1970, 0, 1)
      : new Date(uiOptions.startDate.getTime());
    this.endDate = uiOptions?.endDate === undefined
      ? new Date(2100, 11, 31)
      : new Date(uiOptions.endDate.getTime());
    this.slots = uiOptions?.slots === undefined ? [] : uiOptions.slots.slice();
    this.span = uiOptions?.span ?? 12;
    this.optionsLoader = uiOptions?.optionsLoader;
    this.keepAlive = uiOptions?.keepAlive ?? false;
    this.inputType = uiOptions?.inputType ?? (type === FormFieldType.NUMBER
      ? FormTextInputType.NUMBER : FormTextInputType.NORMAL);
    this.validateOptions();
  }

  usesSlot(slot: string): boolean {
    return this.slots.includes(slot);
  }

  loadsOptions(): boolean {
    return this.optionsLoader !== undefined;
  }

  selectIndex(value: Object | undefined, options?: FormSelectOption[]): number {
    const source = options ?? this.options;
    for (let index = 0; index < source.length; index++) {
      if (source[index].value === value) {
        return index;
      }
    }
    return -1;
  }

  selectValue(index: number, options?: FormSelectOption[]): string | undefined {
    const source = options ?? this.options;
    if (index < 0 || index >= source.length) {
      return undefined;
    }
    return source[index].value;
  }

  selectLabel(value: Object | undefined, options?: FormSelectOption[]): string {
    const source = options ?? this.options;
    const index = this.selectIndex(value, source);
    return index < 0 ? '' : source[index].label;
  }

  checkboxValues(value: Object | undefined, options?: FormSelectOption[]): string[] {
    if (!Array.isArray(value)) {
      return [];
    }
    const source = value as Array<Object>;
    const result: string[] = [];
    for (const option of options ?? this.options) {
      if (source.includes(option.value)) {
        result.push(option.value);
      }
    }
    return result;
  }

  isOptionSelected(value: Object | undefined, optionValue: string, options?: FormSelectOption[]): boolean {
    return this.checkboxValues(value, options).includes(optionValue);
  }

  toggleOptionValue(value: Object | undefined, optionValue: string, selected: boolean,
    options?: FormSelectOption[]): string[] {
    const source = options ?? this.options;
    const current = this.checkboxValues(value, source);
    const selectedValues: Set<string> = new Set<string>();
    for (const currentValue of current) {
      selectedValues.add(currentValue);
    }
    if (selected) {
      selectedValues.add(optionValue);
    } else {
      selectedValues.delete(optionValue);
    }
    const result: string[] = [];
    for (const option of source) {
      if (selectedValues.has(option.value)) {
        result.push(option.value);
      }
    }
    return result;
  }

  isVisible(values: Record<string, Object>): boolean {
    return this.visibleWhen === undefined || this.visibleWhen(values);
  }

  isDisabled(values: Record<string, Object>): boolean {
    return this.disabled || (this.disabledWhen !== undefined && this.disabledWhen(values));
  }

  isActive(values: Record<string, Object>): boolean {
    return this.isVisible(values) && !this.isDisabled(values);
  }

  dateModelValue(value: Date): string {
    return `${value.getFullYear()}-${this.twoDigits(value.getMonth() + 1)}-${this.twoDigits(value.getDate())}`;
  }

  dateDisplayValue(value: Object | undefined): string {
    if (value === undefined || value === null || value === '') {
      return '';
    }
    if (value instanceof Date) {
      return this.dateModelValue(value as Date);
    }
    const text = `${value}`;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) {
      return '';
    }
    const year = parseInt(text.substring(0, 4), 10);
    const month = parseInt(text.substring(5, 7), 10);
    const day = parseInt(text.substring(8, 10), 10);
    const parsed = new Date(year, month - 1, day);
    return parsed.getFullYear() === year && parsed.getMonth() === month - 1 && parsed.getDate() === day ? text : '';
  }

  dateSelected(value: Object | undefined): Date {
    const text = this.dateDisplayValue(value);
    if (text === '') {
      return new Date();
    }
    return new Date(
      parseInt(text.substring(0, 4), 10),
      parseInt(text.substring(5, 7), 10) - 1,
      parseInt(text.substring(8, 10), 10)
    );
  }

  private twoDigits(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private validateIdentity(name: string, type: string): void {
    if (name.trim() === '') {
      throw new Error('Form field name must not be empty');
    }
    validateFormPath(name);
    const supported = [FormFieldType.TEXT, FormFieldType.NUMBER, FormFieldType.TEXTAREA,
      FormFieldType.SELECT, FormFieldType.RADIO, FormFieldType.CHECKBOX, FormFieldType.SWITCH, FormFieldType.DATE];
    if (!supported.includes(type) && !FormFieldType.isCustom(type)) {
      throw new Error(`Unsupported form field type: ${type}`);
    }
  }

  private validateOptions(): void {
    const validationDependencies = this.validationOptions.dependencies ?? [];
    for (const dependency of validationDependencies) validateFormPath(dependency);
    for (const dependency of this.dependencies) validateFormPath(dependency);
    if (this.maxLength !== undefined && this.maxLength <= 0) {
      throw new Error(`Form field maxLength must be positive: ${this.name}`);
    }
    if (this.span < 1 || this.span > 12 || this.span % 1 !== 0) {
      throw new Error(`Form field span must be an integer from 1 to 12: ${this.name}`);
    }
    const inputTypes = [FormTextInputType.NORMAL, FormTextInputType.NUMBER, FormTextInputType.PHONE,
      FormTextInputType.EMAIL, FormTextInputType.PASSWORD];
    if (!inputTypes.includes(this.inputType)) {
      throw new Error(`Unsupported form text input type '${this.inputType}' in field: ${this.name}`);
    }
    if (this.type !== FormFieldType.TEXT && this.type !== FormFieldType.NUMBER &&
      this.inputType !== FormTextInputType.NORMAL) {
      throw new Error(`Text input type is only supported for text/number fields: ${this.name}`);
    }
    if (this.type === FormFieldType.NUMBER && this.inputType !== FormTextInputType.NUMBER) {
      throw new Error(`Number fields require the number input type: ${this.name}`);
    }
    const choice = this.type === FormFieldType.SELECT || this.type === FormFieldType.RADIO ||
      this.type === FormFieldType.CHECKBOX;
    if (choice) {
      if (this.options.length === 0 && this.optionsLoader === undefined) {
        throw new Error(`Form field options must not be empty: ${this.name}`);
      }
      const values: Set<string> = new Set<string>();
      for (const option of this.options) {
        if (values.has(option.value)) {
          throw new Error(`Duplicate form option value '${option.value}' in field: ${this.name}`);
        }
        values.add(option.value);
      }
    } else if (this.optionsLoader !== undefined) {
      throw new Error(`Async options are only supported for choice fields: ${this.name}`);
    }
    if (this.type === FormFieldType.DATE && this.startDate.getTime() > this.endDate.getTime()) {
      throw new Error(`Form field startDate must not be after endDate: ${this.name}`);
    }
    const supportedSlots = [FormFieldSlot.PREFIX, FormFieldSlot.SUFFIX, FormFieldSlot.LABEL,
      FormFieldSlot.HELP, FormFieldSlot.ERROR];
    const slots: Set<string> = new Set<string>();
    for (const slot of this.slots) {
      if (!supportedSlots.includes(slot)) {
        throw new Error(`Unsupported form field slot '${slot}' in field: ${this.name}`);
      }
      if (slots.has(slot)) {
        throw new Error(`Duplicate form field slot '${slot}' in field: ${this.name}`);
      }
      slots.add(slot);
    }
  }
}
