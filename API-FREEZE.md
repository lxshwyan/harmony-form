# @hmkit/form 0.1.0 API 冻结候选

## 冻结范围

`form/Index.ets` 导出的类型、类、函数和 ArkUI 组件，以及这些导出在 release HAR 中可见的 public 构造器、属性和方法，均进入 0.1.0 冻结候选。当前没有标记为 experimental 的公开 API。

标准化签名基线位于 `api/0.1.0-declarations.sha256`，覆盖 release HAR 内全部 14 份 `.d.ets`。`scripts/check-api-freeze.sh` 会去除注释、private 成员和每次 clean build 都会变化的混淆参数名，再逐文件比较消费者可见签名；任何公开声明增删或类型变化都会失败，必须先完成兼容性评审并显式更新基线。

冻结不包含 private 实现、Demo/Showcase、脚本内部函数、视觉 token 的具体默认色值，以及 OHPM/DevEco 生成的非声明元数据；这些变化仍须通过行为与视觉回归。

## 兼容承诺

- 0.1.x patch：不删除或重命名公开符号，不改变既有参数含义、model 形状、默认触发器或生命周期；允许可选参数、重载、字段类型和 bug fix 等向后兼容新增。
- 计划中的破坏性变化只进入后续 minor（至少 0.2.0），优先先提供一版可迁移的弃用周期；ArkTS 无法表达安全弃用时，必须在迁移文档中给出机械替换方式。
- 被弃用 API 在同一 0.1.x 线内不删除。安全、数据损坏或上游平台强制变化可例外，但必须记录原因、影响和替代方案。
- `FormController.dispose()`、受控 `values`、迟到异步隔离、字段 model 形状和 `onSubmit/onInvalid` 事件属于行为契约，即使声明哈希不变也不得静默破坏。

## 依赖矩阵

| 项目 | 冻结候选 |
|---|---|
| HarmonyOS / ArkUI | HarmonyOS 5.0，最低 API 12，状态管理 V2 |
| `@hmkit/validator` | `^1.0.0`；冻结时 registry 已验证 1.0.0 |
| phone 设备 | Pura 90 模拟器完整回归 |
| tablet/foldable | 组件宽度 600vp 断点、12 栅格/span；Showcase 双列预览回归 |
| 2in1 | 0.1.1 增加 module 设备声明；沿用 600vp 组件断点，MateBook Pro 验证宽/窄容器与键鼠焦点 |
| 消费形态 | 仓内 Entry、独立最小 HAR 消费者、独立 Showcase、validator 真实注册表单 |

## 真实反馈决策

| 反馈 | 决策 |
|---|---|
| 同名 validator 的本地/registry 来源冲突 | 接受并关闭：真实入口统一 registry，validator 本地源码独立验证 |
| 手机号 TextInput 缺少 PhoneNumber 键盘 | 接受并关闭：冻结 `FormTextInputType` 与 `inputType` |
| 摘要展开后的跨宿主 Scroll 自动化不稳定 | 不扩展组件 API：隔离 E2E 场景并识别系统恢复状态；保留为测试编排限制 |

## 变更流程

1. 修改公开 API 前先更新 `API.md` 和兼容性判断。
2. 构建 release HAR，运行 `scripts/check-api-freeze.sh` 查看精确声明差异。
3. 向后兼容新增才允许更新基线；破坏性变化不得进入 0.1.x。
4. 同步 CHANGELOG、迁移指南、独立消费者和至少一个设备用例。
5. 完整 dry-run 通过后仍需人工发布授权；冻结不是发布动作。
