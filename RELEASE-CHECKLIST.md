# @hmkit/form 0.1.0 最终检查单

## 版本与 API

- [x] 包名/版本为 `@hmkit/form@0.1.0`
- [x] 最低 HarmonyOS 5.0 / API 12 与 ArkUI V2 已写明
- [x] validator 依赖与三个消费者实际解析均为 `^1.0.0` / 1.0.0
- [x] 14 份 release `.d.ets` 已建立标准化公开签名冻结基线
- [x] API、README、CHANGELOG、迁移与兼容矩阵一致

## 质量与消费

- [x] form 主机测试 63/63
- [x] form release HAR 与 Entry HAP 构建
- [x] HAR 名称、版本、release 标志、公开声明、包内容审计
- [x] 独立最小消费者 clean install、当前 HAR 哈希与 release HAP
- [x] 独立全功能 Showcase clean install、当前 HAR 哈希与 release HAP
- [x] validator 原有测试 194/194，覆盖率 94.05% / 87.98% / 84.51%
- [x] validator HAR 安全/API/体积门禁与真实入口 release HAP
- [x] OHPM 凭据模式扫描和 prepublish

## Pura 90 设备

- [x] 主 Demo：字段、主题、响应式、条件、异步、FormArray、结构与错误定位
- [x] Showcase：综合流程、错误摘要、FormArray、回填与主题
- [x] validator 真实试点：无效摘要/定位、有效回填/提交、重置

## 决策边界

- [x] 风险、已知限制、回滚和发布后观测已记录
- [x] 技术建议为 Go
- [x] 已获得用户明确发布授权
- [x] 已配置并确认 OHPM 发布身份与密钥
- [ ] `@hmkit/form@0.1.0` 首次提交因 repository 不可访问被拒；公开仓库建立后重新提交

最后验证：2026-09-01，`HMKIT_RUN_SIMULATOR=1 ./scripts/release-dry-run.sh`；首次提交 HAR SHA-256 为 `01ca5db02236488ef18dc4a9e3efbed2ad41086acc509691ed0ba7cf0b784aef`，平台因 repository 不可访问拒绝。
