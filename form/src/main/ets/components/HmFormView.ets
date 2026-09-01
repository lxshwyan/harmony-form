import { FormController } from '../core/FormController';
import { FormFieldSlot, FormFieldSpec, FormFieldType, FormSelectOption, FormTextInputType } from '../core/FormField';
import { HmFormFieldRenderContext, HmFormFieldRenderer, HmFormRendererRegistry } from '../core/FormRenderer';
import { HmFormSubmitSlotContext } from '../core/FormSlots';
import { buildFormErrorSummaryItems, HmFormErrorSummaryContext,
  HmFormErrorSummaryItem } from '../core/FormErrors';
import { HmFormLayout } from '../core/FormLayout';
import { FormSectionSpec, FormStructureController } from '../core/FormStructure';
import { HmFormTheme } from '../theme/HmFormTheme';

/** Cross-HAR ArkUI V2 form component with explicit built-in field adapters. */
@ComponentV2
export struct HmFormView {
  @Require @Param fields: FormFieldSpec[];
  @Require @Param values: Record<string, Object>;
  @Event $values: (values: Record<string, Object>) => void = (values: Record<string, Object>): void => {};
  @Event onSubmit: (values: Record<string, Object>) => void = (values: Record<string, Object>): void => {};
  @Event onInvalid: (errors: Record<string, string>) => void = (errors: Record<string, string>): void => {};
  @Require @Param controller: FormController;
  @Param theme: HmFormTheme = HmFormTheme.light();
  @Param renderers: HmFormRendererRegistry = new HmFormRendererRegistry();
  @Param layout: HmFormLayout = HmFormLayout.responsive();
  @Param structure: FormStructureController | undefined = undefined;
  @Param showErrorSummary: boolean = false;
  @BuilderParam prefix: (context: HmFormFieldRenderContext) => void = this.defaultPrefix;
  @BuilderParam suffix: (context: HmFormFieldRenderContext) => void = this.defaultSuffix;
  @BuilderParam label: (context: HmFormFieldRenderContext) => void = this.defaultLabel;
  @BuilderParam help: (context: HmFormFieldRenderContext) => void = this.defaultHelp;
  @BuilderParam error: (context: HmFormFieldRenderContext) => void = this.defaultError;
  @BuilderParam submit: (context: HmFormSubmitSlotContext) => void = this.defaultSubmit;
  @BuilderParam errorSummary: (context: HmFormErrorSummaryContext) => void = this.defaultErrorSummary;
  @BuilderParam footer: () => void = this.defaultFooter;
  private active: boolean = false;
  private submitVersion: number = 0;

  @Builder
  private defaultFooter(): void {
  }

  @Builder
  private defaultPrefix(_context: HmFormFieldRenderContext): void {
  }

  @Builder
  private defaultSuffix(_context: HmFormFieldRenderContext): void {
  }

  @Builder
  private defaultLabel(context: HmFormFieldRenderContext): void {
    Text(context.field.label)
      .fontSize('14fp')
      .fontColor(context.disabled ? context.theme.disabledTextColor : context.theme.textColor)
  }

  @Builder
  private defaultHelp(context: HmFormFieldRenderContext): void {
    Text(context.field.help)
      .fontSize('12fp')
      .fontColor(context.theme.secondaryTextColor)
  }

  @Builder
  private defaultError(context: HmFormFieldRenderContext): void {
    Text(context.error ?? '')
      .fontSize('12fp')
      .fontColor(context.theme.errorColor)
  }

  @Builder
  private defaultSubmit(context: HmFormSubmitSlotContext): void {
    Button(context.label)
      .id('hmkit_form_submit')
      .width('100%')
      .constraintSize({ minHeight: context.theme.controlMinHeight })
      .enabled(!context.submitting)
      .accessibilityDescription(context.description)
      .onClick((): void => {
        context.submit();
      })
  }

  @Builder
  private defaultErrorSummary(context: HmFormErrorSummaryContext): void {
    Column({ space: 8 }) {
      Text(context.title)
        .id('hmkit_form_error_summary_title')
        .width('100%')
        .fontSize('16fp')
        .fontWeight(FontWeight.Medium)
        .fontColor(context.theme.errorColor)
      Text(context.description)
        .width('100%')
        .fontSize('12fp')
        .fontColor(context.theme.secondaryTextColor)
      ForEach(context.items, (item: HmFormErrorSummaryItem): void => {
        Row({ space: 8 }) {
          Text('•')
            .fontSize('16fp')
            .fontColor(context.theme.errorColor)
          Column({ space: 2 }) {
            Text(item.label)
              .width('100%')
              .fontSize('14fp')
              .fontWeight(FontWeight.Medium)
              .fontColor(context.theme.textColor)
            if (item.location() !== '') {
              Text(item.location())
                .width('100%')
                .fontSize('12fp')
                .fontColor(context.theme.secondaryTextColor)
            }
            Text(item.message)
              .width('100%')
              .fontSize('12fp')
              .fontColor(context.theme.errorColor)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Text('定位')
            .fontSize('13fp')
            .fontColor(context.theme.primaryColor)
        }
        .id(`hmkit_form_error_summary_${item.name}`)
        .width('100%')
        .constraintSize({ minHeight: context.theme.controlMinHeight })
        .padding({ left: 8, right: 8, top: 6, bottom: 6 })
        .borderRadius(context.theme.borderRadius)
        .accessibilityGroup(true)
        .accessibilityText(`${item.label}，${item.location() === '' ? '' : `${item.location()}，`}${item.message}`)
        .accessibilityDescription('选择后定位到对应字段')
        .accessibilityLevel('yes')
        .onClick((): void => {
          context.activate(item.name);
        })
      }, (item: HmFormErrorSummaryItem): string => item.name)
    }
    .id('hmkit_form_error_summary')
    .width('100%')
    .padding(12)
    .backgroundColor(context.theme.surfaceColor)
    .borderRadius(context.theme.borderRadius)
    .borderWidth(1)
    .borderColor(context.theme.errorColor)
    .alignItems(HorizontalAlign.Start)
  }

  private inputId(name: string): string {
    return `hmkit_form_${name}`;
  }

  private textInputType(field: FormFieldSpec): InputType {
    if (field.inputType === FormTextInputType.NUMBER) return InputType.Number;
    if (field.inputType === FormTextInputType.PHONE) return InputType.PhoneNumber;
    if (field.inputType === FormTextInputType.EMAIL) return InputType.Email;
    if (field.inputType === FormTextInputType.PASSWORD) return InputType.Password;
    return InputType.Normal;
  }

  aboutToAppear(): void {
    this.renderers.assertFields(this.fields);
    this.structure?.assertFields(this.fields);
    this.active = true;
    this.submitVersion++;
    this.controller.syncValues(this.values);
    this.controller.loadAllOptions();
  }

  aboutToDisappear(): void {
    this.active = false;
    this.submitVersion++;
  }

  @Monitor('values')
  private syncControlledValues(_monitor: IMonitor): void {
    if (this.controller.syncValues(this.values)) {
      this.submitVersion++;
    }
  }

  private async changeText(field: FormFieldSpec, text: string): Promise<void> {
    const value: Object | undefined = field.type === FormFieldType.NUMBER
      ? (text === '' ? undefined : Number(text))
      : text;
    await this.controller.onChange(field.name, value);
    this.$values(this.controller.getValues());
  }

  private async changeSelect(field: FormFieldSpec, index: number): Promise<void> {
    const options = this.fieldOptions(field);
    if (this.fieldDisabled(field) || this.controller.getValue(field.name) === field.selectValue(index, options)) {
      return;
    }
    await this.controller.onChange(field.name, field.selectValue(index, options));
    this.$values(this.controller.getValues());
  }

  private async changeBoolean(field: FormFieldSpec, value: boolean): Promise<void> {
    await this.controller.onChange(field.name, value);
    this.$values(this.controller.getValues());
  }

  private async changeCheckbox(field: FormFieldSpec, optionValue: string, selected: boolean): Promise<void> {
    if (this.fieldDisabled(field)) {
      return;
    }
    const value = field.toggleOptionValue(this.controller.getValue(field.name), optionValue, selected,
      this.fieldOptions(field));
    await this.controller.onChange(field.name, value);
    this.$values(this.controller.getValues());
  }

  private async changeCustom(field: FormFieldSpec, value: Object | undefined): Promise<void> {
    if (this.fieldDisabled(field)) {
      return;
    }
    await this.controller.onChange(field.name, value);
    this.$values(this.controller.getValues());
  }

  private async changeDate(field: FormFieldSpec, value: Date): Promise<void> {
    await this.controller.onChange(field.name, field.dateModelValue(value));
    this.$values(this.controller.getValues());
  }

  private async validateBlur(field: FormFieldSpec): Promise<void> {
    await this.controller.onBlur(field.name);
  }

  private async submitAndFocus(): Promise<void> {
    if (!this.active || this.controller.submitting) {
      return;
    }
    const version = ++this.submitVersion;
    const errors = await this.controller.submit();
    if (!this.active || version !== this.submitVersion) {
      return;
    }
    if (Object.keys(errors).length > 0) {
      const name = this.controller.firstErrorName();
      if (name !== undefined) {
        this.revealAndFocus(name);
      }
      this.onInvalid(errors);
      return;
    }
    this.onSubmit(this.controller.getValues());
  }

  private revealAndFocus(name: string): void {
    this.structure?.revealField(name);
    const version = this.submitVersion;
    setTimeout((): void => {
      this.requestFieldFocus(name, version, 3);
    }, 0);
  }

  private requestFieldFocus(name: string, version: number, attempts: number): void {
    if (!this.active || version !== this.submitVersion) return;
    let focused = false;
    try {
      focused = focusControl.requestFocus(this.inputId(name));
    } catch (_error) {
    }
    if (!focused && attempts > 1) {
      setTimeout((): void => {
        this.requestFieldFocus(name, version, attempts - 1);
      }, 16);
    }
  }

  private errorSummaryItems(): HmFormErrorSummaryItem[] {
    return buildFormErrorSummaryItems(this.fields, this.controller.errors, this.structure);
  }

  private activateErrorSummaryItem(name: string): void {
    for (const item of this.errorSummaryItems()) {
      if (item.name === name) {
        this.revealAndFocus(name);
        return;
      }
    }
  }

  private errorSummaryContext(): HmFormErrorSummaryContext {
    const items = this.errorSummaryItems();
    return new HmFormErrorSummaryContext(
      items,
      `请检查以下 ${items.length} 项`,
      '选择错误可定位到对应字段',
      this.theme,
      (name: string): void => {
        this.activateErrorSummaryItem(name);
      }
    );
  }

  @Builder
  private errorSummaryView(): void {
    if (this.showErrorSummary && this.errorSummaryItems().length > 0) {
      this.errorSummary(this.errorSummaryContext())
    }
  }

  private async validateAndNext(): Promise<void> {
    const structure = this.structure;
    if (!this.active || structure === undefined || !structure.canNext() || !structure.beginStepValidation()) return;
    const version = ++this.submitVersion;
    try {
      const names = structure.currentFieldNames();
      const errors = await this.controller.validateFields(names);
      if (!this.active || version !== this.submitVersion) return;
      if (Object.keys(errors).length > 0) {
        const name = this.controller.firstErrorName(names);
        if (name !== undefined) this.revealAndFocus(name);
        return;
      }
      structure.endStepValidation();
      structure.next();
    } finally {
      structure.endStepValidation();
    }
  }

  private selectOptions(field: FormFieldSpec): SelectOption[] {
    const options: SelectOption[] = [];
    for (const option of this.fieldOptions(field)) {
      options.push({ value: option.label });
    }
    return options;
  }

  private textAreaMaxLength(field: FormFieldSpec): number {
    return field.maxLength === undefined ? 2147483647 : field.maxLength;
  }

  private fieldDisabled(field: FormFieldSpec): boolean {
    return field.isDisabled(this.controller.values) || this.controller.optionsLoading[field.name] === true ||
      this.controller.optionErrors[field.name] !== undefined;
  }

  private fieldOptions(field: FormFieldSpec): FormSelectOption[] {
    return this.controller.getOptions(field.name);
  }

  private fieldDescription(field: FormFieldSpec): string {
    if (this.controller.errors[field.name] !== undefined) {
      return `错误：${this.controller.errors[field.name]}`;
    }
    if (this.controller.validating[field.name] === true) {
      return '正在校验';
    }
    if (this.controller.optionsLoading[field.name] === true) {
      return '正在加载选项';
    }
    if (this.controller.optionErrors[field.name] !== undefined) {
      return `选项加载失败：${this.controller.optionErrors[field.name]}`;
    }
    if (this.fieldDisabled(field)) {
      return field.help === '' ? '不可操作' : `不可操作，${field.help}`;
    }
    return field.help;
  }

  private fieldContext(field: FormFieldSpec): HmFormFieldRenderContext {
    return new HmFormFieldRenderContext(
      field,
      this.controller.getValue(field.name),
      this.controller.errors[field.name],
      this.controller.validating[field.name] === true,
      this.fieldDisabled(field),
      this.inputId(field.name),
      this.fieldDescription(field),
      this.theme,
      (value: Object | undefined): void => {
        this.changeCustom(field, value);
      },
      (): void => {
        this.validateBlur(field);
      }
    );
  }

  @Builder
  private customFieldView(field: FormFieldSpec): void {
    ForEach(this.renderers.matching(field.type), (renderer: HmFormFieldRenderer): void => {
      renderer.builder(this.fieldContext(field))
    })
  }

  private submitContext(): HmFormSubmitSlotContext {
    const stepSubmit = this.structure?.hasSteps() === true;
    return new HmFormSubmitSlotContext(
      this.controller.submitting,
      this.controller.submitting ? '校验中…' : (stepSubmit ? '提交表单' : '验证并定位首错'),
      this.controller.submitting ? '表单正在校验' :
        (stepSubmit ? '校验并提交完整表单' : '校验表单并将焦点移动到第一个错误字段'),
      this.theme,
      (): void => {
        this.submitAndFocus();
      }
    );
  }

  private booleanAccessibilityText(field: FormFieldSpec): string {
    return `${field.label}，${this.controller.getValue(field.name) === true ? '已开启' : '已关闭'}`;
  }

  private fieldsForSection(section: FormSectionSpec): FormFieldSpec[] {
    const result: FormFieldSpec[] = [];
    for (const name of section.fieldNames) {
      for (const field of this.fields) {
        if (field.name === name) result.push(field);
      }
    }
    return result;
  }

  private sectionHasKeepAlive(section: FormSectionSpec): boolean {
    for (const name of section.fieldNames) {
      for (const field of this.fields) if (field.name === name && field.keepAlive) return true;
    }
    return false;
  }

  private sectionActive(section: FormSectionSpec): boolean {
    for (const active of this.structure?.activeSections() ?? []) if (active.id === section.id) return true;
    return false;
  }

  private fieldRenderActive(field: FormFieldSpec, section: FormSectionSpec | undefined): boolean {
    if (!field.isVisible(this.controller.values)) return false;
    return section === undefined || (this.sectionActive(section) && this.structure?.isExpanded(section.id) === true);
  }

  private fieldShouldBuild(field: FormFieldSpec, section: FormSectionSpec | undefined): boolean {
    return field.keepAlive || this.fieldRenderActive(field, section);
  }

  private renderedSections(): FormSectionSpec[] {
    const result: FormSectionSpec[] = [];
    for (const section of this.structure?.sections ?? []) {
      if (this.sectionActive(section) || this.sectionHasKeepAlive(section)) result.push(section);
    }
    return result;
  }

  private showDatePicker(field: FormFieldSpec): void {
    if (this.fieldDisabled(field)) {
      return;
    }
    const selected = field.dateSelected(this.controller.getValue(field.name));
    this.getUIContext().showDatePickerDialog({
      start: field.startDate,
      end: field.endDate,
      selected: selected,
      onAccept: (value: DatePickerResult): void => {
        const year = value.year === undefined ? selected.getFullYear() : value.year;
        const month = value.month === undefined ? selected.getMonth() : value.month;
        const day = value.day === undefined ? selected.getDate() : value.day;
        this.changeDate(field, new Date(year, month, day));
      }
    });
  }

  @Builder
  private fieldMessage(field: FormFieldSpec): void {
    if (this.controller.errors[field.name] !== undefined) {
      if (field.usesSlot(FormFieldSlot.ERROR)) {
        this.error(this.fieldContext(field))
      } else {
        this.defaultError(this.fieldContext(field))
      }
    } else if (this.controller.validating[field.name] === true) {
      Text('校验中…')
        .fontSize('12fp')
        .fontColor(this.theme.validatingColor)
    } else if (this.controller.optionsLoading[field.name] === true ||
      this.controller.optionErrors[field.name] !== undefined) {
    } else if (field.usesSlot(FormFieldSlot.HELP)) {
      this.help(this.fieldContext(field))
    } else if (field.help !== '') {
      this.defaultHelp(this.fieldContext(field))
    }
  }

  @Builder
  private fieldControl(field: FormFieldSpec): void {
    if (this.controller.optionsLoading[field.name] === true) {
        Row({ space: 8 }) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color(this.theme.primaryColor)
          Text('正在加载选项…')
            .id(`hmkit_options_${field.name}_loading`)
            .fontSize('14fp')
            .fontColor(this.theme.secondaryTextColor)
        }
        .id(this.inputId(field.name))
        .width('100%')
        .constraintSize({ minHeight: this.theme.controlMinHeight })
        .padding({ left: 12, right: 12 })
        .backgroundColor(this.theme.disabledSurfaceColor)
        .borderRadius(this.theme.borderRadius)
        .accessibilityGroup(true)
        .accessibilityText(field.label)
        .accessibilityDescription('正在加载选项')
        .accessibilityLevel('yes')
    } else if (this.controller.optionErrors[field.name] !== undefined) {
        Row({ space: 8 }) {
          Text(this.controller.optionErrors[field.name])
            .id(`hmkit_options_${field.name}_error`)
            .layoutWeight(1)
            .fontSize('14fp')
            .fontColor(this.theme.errorColor)
          Button('重试')
            .id(`hmkit_options_${field.name}_retry`)
            .type(ButtonType.Normal)
            .constraintSize({ minHeight: this.theme.controlMinHeight })
            .onClick((): void => {
              this.controller.loadOptions(field.name);
            })
        }
        .id(this.inputId(field.name))
        .width('100%')
        .padding({ left: 12, right: 4 })
        .backgroundColor(this.theme.surfaceColor)
        .borderRadius(this.theme.borderRadius)
        .borderWidth(1)
        .borderColor(this.theme.errorColor)
        .accessibilityGroup(true)
        .accessibilityText(field.label)
        .accessibilityDescription(`选项加载失败：${this.controller.optionErrors[field.name]}，可重试`)
        .accessibilityLevel('yes')
      } else if (field.type === FormFieldType.TEXTAREA) {
        TextArea({
          text: this.controller.displayValue(field.name),
          placeholder: field.placeholder
        })
          .id(this.inputId(field.name))
          .constraintSize({ minHeight: this.theme.textAreaMinHeight })
          .maxLength(this.textAreaMaxLength(field))
          .enabled(!this.fieldDisabled(field))
          .backgroundColor(this.fieldDisabled(field) ? this.theme.disabledSurfaceColor : this.theme.surfaceColor)
          .borderRadius(this.theme.borderRadius)
          .borderWidth(1)
          .borderColor(this.controller.errors[field.name] === undefined ? this.theme.borderColor : this.theme.errorColor)
          .accessibilityText(field.label)
          .accessibilityDescription(this.fieldDescription(field))
          .accessibilityLevel('yes')
          .onChange((text: string): void => {
            this.changeText(field, text);
          })
          .onBlur((): void => {
            this.validateBlur(field);
          })
      } else if (field.type === FormFieldType.SELECT) {
        Select(this.selectOptions(field))
          .id(this.inputId(field.name))
          .selected(field.selectIndex(this.controller.getValue(field.name), this.fieldOptions(field)))
          .value(field.selectLabel(this.controller.getValue(field.name), this.fieldOptions(field)) || field.placeholder)
          .width('100%')
          .constraintSize({ minHeight: this.theme.controlMinHeight })
          .enabled(!this.fieldDisabled(field))
          .backgroundColor(this.fieldDisabled(field) ? this.theme.disabledSurfaceColor : this.theme.surfaceColor)
          .borderRadius(this.theme.borderRadius)
          .borderWidth(1)
          .borderColor(this.controller.errors[field.name] === undefined ? this.theme.borderColor : this.theme.errorColor)
          .accessibilityText(field.label)
          .accessibilityDescription(this.fieldDescription(field))
          .accessibilityLevel('yes')
          .onSelect((index: number, _label: string): void => {
            this.changeSelect(field, index);
          })
          .onBlur((): void => {
            this.validateBlur(field);
          })
      } else if (field.type === FormFieldType.RADIO) {
        Column({ space: 8 }) {
          ForEach(this.fieldOptions(field), (option: FormSelectOption, index: number): void => {
            Row({ space: 8 }) {
              Radio({ value: option.value, group: this.inputId(field.name) })
                .id(index === 0 ? this.inputId(field.name) : `${this.inputId(field.name)}_${index}`)
                .checked(this.controller.getValue(field.name) === option.value)
                .enabled(!this.fieldDisabled(field))
                .accessibilityLevel('no')
                .onChange((checked: boolean): void => {
                  if (checked) {
                    this.changeSelect(field, index);
                  }
                })
              Text(option.label)
                .fontSize('14fp')
                .fontColor(this.fieldDisabled(field) ? this.theme.disabledTextColor : this.theme.textColor)
            }
            .id(`${this.inputId(field.name)}_${index}_row`)
            .width('100%')
            .constraintSize({ minHeight: this.theme.controlMinHeight })
            .padding({ left: 4, right: 4 })
            .accessibilityGroup(true)
            .accessibilityText(`${field.label}，${option.label}，${this.controller.getValue(field.name) === option.value ? '已选中' : '未选中'}`)
            .accessibilityDescription(this.fieldDescription(field))
            .accessibilityLevel('yes')
            .onClick((): void => {
              this.changeSelect(field, index);
            })
          }, (option: FormSelectOption): string => `${field.name}_${option.value}`)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.fieldDisabled(field) ? this.theme.disabledSurfaceColor : this.theme.surfaceColor)
        .borderRadius(this.theme.borderRadius)
        .borderWidth(1)
        .borderColor(this.controller.errors[field.name] === undefined ? this.theme.borderColor : this.theme.errorColor)
      } else if (field.type === FormFieldType.CHECKBOX) {
        Column({ space: 8 }) {
          ForEach(this.fieldOptions(field), (option: FormSelectOption, index: number): void => {
            Row({ space: 8 }) {
              Checkbox({ name: option.value, group: this.inputId(field.name) })
                .id(index === 0 ? this.inputId(field.name) : `${this.inputId(field.name)}_${index}`)
                .select(field.isOptionSelected(this.controller.getValue(field.name), option.value,
                  this.fieldOptions(field)))
                .selectedColor(this.theme.primaryColor)
                .enabled(!this.fieldDisabled(field))
                .accessibilityLevel('no')
                .hitTestBehavior(HitTestMode.None)
              Text(option.label)
                .fontSize('14fp')
                .fontColor(this.fieldDisabled(field) ? this.theme.disabledTextColor : this.theme.textColor)
            }
            .id(`${this.inputId(field.name)}_${index}_row`)
            .width('100%')
            .constraintSize({ minHeight: this.theme.controlMinHeight })
            .padding({ left: 4, right: 4 })
            .accessibilityGroup(true)
            .accessibilityText(`${field.label}，${option.label}，${field.isOptionSelected(this.controller.getValue(field.name), option.value, this.fieldOptions(field)) ? '已选中' : '未选中'}`)
            .accessibilityDescription(this.fieldDescription(field))
            .accessibilityLevel('yes')
            .enabled(!this.fieldDisabled(field))
            .onClick((): void => {
              const selected = field.isOptionSelected(this.controller.getValue(field.name), option.value,
                this.fieldOptions(field));
              this.changeCheckbox(field, option.value, !selected);
            })
          }, (option: FormSelectOption): string => `${field.name}_${option.value}`)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.fieldDisabled(field) ? this.theme.disabledSurfaceColor : this.theme.surfaceColor)
        .borderRadius(this.theme.borderRadius)
        .borderWidth(1)
        .borderColor(this.controller.errors[field.name] === undefined ? this.theme.borderColor : this.theme.errorColor)
      } else if (field.type === FormFieldType.SWITCH) {
        Row() {
          Text(this.controller.getValue(field.name) === true ? '已开启' : '已关闭')
            .fontSize('14fp')
            .fontColor(this.fieldDisabled(field) ? this.theme.disabledTextColor : this.theme.textColor)
          Blank()
          Toggle({
            type: ToggleType.Switch,
            isOn: this.controller.getValue(field.name) === true
          })
            .id(this.inputId(field.name))
            .enabled(!this.fieldDisabled(field))
            .accessibilityText(this.booleanAccessibilityText(field))
            .accessibilityDescription(this.fieldDescription(field))
            .accessibilityLevel('yes')
            .onChange((isOn: boolean): void => {
              this.changeBoolean(field, isOn);
            })
        }
        .width('100%')
        .constraintSize({ minHeight: this.theme.controlMinHeight })
        .padding({ left: 12, right: 12 })
        .backgroundColor(this.fieldDisabled(field) ? this.theme.disabledSurfaceColor : this.theme.surfaceColor)
        .borderRadius(this.theme.borderRadius)
        .borderWidth(1)
        .borderColor(this.controller.errors[field.name] === undefined ? this.theme.borderColor : this.theme.errorColor)
      } else if (field.type === FormFieldType.DATE) {
        Button(field.dateDisplayValue(this.controller.getValue(field.name)) || field.placeholder)
          .id(this.inputId(field.name))
          .type(ButtonType.Normal)
          .width('100%')
          .constraintSize({ minHeight: this.theme.controlMinHeight })
          .enabled(!this.fieldDisabled(field))
          .fontColor(field.dateDisplayValue(this.controller.getValue(field.name)) === '' ? this.theme.placeholderColor : this.theme.textColor)
          .backgroundColor(this.fieldDisabled(field) ? this.theme.disabledSurfaceColor : this.theme.surfaceColor)
          .borderRadius(this.theme.borderRadius)
          .borderWidth(1)
          .borderColor(this.controller.errors[field.name] === undefined ? this.theme.borderColor : this.theme.errorColor)
          .accessibilityText(field.label)
          .accessibilityDescription(this.fieldDescription(field))
          .accessibilityLevel('yes')
          .onClick((): void => {
            this.showDatePicker(field);
          })
      } else if (FormFieldType.isCustom(field.type)) {
        this.customFieldView(field)
      } else {
        TextInput({
          text: this.controller.displayValue(field.name),
          placeholder: field.placeholder
        })
          .id(this.inputId(field.name))
          .type(this.textInputType(field))
          .constraintSize({ minHeight: this.theme.controlMinHeight })
          .enabled(!this.fieldDisabled(field))
          .backgroundColor(this.fieldDisabled(field) ? this.theme.disabledSurfaceColor : this.theme.surfaceColor)
          .borderRadius(this.theme.borderRadius)
          .borderWidth(1)
          .borderColor(this.controller.errors[field.name] === undefined ? this.theme.borderColor : this.theme.errorColor)
          .accessibilityText(field.label)
          .accessibilityDescription(this.fieldDescription(field))
          .accessibilityLevel('yes')
          .onChange((text: string): void => {
            this.changeText(field, text);
          })
          .onBlur((): void => {
            this.validateBlur(field);
          })
      }
  }

  @Builder
  private decoratedFieldControl(field: FormFieldSpec): void {
    if (field.usesSlot(FormFieldSlot.PREFIX) || field.usesSlot(FormFieldSlot.SUFFIX)) {
      Row({ space: 8 }) {
        if (field.usesSlot(FormFieldSlot.PREFIX)) {
          this.prefix(this.fieldContext(field))
        }
        Column() {
          this.fieldControl(field)
        }
        .layoutWeight(1)
        if (field.usesSlot(FormFieldSlot.SUFFIX)) {
          this.suffix(this.fieldContext(field))
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    } else {
      this.fieldControl(field)
    }
  }

  @Builder
  private fieldView(field: FormFieldSpec): void {
    Column({ space: 6 }) {
      if (field.usesSlot(FormFieldSlot.LABEL)) {
        this.label(this.fieldContext(field))
      } else {
        this.defaultLabel(this.fieldContext(field))
      }
      this.decoratedFieldControl(field)
      this.fieldMessage(field)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private fieldGrid(fields: FormFieldSpec[], section: FormSectionSpec | undefined = undefined): void {
    GridRow({
      columns: 12,
      gutter: { x: this.layout.columnGap, y: this.layout.rowGap },
      breakpoints: {
        value: [this.layout.breakpoint],
        reference: BreakpointsReference.ComponentSize
      }
    }) {
      ForEach(fields, (field: FormFieldSpec): void => {
        GridCol({ span: { xs: 12, sm: field.span } }) {
          if (this.fieldShouldBuild(field, section)) {
            this.fieldView(field)
          }
        }
        .width('100%')
        .visibility(this.fieldRenderActive(field, section) ? Visibility.Visible : Visibility.None)
      }, (field: FormFieldSpec): string => field.name)
    }
    .width('100%')
  }

  @Builder
  private sectionView(section: FormSectionSpec): void {
    // keepAlive sections stay under the same keyed parent while inactive.
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text(section.title)
            .fontSize('16fp')
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.textColor)
          if (section.description !== '') {
            Text(section.description)
              .fontSize('12fp')
              .fontColor(this.theme.secondaryTextColor)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        if (section.collapsible) {
          Text(this.structure?.isExpanded(section.id) === true ? '收起' : '展开')
            .id(`hmkit_form_section_${section.id}_toggle`)
            .fontSize('14fp')
            .fontColor(this.theme.primaryColor)
        }
      }
      .id(`hmkit_form_section_${section.id}`)
      .width('100%')
      .constraintSize({ minHeight: this.theme.controlMinHeight })
      .accessibilityGroup(true)
      .accessibilityText(section.title)
      .accessibilityDescription(section.collapsible ?
        (this.structure?.isExpanded(section.id) === true ? '已展开，可收起' : '已收起，可展开') : section.description)
      .accessibilityLevel('yes')
      .onClick((): void => {
        if (section.collapsible) this.structure?.toggleSection(section.id);
      })

      if (this.structure?.isExpanded(section.id) === true || this.sectionHasKeepAlive(section)) {
        this.fieldGrid(this.fieldsForSection(section), section)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.theme.surfaceColor)
    .borderRadius(this.theme.borderRadius)
    .borderWidth(1)
    .borderColor(this.theme.borderColor)
    .visibility(this.sectionActive(section) ? Visibility.Visible : Visibility.None)
  }

  @Builder
  private stepHeader(): void {
    Column({ space: 4 }) {
      Text(`步骤 ${this.structure === undefined ? 1 : this.structure.currentStepIndex + 1}/${this.structure?.steps.length ?? 1}`)
        .fontSize('12fp')
        .fontColor(this.theme.primaryColor)
      Text(this.structure?.currentStep()?.title ?? '')
        .id(`hmkit_form_step_${this.structure?.currentStepId() ?? ''}`)
        .fontSize('20fp')
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.textColor)
      if ((this.structure?.currentStep()?.description ?? '') !== '') {
        Text(this.structure?.currentStep()?.description ?? '')
          .fontSize('13fp')
          .fontColor(this.theme.secondaryTextColor)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .accessibilityGroup(true)
    .accessibilityText(`${this.structure?.currentStep()?.title ?? ''}，步骤 ${this.structure === undefined ? 1 : this.structure.currentStepIndex + 1}/${this.structure?.steps.length ?? 1}`)
    .accessibilityLevel('yes')
  }

  @Builder
  private stepNavigation(): void {
    Row({ space: 12 }) {
      if (this.structure?.canPrevious() === true) {
        Button('上一步')
          .id('hmkit_form_previous')
          .layoutWeight(1)
          .constraintSize({ minHeight: this.theme.controlMinHeight })
          .enabled(this.structure?.validatingStep !== true && !this.controller.submitting)
          .onClick((): void => {
            this.submitVersion++;
            this.structure?.previous();
          })
      }
      if (this.structure?.canNext() === true) {
        Button(this.structure?.validatingStep === true ? '校验中…' : '下一步')
          .id('hmkit_form_next')
          .layoutWeight(1)
          .constraintSize({ minHeight: this.theme.controlMinHeight })
          .enabled(this.structure?.validatingStep !== true && !this.controller.submitting)
          .onClick((): void => {
            this.validateAndNext();
          })
      } else {
        Row() {
          this.submit(this.submitContext())
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
  }

  build(): void {
    Column({ space: 16 }) {
      this.errorSummaryView()
      if (this.structure === undefined) {
        this.fieldGrid(this.fields)
        this.submit(this.submitContext())
      } else {
        if (this.structure.currentStep() !== undefined) {
          this.stepHeader()
        }
        ForEach(this.renderedSections(), (section: FormSectionSpec): void => {
          this.sectionView(section)
        }, (section: FormSectionSpec): string => section.id)
        if (this.structure.hasSteps()) {
          this.stepNavigation()
        } else {
          this.submit(this.submitContext())
        }
      }

      this.footer()
    }
    .width('100%')
  }
}
