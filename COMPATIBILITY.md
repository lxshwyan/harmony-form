# Compatibility matrix

`@hmkit/form` 0.1.x 的最低基线是 HarmonyOS 5.0 / API 12，状态管理使用 ArkUI V2。Registry 稳定版 0.1.0 支持 phone/tablet；未发布的 0.1.1 候选正式扩展到 2in1。

| Consumer | SDK / API | Dependency path | Result |
| --- | --- | --- | --- |
| 仓内 Entry Demo | HarmonyOS 5.0.0(12) | DevEco module | release HAP 编译通过；Pura 90 运行通过 |
| 独立 external-consumer | HarmonyOS 5.0.0(12) | release `form.har` file dependency | OHPM 安装、release HAP 编译、Pura 90 启动均通过 |
| validator integration | `@hmkit/validator@^1.0.0` | OHPM Registry | 63 项 form 单测、HAR、三个消费者均通过 |
| 独立 validator 真实试点 | HarmonyOS 5.0.0(12) / validator 1.0.x | 当前 release `form.har` | clean install、release HAP、失败/成功/重置 Pura 90 流程均通过 |
| MateBook Pro 2in1 | HarmonyOS 6.1.0(23) | 0.1.1 候选 `form.har` | 设备类型识别、宽容器双列、窄容器单列、恢复宽容器、坐标点击与 Tab 焦点均通过 |

## 验证命令

```bash
./scripts/build-release.sh
./scripts/verify-external-consumer.sh
./scripts/test-2in1-simulator.sh
```

兼容性结论只覆盖已执行的组合。API 13+ 预计向后兼容，但在加入对应 SDK 编译与设备证据前不标记为已验证。
