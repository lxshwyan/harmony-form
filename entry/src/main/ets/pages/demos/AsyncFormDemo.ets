import { FormController, FormFieldSpec, FormFieldType, FormSelectOption, HmFormTheme, HmFormView } from '@hmkit/form';
import { v } from '@hmkit/validator';

let cityOptionsAttempt: number = 0;

function checkAccountAvailable(account: string): Promise<boolean> {
  return new Promise<boolean>((resolve: (value: boolean) => void): void => {
    setTimeout((): void => {
      resolve(account.toLowerCase() !== 'admin');
    }, 700);
  });
}

async function loadServiceCities(): Promise<FormSelectOption[]> {
  cityOptionsAttempt++;
  await new Promise<void>((resolve: () => void): void => {
    setTimeout(resolve, 700);
  });
  if (cityOptionsAttempt === 1) {
    throw new Error('城市服务暂不可用');
  }
  return [
    new FormSelectOption('上海市', 'shanghai'),
    new FormSelectOption('深圳市', 'shenzhen'),
    new FormSelectOption('杭州市', 'hangzhou')
  ];
}

@ComponentV2
export struct AsyncFormDemo {
  @Require @Param theme: HmFormTheme;

  private fields: FormFieldSpec[] = [
    new FormFieldSpec('account', FormFieldType.TEXT, '账号',
      v.string().required('请输入账号').min(3, '账号至少 3 位')
        .customAsync(checkAccountAvailable, '该账号已被占用'),
      '输入 admin 可触发异步错误', { 'debounceMs': 350 },
      { 'help': '停止输入 350ms 后模拟 700ms 远程查重' }),
    new FormFieldSpec('email', FormFieldType.TEXT, '联系邮箱',
      v.string().required('请输入邮箱').email('邮箱格式不正确'), 'name@example.com'),
    new FormFieldSpec('city', FormFieldType.SELECT, '服务城市', v.string(), '请选择城市', undefined, {
      'help': '首次加载失败，点击重试后恢复',
      'optionsLoader': loadServiceCities
    })
  ];
  @Local values: Record<string, Object> = {};
  @Local submitStatus: string = '尚未提交';
  private controller: FormController = new FormController(this.fields, this.values);

  aboutToAppear(): void {
    cityOptionsAttempt = 0;
  }

  aboutToDisappear(): void {
    this.controller.dispose();
  }

  build(): void {
    Column({ space: 16 }) {
      Text('异步校验与选项')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textColor)
      Text('debounce · loading/error/retry · 远程查重 · 竞态保护')
        .fontSize(13)
        .fontColor(this.theme.secondaryTextColor)
      HmFormView({
        fields: this.fields,
        values: this.values!!,
        controller: this.controller,
        theme: this.theme,
        onSubmit: (_values: Record<string, Object>): void => {
          this.submitStatus = '提交成功';
        },
        onInvalid: (errors: Record<string, string>): void => {
          this.submitStatus = `提交失败：${Object.keys(errors).length} 项错误`;
        }
      })
      Text(this.submitStatus)
        .id('hmkit_async_submit_status')
        .fontSize(12)
        .fontColor(this.theme.secondaryTextColor)
      Text(`受控值：${JSON.stringify(this.values)}`)
        .fontSize(12)
        .fontColor(this.theme.secondaryTextColor)
    }
    .width('100%')
  }
}
