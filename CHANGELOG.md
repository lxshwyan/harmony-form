# Changelog

All notable changes to `@hmkit/form` are documented here.

## 0.1.0 - 2026-08-31

- 首个 ArkUI V2 表单组件版本，最低 HarmonyOS 5.0 / API 12。
- 提供 text、number、textarea、select、radio、checkbox、switch、date 内置字段。
- 集成 `@hmkit/validator@^1.0.0` 的 change、blur、submit、debounce、异步校验和字段依赖。
- 支持受控 values、外部干净回填、reset/dispose、首错聚焦与 `@BuilderParam` footer。
- 支持条件显示、条件禁用、select/radio label-value 映射和 `YYYY-MM-DD` 日期模型。
- 提供 HmFormTheme light/dark 预设、自定义 token、动态字体布局和内置无障碍语义。
- 提供 `onSubmit(values)` / `onInvalid(errors)` 默认提交闭环，并隔离退出、外部回填和重复提交后的迟到结果。
- 对重复字段名、非法字段类型、选项冲突和日期范围执行构造期 fail-fast。
- Checkbox 使用稳定去重的 `string[]` model，并对数组 values 做防御性复制与等值回声识别。
- 增加基于 `WrappedBuilder` 的自定义字段 registry、受限 renderer context 与配置 fail-fast。
- 增加 prefix/suffix/label/help/error/submit Builder 插槽、字段级显式启用和受保护提交 context。
- 增加基于组件宽度的 12 列响应式栅格、字段 span 与可替换 HmFormLayout。
- 增加 Select/Radio/Checkbox 异步选项源、loading/error/retry、缓存、最后请求生效与生命周期隔离。
- 增加 SchemaDescriptor 驱动的默认字段推导、显式 override、默认值快照和歧义类型 fail-fast。
- 增加点分隔嵌套字段路径、嵌套 values、不可变路径读写、深快照、完整路径依赖和冲突防御。
- 增加动态 FormArray、受控数组、增删/插入/更新/移动、稳定 key、业务 identity、min/max 与 item Builder。
- 增加 FormSection/FormStep 结构协议、可控折叠、当前步骤局部校验、步骤导航、最终全表提交和跨步骤错误定位。
- 增加可选默认错误摘要、section/step 位置、自定义 errorSummary Builder，以及点击展开区块、切换步骤和聚焦字段。
- 增加默认关闭的字段级 keepAlive，在条件、折叠和步骤切换时以 Visibility.None 保留稳定 keyed 子树。
- 增加 `FormTextInputType` 与字段 `inputType`，为手机号、邮箱、密码等 TextInput 提供不泄漏 ArkUI 枚举的跨 HAR 键盘协议。
- 增加独立全功能 API 12 Showcase、当前 HAR 哈希门禁和 Pura 90 自动化验收。
- validator 运行依赖对齐已发布的稳定 `^1.0.0`，真实试点与 form 共用同一 validator 实例并消除 OHPM 冲突警告。
- 增加 63 项主机测试、release HAR 审计、独立最小消费者、真实 validator 注册表单试点与多应用设备回归。
