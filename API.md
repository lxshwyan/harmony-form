# @hmkit/form 0.1 API

## Exports

```ts
FormController
FormControllerOptions
FormArrayController
FormArrayControllerOptions
FormArrayEntry
FormArrayIdentity
HmFormArrayItemContext
FormSectionOptions
FormSectionSpec
FormStepOptions
FormStepSpec
FormStructureController
FormCondition
FormFieldSlot
FormFieldSpec
FormFieldType
FormFieldUIOptions
FormOptionsLoader
FormTextInputType
FormSelectOption
FormFieldInferenceOptions
FormFieldInferenceResult
inferFormFields
getFormValue
setFormValue
HmFormFieldRenderContext
HmFormFieldRenderer
HmFormRendererRegistry
HmFormSubmitSlotContext
HmFormLayout
HmFormLayoutOptions
HmFormTheme
HmFormThemeOptions
HmFormView
HmFormArrayView
```

## FormFieldSpec

```ts
new FormFieldSpec(
  name: string,
  type: string,
  label: string,
  schema: AnySchema,
  placeholder?: string,
  validationOptions?: FormFieldOptions,
  uiOptions?: FormFieldUIOptions
)
```

`FormFieldType` 包含 `TEXT`、`NUMBER`、`TEXTAREA`、`SELECT`、`RADIO`、`CHECKBOX`、`SWITCH`、`DATE`，并提供 `custom(name)` / `isCustom(type)`。

`FormFieldUIOptions`：

- `help`、`disabled`、`maxLength`
- `options: FormSelectOption[]`
- `optionsLoader: () => Promise<FormSelectOption[]>`，仅 Select/Radio/Checkbox
- `dependencies: string[]`
- `visibleWhen(values)`、`disabledWhen(values)`
- `startDate`、`endDate`
- `slots: string[]`，成员来自 `FormFieldSlot.PREFIX/SUFFIX/LABEL/HELP/ERROR`
- `span: number`，宽容器中的 12 栅格跨度，默认 12
- `keepAlive: boolean`，隐藏/折叠/离步时保留 keyed 控件子树，默认 false
- `inputType: FormTextInputType.*`，Text/Number 的便携键盘类型；NUMBER 字段固定为 NUMBER

`FormTextInputType` 包含 `NORMAL`、`NUMBER`、`PHONE`、`EMAIL`、`PASSWORD`。它使用稳定字符串并由 `HmFormView` 映射到 ArkUI `InputType`，不会把 ArkUI 枚举泄漏到跨 HAR API。非 Text/Number 字段只接受 NORMAL。

Select/Radio 的 option label 用于显示，string value 写入 model。choice 字段必须至少提供静态 options 或 optionsLoader；非 choice 字段不接受 loader。Date model 固定为有效的本地日历字符串 `YYYY-MM-DD`。

Checkbox 同样复用 option label/value，model 为按 options 顺序去重的 `string[]`。公开 adapter 为 `checkboxValues(value)`、`isOptionSelected(value, optionValue)`、`toggleOptionValue(value, optionValue, selected)`。

构造阶段会拒绝空 name、不支持的 type、非正 maxLength、空或重复 value 的 Select/Radio/Checkbox options、startDate 晚于 endDate 的 Date、1..12 之外或非整数 span，以及未知或重复 slot。`field.usesSlot(slot)` 可查询启用点；FormController 会拒绝重复字段 name。

## Nested value paths

```ts
getFormValue(values: Record<string, Object>, path: string): Object | undefined
setFormValue(values: Record<string, Object>, path: string, value: Object | undefined): Record<string, Object>
```

`FormFieldSpec.name` 支持 `profile.name` 点路径。Controller 公开 values、受控同步、reset 与 submit 均保持嵌套 Record；字段 errors/validating/state 使用完整路径作为 key。路径写入不可变地复制 Record、Array 和 Date，删除叶值时自动清理空父对象。

`FormFieldUIOptions.keepAlive?: boolean` 默认 `false`。设为 `true` 后，条件隐藏、区块折叠或步骤离开时字段仍保留在稳定 keyed 子树中，并以 `Visibility.None` 移出布局；再次显示沿用同一控件子树。它不等同于 V1 `@Reusable`，也不会跨页面缓存组件。仅对确实持有 UI 临时状态或创建成本较高的字段启用。

路径不允许空分段、首尾点、纯数字分段、括号数组索引或原型相关危险分段；父路径与子路径不能同时成为字段。conditions 收到嵌套 values，可用 `getFormValue` 读取；`requiredWhen` 和 dependencies 使用完整路径。数组索引留给 FormArray，不属于当前点路径协议。

## FormArray

```ts
new FormArrayController(values?: Object[], {
  minItems?: number,
  maxItems?: number,
  identity?: (value: Object, index: number) => string
})

getValues(): Object[]
getEntry(index): FormArrayEntry
canAppend(): boolean
canRemove(): boolean
append(value): boolean
insert(index, value): boolean
update(index, value): boolean
remove(index): boolean
removeByKey(key): boolean
move(from, to): boolean
syncValues(values): boolean
reset(values?): void
dispose(): void
```

`FormArrayEntry.key` 是位置无关的 UI 身份，不写入业务值。内部操作保持未删除项的 key；带 identity 的外部替换/重排按业务身份保留 key，并拒绝空/重复身份。不带 identity 时按深值匹配复用。values、entry.value 和 item context.value 都是防御性快照；null/undefined 项、非法下标和非法 min/max fail-fast。

`HmFormArrayView` 接收 `values: Object[]`、`controller`、`item(context)`、可选 `space/emptyText`，并通过 `$values` 提交新数组。context 提供 key/index/value/canMoveUp/canMoveDown/canRemove 和 `change/remove/moveUp/moveDown`。页面退出时调用 array controller 的 `dispose()`；`reset()` 可恢复复用。

## FormStructureController

```ts
new FormSectionSpec(id, title, fieldNames, {
  description?: string,
  collapsible?: boolean,
  defaultExpanded?: boolean
})

new FormStepSpec(id, title, sectionIds, { description?: string })
new FormStructureController(sections, steps?)
```

section/step id 必须为字母开头的稳定标识。字段必须且只能分配给一个 section；配置 steps 时，每个 section 必须且只能分配给一个 step。`HmFormView` 出现时用完整 fields 执行归属校验，未知、重复或遗漏配置 fail-fast。

Controller 的可观察状态为 `currentStepIndex`、`expandedSections`、`validatingStep`。公开 `activeSections/currentFieldNames/sectionForField/stepForField/isExpanded/toggleSection/setExpanded/canPrevious/canNext/previous/next/goTo/goToStep/revealField/reset/dispose`。校验进行中拒绝外部步骤跳转；`revealField` 会切换到字段所属 step 并展开 section。

`HmFormView.structure` 可选。分组模式按 section 复用既有 GridRow/field renderer；分步模式的 next 调用 `FormController.validateFields(currentFieldNames)`，只返回当前 active 字段错误并保留其他错误，失败时展开并聚焦首错。最后一步才调用完整 `submit()` 和 `onSubmit/onInvalid`。未传 structure 时行为不变。

## Error summary

`HmFormView.showErrorSummary` 默认为 false。设为 true 后，组件通过 `buildFormErrorSummaryItems(fields, errors, structure?)` 按字段定义顺序生成 `HmFormErrorSummaryItem[]`，忽略非字段错误。item 公开 name/label/message、sectionId/sectionTitle、stepId/stepTitle 与 `location()`。

默认摘要使用稳定 ID `hmkit_form_error_summary` 和 `hmkit_form_error_summary_<fieldName>`；点击项目会复用 reveal + 延迟 focus。可通过参数化 `errorSummary(context: HmFormErrorSummaryContext)` 替换外观。context 提供防御性 items、title、description、theme 与 `activate(name)`，自定义 Builder 应调用 activate 保留折叠展开、步骤切换和生命周期安全边界。

## Schema field inference

```ts
inferFormFields(
  shape: Record<string, AnySchema<Object | null>>,
  overrides?: Record<string, FormFieldInferenceOptions>
): FormFieldInferenceResult

result.fields: FormFieldSpec[]
result.getInitialValues(): Record<string, Object>
```

默认映射为 string→text、number→number、boolean→switch、date→date、字符串 enum→select、字符串 enum 数组→checkbox、字符串 literal union→select，并解包 nullable/default。label 优先读取 override、descriptor label、metadata title，最后回退字段名；description、maxLength、日期上下界、枚举 options 和 defaultValue 会生成对应 UI/初始值。复杂或歧义 schema 必须显式 override type；未知 override 字段名 fail-fast。dotted shape key 的 defaultValue 会生成嵌套初始值；返回值是防御性快照。

## Custom renderer

```ts
type HmFormFieldRenderer = WrappedBuilder<[HmFormFieldRenderContext]>

new HmFormRendererRegistry()
  .register(FormFieldType.custom('segmented'), wrapBuilder(GlobalRenderer))

registry.has(type): boolean
registry.matching(type): HmFormFieldRenderer[]
registry.assertFields(fields): void
```

`register` 只接受 `custom:` 命名空间，拒绝重复注册和覆盖内置类型。HmFormView 出现时会检查所有自定义字段均有 renderer；`matching` 是基于 ArkUI 官方 `ForEach(WrappedBuilder[])` 动态调用形态的单项视图。Render context 公开 `field`、防御性 `value`、`error`、`validating`、`disabled`、`inputId`、`description`、`theme`、`change(value)` 和 `blur()`；不公开 Controller/Validator。renderer 负责实际控件、值适配和控件级语义，form 保留统一外壳及生命周期。

## FormController

```ts
new FormController(fields, initialValues?, { debounceMs? })

getValues(): Record<string, Object>
getValue(name): Object | undefined
getFieldState(name): FormFieldState
displayValue(name): string
getOptions(name): FormSelectOption[]
loadAllOptions(): void
loadOptions(name): Promise<void>
syncValues(values): boolean
onChange(name, value): Promise<void>
onBlur(name): Promise<void>
submit(): Promise<Record<string, string>>
reset(values?): void
firstErrorName(): string | undefined
dispose(): void
```

可观察状态为 `values`、`errors`、`validating`、`submitting`、`optionValues`、`optionsLoading`、`optionErrors`。`getOptions` 返回防御性快照；`loadOptions` 强制发起指定 loader，且同字段只采用最后请求。成功缓存在 reset 后保留，loading/error 被清理；dispose 阻止迟到回写。隐藏或禁用字段不参与错误结果；`syncValues` 用于不标记 dirty/touched 的外部受控替换。

## HmFormView

```ts
HmFormView({
  fields,
  values: values!!,
  controller,
  theme?: HmFormTheme,
  renderers?: HmFormRendererRegistry,
  layout?: HmFormLayout,
  prefix?: (context: HmFormFieldRenderContext) => void,
  suffix?: (context: HmFormFieldRenderContext) => void,
  label?: (context: HmFormFieldRenderContext) => void,
  help?: (context: HmFormFieldRenderContext) => void,
  error?: (context: HmFormFieldRenderContext) => void,
  submit?: (context: HmFormSubmitSlotContext) => void,
  onSubmit?: (values: Record<string, Object>) => void,
  onInvalid?: (errors: Record<string, string>) => void,
  footer?: (): void => { ... }
})
```

`fields`、`values`、`controller` 必填；`values!!` 通过 `$values` 回写父级。字段插槽只在对应字段的 `slots` 中显式启用，未启用时保留默认 label/help/error，prefix/suffix 为空。error 仅在错误态调用，help 仅在无错误且未 validating 时调用。submit 总是替换默认提交区；其 context 提供 `submitting/label/description/theme/submit()`，调用 `submit()` 才会进入受保护的校验、首错聚焦和事件生命周期。校验成功触发 `onSubmit`，失败并完成首错聚焦后触发 `onInvalid`。退出、外部回填或新提交会使旧异步提交结果失效。传父组件本地 Builder 时使用箭头函数保留父组件 `this`；全局 Builder 可直接传递。footer 仍是提交区后的附加 Builder。

HmFormView 出现时自动加载尚未缓存的异步 choice 选项；loading 和 error/retry 取代字段控件但保持 `hmkit_form_<name>` 稳定聚焦 ID。选项错误不会调用 help/error Builder，重试成功后恢复内置控件。

## HmFormLayout

```ts
HmFormLayout.responsive() // breakpoint=600vp, columnGap=16, rowGap=16
new HmFormLayout({ breakpoint: '720vp', columnGap: 20, rowGap: 16 })
```

HmFormView 固定使用 12 栅格和 `BreakpointsReference.ComponentSize`。断点以下每个字段强制 span=12，断点及以上使用 `FormFieldSpec.span`；默认 span=12 保持旧页面单列。breakpoint 必须是正数 vp 字符串，gap 必须非负。当前不公开 order、offset 或多断点配置。

## HmFormTheme

```ts
HmFormTheme.light()
HmFormTheme.dark()
new HmFormTheme({ primaryColor, controlMinHeight, borderRadius, ... })
```

公开 token 包含文本/辅助/占位/表面/禁用/边框/错误/校验中/主色，以及控件最小高度、textarea 最小高度和圆角。替换 theme 实例即可响应式切换主题。

## Lifecycle contract

- 页面退出调用 `controller.dispose()`，阻止 pending 结果回写。
- 需要复用已 dispose controller 时调用 `reset(values)`。
- 条件字段隐藏时保留 model value，但不阻塞提交；清值由宿主显式替换受控 values。
- 当前只保证扁平 values 和一级显式依赖；自定义 renderer 必须使用全局 `@Builder` + `wrapBuilder()`。
