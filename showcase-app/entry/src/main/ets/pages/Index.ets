import { FormArrayController, FormController, FormFieldSlot, FormFieldSpec, FormFieldType, FormOptionsLoader,
  FormSelectOption, FormSectionSpec, FormStepSpec, FormStructureController, HmFormArrayItemContext,
  HmFormArrayView, HmFormFieldRenderContext, HmFormLayout, HmFormRendererRegistry,
  HmFormSubmitSlotContext, HmFormTheme, HmFormView, getFormValue, inferFormFields, setFormValue } from '@hmkit/form';
import { v } from '@hmkit/validator';

const SEGMENTED: string = FormFieldType.custom('segmented');
const inferred = inferFormFields({
  'profile.name': v.string().required('请输入负责人姓名').label('负责人').describe('与证件姓名保持一致'),
  'profile.age': v.number().min(18, '负责人须年满 18 岁').label('年龄')
}, {
  'profile.name': { 'uiOptions': { 'span': 6, 'slots': [FormFieldSlot.PREFIX] } },
  'profile.age': { 'uiOptions': { 'span': 6 } }
});
const loadRegions: FormOptionsLoader = async (): Promise<FormSelectOption[]> => [
  new FormSelectOption('华东', 'east'),
  new FormSelectOption('华南', 'south'),
  new FormSelectOption('华北', 'north')
];
let licenseAttempts: number = 0;
const loadLicenses: FormOptionsLoader = async (): Promise<FormSelectOption[]> => {
  licenseAttempts++;
  if (licenseAttempts === 1) throw new Error('资质服务暂不可用');
  return [new FormSelectOption('软件服务商', 'software'), new FormSelectOption('系统集成商', 'integrator')];
};

@Builder
function SegmentedRenderer(context: HmFormFieldRenderContext): void {
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
    }, (option: FormSelectOption): string => option.value)
  }
  .width('100%')
}

@Builder
function PrefixSlot(context: HmFormFieldRenderContext): void {
  Text('👤').id(`showcase_prefix_${context.field.name}`).fontSize('16fp')
}

@Builder
function SuffixSlot(context: HmFormFieldRenderContext): void {
  Text(context.field.name === 'profile.age' ? '岁' : '✓').fontColor(context.theme.primaryColor)
}

@Builder
function LabelSlot(context: HmFormFieldRenderContext): void {
  Text(`自定义标题 · ${context.field.label}`).fontColor(context.theme.primaryColor).fontWeight(FontWeight.Medium)
}

@Builder
function HelpSlot(context: HmFormFieldRenderContext): void {
  Text(`提示：${context.field.help}`).fontSize('12fp').fontColor(context.theme.secondaryTextColor)
}

@Builder
function ErrorSlot(context: HmFormFieldRenderContext): void {
  Text(`⚠ ${context.error ?? ''}`).fontSize('12fp').fontColor(context.theme.errorColor)
}

@Builder
function FooterSlot(): void {
  Text('数据仅用于本地 Showcase，不会上传。').fontSize('12fp').fontColor('#667085')
}

@Builder
function SubmitSlot(context: HmFormSubmitSlotContext): void {
  Button(context.submitting ? '正在校验…' : '提交企业入驻申请')
    .id('showcase_submit')
    .width('100%')
    .enabled(!context.submitting)
    .onClick((): void => { context.submit(); })
}

@Builder
function ContactItem(context: HmFormArrayItemContext): void {
  Row({ space: 8 }) {
    Text(`联系人 ${context.index + 1}：${context.value}`).layoutWeight(1)
    Button('上移').enabled(context.index > 0).onClick((): void => { context.moveUp(); })
    Button('删除').enabled(context.canRemove).onClick((): void => { context.remove(); })
  }
  .id(`showcase_contact_${context.index}`)
  .width('100%')
}

@Entry
@ComponentV2
struct Index {
  private fields: FormFieldSpec[] = [
    inferred.fields[0],
    inferred.fields[1],
    new FormFieldSpec('profile.email', FormFieldType.TEXT, '联系邮箱',
      v.string().required('请输入邮箱').email('邮箱格式不正确'), 'name@example.com', undefined,
      { 'span': 6, 'keepAlive': true, 'slots': [FormFieldSlot.SUFFIX] }),
    new FormFieldSpec('profile.bio', FormFieldType.TEXTAREA, '负责人简介', v.string().max(200), '最多 200 字',
      undefined, { 'maxLength': 200, 'help': '介绍专业方向与交付经验',
        'slots': [FormFieldSlot.LABEL, FormFieldSlot.HELP, FormFieldSlot.ERROR] }),
    new FormFieldSpec('business.region', FormFieldType.SELECT, '经营区域', v.string().required('请选择经营区域'),
      '远程加载', undefined, { 'optionsLoader': loadRegions, 'span': 6 }),
    new FormFieldSpec('business.channel', FormFieldType.RADIO, '首选沟通渠道', v.string().required('请选择沟通渠道'),
      '', undefined, { 'options': [new FormSelectOption('电话', 'phone'), new FormSelectOption('邮件', 'email')], 'span': 6 }),
    new FormFieldSpec('business.license', FormFieldType.SELECT, '企业资质', v.string().required('请选择企业资质'),
      '首次失败后可重试', undefined, { 'optionsLoader': loadLicenses, 'span': 6 }),
    new FormFieldSpec('business.services', FormFieldType.CHECKBOX, '服务能力',
      v.array(v.string()).min(1, '至少选择一项'), '', undefined, { 'options': [
        new FormSelectOption('设计', 'design'), new FormSelectOption('开发', 'development'),
        new FormSelectOption('运维', 'operations')
      ] }),
    new FormFieldSpec('business.level', SEGMENTED, '服务等级', v.string().required('请选择服务等级'), '', undefined,
      { 'options': [new FormSelectOption('标准', 'standard'), new FormSelectOption('优先', 'priority')],
        'disabledWhen': (values: Record<string, Object>): boolean => getFormValue(values, 'business.region') === undefined,
        'dependencies': ['business.region'], 'keepAlive': true }),
    new FormFieldSpec('business.visit', FormFieldType.SWITCH, '需要线下认证', v.boolean(), '', undefined, { 'span': 6 }),
    new FormFieldSpec('business.visitDate', FormFieldType.DATE, '认证日期', v.date().strict(), '请选择日期', undefined,
      { 'dependencies': ['business.visit'], 'visibleWhen': (values: Record<string, Object>): boolean =>
        values['business'] !== undefined && (values['business'] as Record<string, Object>)['visit'] === true,
        'keepAlive': true, 'span': 6 }),
    new FormFieldSpec('agreement', FormFieldType.SWITCH, '确认资料真实并同意协议',
      v.boolean().isTrue('请确认协议'))
  ];
  @Local values: Record<string, Object> = {};
  @Local contacts: Object[] = ['张三 / 13800000000'];
  @Local status: string = '等待填写';
  @Local dark: boolean = false;
  @Local compactPreview: boolean = false;
  private controller: FormController = new FormController(this.fields, this.values, { 'debounceMs': 0 });
  private contactsController: FormArrayController = new FormArrayController(this.contacts, { 'minItems': 1, 'maxItems': 4 });
  private structure: FormStructureController = new FormStructureController([
    new FormSectionSpec('owner', '负责人资料', ['profile.name', 'profile.age', 'profile.email', 'profile.bio'],
      { 'description': 'Schema 推导、嵌套路径、插槽与响应式栅格', 'collapsible': true }),
    new FormSectionSpec('business', '企业能力', ['business.region', 'business.channel', 'business.license', 'business.services',
      'business.level', 'business.visit', 'business.visitDate'],
      { 'description': '异步选项、条件依赖、自定义 renderer 与字段保活', 'collapsible': true }),
    new FormSectionSpec('confirm', '确认提交', ['agreement'], { 'collapsible': true })
  ], [
    new FormStepSpec('profile', '基础资料', ['owner']),
    new FormStepSpec('business', '业务与确认', ['business', 'confirm'])
  ]);
  private layout: HmFormLayout = HmFormLayout.responsive();
  private renderers: HmFormRendererRegistry = new HmFormRendererRegistry()
    .register(SEGMENTED, wrapBuilder(SegmentedRenderer));

  aboutToDisappear(): void {
    this.controller.dispose();
    this.contactsController.dispose();
    this.structure.dispose();
  }

  private theme(): HmFormTheme {
    return this.dark ? HmFormTheme.dark() : HmFormTheme.light();
  }

  private refill(): void {
    let next: Record<string, Object> = {};
    next = setFormValue(next, 'profile.name', '鸿蒙开发者');
    next = setFormValue(next, 'profile.age', 28);
    next = setFormValue(next, 'profile.email', 'dev@hmkit.cn');
    this.values = next;
    this.status = '已回填受控 values';
  }

  build(): void {
    Column() {
      Row() {
        Column({ space: 3 }) {
          Text('@hmkit/form Showcase').id('showcase_title').fontSize('22fp').fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textColor)
          Text('企业入驻工作台 · API 12 HAR 独立消费').fontSize('12fp').fontColor(this.theme().secondaryTextColor)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button(this.dark ? '浅色' : '深色').id('showcase_theme').onClick((): void => { this.dark = !this.dark; })
      }.width('100%').padding({ left: 20, right: 20, top: 18, bottom: 12 })

      Scroll() {
        Column({ space: 18 }) {
          Row({ space: 8 }) {
            Text(this.compactPreview ? '窄窗单列预览' : '当前窗口自适应')
              .id('showcase_2in1_layout_status')
              .fontSize('12fp')
              .fontColor(this.theme().secondaryTextColor)
              .layoutWeight(1)
            Button(this.compactPreview ? '展开宽窗' : '模拟窄窗')
              .id('showcase_2in1_compact')
              .onClick((): void => { this.compactPreview = !this.compactPreview; })
          }
          .width('100%')

          HmFormView({
            fields: this.fields,
            values: this.values!!,
            controller: this.controller,
            structure: this.structure,
            showErrorSummary: true,
            theme: this.theme(),
            layout: this.layout,
            renderers: this.renderers,
            prefix: PrefixSlot,
            suffix: SuffixSlot,
            label: LabelSlot,
            help: HelpSlot,
            error: ErrorSlot,
            submit: SubmitSlot,
            footer: FooterSlot,
            onSubmit: (_values: Record<string, Object>): void => { this.status = '提交成功'; },
            onInvalid: (errors: Record<string, string>): void => { this.status = `发现 ${Object.keys(errors).length} 项错误`; }
          })

          Column({ space: 10 }) {
            Row() {
              Text('动态联系人').fontSize('18fp').fontWeight(FontWeight.Medium).layoutWeight(1)
              Button('新增').id('showcase_add_contact').enabled(this.contactsController.canAppend())
                .onClick((): void => {
                  if (this.contactsController.append(`新联系人 ${this.contactsController.entries.length + 1}`)) {
                    this.contacts = this.contactsController.getValues();
                  }
                })
            }.width('100%')
            HmFormArrayView({ values: this.contacts!!, controller: this.contactsController, item: ContactItem })
          }.width('100%').padding(14).backgroundColor(this.theme().surfaceColor).borderRadius(12)

          Row({ space: 8 }) {
            Button('服务端回填').id('showcase_refill').layoutWeight(1).onClick((): void => {
              this.refill();
            })
            Button('重置').id('showcase_reset').layoutWeight(1).onClick((): void => {
              this.values = {};
              this.controller.reset({});
              this.structure.reset();
              this.status = '已重置';
            })
          }.width('100%')
          Text(this.status).id('showcase_status').fontSize('13fp').fontColor(this.theme().secondaryTextColor)
          Text(`当前模型：${JSON.stringify(this.values)}`).id('showcase_values').fontSize('11fp')
            .fontColor(this.theme().secondaryTextColor)
        }
        .width('100%')
        .constraintSize({ maxWidth: this.compactPreview ? 520 : 1200 })
        .alignSelf(ItemAlign.Center)
        .padding({ left: 20, right: 20, bottom: 32 })
      }.layoutWeight(1).scrollBar(BarState.Auto)
    }.width('100%').height('100%').backgroundColor(this.dark ? '#111827' : '#F5F7FB')
  }
}
