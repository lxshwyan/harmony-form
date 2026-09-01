# @hmkit/form 真实接入试点

## 接入方

- 项目：独立 Git 仓库 `openharmony-libs/harmony-validator`
- 页面：既有注册表单 `entry/src/main/ets/pages/FormDemo.ets`
- 设备基线：HarmonyOS 5.0 / API 12，phone/tablet
- 依赖基线：入口应用消费 registry `@hmkit/validator@^1.0.0`；form 使用当前未发布 release HAR；validator 本地源码由其独立测试与 HAR 门禁覆盖

这不是新增的展示页面。试点将现有手写 ArkUI 表单迁移为 `HmFormView`，同时保留 validator 项目原有 Schema JSON、版本化序列化和轻量规则入口编译门禁。

## 接入前基线

| 指标 | 基线 |
|---|---:|
| FormDemo 总行数 | 175 |
| 页面表单状态 | 6 个 `@State` |
| 手工值/错误/字段校验/提交方法 | 5 类 |
| 重复字段外壳 | 3 套 |
| validator 主机测试 | 194/194 |
| 覆盖率 lines/functions/branches | 94.05% / 87.98% / 84.51% |
| validator release HAR / Entry release HAP | 均构建通过 |

## 反馈分级

- 阻断：无法安装、编译、启动、提交或产生错误业务值；必须在冻结前解决。
- 高：需要绕过公开 API、生命周期/焦点/校验明显错误、常规业务流程不可接受；冻结前解决。
- 中：样板代码、可发现性、类型或文档摩擦，但有稳定公开做法；记录并酌情修复。
- 低：视觉偏好、非核心便利 API 或后续版本能力；不阻止 0.1.0。

每条反馈记录：场景、预期、实际、严重度、复现证据、决策、对应修改和回归证据。

## 接入结果

| 指标 | 接入后 |
|---|---:|
| FormDemo 总行数 | 139（减少 36，-20.6%） |
| 页面业务状态 | 3 个 `@Local`（减少 3） |
| 手写值/错误/字段校验/提交方法 | 0 类 |
| 重复字段外壳 | 0 套 |
| form 主机测试 | 63/63 |
| validator 主机测试 | 194/194（最终 full dry-run 复核） |
| release HAR / 真实 Entry HAP | 构建通过 |
| Pura 90 业务链路 | 无效摘要、定位、回填、成功提交、重置均通过 |

## 反馈闭环

| 场景 | 严重度 | 发现 | 决策与证据 |
|---|---|---|---|
| 宿主本地 validator + form registry validator | 高 | OHPM 按不同来源报告同名依赖冲突 | 入口统一消费 registry `^1.0.0`，本地 validator 由独立门禁覆盖；clean install 不再出现冲突 |
| 手机号输入 | 中 | Text 字段需要 PhoneNumber 键盘，但公共 API 不应暴露 ArkUI 枚举 | 新增 `FormTextInputType.PHONE` 与 `uiOptions.inputType`；63/63 单测、HAR/HAP、真实消费通过 |
| 摘要展开后的串联 UI 自动化 | 低 | Router/键盘/Scroll 恢复状态让单脚本连续场景不稳定 | E2E 分成冷启动隔离的失败与成功场景，并按页面树识别恢复状态；业务组件无需绕过 |

阻断项为 0。全部高/中优反馈已在冻结候选前关闭；低优项只影响测试编排，不改变 API 或运行语义。

## 试点验收

- 使用当前 release HAR，不引用 form 源码模块。
- 保留 username change、phone blur、age number、完整 submit 的既有业务语义。
- 覆盖失败错误摘要、首错定位、成功回调、受控回填/reset 和页面 dispose。
- clean install 后验证实际 validator 版本解析，不允许缓存假阳性。
- validator 原有 194 项测试、覆盖率、HAR 门禁无回归。
- Entry release HAP 在 Pura 90 完成失败与成功主流程。

## 发布边界

试点通过只代表一个独立项目完成接入，不代表真实线上流量或社区采用。正式 `ohpm publish` 仍需单独授权。
