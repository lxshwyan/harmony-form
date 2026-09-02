# @hmkit/form

面向 HarmonyOS ArkUI V2 的声明式表单组件库，与 `@hmkit/validator` 共用同一套 Schema 和校验状态机。

当前 Registry 稳定版本为 [`@hmkit/form@0.1.0`](https://ohpm.openharmony.cn/#/cn/detail/@hmkit/form)；`main` 正在准备兼容补丁版 0.1.1，正式增加 2in1 支持。最低 HarmonyOS 5.0 / API 12。

## 安装

```bash
ohpm install @hmkit/form
```

`@hmkit/validator@^1.0.0` 会作为运行依赖自动安装。建议应用锁定生成的 `oh-package-lock.json5`，保证团队与 CI 使用一致版本。

## 能力

已经可用的能力包括：

- `FormController`：values、errors、change、blur、submit、reset、dispose。
- `HmFormView`：text/number/textarea/select/radio/checkbox/switch/date 动态字段、稳定字段 key、首错聚焦、成功/失败提交事件与可替换提交区。
- 统一字段外壳：label、help、error、loading、disabled 使用一致的展示规则。
- `HmFormTheme`：可替换的视觉 token 与 light/dark 预设，控件支持动态字体扩展布局。
- 内置字段提供无障碍 label、状态、说明和至少 48vp 的主要操作热区。
- `@Param + @Event + !!` 跨 HAR 双向绑定。
- prefix、suffix、label、help、error、submit 六类 `@BuilderParam` 插槽。
- 基于容器宽度的 12 列响应式栅格和字段 `span`。
- Select/Radio/Checkbox 异步选项源，内置 loading/error/retry、成功缓存和竞态保护。
- 从 validator schema shape 安全推导默认字段、选项、帮助信息、范围和初始默认值。
- 点分隔嵌套字段路径、嵌套 values、深快照和完整路径依赖。
- 动态 `FormArray`：受控数组、增删/插入/更新/移动、min/max、稳定 key 与自定义 item Builder。
- 分组、可折叠区块与分步表单：当前步骤局部校验、上一步/下一步、最终全表提交和跨步骤错误定位。
- 可选错误摘要：字段顺序、section/step 位置、默认无障碍 UI、自定义 Builder 和点击跨区块定位。
- 字段级 `keepAlive`：条件、折叠和步骤切换时可显式保留 keyed 控件子树，默认关闭。
- 基于 `WrappedBuilder` 的每表单自定义字段 registry。
- Registry `@hmkit/validator@^1.0.0` 真实消费路径；validator 仓库本地源码由其独立测试与 HAR 门禁覆盖。

## 环境

- DevEco Studio，HarmonyOS SDK 5.0.0(12) 或更高兼容版本。
- 状态管理 V2，最低 API 12。

## 全功能 Showcase

[`showcase-app`](./showcase-app) 是独立 API 12 应用，只消费当前 release HAR。它把内置字段、Schema 推导、嵌套值、条件依赖、异步成功/失败重试、响应式布局、主题、全部字段插槽、自定义 renderer、分组/折叠/步骤、错误摘要、keepAlive、FormArray、受控回填/reset/submit 集中在一个企业入驻流程中。

手机窄窗保持单列；tablet、foldable 与 2in1 在组件宽度达到 600vp 后按字段 `span` 自动进入双列/跨列布局，2in1 窗口缩窄后会原地回到单列。折叠态和非当前步骤默认释放子树，仅对确有临时 UI 状态或创建成本的字段启用 `keepAlive`。完整能力清单与运行方式见 [`showcase-app/README.md`](./showcase-app/README.md)。

## 最小示例

```ts
import { v } from '@hmkit/validator';
import { FormController, FormFieldSpec, FormFieldType, HmFormView, inferFormFields } from '@hmkit/form';

@Entry
@ComponentV2
struct FormPage {
  private readonly fields: FormFieldSpec[] = [
    new FormFieldSpec('name', FormFieldType.TEXT, '姓名', v.string().required('请输入姓名')),
    new FormFieldSpec('age', FormFieldType.NUMBER, '年龄', v.number().min(18, '年龄不能小于 18 岁'))
  ];
  @Local values: Record<string, Object> = {};
  private readonly controller: FormController = new FormController(this.fields, this.values);

  build() {
    HmFormView({
      fields: this.fields,
      values: this.values!!,
      controller: this.controller,
      onSubmit: (values: Record<string, Object>): void => {
        // 校验通过，可以调用业务接口。
      },
      onInvalid: (errors: Record<string, string>): void => {
        // 校验失败，组件已经定位首错。
      }
    })
  }

  aboutToDisappear(): void {
    this.controller.dispose();
  }
}
```

默认提交按钮只在当前提交仍有效时触发一次事件：无错误调用 `onSubmit` 并传入防御性 values 快照；有错误调用 `onInvalid` 并传入 errors。页面退出、外部 values 替换或更新的提交开始后，旧异步结果不会通知宿主。

## 从 Schema 推导默认字段

```ts
const inferred = inferFormFields({
  name: v.string().required().label('姓名').describe('与证件保持一致'),
  age: v.number().label('年龄'),
  enabled: v.boolean().label('启用'),
  role: v.enumOf(['admin', 'member']).label('角色'),
  tags: v.array(v.enumOf(['frontend', 'backend'])).label('方向').default(['frontend'])
}, {
  name: { uiOptions: { span: 6 } },
  age: { uiOptions: { span: 6 } }
});

private fields = inferred.fields;
@Local values: Record<string, Object> = inferred.getInitialValues();
private controller = new FormController(this.fields, this.values);
```

默认支持 string、number、boolean、date、字符串 enum、字符串 enum 数组和字符串 literal union；`nullable` / `default` 会安全解包。transform、object、普通数组、单 literal、数字 enum 或混合 union 无法可靠决定 UI，必须通过对应字段的 `type` override 显式指定。override 可以覆盖 label、placeholder、validationOptions 和全部 uiOptions；未知 override 名称会直接报错。推导只读取 SchemaDescriptor，不会把 UI 元数据写回 validator schema。

## 嵌套对象路径

字段名可使用点路径，受控 values 和提交结果保持自然的嵌套对象：

```ts
const fields = [
  new FormFieldSpec('profile.name', FormFieldType.TEXT, '姓名', v.string().required()),
  new FormFieldSpec('address.country', FormFieldType.TEXT, '国家', v.string()),
  new FormFieldSpec('address.postcode', FormFieldType.TEXT, '邮编',
    v.string().requiredWhen('address.country', country => country === 'CN'), '', undefined, {
      dependencies: ['address.country'],
      visibleWhen: values => getFormValue(values, 'address.country') === 'CN'
    })
];

@Local values: Record<string, Object> = {
  profile: { name: '鸿蒙开发者' },
  address: { country: 'CN' }
};

const next = setFormValue(values, 'address.postcode', '200000');
```

`getValue/onChange/onBlur` 接收完整路径，`getValues/onSubmit` 返回嵌套 model；errors、validating 和 field state 仍以完整路径索引。`requiredWhen`、validator dependencies 和 UI dependencies 使用完整路径。`items[0].name` 或 `items.0.name` 仍不属于点路径协议，动态数组使用独立 FormArray；父子冲突路径（同时声明 `profile` 与 `profile.name`）会 fail-fast。

## 动态 FormArray

`FormArrayController` 把业务 `Object[]` 与 ArkUI item key 分离。内部 append/insert/update/remove/move 不改变未删除条目的 key；外部受控替换可用 `identity(value, index)` 按业务 ID 保留 key，并会拒绝空或重复 identity：

```ts
function identity(value: Object, _index: number): string {
  return (value as Record<string, Object>)['id'] as string;
}

@Local contacts: Object[] = [{ id: 'a', name: '张三' }];
private array = new FormArrayController(contacts, {
  minItems: 1,
  maxItems: 5,
  identity
});

HmFormArrayView({
  values: this.contacts!!,
  controller: this.array,
  item: ContactItem
})
```

全局 item Builder 接收 `HmFormArrayItemContext`，可读取防御性的 key/index/value/canMoveUp/canMoveDown/canRemove，并调用 `change/remove/moveUp/moveDown`。内部 key 不进入 `getValues()` 或提交数据。没有 identity 时，外部同步按深值尽量复用 key；可编辑对象应提供稳定业务 identity。数组整体校验继续使用 validator 的 `v.array(...)`，FormArray 不生成数字字段路径或动态修改 FormValidator shape。

## 分组、折叠区块与分步表单

结构状态与业务表单状态分离：`FormStructureController` 只管理 section 展开态和当前 step，字段值、errors、dirty/touched 和异步校验仍由同一个 `FormController` 管理。

```ts
private structure = new FormStructureController([
  new FormSectionSpec('account', '账号资料', ['name'], { collapsible: true }),
  new FormSectionSpec('company', '企业资料', ['company'])
], [
  new FormStepSpec('account', '创建账号', ['account']),
  new FormStepSpec('company', '企业认证', ['company'])
]);

HmFormView({
  fields: this.fields,
  values: this.values!!,
  controller: this.controller,
  structure: this.structure,
  showErrorSummary: true
})
```

每个字段必须且只能属于一个 section；启用 steps 后，每个 section 必须且只能属于一个 step，未知、重复或遗漏归属会 fail-fast。下一步只异步校验当前 step 的 active fields，失败时展开错误 section 并聚焦首错；最后一步复用完整 submit、`onSubmit/onInvalid` 和迟到结果隔离。`previous/goToStep/revealField/reset/dispose` 可由宿主显式控制。未传 `structure` 时保持原单栅格和提交行为。

`showErrorSummary` 默认 false，保证既有页面零迁移；启用后按 fields 定义顺序展示当前错误。每项携带字段 label/message 以及可用的 section/step 位置，点击后会先切换步骤、展开折叠区块，再聚焦字段。`errorSummary(context)` 可替换默认外观，context 提供防御性 `items`、theme 和受保护的 `activate(name)`；默认摘要行具有至少 48vp 热区和合并的无障碍语义。

## textarea 与 select

字段构造器的最后一个参数是可选的 `FormFieldUIOptions`。textarea 可以声明帮助信息和最大长度；select 使用 `FormSelectOption(label, value)` 分离展示文字与业务值：

```ts
const fields: FormFieldSpec[] = [
  new FormFieldSpec(
    'bio',
    FormFieldType.TEXTAREA,
    '个人简介',
    v.string().max(120, '个人简介不能超过 120 字'),
    '简单介绍你的经验与方向',
    undefined,
    { help: '选填，最多 120 字', maxLength: 120 }
  ),
  new FormFieldSpec(
    'city',
    FormFieldType.SELECT,
    '服务城市',
    v.string().required('请选择服务城市'),
    '请选择城市',
    undefined,
    {
      help: '用于匹配本地服务资源',
      options: [
        new FormSelectOption('上海市', 'shanghai'),
        new FormSelectOption('深圳市', 'shenzhen')
      ]
    }
  )
];
```

用户看到的是“上海市”，`values.city` 中保存的是 `shanghai`。外部回填同样传业务值；未知值显示为未选择，不会误用 label 覆盖 model。

Select/Radio/Checkbox 也可以不声明静态 `options`，改用异步选项源：

```ts
async function loadCities(): Promise<FormSelectOption[]> {
  return fetchCitiesFromService();
}

new FormFieldSpec('city', FormFieldType.SELECT, '服务城市', v.string(), '请选择', undefined, {
  optionsLoader: loadCities
})
```

HmFormView 首次出现时自动加载，请求中显示 loading，失败时显示原因与重试按钮。成功结果缓存在 Controller 中，`reset()` 保留缓存；手动 `loadOptions(name)` 可强制刷新。同一字段多次请求只采用最后一次，`reset()` / `dispose()` 后的迟到结果不会回写。空结果或重复 value 会进入可重试错误态。

辅助信息的显示优先级为 error > loading > help。`disabled: true` 会同时禁用控件并应用统一禁用外观；校验规则仍只配置在 validator schema 中。

## radio、switch、date 与条件字段

Radio 与 Select 共用 `FormSelectOption` 的 label/value 映射；Switch 保存 boolean；Date 保存不含时区歧义的 `YYYY-MM-DD`：

```ts
new FormFieldSpec(
  'needsVisit',
  FormFieldType.SWITCH,
  '需要上门服务',
  v.boolean()
),
new FormFieldSpec(
  'visitDate',
  FormFieldType.DATE,
  '期望上门日期',
  v.date().strict().required('请选择上门日期'),
  '请选择日期',
  undefined,
  {
    dependencies: ['needsVisit'],
    visibleWhen: (values: Record<string, Object>): boolean => values['needsVisit'] === true,
    startDate: new Date(2026, 0, 1),
    endDate: new Date(2030, 11, 31)
  }
)
```

`visibleWhen` 和 `disabledWhen` 只读取当前扁平 values；`dependencies` 声明直接依赖的源字段，并自动合并到 validator dependencies。隐藏或禁用字段不会阻塞提交，迟到的控件事件会被忽略。字段再次显示时保留原 model value，业务若需要清空应显式更新受控 values。

## checkbox 多选

Checkbox 复用 `FormSelectOption`，model 固定为按 options 顺序去重的 `string[]`：

```ts
new FormFieldSpec(
  'interests',
  FormFieldType.CHECKBOX,
  '兴趣偏好',
  v.array(v.string()).min(1, '至少选择一项'),
  '',
  undefined,
  {
    options: [
      new FormSelectOption('阅读', 'reading'),
      new FormSelectOption('运动', 'sports'),
      new FormSelectOption('音乐', 'music')
    ]
  }
)
```

外部回填可传 `['music', 'reading']`；UI 按声明顺序选中。用户交互会生成新的数组，过滤未知值并保持稳定顺序。Controller 对顶层数组做防御性复制和逐项相等，父组件收到等值数组回声时不会误清 dirty/errors。

## tablet 栅格与响应式布局

表单使用固定 12 栅格，并根据组件自身宽度而非整窗宽度切换布局。低于断点时所有字段强制占满 12 列；达到断点后应用字段声明的 `span`：

```ts
private fields = [
  new FormFieldSpec('firstName', FormFieldType.TEXT, '名', v.string(), '', undefined, { span: 6 }),
  new FormFieldSpec('lastName', FormFieldType.TEXT, '姓', v.string(), '', undefined, { span: 6 }),
  new FormFieldSpec('bio', FormFieldType.TEXTAREA, '简介', v.string()) // 默认 span=12
];

private layout = new HmFormLayout({
  breakpoint: '600vp',
  columnGap: 16,
  rowGap: 16
});

HmFormView({
  fields: this.fields,
  values: this.values!!,
  controller: this.controller,
  layout: this.layout
})
```

默认 `HmFormLayout.responsive()` 为 600vp/16vp/16vp。`span` 必须是 1..12 的整数且默认 12，因此现有表单升级后仍保持单列。断点只接受正数 vp 字符串；容器宽度变化时 ArkUI 会原地重新排布，字段 name/key、受控状态和首错聚焦目标不变。

## 自定义字段 registry

自定义类型必须使用 `FormFieldType.custom(name)` 创建；renderer 必须是全局 `@Builder`，并通过 ArkUI `wrapBuilder()` 注册：

```ts
const SEGMENTED = FormFieldType.custom('segmented');

@Builder
function SegmentedRenderer(context: HmFormFieldRenderContext): void {
  Row({ space: 8 }) {
    ForEach(context.field.options, (option: FormSelectOption): void => {
      Button(option.label)
        .enabled(!context.disabled)
        .backgroundColor(context.value === option.value
          ? context.theme.primaryColor : context.theme.surfaceColor)
        .onClick((): void => { context.change(option.value); })
        .onBlur((): void => { context.blur(); })
    })
  }
}

private renderers = new HmFormRendererRegistry()
  .register(SEGMENTED, wrapBuilder(SegmentedRenderer));

private fields = [
  new FormFieldSpec('level', SEGMENTED, '服务等级', v.string().required('请选择服务等级'))
];

HmFormView({
  fields: this.fields,
  values: this.values!!,
  controller: this.controller,
  renderers: this.renderers
})
```

`HmFormFieldRenderContext` 只暴露稳定的 `field/value/error/validating/disabled/inputId/description/theme/change/blur`。label、help、error、loading、条件显示和校验仍由表单统一管理；renderer 不会拿到 Controller 或 Validator。缺失 renderer、重复注册、覆盖内置类型和非法自定义类型都会 fail-fast。为了支持首错聚焦，自定义主控件应使用 `context.inputId`。

## Builder 插槽

字段通过 `FormFieldUIOptions.slots` 显式选择要覆盖的位置，未声明的位置继续使用默认外壳：

```ts
@Builder
function Prefix(context: HmFormFieldRenderContext): void {
  Text('@').fontColor(context.theme.primaryColor)
}

@Builder
function ErrorMessage(context: HmFormFieldRenderContext): void {
  Text(`⚠ ${context.error ?? ''}`).fontColor(context.theme.errorColor)
}

@Builder
function SubmitButton(context: HmFormSubmitSlotContext): void {
  Button(context.submitting ? '提交中…' : '提交')
    .enabled(!context.submitting)
    .onClick((): void => { context.submit(); })
}

private fields = [
  new FormFieldSpec('account', FormFieldType.TEXT, '账号', v.string().required(), '', undefined, {
    slots: [FormFieldSlot.PREFIX, FormFieldSlot.ERROR]
  })
];

HmFormView({
  fields: this.fields,
  values: this.values!!,
  controller: this.controller,
  prefix: Prefix,
  error: ErrorMessage,
  submit: SubmitButton
})
```

字段插槽均接收 `HmFormFieldRenderContext`；prefix/suffix 可以调用 `change/blur`，label/help/error 可读取同一份主题和状态。submit 接收独立 `HmFormSubmitSlotContext`，必须调用 `context.submit()` 才能复用提交防重、迟到隔离、首错聚焦及 `onSubmit/onInvalid`。`FormFieldSlot` 会拒绝未知或重复配置；error 仅在有错误时调用，help 在无错误且未校验中时调用。

`dispose()` 会取消底层校验并阻止页面退出后的迟到事件回写。需要重新使用同一实例时，调用 `reset(values)` 会建立新的生命周期。

## 受控 values 与外部回填

`values` 是受控模式的单一事实来源。字段输入通过 `values!!` 回写父组件；父组件也可以直接替换整个 values 对象完成服务端回填：

```ts
this.values = { 'name': '服务端姓名', 'age': 28 };
```

`HmFormView` 会把不同的外部 values 同步到 controller，并清空旧 errors、dirty、touched 与 pending 校验；内部输入回写得到的相同 values 不会重置交互状态。非组件场景可显式调用 `controller.syncValues(values)`，返回值表示是否发生了替换。

## 字段子树保活

条件字段、折叠区块和非当前步骤默认按需创建/销毁。对于内部包含临时 UI 状态、昂贵自定义 renderer 或需要保持原生控件实例的字段，可显式设置 `keepAlive: true`：

```ts
new FormFieldSpec('company', FormFieldType.TEXT, '企业名称', v.string(), '', undefined, {
  keepAlive: true,
  visibleWhen: values => values['kind'] === 'enterprise'
})
```

保活字段会稳定留在同一 keyed 父节点下，隐藏时使用 `Visibility.None`，不占布局空间也不能交互；重新显示后沿用原子树。默认 `false`，因此旧表单的内存与生命周期行为不变。该能力是 ArkUI V2 的显式子树保留策略，不等同于 V1 `@Reusable/aboutToReuse` 缓存；页面离开时仍会正常销毁。

父组件向 `@BuilderParam` 传递本地 Builder 时，应使用箭头函数保留父组件 `this`，否则 Builder 内事件可能绑定到子组件上下文：

```ts
HmFormView({
  fields: this.fields,
  values: this.values!!,
  controller: this.controller,
  footer: (): void => {
    this.customFooter()
  }
})
```

## 主题、动态字体与无障碍

`HmFormView` 默认使用 `HmFormTheme.light()`。宿主可以显式传入深色预设或只覆盖需要的 token：

```ts
@Local theme: HmFormTheme = HmFormTheme.dark();

HmFormView({
  fields: this.fields,
  values: this.values!!,
  controller: this.controller,
  theme: this.theme
})

const brandTheme = new HmFormTheme({
  primaryColor: '#00AA66',
  controlMinHeight: 52,
  borderRadius: 12
});
```

主题由宿主受控，组件库不会修改应用的全局 ColorMode；应用可在配置变化时把 `theme` 替换为 light/dark 预设。字段采用 fp 字体和最小高度约束，不用固定控件高度裁切放大文字。

输入、选择、日期、开关和 Radio 选项会暴露字段 label、当前状态、help/error/loading 说明。Radio 整行可点击且最小高度为 48vp；自定义 footer 的语义和热区由宿主负责。

## 本地验证

```bash
./scripts/test-local.sh
./scripts/build-release.sh
./scripts/scan-har.sh
./scripts/verify.sh
./scripts/verify-external-consumer.sh
./scripts/verify-showcase.sh
./scripts/verify-validator-pilot.sh
./scripts/check-api-freeze.sh
./scripts/release-dry-run.sh
./scripts/test-simulator.sh
./scripts/test-showcase-simulator.sh
./scripts/test-2in1-simulator.sh
```

`verify.sh` 从 clean 状态执行测试、release HAR/HAP 构建和包内容审计。当前主机测试为 63 项；真正通过的数量以脚本输出为准。

`release-dry-run.sh` 还会强制刷新并编译最小 API 12 HAR 消费者、全功能 Showcase 与 validator 真实注册表单，核对当前 HAR 声明/ABC 哈希和 validator 1.0.0 实际解析，运行 14 份声明冻结、凭据模式扫描和 `ohpm prepublish`；脚本不会调用 `ohpm publish`。连接模拟器时可运行 `HMKIT_RUN_SIMULATOR=1 ./scripts/release-dry-run.sh`，把三个应用的设备验收一并纳入门禁。

连接 HDC 模拟器后，`test-simulator.sh` 会自动安装当前 HAP，并按稳定控件 ID 验证单列/双列响应式切换、Builder 插槽、深色主题、Checkbox、自定义 renderer、条件字段、异步校验、选项加载失败/重试/恢复，以及错误摘要的折叠展开、跨步骤定位与聚焦。

启动 MateBook Pro 2in1 模拟器后，`test-2in1-simulator.sh` 会安装 Showcase，验证 2in1 模块声明、宽容器双列、窄容器预览的单列重排、坐标点击和键盘 Tab 焦点链路。

## 当前边界

- 当前内置 text、number、textarea、select、radio、checkbox、switch、date，并支持条件显示、条件禁用和一级字段依赖。
- 字段 name 必须非空且唯一；字段 type、maxLength、choice options/loader 和 Date 范围会在构造阶段校验，歧义配置直接抛错。
- 条件能力支持嵌套 values 与完整路径直接依赖；多级依赖图、数组索引与隐藏时自动清值仍不属于当前默认语义。
- 自定义 renderer 采用全局 `@Builder` + `wrapBuilder()`；不支持普通函数、局部 Builder 或动态 Node renderer。
- 字段插槽是每个 HmFormView 的全局 Builder，具体字段必须通过 `slots` 显式启用；submit 始终替换默认提交区，footer 仍作为其后的附加内容。
- 错误摘要默认关闭；启用后的 custom Builder 应调用 context.activate，而不是自行修改 structure 或直接请求私有控件焦点。
- keepAlive 默认关闭，只保留页面内同一 keyed 字段子树，不跨页面缓存；普通字段仍按条件、折叠和步骤状态创建/销毁。
- 响应式布局固定为 12 栅格和单一 phone/tablet 断点；更复杂的多断点 order/offset 不属于当前协议。
- 动态字段使用稳定 `name` 作为 key；已在 Pura 90 模拟器验证连续受控更新不丢焦点、首错聚焦及合法提交。
- Entry Demo 已拆分为核心字段、条件依赖、异步校验、嵌套资料、动态数组、分组分步六个场景，并提供 light/dark 主题切换。
- 真实入口与发布候选统一消费 Registry validator；validator 本地源码变化由其独立测试/HAR 门禁验证，避免同一应用混用本地与 Registry 来源。
- 发布配置必须使用 Registry 依赖，不能把 `file:` 路径打进 HAR。

0.1.0 的精确公开声明、兼容承诺与变更流程见 [`API-FREEZE.md`](./API-FREEZE.md)，迁移见 [`MIGRATION.md`](./MIGRATION.md)，最终 Go/No-Go 依据见 [`RELEASE-DECISION.md`](./RELEASE-DECISION.md)。
