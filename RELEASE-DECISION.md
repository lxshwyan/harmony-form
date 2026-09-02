# @hmkit/form 0.1.0 发布决策包

## 决策

最终结果：**Go，`@hmkit/form@0.1.0` 已公开发布**。

代码、包、API 冻结、独立消费和设备证据已达到 0.1.0 标准，OHPM registry 已可查询并安装。发布成功不等于已经获得生产流量或社区采用证明；后续结论必须基于真实接入反馈。最终 full dry-run 的结果记录在 `RELEASE-CHECKLIST.md`。

## 发布收益

- validator 用户不再重复维护字段值、错误、dirty/touched、异步竞态和提交生命周期。
- 内置字段、条件/异步/嵌套/FormArray/结构化表单/错误摘要/响应式和扩展协议形成完整产品，而非孤立控件。
- 独立 validator 注册表单试点减少 36 行（20.6%），六个页面状态降到三个，手写校验/提交胶水和重复字段外壳归零。
- release HAR 已由最小消费者、全功能 Showcase 和独立真实项目三种形态验证。

## 风险与已知限制

| 风险 | 等级 | 当前处理 |
|---|---|---|
| 只有一个真实独立项目试点，没有线上流量或社区反馈 | 中 | 0.1.0 发布后优先收集 2–3 个真实接入；不据此宣称市场采用 |
| 0.1.0 公开面较宽，后续维护成本高 | 中 | 14 份声明精确冻结；0.1.x 禁止破坏性变化，变更须过兼容评审 |
| form/validator 的工具链生成声明含 `@keepTs` / `@ts-nocheck`，ArkTS 消费编译产生 strict warning | 中 | 源码未手写该指令，HAR/HAP 均成功；持续跟踪 SDK 生成器修复，不篡改产物隐藏 warning |
| Demo 导航架构 | 低 | form Demo 是单页场景切换且不使用 `@ohos.router`；独立 validator 试点 Demo 仍有旧 router warning，应在 validator 仓单独迁移；form 未来多页统一使用 `Navigation` + `NavPathStack` |
| Entry 模块偶发通用 SemVer/module info warning | 低 | 三个消费者实际依赖解析和产物均已显式断言，不影响 HAR 发布元数据 |
| 当前仅验证 API 12 / HarmonyOS 5.0 基线 | 低 | 文档不承诺未验证的 API 13+；后续补 SDK/设备矩阵 |

## 回滚与修复策略

- 发布前发现问题：保持不发布，修复后重建 HAR、更新冻结基线并重跑全部门禁。
- 发布后发现兼容 bug：停止推荐 0.1.0，优先发布向后兼容的 0.1.1；消费者可暂时精确锁定已验证版本。
- 发布后发现数据错误或安全问题：公开问题范围与替代方案，发布修复版本，并在迁移指南标注受影响 API。不要假定 registry 支持可逆 unpublish。
- 需要破坏性修复：不得伪装成 patch；进入至少 0.2.0，并提供迁移说明和可行的弃用窗口。

## 发布后观测

1. 从全新目录安装 registry `@hmkit/form@0.1.0`，编译最小 API 12 HAP并在 Pura 90 提交一次无效/有效表单。
2. 检查 registry 包内依赖仍为 `@hmkit/validator@^1.0.0`，无 `file:`、源码、凭据或嵌套包。
3. 首周按日查看 issue/安装反馈；重点标签：install、compile、binding、async、focus、tablet、custom-renderer。
4. 获取首批 2–3 个真实项目的接入耗时、样板代码、崩溃/卡顿与缺失字段反馈。
5. 任何 API 变更先过 `check-api-freeze.sh`；0.1.x 只接受兼容新增和修复。

## 已执行的发布命令

```bash
source scripts/env.sh
"${OHPM}" publish form/build/default/outputs/default/form.har \
  --disallow_nested_package --ensure_dependency_include
```

2026-09-01 首次提交因 `repository` 仓库地址不可访问被拒；建立公开仓库并完成匿名访问验证后重新提交。2026-09-02 OHPM registry 已公开 `@hmkit/form@0.1.0`，`latest` 指向 0.1.0；发布 HAR SHA-256 为 `c8c4b2e9f9c0234d588daa2edbfdc09855954223fadfdecb5e7adae93c86a6d9`。
