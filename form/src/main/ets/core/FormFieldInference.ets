import { AnySchema, FormFieldOptions, SchemaDescriptor, SchemaRuleDescriptor, schemaToDescriptor } from '@hmkit/validator';
import { FormFieldSpec, FormFieldType, FormFieldUIOptions, FormSelectOption } from './FormField';
import { copyFormValues, setFormValue } from './FormPath';

/** Explicit UI overrides for one schema-inferred field. Validation stays in schema. */
export interface FormFieldInferenceOptions {
  type?: string;
  label?: string;
  placeholder?: string;
  validationOptions?: FormFieldOptions;
  uiOptions?: FormFieldUIOptions;
}

/** Inferred field list plus defensive snapshots of schema defaults. */
export class FormFieldInferenceResult {
  readonly fields: FormFieldSpec[];
  private readonly defaults: Record<string, Object>;

  constructor(fields: FormFieldSpec[], defaults: Record<string, Object>) {
    this.fields = fields.slice();
    this.defaults = copyValues(defaults);
  }

  getInitialValues(): Record<string, Object> {
    return copyValues(this.defaults);
  }
}

/**
 * Builds a predictable flat form field list from validator schema descriptions.
 * Unsupported or ambiguous schema kinds require an explicit type override.
 */
export function inferFormFields(shape: Record<string, AnySchema<Object | null>>,
  overrides?: Record<string, FormFieldInferenceOptions>): FormFieldInferenceResult {
  assertOverrideNames(shape, overrides);
  const fields: FormFieldSpec[] = [];
  let defaults: Record<string, Object> = {};
  for (const name of Object.keys(shape)) {
    const schema = shape[name];
    const descriptor = schemaToDescriptor(schema);
    const override = overrides?.[name];
    const type = override?.type ?? inferType(name, descriptor);
    const label = override?.label ?? firstLabel(descriptor) ?? name;
    const inferredOptions = inferOptions(name, descriptor, type);
    const uiOptions = mergeUIOptions(descriptor, override?.uiOptions, inferredOptions);
    const placeholder = override?.placeholder ?? defaultPlaceholder(type, label);
    fields.push(new FormFieldSpec(name, type, label, schema, placeholder,
      override?.validationOptions, uiOptions));
    const defaultValue = firstDefault(descriptor);
    if (defaultValue !== undefined) {
      defaults = setFormValue(defaults, name, defaultValue);
    }
  }
  return new FormFieldInferenceResult(fields, defaults);
}

function assertOverrideNames(shape: Record<string, AnySchema<Object | null>>,
  overrides?: Record<string, FormFieldInferenceOptions>): void {
  if (overrides === undefined) return;
  for (const name of Object.keys(overrides)) {
    if (shape[name] === undefined) {
      throw new Error(`Unknown form field inference override: ${name}`);
    }
  }
}

function inferType(name: string, source: SchemaDescriptor): string {
  const descriptor = unwrapSafe(source, name);
  if (descriptor.kind === 'string') return FormFieldType.TEXT;
  if (descriptor.kind === 'number') return FormFieldType.NUMBER;
  if (descriptor.kind === 'boolean') return FormFieldType.SWITCH;
  if (descriptor.kind === 'date') return FormFieldType.DATE;
  if (descriptor.kind === 'enum') {
    assertStringOptions(name, descriptor, 'enum');
    return FormFieldType.SELECT;
  }
  if (descriptor.kind === 'array' && descriptor.items !== undefined) {
    const items = unwrapSafe(descriptor.items, name);
    if (items.kind === 'enum') {
      assertStringOptions(name, items, 'array enum');
      return FormFieldType.CHECKBOX;
    }
  }
  if (descriptor.kind === 'union') {
    assertStringLiteralUnion(name, descriptor);
    return FormFieldType.SELECT;
  }
  throw cannotInfer(name, descriptor.kind);
}

function inferOptions(name: string, source: SchemaDescriptor, type: string): FormSelectOption[] {
  const descriptor = unwrapSafe(source, name);
  if (descriptor.kind === 'enum') return enumOptions(name, descriptor);
  if (descriptor.kind === 'array' && descriptor.items !== undefined) {
    const items = unwrapSafe(descriptor.items, name);
    if (items.kind === 'enum') return enumOptions(name, items);
  }
  if (descriptor.kind === 'union') return literalOptions(name, descriptor);
  if (type === FormFieldType.SELECT || type === FormFieldType.RADIO || type === FormFieldType.CHECKBOX) {
    return [];
  }
  return [];
}

function enumOptions(name: string, descriptor: SchemaDescriptor): FormSelectOption[] {
  const result: FormSelectOption[] = [];
  for (const rule of descriptor.rules) {
    if (rule.name === 'enum') {
      if (typeof rule.value !== 'string') throw cannotInfer(name, 'non-string enum');
      result.push(new FormSelectOption(rule.value as string, rule.value as string));
    }
  }
  if (result.length === 0) throw cannotInfer(name, 'empty enum');
  return result;
}

function literalOptions(name: string, descriptor: SchemaDescriptor): FormSelectOption[] {
  assertStringLiteralUnion(name, descriptor);
  const result: FormSelectOption[] = [];
  for (const option of descriptor.options) {
    const literal = unwrapSafe(option, name);
    const value = literal.value as string;
    result.push(new FormSelectOption(value, value));
  }
  return result;
}

function assertStringOptions(name: string, descriptor: SchemaDescriptor, kind: string): void {
  let count = 0;
  for (const rule of descriptor.rules) {
    if (rule.name === 'enum') {
      count++;
      if (typeof rule.value !== 'string') throw cannotInfer(name, `non-string ${kind}`);
    }
  }
  if (count === 0) throw cannotInfer(name, `empty ${kind}`);
}

function assertStringLiteralUnion(name: string, descriptor: SchemaDescriptor): void {
  if (descriptor.options.length === 0) throw cannotInfer(name, 'empty union');
  for (const option of descriptor.options) {
    const literal = unwrapSafe(option, name);
    if (literal.kind !== 'literal' || typeof literal.value !== 'string') {
      throw cannotInfer(name, 'ambiguous union');
    }
  }
}

function unwrapSafe(source: SchemaDescriptor, name: string): SchemaDescriptor {
  let current = source;
  while (current.kind === 'nullable' || current.kind === 'default') {
    if (current.inner === undefined) throw cannotInfer(name, `${current.kind} without inner schema`);
    current = current.inner;
  }
  return current;
}

function firstLabel(source: SchemaDescriptor): string | undefined {
  let current: SchemaDescriptor | undefined = source;
  while (current !== undefined) {
    if (current.label !== undefined && current.label.trim() !== '') return current.label;
    if (current.metadata?.title !== undefined && current.metadata.title.trim() !== '') return current.metadata.title;
    current = current.inner;
  }
  return undefined;
}

function firstDescription(source: SchemaDescriptor): string | undefined {
  let current: SchemaDescriptor | undefined = source;
  while (current !== undefined) {
    if (current.metadata?.description !== undefined && current.metadata.description.trim() !== '') {
      return current.metadata.description;
    }
    current = current.inner;
  }
  return undefined;
}

function firstDefault(source: SchemaDescriptor): Object | undefined {
  let current: SchemaDescriptor | undefined = source;
  while (current !== undefined) {
    if (current.defaultValue !== undefined) return current.defaultValue;
    current = current.inner;
  }
  return undefined;
}

function mergeUIOptions(descriptor: SchemaDescriptor, override: FormFieldUIOptions | undefined,
  inferredOptions: FormSelectOption[]): FormFieldUIOptions {
  const effective = unwrapForMetadata(descriptor);
  return {
    'help': override?.help ?? firstDescription(descriptor),
    'disabled': override?.disabled,
    'maxLength': override?.maxLength ?? inferMaxLength(effective),
    'options': override?.options === undefined ? inferredOptions : override.options.slice(),
    'dependencies': override?.dependencies === undefined ? undefined : override.dependencies.slice(),
    'visibleWhen': override?.visibleWhen,
    'disabledWhen': override?.disabledWhen,
    'startDate': override?.startDate ?? inferDateBound(effective.rules, 'minimum-date'),
    'endDate': override?.endDate ?? inferDateBound(effective.rules, 'maximum-date'),
    'slots': override?.slots === undefined ? undefined : override.slots.slice(),
    'span': override?.span,
    'optionsLoader': override?.optionsLoader
  };
}

function unwrapForMetadata(source: SchemaDescriptor): SchemaDescriptor {
  let current = source;
  while ((current.kind === 'nullable' || current.kind === 'default') && current.inner !== undefined) {
    current = current.inner;
  }
  return current;
}

function inferMaxLength(descriptor: SchemaDescriptor): number | undefined {
  if (descriptor.kind !== 'string') return undefined;
  let result: number | undefined = undefined;
  for (const rule of descriptor.rules) {
    if (rule.name === 'maxLength' && typeof rule.value === 'number') {
      const value = rule.value as number;
      result = result === undefined || value < result ? value : result;
    }
  }
  return result;
}

function inferDateBound(rules: SchemaRuleDescriptor[], name: string): Date | undefined {
  for (const rule of rules) {
    if (rule.name === name && typeof rule.value === 'number') return new Date(rule.value as number);
  }
  return undefined;
}

function defaultPlaceholder(type: string, label: string): string {
  if (type === FormFieldType.TEXT || type === FormFieldType.NUMBER || type === FormFieldType.TEXTAREA) {
    return `请输入${label}`;
  }
  if (type === FormFieldType.SELECT || type === FormFieldType.RADIO || type === FormFieldType.DATE) {
    return `请选择${label}`;
  }
  return '';
}

function cannotInfer(name: string, kind: string): Error {
  return new Error(`Cannot infer form field '${name}' from schema kind '${kind}'; provide an explicit type override`);
}

function copyValues(source: Record<string, Object>): Record<string, Object> {
  return copyFormValues(source);
}
