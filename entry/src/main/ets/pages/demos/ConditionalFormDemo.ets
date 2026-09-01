import { FormController, FormFieldSpec, FormFieldType, FormSelectOption, HmFormTheme, HmFormView } from '@hmkit/form';
import { v } from '@hmkit/validator';

@ComponentV2
export struct ConditionalFormDemo {
  @Require @Param theme: HmFormTheme;

  private fields: FormFieldSpec[] = [
    new FormFieldSpec('contact', FormFieldType.RADIO, '首选联系方式', v.string().required('请选择联系方式'),
      '', undefined, { 'options': [
        new FormSelectOption('电话', 'phone'), new FormSelectOption('邮件', 'email')
      ] }),
    new FormFieldSpec('needsVisit', FormFieldType.SWITCH, '需要上门服务', v.boolean(), '', undefined,
      { 'help': '开启后显示日期字段' }),
    new FormFieldSpec('visitDate', FormFieldType.DATE, '期望上门日期',
      v.date().strict().required('请选择上门日期'), '请选择日期', undefined, {
        'help': 'model 使用 YYYY-MM-DD', 'dependencies': ['needsVisit'],
        'visibleWhen': (values: Record<string, Object>): boolean => values['needsVisit'] === true,
        'startDate': new Date(2026, 0, 1), 'endDate': new Date(2030, 11, 31)
      }),
    new FormFieldSpec('city', FormFieldType.SELECT, '服务城市', v.string(), '请选择城市', undefined, {
      'options': [new FormSelectOption('上海市', 'shanghai'), new FormSelectOption('深圳市', 'shenzhen')]
    }),
    new FormFieldSpec('priority', FormFieldType.SWITCH, '优先安排', v.boolean(), '', undefined, {
      'help': '选择服务城市后才可开启', 'dependencies': ['city'],
      'disabledWhen': (values: Record<string, Object>): boolean => values['city'] === undefined
    }),
    new FormFieldSpec('agreement', FormFieldType.SWITCH, '同意服务协议',
      v.boolean().isTrue('请先同意服务协议'), '', undefined, { 'help': 'Switch 保存 boolean' })
  ];
  @Local values: Record<string, Object> = { 'needsVisit': false, 'agreement': false };
  private controller: FormController = new FormController(this.fields, this.values);

  aboutToDisappear(): void {
    this.controller.dispose();
  }

  build(): void {
    Column({ space: 16 }) {
      Text('条件与依赖')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textColor)
      Text('radio · switch · date · 条件显示/禁用 · 一级依赖')
        .fontSize(13)
        .fontColor(this.theme.secondaryTextColor)
      HmFormView({ fields: this.fields, values: this.values!!, controller: this.controller, theme: this.theme })
      Text(`受控值：${JSON.stringify(this.values)}`)
        .fontSize(12)
        .fontColor(this.theme.secondaryTextColor)
    }
    .width('100%')
  }
}
