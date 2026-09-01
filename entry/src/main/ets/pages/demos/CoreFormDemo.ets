import { FormController, FormFieldSlot, FormFieldSpec, FormFieldType, FormSelectOption, HmFormFieldRenderContext,
  HmFormLayout, HmFormRendererRegistry, HmFormSubmitSlotContext, HmFormTheme, HmFormView,
  inferFormFields } from '@hmkit/form';
import { v } from '@hmkit/validator';

const SEGMENTED_TYPE: string = FormFieldType.custom('segmented');
const INFERRED_CORE_FIELDS = inferFormFields({
  'username': v.string().required('请输入用户名').min(3, '用户名至少 3 位').label('用户名'),
  'age': v.number().required('请输入年龄').integer('年龄必须是整数').min(18, '需年满 18 岁').label('年龄')
}, {
  'username': { 'uiOptions': { 'slots': [FormFieldSlot.PREFIX, FormFieldSlot.SUFFIX, FormFieldSlot.ERROR], 'span': 6 } },
  'age': { 'uiOptions': { 'span': 6 } }
});

@Builder
function SegmentedFieldRenderer(context: HmFormFieldRenderContext): void {
  Row({ space: 8 }) {
    ForEach(context.field.options, (option: FormSelectOption, index: number): void => {
      Button(option.label)
        .id(index === 0 ? context.inputId : `${context.inputId}_${index}`)
        .layoutWeight(1)
        .constraintSize({ minHeight: context.theme.controlMinHeight })
        .enabled(!context.disabled)
        .fontColor(context.value === option.value ? '#FFFFFF' : context.theme.textColor)
        .backgroundColor(context.value === option.value ? context.theme.primaryColor : context.theme.surfaceColor)
        .borderRadius(context.theme.borderRadius)
        .borderWidth(1)
        .borderColor(context.error === undefined ? context.theme.borderColor : context.theme.errorColor)
        .accessibilityText(`${context.field.label}，${option.label}`)
        .accessibilityDescription(context.description)
        .onClick((): void => { context.change(option.value); })
        .onBlur((): void => { context.blur(); })
    }, (option: FormSelectOption): string => `${context.field.name}_${option.value}`)
  }
  .width('100%')
}

@Builder
function FieldPrefix(context: HmFormFieldRenderContext): void {
  Text('@')
    .id(`hmkit_slot_prefix_${context.field.name}`)
    .fontSize('16fp')
    .fontColor(context.theme.primaryColor)
}

@Builder
function FieldSuffix(context: HmFormFieldRenderContext): void {
  Text('必填')
    .id(`hmkit_slot_suffix_${context.field.name}`)
    .fontSize('12fp')
    .fontColor(context.theme.secondaryTextColor)
}

@Builder
function FieldLabel(context: HmFormFieldRenderContext): void {
  Text(`⭐ ${context.field.label}`)
    .id(`hmkit_slot_label_${context.field.name}`)
    .fontSize('14fp')
    .fontColor(context.theme.primaryColor)
}

@Builder
function FieldHelp(context: HmFormFieldRenderContext): void {
  Text(`提示：${context.field.help}`)
    .id(`hmkit_slot_help_${context.field.name}`)
    .fontSize('12fp')
    .fontColor(context.theme.secondaryTextColor)
}

@Builder
function FieldError(context: HmFormFieldRenderContext): void {
  Text(`⚠ ${context.error ?? ''}`)
    .id(`hmkit_slot_error_${context.field.name}`)
    .fontSize('12fp')
    .fontColor(context.theme.errorColor)
}

@Builder
function FormSubmit(context: HmFormSubmitSlotContext): void {
  Button(context.submitting ? '正在处理…' : '提交资料')
    .id('hmkit_slot_submit')
    .width('100%')
    .constraintSize({ minHeight: context.theme.controlMinHeight })
    .enabled(!context.submitting)
    .accessibilityDescription(context.description)
    .onClick((): void => { context.submit(); })
}

@ComponentV2
export struct CoreFormDemo {
  @Require @Param theme: HmFormTheme;

  private fields: FormFieldSpec[] = [
    INFERRED_CORE_FIELDS.fields[0],
    INFERRED_CORE_FIELDS.fields[1],
    new FormFieldSpec('bio', FormFieldType.TEXTAREA, '个人简介',
      v.string().max(120, '个人简介不能超过 120 字'), '简单介绍你的经验与方向', undefined,
      { 'help': '选填，最多 120 字', 'maxLength': 120 }),
    new FormFieldSpec('city', FormFieldType.SELECT, '服务城市', v.string().required('请选择服务城市'),
      '请选择城市', undefined, {
        'help': '显示 label，受控值保存稳定 value',
        'slots': [FormFieldSlot.HELP],
        'span': 6,
        'options': [
          new FormSelectOption('上海市', 'shanghai'),
          new FormSelectOption('深圳市', 'shenzhen'),
          new FormSelectOption('杭州市', 'hangzhou')
        ]
      }),
    new FormFieldSpec('interests', FormFieldType.CHECKBOX, '兴趣偏好',
      v.array(v.string()).min(1, '至少选择一项兴趣'), '', undefined, {
        'help': '多选值以稳定 string[] 保存',
        'span': 6,
        'options': [
          new FormSelectOption('阅读', 'reading'),
          new FormSelectOption('运动', 'sports'),
          new FormSelectOption('音乐', 'music')
        ]
      }),
    new FormFieldSpec('serviceLevel', SEGMENTED_TYPE, '服务等级',
      v.string().required('请选择服务等级'), '', undefined, {
        'help': '由宿主通过 WrappedBuilder 注册的分段选择字段',
        'slots': [FormFieldSlot.LABEL],
        'options': [
          new FormSelectOption('标准', 'standard'),
          new FormSelectOption('优先', 'priority'),
          new FormSelectOption('加急', 'urgent')
        ]
      })
  ];
  @Local values: Record<string, Object> = {};
  @Local submitStatus: string = '尚未提交';
  @Local layout: HmFormLayout = HmFormLayout.responsive();
  private controller: FormController = new FormController(this.fields, this.values);
  private renderers: HmFormRendererRegistry = new HmFormRendererRegistry()
    .register(SEGMENTED_TYPE, wrapBuilder(SegmentedFieldRenderer));

  @Builder
  private valuePreview(): void {
    Text(`受控值：${JSON.stringify(this.values)}`)
      .id('hmkit_core_values')
      .fontSize(12)
      .fontColor(this.theme.secondaryTextColor)
  }

  aboutToDisappear(): void {
    this.controller.dispose();
  }

  build(): void {
    Column({ space: 16 }) {
      Text('核心字段')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textColor)
      Text('内置字段 · 自定义 registry · 受控回填')
        .fontSize(13)
        .fontColor(this.theme.secondaryTextColor)
      Row({ space: 8 }) {
        Button(this.layout.breakpoint === '600vp' ? '预览 tablet 双列' : '恢复自动断点')
          .id('hmkit_layout_toggle')
          .constraintSize({ minHeight: this.theme.controlMinHeight })
          .onClick((): void => {
            this.layout = new HmFormLayout({
              'breakpoint': this.layout.breakpoint === '600vp' ? '320vp' : '600vp',
              'columnGap': 16,
              'rowGap': 16
            });
          })
        Text(this.layout.breakpoint === '600vp' ? '容器 < 600vp：单列' : 'tablet 双列预览')
          .id('hmkit_layout_status')
          .fontSize('12fp')
          .fontColor(this.theme.secondaryTextColor)
      }
      .width('100%')
      HmFormView({
        fields: this.fields,
        values: this.values!!,
        controller: this.controller,
        theme: this.theme,
        renderers: this.renderers,
        layout: this.layout,
        prefix: FieldPrefix,
        suffix: FieldSuffix,
        label: FieldLabel,
        help: FieldHelp,
        error: FieldError,
        submit: FormSubmit,
        onSubmit: (values: Record<string, Object>): void => {
          this.submitStatus = `提交成功：${values['username']}`;
        },
        onInvalid: (errors: Record<string, string>): void => {
          this.submitStatus = `提交失败：${Object.keys(errors).length} 项错误`;
        },
        footer: (): void => { this.valuePreview() }
      })
      Text(this.submitStatus)
        .id('hmkit_core_submit_status')
        .fontSize(12)
        .fontColor(this.theme.secondaryTextColor)
      Row({ space: 8 }) {
        Button('外部回填')
          .id('hmkit_core_refill')
          .constraintSize({ minHeight: this.theme.controlMinHeight })
          .onClick((): void => {
            this.values = {
              'username': '服务端用户', 'age': 28,
              'bio': '服务端返回的多行简介', 'city': 'hangzhou',
              'interests': ['reading', 'music'], 'serviceLevel': 'priority'
            };
          })
        Button('外部清空')
          .id('hmkit_core_clear')
          .constraintSize({ minHeight: this.theme.controlMinHeight })
          .onClick((): void => { this.values = {}; })
      }
      .width('100%')
    }
    .width('100%')
  }
}
