# Phase 0 验收报告

更新时间：2026-08-30

| 退出条件 | 结论 | 证据 |
|---|---|---|
| 独立最小工程 | 通过 | form HAR 与 entry HAP 均可 clean release 构建 |
| 跨 HAR V2、Builder、observed controller | 通过 | Entry 实际消费编译；HAR 公开声明审计通过 |
| `values!!` 双向绑定 | 通过 | 独立 Entry 跨 HAR 编译通过；模拟器确认 `username` 与数值 `age` 同步到父组件 |
| 动态 `ForEach` 更新保持焦点 | 通过 | Pura 90 模拟器连续更新 `abc -> abcd -> abcde` 后，TextInput 始终 `focused=true` 且 key 不变 |
| 自定义字段扩展形态 | 通过 | 跨 HAR `@BuilderParam` footer 成功；0.1 暂不冻结 renderer registry |
| validator Registry 与本地依赖 | 通过 | exact Registry 0.8.0 和本地已构建 HAR 均完成测试及 release 构建；源码目录依赖明确不支持 |

## 自动化结果

- FormController Hypium：7/7 通过。
- Release HAR：`form/build/default/outputs/default/form.har`。
- Release Demo HAP：`entry/build/default/outputs/default/entry-default-unsigned.hap`。
- HAR 审计：名称、版本、validator 精确依赖、release 标志、入口/目标声明和禁入路径。
- 模拟器：DevEco Pura 90 / OpenHarmony 6.1.0；Debug HAP 安装、启动及交互通过。
- 运行断言：受控值同步、text/number 类型转换、连续输入焦点保持、必填/最小值错误、首错聚焦、合法提交无残留错误。

## 0.1 API 冻结建议

Phase 0 六项退出条件已全部通过，公开形态可以作为后续实现基线。进入 0.1 MVP 字段扩展前仍需完成：

1. ~~明确受控 values 与 controller 初始值的单一事实来源，补外部 values 更新同步策略。~~ 已在 Phase 11 完成并通过设备验收。
2. ~~用 select 和一个业务自定义字段验证 adapter 协议，再决定是否公开 renderer registry。~~ Phase 12 已用城市选择器验证 label/value 适配；0.1 决定不公开 renderer registry。
3. 在 validator 后续版本治理生成声明的 `@ts-nocheck` 消费 warning。
