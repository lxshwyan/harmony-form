import { FormFieldSpec } from './FormField';

export interface FormSectionOptions {
  description?: string;
  collapsible?: boolean;
  defaultExpanded?: boolean;
}

/** Immutable field group metadata. Every configured field belongs to exactly one section. */
export class FormSectionSpec {
  readonly id: string;
  readonly title: string;
  readonly fieldNames: string[];
  readonly description: string;
  readonly collapsible: boolean;
  readonly defaultExpanded: boolean;

  constructor(id: string, title: string, fieldNames: string[], options?: FormSectionOptions) {
    validateStructureId(id, 'section');
    if (fieldNames.length === 0) {
      throw new Error(`Form section fields must not be empty: ${id}`);
    }
    const names: Set<string> = new Set<string>();
    for (const name of fieldNames) {
      if (names.has(name)) {
        throw new Error(`Duplicate field '${name}' in form section: ${id}`);
      }
      names.add(name);
    }
    this.id = id;
    this.title = title;
    this.fieldNames = fieldNames.slice();
    this.description = options?.description ?? '';
    this.collapsible = options?.collapsible ?? false;
    this.defaultExpanded = this.collapsible ? (options?.defaultExpanded ?? true) : true;
  }
}

export interface FormStepOptions {
  description?: string;
}

/** Immutable step metadata. A step owns one or more complete sections. */
export class FormStepSpec {
  readonly id: string;
  readonly title: string;
  readonly sectionIds: string[];
  readonly description: string;

  constructor(id: string, title: string, sectionIds: string[], options?: FormStepOptions) {
    validateStructureId(id, 'step');
    if (sectionIds.length === 0) {
      throw new Error(`Form step sections must not be empty: ${id}`);
    }
    const ids: Set<string> = new Set<string>();
    for (const sectionId of sectionIds) {
      if (ids.has(sectionId)) {
        throw new Error(`Duplicate section '${sectionId}' in form step: ${id}`);
      }
      ids.add(sectionId);
    }
    this.id = id;
    this.title = title;
    this.sectionIds = sectionIds.slice();
    this.description = options?.description ?? '';
  }
}

function validateStructureId(id: string, kind: string): void {
  if (!/^[A-Za-z][A-Za-z0-9._-]*$/.test(id)) {
    throw new Error(`Invalid form ${kind} id: ${id}`);
  }
}

/**
 * Observable structure state shared with HmFormView. The form values and validation
 * state remain in FormController; this class owns only presentation/navigation state.
 */
@ObservedV2
export class FormStructureController {
  readonly sections: FormSectionSpec[];
  readonly steps: FormStepSpec[];
  @Trace currentStepIndex: number = 0;
  @Trace expandedSections: Record<string, boolean> = {};
  @Trace validatingStep: boolean = false;
  private disposed: boolean = false;

  constructor(sections: FormSectionSpec[], steps?: FormStepSpec[]) {
    this.sections = sections.slice();
    this.steps = steps === undefined ? [] : steps.slice();
    this.validateStructure();
    this.expandedSections = this.defaultExpandedState();
  }

  assertFields(fields: FormFieldSpec[]): void {
    const available: Set<string> = new Set<string>();
    for (const field of fields) {
      available.add(field.name);
    }
    const assigned: Set<string> = new Set<string>();
    for (const section of this.sections) {
      for (const name of section.fieldNames) {
        if (!available.has(name)) {
          throw new Error(`Unknown form section field '${name}' in section: ${section.id}`);
        }
        if (assigned.has(name)) {
          throw new Error(`Form field assigned to multiple sections: ${name}`);
        }
        assigned.add(name);
      }
    }
    for (const field of fields) {
      if (!assigned.has(field.name)) {
        throw new Error(`Form field is not assigned to a section: ${field.name}`);
      }
    }
  }

  hasSteps(): boolean {
    return this.steps.length > 0;
  }

  currentStep(): FormStepSpec | undefined {
    return this.hasSteps() ? this.steps[this.currentStepIndex] : undefined;
  }

  currentStepId(): string | undefined {
    return this.currentStep()?.id;
  }

  activeSections(): FormSectionSpec[] {
    const step = this.currentStep();
    if (step === undefined) {
      return this.sections.slice();
    }
    const result: FormSectionSpec[] = [];
    for (const sectionId of step.sectionIds) {
      const section = this.findSection(sectionId);
      if (section !== undefined) {
        result.push(section);
      }
    }
    return result;
  }

  currentFieldNames(): string[] {
    const result: string[] = [];
    for (const section of this.activeSections()) {
      for (const name of section.fieldNames) {
        result.push(name);
      }
    }
    return result;
  }

  sectionForField(name: string): FormSectionSpec | undefined {
    for (const section of this.sections) if (section.fieldNames.includes(name)) return section;
    return undefined;
  }

  stepForField(name: string): FormStepSpec | undefined {
    const section = this.sectionForField(name);
    if (section === undefined) return undefined;
    const index = this.stepIndexForSection(section.id);
    return index < 0 ? undefined : this.steps[index];
  }

  isExpanded(sectionId: string): boolean {
    const section = this.requireSection(sectionId);
    return !section.collapsible || this.expandedSections[sectionId] === true;
  }

  toggleSection(sectionId: string): boolean {
    if (this.disposed) return false;
    const section = this.requireSection(sectionId);
    if (!section.collapsible) return false;
    return this.setExpanded(sectionId, !this.isExpanded(sectionId));
  }

  setExpanded(sectionId: string, expanded: boolean): boolean {
    if (this.disposed) return false;
    const section = this.requireSection(sectionId);
    if (!section.collapsible || this.isExpanded(sectionId) === expanded) return false;
    const next: Record<string, boolean> = {};
    for (const id of Object.keys(this.expandedSections)) next[id] = this.expandedSections[id];
    next[sectionId] = expanded;
    this.expandedSections = next;
    return true;
  }

  canPrevious(): boolean {
    return this.hasSteps() && this.currentStepIndex > 0;
  }

  canNext(): boolean {
    return this.hasSteps() && this.currentStepIndex < this.steps.length - 1;
  }

  previous(): boolean {
    return this.goTo(this.currentStepIndex - 1);
  }

  next(): boolean {
    return this.goTo(this.currentStepIndex + 1);
  }

  goTo(index: number): boolean {
    if (this.disposed || this.validatingStep || index < 0 || index >= this.steps.length ||
      index === this.currentStepIndex) return false;
    this.currentStepIndex = index;
    return true;
  }

  goToStep(id: string): boolean {
    for (let index = 0; index < this.steps.length; index++) {
      if (this.steps[index].id === id) return this.goTo(index);
    }
    throw new Error(`Unknown form step: ${id}`);
  }

  revealField(name: string): boolean {
    if (this.disposed) return false;
    const section = this.sectionForField(name);
    if (section === undefined) return false;
    let changed = false;
    if (this.hasSteps()) {
      const stepIndex = this.stepIndexForSection(section.id);
      if (stepIndex >= 0 && stepIndex !== this.currentStepIndex) {
        this.currentStepIndex = stepIndex;
        changed = true;
      }
    }
    if (section.collapsible && !this.isExpanded(section.id)) {
      changed = this.setExpanded(section.id, true) || changed;
    }
    return changed;
  }

  beginStepValidation(): boolean {
    if (this.disposed || this.validatingStep) return false;
    this.validatingStep = true;
    return true;
  }

  endStepValidation(): void {
    this.validatingStep = false;
  }

  reset(): void {
    this.disposed = false;
    this.currentStepIndex = 0;
    this.expandedSections = this.defaultExpandedState();
    this.validatingStep = false;
  }

  dispose(): void {
    this.disposed = true;
    this.validatingStep = false;
  }

  private validateStructure(): void {
    if (this.sections.length === 0) {
      throw new Error('Form sections must not be empty');
    }
    const sectionIds: Set<string> = new Set<string>();
    for (const section of this.sections) {
      if (sectionIds.has(section.id)) throw new Error(`Duplicate form section id: ${section.id}`);
      sectionIds.add(section.id);
    }
    const stepIds: Set<string> = new Set<string>();
    const assignedSections: Set<string> = new Set<string>();
    for (const step of this.steps) {
      if (stepIds.has(step.id)) throw new Error(`Duplicate form step id: ${step.id}`);
      stepIds.add(step.id);
      for (const sectionId of step.sectionIds) {
        if (!sectionIds.has(sectionId)) throw new Error(`Unknown form step section '${sectionId}' in step: ${step.id}`);
        if (assignedSections.has(sectionId)) throw new Error(`Form section assigned to multiple steps: ${sectionId}`);
        assignedSections.add(sectionId);
      }
    }
    if (this.steps.length > 0) {
      for (const section of this.sections) {
        if (!assignedSections.has(section.id)) throw new Error(`Form section is not assigned to a step: ${section.id}`);
      }
    }
  }

  private defaultExpandedState(): Record<string, boolean> {
    const result: Record<string, boolean> = {};
    for (const section of this.sections) result[section.id] = section.defaultExpanded;
    return result;
  }

  private findSection(id: string): FormSectionSpec | undefined {
    for (const section of this.sections) if (section.id === id) return section;
    return undefined;
  }

  private requireSection(id: string): FormSectionSpec {
    const section = this.findSection(id);
    if (section === undefined) throw new Error(`Unknown form section: ${id}`);
    return section;
  }

  private stepIndexForSection(sectionId: string): number {
    for (let index = 0; index < this.steps.length; index++) {
      if (this.steps[index].sectionIds.includes(sectionId)) return index;
    }
    return -1;
  }
}
