import { FormArrayController, FormController, FormFieldSlot, FormFieldSpec, FormFieldType, FormOptionsLoader, FormSelectOption,
  FormSectionSpec, FormStepSpec, FormStructureController,
  HmFormErrorSummaryContext, HmFormErrorSummaryItem, HmFormFieldRenderContext,
  HmFormArrayItemContext, HmFormArrayView, HmFormLayout, HmFormRendererRegistry, HmFormSubmitSlotContext, HmFormTheme, HmFormView,
  getFormValue, inferFormFields } from '@hmkit/form';
import { v } from '@hmkit/validator';

const SEGMENTED_TYPE: string = FormFieldType.custom('segmented');
const loadConsumerRoles: FormOptionsLoader = async (): Promise<FormSelectOption[]> => [
  new FormSelectOption('管理员', 'admin'),
  new FormSelectOption('成员', 'member')
];
const INFERRED_CONSUMER = inferFormFields({
  'profile.name': v.string().required('请输入姓名').label('姓名')
}, {
  'profile.name': { 'uiOptions': { 'slots': [FormFieldSlot.PREFIX], 'span': 6 } }
});

@Builder
function ConsumerSegmentedRenderer(context: HmFormFieldRenderContext): void {
  Row({ space: 8 }) {
    ForEach(context.field.options, (option: FormSelectOption, index: number): void => {
      Button(option.label)
        .id(index === 0 ? context.inputId : `${context.inputId}_${index}`)
        .layoutWeight(1)
        .enabled(!context.disabled)
        .backgroundColor(context.value === option.value ? context.theme.primaryColor : context.theme.surfaceColor)
        .fontColor(context.value === option.value ? '#FFFFFF' : context.theme.textColor)
        .borderWidth(1)
        .borderColor(context.error === undefined ? context.theme.borderColor : context.theme.errorColor)
        .onClick((): void => { context.change(option.value); })
        .onBlur((): void => { context.blur(); })
    }, (option: FormSelectOption): string => `${context.field.name}_${option.value}`)
  }
  .width('100%')
}

@Builder
function ConsumerPrefix(context: HmFormFieldRenderContext): void {
  Text('#')
    .id(`consumer_slot_prefix_${context.field.name}`)
    .fontColor(context.theme.primaryColor)
}

@Builder
function ConsumerSubmit(context: HmFormSubmitSlotContext): void {
  Button(context.submitting ? 'validating' : 'submit from HAR')
    .id('consumer_slot_submit')
    .width('100%')
    .enabled(!context.submitting)
    .onClick((): void => { context.submit(); })
}

@Builder
function ConsumerErrorSummary(context: HmFormErrorSummaryContext): void {
  Column({ space: 4 }) {
    Text(context.title)
      .id('consumer_error_summary')
      .fontColor(context.theme.errorColor)
    ForEach(context.items, (item: HmFormErrorSummaryItem): void => {
      Button(`${item.label}: ${item.message}`)
        .id(`consumer_error_${item.name}`)
        .onClick((): void => { context.activate(item.name); })
    }, (item: HmFormErrorSummaryItem): string => item.name)
  }
  .width('100%')
}

@Builder
function ConsumerArrayItem(context: HmFormArrayItemContext): void {
  Text(`HAR item ${context.index + 1}: ${context.value}`)
    .id(`consumer_array_${context.index}`)
}

@Entry
@ComponentV2
struct Index {
  private fields: FormFieldSpec[] = [
    INFERRED_CONSUMER.fields[0],
    new FormFieldSpec('roles', FormFieldType.CHECKBOX, '角色', v.array(v.string()).min(1, '请选择角色'), '',
      undefined, {
        'optionsLoader': loadConsumerRoles,
        'span': 6,
        'keepAlive': true
      }),
    new FormFieldSpec('level', SEGMENTED_TYPE, '服务级别', v.string().required('请选择服务级别'), '',
      undefined, {
        'options': [new FormSelectOption('普通', 'normal'), new FormSelectOption('优先', 'priority')]
      })
  ];
  @Local values: Record<string, Object> = {};
  @Local submitStatus: string = '';
  @Local arrayValues: Object[] = ['one', 'two'];
  private controller: FormController = new FormController(this.fields, this.values);
  private structure: FormStructureController = new FormStructureController([
    new FormSectionSpec('profile', '资料', ['profile.name', 'roles'], { 'collapsible': true }),
    new FormSectionSpec('service', '服务', ['level'])
  ], [
    new FormStepSpec('profile', '资料', ['profile']),
    new FormStepSpec('service', '服务', ['service'])
  ]);
  private arrayController: FormArrayController = new FormArrayController(this.arrayValues);
  private theme: HmFormTheme = HmFormTheme.light();
  private layout: HmFormLayout = new HmFormLayout({ 'breakpoint': '600vp', 'columnGap': 12, 'rowGap': 16 });
  private renderers: HmFormRendererRegistry = new HmFormRendererRegistry()
    .register(SEGMENTED_TYPE, wrapBuilder(ConsumerSegmentedRenderer));

  aboutToDisappear(): void {
    this.controller.dispose();
    this.arrayController.dispose();
    this.structure.dispose();
  }

  build(): void {
    Column({ space: 16 }) {
      Text('External HAR consumer')
        .fontSize(20)
      HmFormView({
        fields: this.fields,
        values: this.values!!,
        controller: this.controller,
        theme: this.theme,
        renderers: this.renderers,
        layout: this.layout,
        structure: this.structure,
        showErrorSummary: true,
        prefix: ConsumerPrefix,
        submit: ConsumerSubmit,
        errorSummary: ConsumerErrorSummary,
        onSubmit: (values: Record<string, Object>): void => {
          this.submitStatus = `submitted:${getFormValue(values, 'profile.name')}`;
        },
        onInvalid: (errors: Record<string, string>): void => {
          this.submitStatus = `invalid:${Object.keys(errors).length}`;
        }
      })
      Text(this.submitStatus)
      HmFormArrayView({
        values: this.arrayValues!!,
        controller: this.arrayController,
        item: ConsumerArrayItem
      })
    }
    .width('100%')
    .padding(20)
  }
}
