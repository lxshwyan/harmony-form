import { FormFieldOptions, FormFieldState, FormValidator, FormValidatorOptions } from '@hmkit/validator';
import { FormFieldSpec, FormSelectOption } from './FormField';
import { copyFormValues, formPathConflicts, formValuesEqual, getFormValue, setFormValue,
  validateFormPath } from './FormPath';

/** Runtime behavior that does not belong to UI field metadata. */
export interface FormControllerOptions {
  debounceMs?: number;
}

/** Observable bridge between ArkUI V2 and the validator's UI-independent state machine. */
@ObservedV2
export class FormController {
  @Trace values: Record<string, Object> = {};
  @Trace errors: Record<string, string> = {};
  @Trace validating: Record<string, boolean> = {};
  @Trace submitting: boolean = false;
  @Trace optionValues: Record<string, FormSelectOption[]> = {};
  @Trace optionsLoading: Record<string, boolean> = {};
  @Trace optionErrors: Record<string, string> = {};

  private readonly fields: FormFieldSpec[];
  private readonly validator: FormValidator;
  private disposed: boolean = false;
  private lifecycleVersion: number = 0;
  private controlledEchoFields: Set<string> = new Set<string>();
  private optionLifecycleVersion: number = 0;
  private optionRequestVersions: Map<string, number> = new Map<string, number>();

  constructor(fields: FormFieldSpec[], initialValues?: Record<string, Object>, options?: FormControllerOptions) {
    this.assertFields(fields);
    this.fields = fields.slice();
    this.values = copyFormValues(initialValues ?? {});

    const shape: Record<string, import('@hmkit/validator').AnySchema> = {};
    const fieldOptions: Record<string, FormFieldOptions> = {};
    for (const field of this.fields) {
      shape[field.name] = field.schema as import('@hmkit/validator').AnySchema;
      fieldOptions[field.name] = {
        triggers: field.validationOptions.triggers,
        debounceMs: field.validationOptions.debounceMs,
        dependencies: this.mergeDependencies(field.validationOptions.dependencies, field.dependencies)
      };
    }
    const validatorOptions: FormValidatorOptions = {
      fields: fieldOptions,
      debounceMs: options?.debounceMs ?? 250
    };
    this.validator = new FormValidator(shape, validatorOptions);
  }

  getValues(): Record<string, Object> {
    return copyFormValues(this.values);
  }

  getValue(name: string): Object | undefined {
    return getFormValue(this.values, name);
  }

  getFieldState(name: string): FormFieldState {
    return this.validator.getFieldState(name);
  }

  displayValue(name: string): string {
    return this.toDisplayValue(getFormValue(this.values, name));
  }

  getOptions(name: string): FormSelectOption[] {
    const loaded = this.optionValues[name];
    if (loaded !== undefined) {
      return loaded.slice();
    }
    const field = this.findField(name);
    return field === undefined ? [] : field.options.slice();
  }

  loadAllOptions(): void {
    for (const field of this.fields) {
      if (field.loadsOptions() && this.optionValues[field.name] === undefined &&
        this.optionsLoading[field.name] !== true) {
        this.loadOptions(field.name);
      }
    }
  }

  async loadOptions(name: string): Promise<void> {
    const field = this.findField(name);
    if (this.disposed || field === undefined || field.optionsLoader === undefined) {
      return;
    }
    const requestVersion = (this.optionRequestVersions.get(name) ?? 0) + 1;
    this.optionRequestVersions.set(name, requestVersion);
    const lifecycleVersion = this.optionLifecycleVersion;
    this.optionsLoading = this.withBoolean(this.optionsLoading, name, true);
    this.optionErrors = this.withoutString(this.optionErrors, name);
    try {
      const options = await field.optionsLoader();
      this.validateLoadedOptions(name, options);
      if (this.optionRequestActive(name, requestVersion, lifecycleVersion)) {
        this.optionValues = this.withOptions(this.optionValues, name, options);
      }
    } catch (error) {
      if (this.optionRequestActive(name, requestVersion, lifecycleVersion)) {
        this.optionErrors = this.withString(this.optionErrors, name, this.optionErrorMessage(error));
      }
    } finally {
      if (this.optionRequestActive(name, requestVersion, lifecycleVersion)) {
        this.optionsLoading = this.withoutBoolean(this.optionsLoading, name);
      }
    }
  }

  /**
   * Reconciles a parent-controlled values replacement without marking fields as
   * dirty or touched. Equal values are treated as the echo of an internal change
   * and preserve the current validation state.
   */
  syncValues(values: Record<string, Object>): boolean {
    if (this.disposed || formValuesEqual(this.values, values)) {
      return false;
    }
    this.controlledEchoFields.clear();
    for (const field of this.fields) {
      if (this.toDisplayValue(getFormValue(this.values, field.name)) !==
        this.toDisplayValue(getFormValue(values, field.name))) {
        this.controlledEchoFields.add(field.name);
      }
    }
    this.lifecycleVersion++;
    this.validator.reset();
    this.values = copyFormValues(values);
    this.errors = {};
    this.validating = {};
    this.submitting = false;
    return true;
  }

  async onChange(name: string, value: Object | undefined): Promise<void> {
    if (this.disposed) {
      return;
    }
    if (this.consumeControlledEcho(name, value)) {
      return;
    }
    if (!this.isFieldActive(name)) {
      return;
    }
    const version = this.lifecycleVersion;
    this.values = this.withValue(name, value);
    this.errors = this.copyRelevantErrors(this.errors);
    const pending = this.validator.onChange(name, value, this.validationValues());
    this.syncValidating();
    try {
      await pending;
      if (!this.disposed && version === this.lifecycleVersion) {
        this.errors = this.copyRelevantErrors(this.validator.getState().errors);
      }
    } finally {
      if (version === this.lifecycleVersion) {
        this.syncValidating();
      }
    }
  }

  async onBlur(name: string): Promise<void> {
    if (this.disposed || !this.isFieldActive(name)) {
      return;
    }
    const version = this.lifecycleVersion;
    const pending = this.validator.onBlur(name, getFormValue(this.values, name), this.validationValues());
    this.syncValidating();
    try {
      await pending;
      if (!this.disposed && version === this.lifecycleVersion) {
        this.errors = this.copyRelevantErrors(this.validator.getState().errors);
      }
    } finally {
      if (version === this.lifecycleVersion) {
        this.syncValidating();
      }
    }
  }

  async submit(): Promise<Record<string, string>> {
    if (this.disposed) {
      return this.copyErrors(this.errors);
    }
    const version = this.lifecycleVersion;
    this.submitting = true;
    const pending = this.validator.submit(this.validationValues());
    this.syncValidating();
    try {
      const result = await pending;
      const relevant = this.copyRelevantErrors(result);
      if (!this.disposed && version === this.lifecycleVersion) {
        this.errors = relevant;
      }
      return this.copyErrors(relevant);
    } finally {
      if (version === this.lifecycleVersion) {
        this.syncValidating();
        this.submitting = false;
      }
    }
  }

  /** Validates an explicit field subset while preserving errors outside that subset. */
  async validateFields(names: string[]): Promise<Record<string, string>> {
    if (this.disposed) return {};
    const selected = this.assertFieldNames(names);
    const version = this.lifecycleVersion;
    const values = this.validationValues();
    const tasks: Array<Promise<string | null>> = [];
    for (const name of selected) {
      if (this.isFieldActive(name)) {
        tasks.push(this.validator.validateFieldAsync(name, values[name], values));
      }
    }
    this.syncValidating();
    try {
      await Promise.all(tasks);
      if (!this.disposed && version === this.lifecycleVersion) {
        this.errors = this.copyRelevantErrors(this.validator.getState().errors);
      }
      return this.copySelectedErrors(selected, this.errors);
    } finally {
      if (version === this.lifecycleVersion) this.syncValidating();
    }
  }

  reset(values?: Record<string, Object>): void {
    this.lifecycleVersion++;
    this.disposed = false;
    this.validator.reset();
    this.controlledEchoFields.clear();
    this.values = copyFormValues(values ?? {});
    this.errors = {};
    this.validating = {};
    this.submitting = false;
    this.optionLifecycleVersion++;
    this.optionsLoading = {};
    this.optionErrors = {};
  }

  firstErrorName(names?: string[]): string | undefined {
    const selected: Set<string> | undefined = names === undefined ? undefined : new Set<string>(names);
    for (const field of this.fields) {
      if ((selected === undefined || selected.has(field.name)) && this.errors[field.name] !== undefined) {
        return field.name;
      }
    }
    return undefined;
  }

  dispose(): void {
    this.lifecycleVersion++;
    this.disposed = true;
    this.controlledEchoFields.clear();
    this.validator.dispose();
    this.validating = {};
    this.submitting = false;
    this.optionLifecycleVersion++;
    this.optionsLoading = {};
    this.optionErrors = {};
  }

  private withValue(name: string, value: Object | undefined): Record<string, Object> {
    return setFormValue(this.values, name, value);
  }

  private findField(name: string): FormFieldSpec | undefined {
    for (const field of this.fields) {
      if (field.name === name) {
        return field;
      }
    }
    return undefined;
  }

  private optionRequestActive(name: string, requestVersion: number, lifecycleVersion: number): boolean {
    return !this.disposed && this.optionLifecycleVersion === lifecycleVersion &&
      this.optionRequestVersions.get(name) === requestVersion;
  }

  private validateLoadedOptions(name: string, options: FormSelectOption[]): void {
    if (options.length === 0) {
      throw new Error(`Loaded options must not be empty: ${name}`);
    }
    const values: Set<string> = new Set<string>();
    for (const option of options) {
      if (values.has(option.value)) {
        throw new Error(`Duplicate loaded option value '${option.value}' in field: ${name}`);
      }
      values.add(option.value);
    }
  }

  private optionErrorMessage(error: Object): string {
    const message = `${error}`;
    return message.startsWith('Error: ') ? message.substring(7) : message;
  }

  private withOptions(source: Record<string, FormSelectOption[]>, name: string,
    options: FormSelectOption[]): Record<string, FormSelectOption[]> {
    const result: Record<string, FormSelectOption[]> = {};
    for (const key of Object.keys(source)) {
      result[key] = source[key].slice();
    }
    result[name] = options.slice();
    return result;
  }

  private withBoolean(source: Record<string, boolean>, name: string, value: boolean): Record<string, boolean> {
    const result: Record<string, boolean> = {};
    for (const key of Object.keys(source)) {
      result[key] = source[key];
    }
    result[name] = value;
    return result;
  }

  private withoutBoolean(source: Record<string, boolean>, name: string): Record<string, boolean> {
    const result: Record<string, boolean> = {};
    for (const key of Object.keys(source)) {
      if (key !== name) {
        result[key] = source[key];
      }
    }
    return result;
  }

  private withString(source: Record<string, string>, name: string, value: string): Record<string, string> {
    const result: Record<string, string> = {};
    for (const key of Object.keys(source)) {
      result[key] = source[key];
    }
    result[name] = value;
    return result;
  }

  private withoutString(source: Record<string, string>, name: string): Record<string, string> {
    const result: Record<string, string> = {};
    for (const key of Object.keys(source)) {
      if (key !== name) {
        result[key] = source[key];
      }
    }
    return result;
  }

  private copyErrors(source: Record<string, string>): Record<string, string> {
    const result: Record<string, string> = {};
    for (const key of Object.keys(source)) {
      result[key] = source[key];
    }
    return result;
  }

  private copyRelevantErrors(source: Record<string, string>): Record<string, string> {
    const result: Record<string, string> = {};
    for (const field of this.fields) {
      if (field.isActive(this.values) && source[field.name] !== undefined) {
        result[field.name] = source[field.name];
      }
    }
    return result;
  }

  private copySelectedErrors(names: string[], source: Record<string, string>): Record<string, string> {
    const result: Record<string, string> = {};
    for (const name of names) if (source[name] !== undefined) result[name] = source[name];
    return result;
  }

  private mergeDependencies(validationDependencies: string[] | undefined, uiDependencies: string[]): string[] {
    const result: string[] = [];
    const source = validationDependencies === undefined ? [] : validationDependencies;
    for (const name of source) {
      if (!result.includes(name)) {
        result.push(name);
      }
    }
    for (const name of uiDependencies) {
      if (!result.includes(name)) {
        result.push(name);
      }
    }
    return result;
  }

  private isFieldActive(name: string): boolean {
    for (const field of this.fields) {
      if (field.name === name) {
        return field.isActive(this.values);
      }
    }
    return false;
  }

  private syncValidating(): void {
    const result: Record<string, boolean> = {};
    for (const field of this.fields) {
      if (field.isActive(this.values) && this.validator.getFieldState(field.name).validating) {
        result[field.name] = true;
      }
    }
    this.validating = result;
  }

  private consumeControlledEcho(name: string, value: Object | undefined): boolean {
    if (!this.controlledEchoFields.has(name)) {
      return false;
    }
    this.controlledEchoFields.delete(name);
    return this.toDisplayValue(getFormValue(this.values, name)) === this.toDisplayValue(value);
  }

  private toDisplayValue(value: Object | undefined): string {
    return value === undefined || value === null ? '' : `${value}`;
  }

  private assertFields(fields: FormFieldSpec[]): void {
    const names: Set<string> = new Set<string>();
    for (const field of fields) {
      validateFormPath(field.name);
      if (names.has(field.name)) {
        throw new Error(`Duplicate form field name: ${field.name}`);
      }
      names.add(field.name);
    }
    const ordered = Array.from(names);
    for (let left = 0; left < ordered.length; left++) {
      for (let right = left + 1; right < ordered.length; right++) {
        if (formPathConflicts(ordered[left], ordered[right])) {
          throw new Error(`Conflicting form field paths: ${ordered[left]} and ${ordered[right]}`);
        }
      }
    }
  }

  private assertFieldNames(names: string[]): string[] {
    if (names.length === 0) throw new Error('Form validation fields must not be empty');
    const result: string[] = [];
    for (const name of names) {
      if (this.findField(name) === undefined) throw new Error(`Unknown form field: ${name}`);
      if (result.includes(name)) throw new Error(`Duplicate form validation field: ${name}`);
      result.push(name);
    }
    return result;
  }

  private validationValues(): Record<string, Object> {
    const result: Record<string, Object> = {};
    for (const field of this.fields) {
      const value = getFormValue(this.values, field.name);
      if (value !== undefined) result[field.name] = value;
    }
    return result;
  }
}
