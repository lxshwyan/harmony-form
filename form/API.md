# Public API

公开导出：`FormController`、`FormFieldSpec`、`FormFieldType`、`FormTextInputType`、`FormSelectOption`、`HmFormFieldRenderContext`、`HmFormFieldRenderer`、`HmFormRendererRegistry`、`HmFormTheme`、`HmFormView` 及其 options/types。Text/Number 通过 `FormFieldUIOptions.inputType` 使用稳定字符串键盘协议，由组件内部映射 ArkUI InputType。自定义类型由 `FormFieldType.custom(name)` 创建，全局 `@Builder` 经 `wrapBuilder()` 注册并通过 HmFormView `renderers` 传入；context 只提供稳定状态和 change/blur 事件。`HmFormView` 通过 `onSubmit(values)` / `onInvalid(errors)` 形成默认提交闭环；字段配置歧义会直接抛错。

完整签名、生命周期和条件字段语义参见仓库根目录 `API.md` 与 `README.md`。
