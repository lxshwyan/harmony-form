import { FormController, FormFieldSpec, FormFieldType, FormSelectOption, HmFormTheme, HmFormView,
  getFormValue, inferFormFields } from '@hmkit/form';
import { v } from '@hmkit/validator';

const INFERRED_NESTED_FIELDS = inferFormFields({
  'profile.name': v.string().required('请输入姓名').label('姓名'),
  'profile.email': v.string().email('邮箱格式不正确').default('guest@hmkit.dev').label('邮箱'),
  'address.country': v.enumOf(['CN', 'US']).default('CN').label('国家/地区')
}, {
  'profile.name': { 'uiOptions': { 'span': 6 } },
  'profile.email': { 'uiOptions': { 'span': 6 } },
  'address.country': { 'uiOptions': {
    'span': 6,
    'options': [new FormSelectOption('中国', 'CN'), new FormSelectOption('美国', 'US')]
  } }
});

@ComponentV2
export struct NestedFormDemo {
  @Require @Param theme: HmFormTheme;

  private fields: FormFieldSpec[] = [
    INFERRED_NESTED_FIELDS.fields[0],
    INFERRED_NESTED_FIELDS.fields[1],
    INFERRED_NESTED_FIELDS.fields[2],
    new FormFieldSpec('address.postcode', FormFieldType.TEXT, '邮政编码',
      v.string().requiredWhen('address.country',
        (country: Object | null | undefined): boolean => country === 'CN', '中国地址需要邮政编码'),
      '请输入邮政编码', undefined, {
        'span': 6,
        'dependencies': ['address.country'],
        'visibleWhen': (values: Record<string, Object>): boolean =>
          getFormValue(values, 'address.country') === 'CN'
      })
  ];
  @Local values: Record<string, Object> = INFERRED_NESTED_FIELDS.getInitialValues();
  @Local submitStatus: string = '尚未提交';
  private controller: FormController = new FormController(this.fields, this.values, { 'debounceMs': 0 });

  aboutToDisappear(): void {
    this.controller.dispose();
  }

  build(): void {
    Column({ space: 16 }) {
      Text('嵌套资料')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textColor)
      Text('点路径字段 · 嵌套 values · 完整路径依赖')
        .fontSize(13)
        .fontColor(this.theme.secondaryTextColor)
      HmFormView({
        fields: this.fields,
        values: this.values!!,
        controller: this.controller,
        theme: this.theme,
        onSubmit: (values: Record<string, Object>): void => {
          this.submitStatus = `提交成功：${getFormValue(values, 'profile.name')}`;
        },
        onInvalid: (errors: Record<string, string>): void => {
          this.submitStatus = `提交失败：${Object.keys(errors).length} 项错误`;
        }
      })
      Text(`嵌套值：${JSON.stringify(this.values)}`)
        .id('hmkit_nested_values')
        .fontSize(12)
        .fontColor(this.theme.secondaryTextColor)
      Text(this.submitStatus)
        .id('hmkit_nested_submit_status')
        .fontSize(12)
        .fontColor(this.theme.secondaryTextColor)
      Button('服务端嵌套回填')
        .id('hmkit_nested_refill')
        .width('100%')
        .constraintSize({ minHeight: this.theme.controlMinHeight })
        .onClick((): void => {
          this.values = {
            'profile': { 'name': '服务端嵌套用户', 'email': 'nested@hmkit.dev' } as Record<string, Object>,
            'address': { 'country': 'CN', 'postcode': '200000' } as Record<string, Object>
          };
        })
    }
    .width('100%')
  }
}
