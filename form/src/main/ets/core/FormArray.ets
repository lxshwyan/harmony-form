import { copyFormValue, formValueEqual } from './FormPath';

/** Optional business identity used to preserve item keys across controlled replacements and reorder. */
export type FormArrayIdentity = (value: Object, index: number) => string;

export interface FormArrayControllerOptions {
  minItems?: number;
  maxItems?: number;
  identity?: FormArrayIdentity;
}

/** Stable observable item. The key is UI metadata and is never written into form values. */
@ObservedV2
export class FormArrayEntry {
  readonly key: string;
  @Trace value: Object;
  @Trace index: number = 0;
  @Trace length: number = 0;
  @Trace removable: boolean = false;

  constructor(key: string, value: Object) {
    this.key = key;
    this.value = copyFormValue(value) as Object;
  }
}

/** Controlled dynamic-array state with position-independent ArkUI keys. */
@ObservedV2
export class FormArrayController {
  @Trace entries: FormArrayEntry[] = [];

  readonly minItems: number;
  readonly maxItems: number | undefined;
  private readonly identity: FormArrayIdentity | undefined;
  private nextKey: number = 0;
  private disposed: boolean = false;

  constructor(values?: Object[], options?: FormArrayControllerOptions) {
    this.minItems = options?.minItems ?? 0;
    this.maxItems = options?.maxItems;
    this.identity = options?.identity;
    this.validateLimits();
    this.entries = this.createEntries(values ?? []);
    this.validateLength(this.entries.length);
  }

  getValues(): Object[] {
    const result: Object[] = [];
    for (const entry of this.entries) {
      result.push(copyFormValue(entry.value) as Object);
    }
    return result;
  }

  getEntry(index: number): FormArrayEntry {
    this.assertItemIndex(index);
    const entry = this.entries[index];
    const snapshot = new FormArrayEntry(entry.key, entry.value);
    snapshot.index = entry.index;
    snapshot.length = entry.length;
    snapshot.removable = entry.removable;
    return snapshot;
  }

  canAppend(): boolean {
    return !this.disposed && (this.maxItems === undefined || this.entries.length < this.maxItems);
  }

  canRemove(): boolean {
    return !this.disposed && this.entries.length > this.minItems;
  }

  append(value: Object): boolean {
    return this.insert(this.entries.length, value);
  }

  insert(index: number, value: Object): boolean {
    if (this.disposed) return false;
    this.assertInsertIndex(index);
    if (!this.canAppend()) return false;
    const entry = this.createEntry(value, index, this.entries);
    const result = this.entries.slice();
    result.splice(index, 0, entry);
    this.refreshEntries(result);
    this.entries = result;
    return true;
  }

  update(index: number, value: Object): boolean {
    if (this.disposed) return false;
    this.assertItemIndex(index);
    const existing = this.entries[index];
    if (formValueEqual(existing.value, value)) return false;
    const key = this.identity === undefined ? existing.key : this.identityKey(value, index);
    this.assertUniqueKey(key, index);
    const result = this.entries.slice();
    if (key === existing.key) {
      existing.value = copyFormValue(value) as Object;
    } else {
      result[index] = new FormArrayEntry(key, value);
    }
    this.refreshEntries(result);
    this.entries = result;
    return true;
  }

  remove(index: number): boolean {
    if (this.disposed) return false;
    this.assertItemIndex(index);
    if (!this.canRemove()) return false;
    const result = this.entries.slice();
    result.splice(index, 1);
    this.refreshEntries(result);
    this.entries = result;
    return true;
  }

  removeByKey(key: string): boolean {
    const index = this.indexOfKey(key);
    return index < 0 ? false : this.remove(index);
  }

  move(from: number, to: number): boolean {
    if (this.disposed) return false;
    this.assertItemIndex(from);
    this.assertItemIndex(to);
    if (from === to) return false;
    const result = this.entries.slice();
    const moved = result.splice(from, 1)[0];
    result.splice(to, 0, moved);
    this.refreshEntries(result);
    this.entries = result;
    return true;
  }

  syncValues(values: Object[]): boolean {
    if (this.disposed || this.valuesEqual(values)) return false;
    this.validateLength(values.length);
    this.entries = this.reconcileEntries(values);
    return true;
  }

  reset(values?: Object[]): void {
    this.disposed = false;
    this.nextKey = 0;
    const next = values ?? [];
    this.validateLength(next.length);
    this.entries = this.createEntries(next);
  }

  dispose(): void {
    this.disposed = true;
  }

  private createEntries(values: Object[]): FormArrayEntry[] {
    const result: FormArrayEntry[] = [];
    for (let index = 0; index < values.length; index++) {
      result.push(this.createEntry(values[index], index, result));
    }
    this.refreshEntries(result);
    return result;
  }

  private createEntry(value: Object, index: number, existing: FormArrayEntry[]): FormArrayEntry {
    this.assertValue(value);
    const key = this.identity === undefined ? this.generatedKey() : this.identityKey(value, index);
    for (const entry of existing) {
      if (entry.key === key) throw new Error(`Duplicate FormArray item identity: ${key.substring(key.indexOf(':') + 1)}`);
    }
    return new FormArrayEntry(key, value);
  }

  private reconcileEntries(values: Object[]): FormArrayEntry[] {
    if (this.identity !== undefined) {
      const previous: Map<string, FormArrayEntry> = new Map<string, FormArrayEntry>();
      for (const entry of this.entries) previous.set(entry.key, entry);
      const result: FormArrayEntry[] = [];
      for (let index = 0; index < values.length; index++) {
        this.assertValue(values[index]);
        const key = this.identityKey(values[index], index);
        for (const entry of result) {
          if (entry.key === key) throw new Error(`Duplicate FormArray item identity: ${key.substring(key.indexOf(':') + 1)}`);
        }
        const existing = previous.get(key);
        if (existing === undefined) {
          result.push(new FormArrayEntry(key, values[index]));
        } else {
          existing.value = copyFormValue(values[index]) as Object;
          result.push(existing);
        }
      }
      this.refreshEntries(result);
      return result;
    }

    const used: Set<number> = new Set<number>();
    const result: FormArrayEntry[] = [];
    for (const value of values) {
      this.assertValue(value);
      let match = -1;
      for (let index = 0; index < this.entries.length; index++) {
        if (!used.has(index) && formValueEqual(this.entries[index].value, value)) {
          match = index;
          break;
        }
      }
      if (match >= 0) {
        used.add(match);
        const existing = this.entries[match];
        existing.value = copyFormValue(value) as Object;
        result.push(existing);
      } else {
        result.push(new FormArrayEntry(this.generatedKey(), value));
      }
    }
    this.refreshEntries(result);
    return result;
  }

  private refreshEntries(entries: FormArrayEntry[]): void {
    const removable = entries.length > this.minItems;
    for (let index = 0; index < entries.length; index++) {
      entries[index].index = index;
      entries[index].length = entries.length;
      entries[index].removable = removable;
    }
  }

  private valuesEqual(values: Object[]): boolean {
    if (values.length !== this.entries.length) return false;
    for (let index = 0; index < values.length; index++) {
      if (!formValueEqual(this.entries[index].value, values[index])) return false;
    }
    return true;
  }

  private identityKey(value: Object, index: number): string {
    this.assertValue(value);
    const identity = (this.identity as FormArrayIdentity)(value, index);
    if (identity.trim() !== identity || identity === '') {
      throw new Error(`FormArray item identity must not be empty at index ${index}`);
    }
    return `identity:${identity}`;
  }

  private generatedKey(): string {
    const key = `generated:${this.nextKey}`;
    this.nextKey++;
    return key;
  }

  private assertUniqueKey(key: string, currentIndex: number): void {
    for (let index = 0; index < this.entries.length; index++) {
      if (index !== currentIndex && this.entries[index].key === key) {
        throw new Error(`Duplicate FormArray item identity: ${key.substring(key.indexOf(':') + 1)}`);
      }
    }
  }

  private indexOfKey(key: string): number {
    for (let index = 0; index < this.entries.length; index++) {
      if (this.entries[index].key === key) return index;
    }
    return -1;
  }

  private validateLimits(): void {
    if (!Number.isInteger(this.minItems) || this.minItems < 0) {
      throw new Error('FormArray minItems must be a non-negative integer');
    }
    if (this.maxItems !== undefined && (!Number.isInteger(this.maxItems) || this.maxItems < this.minItems)) {
      throw new Error('FormArray maxItems must be an integer not smaller than minItems');
    }
  }

  private validateLength(length: number): void {
    if (length < this.minItems) throw new Error(`FormArray requires at least ${this.minItems} items`);
    if (this.maxItems !== undefined && length > this.maxItems) {
      throw new Error(`FormArray allows at most ${this.maxItems} items`);
    }
  }

  private assertValue(value: Object): void {
    if (value === undefined || value === null) throw new Error('FormArray items must not be null or undefined');
  }

  private assertInsertIndex(index: number): void {
    if (!Number.isInteger(index) || index < 0 || index > this.entries.length) {
      throw new Error(`FormArray insert index out of range: ${index}`);
    }
  }

  private assertItemIndex(index: number): void {
    if (!Number.isInteger(index) || index < 0 || index >= this.entries.length) {
      throw new Error(`FormArray item index out of range: ${index}`);
    }
  }
}

/** Safe operations exposed to an item Builder without leaking controller internals. */
export class HmFormArrayItemContext {
  readonly key: string;
  private readonly entry: FormArrayEntry;
  private readonly changeAction: (value: Object) => void;
  private readonly removeAction: () => void;
  private readonly moveUpAction: () => void;
  private readonly moveDownAction: () => void;

  constructor(entry: FormArrayEntry,
    changeAction: (value: Object) => void, removeAction: () => void,
    moveUpAction: () => void, moveDownAction: () => void) {
    this.key = entry.key;
    this.entry = entry;
    this.changeAction = changeAction;
    this.removeAction = removeAction;
    this.moveUpAction = moveUpAction;
    this.moveDownAction = moveDownAction;
  }

  get index(): number { return this.entry.index; }
  get value(): Object { return copyFormValue(this.entry.value) as Object; }
  get canMoveUp(): boolean { return this.entry.index > 0; }
  get canMoveDown(): boolean { return this.entry.index < this.entry.length - 1; }
  get canRemove(): boolean { return this.entry.removable; }

  change(value: Object): void { this.changeAction(value); }
  remove(): void { if (this.canRemove) this.removeAction(); }
  moveUp(): void { if (this.canMoveUp) this.moveUpAction(); }
  moveDown(): void { if (this.canMoveDown) this.moveDownAction(); }
}
