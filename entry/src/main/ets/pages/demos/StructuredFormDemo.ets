import { FormController, FormFieldSpec, FormFieldType, FormSectionSpec, FormStepSpec,
  FormStructureController, HmFormTheme, HmFormView } from '@hmkit/form';
import { v } from '@hmkit/validator';

@ComponentV2
export struct StructuredFormDemo {
  @Require @Param theme: HmFormTheme;

  private fields: FormFieldSpec[] = [
    new FormFieldSpec('accountName', FormFieldType.TEXT, '账号名称',
      v.string().required('请输入账号名称'), '请输入账号名称'),
    new FormFieldSpec('email', FormFieldType.TEXT, '联系邮箱',
      v.string().required('请输入联系邮箱').email('邮箱格式不正确'), '请输入联系邮箱', undefined,
      { 'keepAlive': true }),
    new FormFieldSpec('company', FormFieldType.TEXT, '企业名称',
      v.string().required('请输入企业名称'), '请输入企业名称', undefined, { 'keepAlive': true }),
    new FormFieldSpec('agreement', FormFieldType.SWITCH, '确认资料真实',
      v.boolean().isTrue('请确认资料真实'))
  ];
  private structure: FormStructureController = new FormStructureController([
    new FormSectionSpec('account', '账号资料', ['accountName'], {
      'description': '第一步仅校验当前区块',
      'collapsible': true
    }),
    new FormSectionSpec('contact', '联系邮箱', ['email'], {
      'description': '默认收起，错误摘要可直接展开并定位',
      'collapsible': true,
      'defaultExpanded': false
    }),
    new FormSectionSpec('company', '企业资料', ['company'], {
      'collapsible': true
    }),
    new FormSectionSpec('confirm', '提交确认', ['agreement'])
  ], [
    new FormStepSpec('account', '创建账号', ['account', 'contact'], {
      'description': '完成当前步骤后再进入企业资料'
    }),
    new FormStepSpec('company', '企业认证', ['company', 'confirm'], {
      'description': '最终提交会再次校验完整表单'
    })
  ]);
  @Local values: Record<string, Object> = {};
  @Local submitStatus: string = '尚未提交';
  private controller: FormController = new FormController(this.fields, this.values, { 'debounceMs': 0 });

  aboutToDisappear(): void {
    this.controller.dispose();
    this.structure.dispose();
  }

  build(): void {
    Column({ space: 16 }) {
      Text('分组与分步表单')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textColor)
      Text('稳定区块 · 局部校验 · 跨步骤错误定位')
        .fontSize(13)
        .fontColor(this.theme.secondaryTextColor)
      HmFormView({
        fields: this.fields,
        values: this.values!!,
        controller: this.controller,
        structure: this.structure,
        showErrorSummary: true,
        theme: this.theme,
        onSubmit: (_values: Record<string, Object>): void => {
          this.submitStatus = '提交成功';
        },
        onInvalid: (errors: Record<string, string>): void => {
          this.submitStatus = `提交失败：${Object.keys(errors).length} 项错误`;
        }
      })
      Button('模拟服务端使账号失效')
        .id('hmkit_structure_invalidate_account')
        .width('100%')
        .constraintSize({ minHeight: this.theme.controlMinHeight })
        .onClick((): void => {
          this.values = { 'email': 'demo@hmkit.dev' };
        })
      Text(`结构值：${JSON.stringify(this.values)}`)
        .id('hmkit_structure_values')
        .fontSize(12)
        .fontColor(this.theme.secondaryTextColor)
      Text(this.submitStatus)
        .id('hmkit_structure_submit_status')
        .fontSize(12)
        .fontColor(this.theme.secondaryTextColor)
    }
    .width('100%')
  }
}
