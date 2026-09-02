# @hmkit/form

HarmonyOS ArkUI V2 声明式表单组件库，与 `@hmkit/validator` 共用 Schema 和校验状态机。最低 API 12。

## 安装

```bash
ohpm install @hmkit/form
```

`@hmkit/form` 依赖 `@hmkit/validator`，OHPM 会自动解析并安装兼容版本。

## 快速开始

```ts
import { v } from '@hmkit/validator';
import { FormController, FormFieldSpec, FormFieldType, HmFormView } from '@hmkit/form';

private fields: FormFieldSpec[] = [
  new FormFieldSpec('name', FormFieldType.TEXT, '姓名', v.string().required('请输入姓名'))
];
@Local values: Record<string, Object> = {};
private controller: FormController = new FormController(this.fields, this.values);

HmFormView({
  fields: this.fields,
  values: this.values!!,
  controller: this.controller,
  onSubmit: (values: Record<string, Object>): void => { /* 提交业务 */ },
  onInvalid: (errors: Record<string, string>): void => { /* 展示汇总 */ }
})
```

内置 text、number、textarea、select、radio、checkbox、switch、date；checkbox 使用去重 `string[]` model。Text/Number 可通过 `FormTextInputType` + `uiOptions.inputType` 声明手机号、邮箱、密码等键盘类型。Select/Radio/Checkbox 支持 `optionsLoader` 异步选项、loading/error/retry、缓存和竞态保护。支持 `FormFieldType.custom()` + `HmFormRendererRegistry` 自定义字段、prefix/suffix/label/help/error/submit Builder 插槽、12 列 phone/tablet/2in1 响应式 span、受控回填、异步校验、条件显示/禁用、一级依赖、成功/失败提交事件、首错聚焦、Builder footer、light/dark 主题、动态字体和无障碍语义。字段用 `FormFieldUIOptions.slots` + `FormFieldSlot` 显式启用覆盖，并用 `span` 声明宽容器跨度；`HmFormLayout` 默认按组件宽度在 600vp 切换。submit Builder 通过 `HmFormSubmitSlotContext.submit()` 进入默认提交生命周期。自定义 renderer 必须是全局 `@Builder` 并通过 `wrapBuilder()` 注册。

`inferFormFields(schemaShape, overrides?)` 可从 validator schema 推导默认字段和初始 defaultValue；复杂或歧义类型必须显式覆盖 type。

字段名支持 `profile.name` 点路径，公开 values/submit 保持嵌套 Record，errors/state 使用完整路径；`getFormValue` / `setFormValue` 用于安全读取和不可变回填。数组索引不进入点路径；动态集合使用 `FormArrayController` + `HmFormArrayView`，支持增删、移动、稳定 key、业务 identity、min/max 和 item Builder，内部 key 不进入业务 values。

`FormSectionSpec` + `FormStructureController` 提供严格字段分组和可控折叠；增加 `FormStepSpec` 后启用分步表单，下一步只校验当前 active fields，最后一步执行完整 submit。错误会切换到所属 step、展开 section 并聚焦字段。设置 `showErrorSummary: true` 可显示按字段顺序、带 section/step 位置的默认摘要；`errorSummary(context)` 可替换外观并通过 `context.activate(name)` 保留跨区块定位。未配置 structure 时保持原布局。

字段 `uiOptions.keepAlive` 默认 `false`；启用后在条件隐藏、区块折叠和步骤离开时通过 `Visibility.None` 保留同一 keyed 子树，不占布局空间。它是 V2 子树保留策略，不是 V1 `@Reusable` 缓存，也不会跨页面存活。

页面退出时调用 controller 的 `dispose()`。公开入口还包括 `FormArrayController`、`FormArrayEntry`、`HmFormArrayItemContext`、`HmFormArrayView`、`FormSectionSpec`、`FormStepSpec`、`FormStructureController`、`HmFormErrorSummaryItem`、`HmFormErrorSummaryContext`、`buildFormErrorSummaryItems`、`getFormValue`、`setFormValue`、`inferFormFields`、`FormFieldInferenceOptions`、`FormFieldInferenceResult`、`FormSelectOption`、`FormOptionsLoader`、`FormTextInputType`、`FormFieldSlot`、`HmFormLayout`、`HmFormFieldRenderContext`、`HmFormSubmitSlotContext`、`HmFormRendererRegistry`、`FormFieldUIOptions`、`FormControllerOptions` 和 `HmFormTheme`；完整签名与条件字段语义见项目主页的 `API.md`，版本记录见包内 `CHANGELOG.md`。
