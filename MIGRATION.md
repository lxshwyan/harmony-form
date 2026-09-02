# @hmkit/form 迁移指南

## 从手写 FormValidator + ArkUI 表单迁移

1. 保留原有 validator schema，把每个字段转换为 `FormFieldSpec`。
2. 把业务值收敛为一个 `@Local Record<string, Object>`，用 `values: this.values!!` 绑定 `HmFormView`。
3. 用一个 `FormController` 替换字段级 errors、validating、change/blur 和 submit 胶水。
4. 在 `onSubmit` 调业务接口，在 `onInvalid` 记录或补充宿主反馈；组件已负责显示错误和首错定位。
5. 页面退出调用 `controller.dispose()`；外部回填直接替换 values，清空使用 `controller.reset({})`。

手机号仍使用 TEXT 字段和 string model，只改变键盘：

```ts
new FormFieldSpec('phone', FormFieldType.TEXT, '手机号', phoneSchema, '请输入手机号', {
  triggers: [FormTrigger.BLUR]
}, {
  inputType: FormTextInputType.PHONE
})
```

## 从冻结前内部版本迁移到 0.1.0

- 将 `@hmkit/validator` 依赖统一为 `^1.0.0`。同一应用不要同时混用本地 file validator 和 registry validator；本地源码测试与真实入口消费应分开。
- NUMBER 字段自动使用 NUMBER 键盘；TEXT 默认为 NORMAL。手机号、邮箱、密码分别使用 `FormTextInputType.PHONE/EMAIL/PASSWORD`。
- 受控 values 是事实来源。不要直接修改 `controller.values`，也不要同时保留每字段 `@State`。
- 自定义提交 UI 必须调用 `HmFormSubmitSlotContext.submit()`，不要绕过默认的异步隔离与生命周期检查。
- 动态数组使用 `FormArrayController`，不要把数字下标塞进点路径字段名。

0.1.0 是首个公开版本，因此没有更早的 registry 版本需要迁移。本指南用于手写表单、冻结前试点或本地 HAR 用户切换到公开包；后续 0.1.x 只接受兼容新增与修复。
