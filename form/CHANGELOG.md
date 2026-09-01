# Changelog

## 0.1.0 - 2026-08-31

- 首个 API 12+ ArkUI V2 表单组件版本。
- 内置 text/number/textarea/select/radio/checkbox/switch/date、受控回填、异步校验、条件依赖和首错聚焦。
- 提供 light/dark 主题、动态字体布局与无障碍语义。
- 提供成功/失败提交事件与字段配置 fail-fast。
- 增加 checkbox `string[]` 多选与数组受控快照保护。
- 增加 WrappedBuilder 自定义字段 registry 与受限 renderer context。
- 增加 prefix/suffix/label/help/error/submit Builder 插槽与字段级显式启用协议。
- 增加 ComponentSize 12 列响应式栅格、字段 span 与 HmFormLayout。
- 增加 choice 异步选项加载、失败重试、缓存和迟到结果隔离。
- 增加 SchemaDescriptor 默认字段推导与点分隔嵌套对象路径。
- 增加动态 FormArray、稳定 key、业务 identity、增删/移动与 item Builder。
- 增加分组、可折叠区块、当前步骤局部校验、分步导航和跨步骤错误定位。
- 增加可选错误摘要、section/step 位置、自定义 Builder 和点击跨区块定位。
- 增加默认关闭的字段级 keepAlive，在条件、折叠和步骤切换时保留稳定 keyed 子树。
- 增加 `FormTextInputType` 与字段 `inputType`，支持手机号、邮箱、密码等便携键盘类型。
- validator 运行依赖对齐稳定 `^1.0.0`，真实试点不再产生同名版本冲突。
- 通过 63 项测试、独立最小 HAR 消费者、全功能 Showcase、真实 validator 注册表单试点与多应用 Pura 90 自动化运行验收。
