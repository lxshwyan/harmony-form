# @hmkit/form Showcase

这是一个独立 HarmonyOS API 12 应用，只通过当前 release `form.har` 使用 `@hmkit/form`，不依赖库源码模块。页面以“企业入驻工作台”为完整业务流程，并保留稳定自动化 ID。

覆盖能力：

- text、number、textarea、select、radio、checkbox、switch、date 全部内置字段；
- SchemaDescriptor 字段推导、嵌套路径、受控回填、reset 与提交事件；
- 成功和失败重试两类异步选项、条件显示/禁用与 dependencies；
- phone/tablet/2in1 的 12 列响应式 span、light/dark 主题、无障碍外壳；
- prefix/suffix/label/help/error/submit/footer Builder 插槽；
- 自定义 segmented renderer registry；
- 分组、折叠、步骤局部校验、错误摘要与跨区块定位；
- 条件/折叠/步骤字段 `keepAlive`；
- 独立 FormArray 增加、删除和移动。

从项目根运行：

```bash
./scripts/build-release.sh
./scripts/verify-showcase.sh
./scripts/test-showcase-simulator.sh
./scripts/test-2in1-simulator.sh
```

`verify-showcase.sh` 会清理依赖、重新安装当前 HAR、校验声明和 ABC 哈希，再构建 release HAP。手机设备脚本验证推导字段/插槽、步骤错误摘要、FormArray、受控回填与主题切换；MateBook Pro 脚本验证宽/窄容器重排、坐标点击和键盘焦点。
