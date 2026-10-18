## Why

`documents/产品需求文档.md` 已完成更新，但四份配套文档仍存在残余偏差：顶层设计缺少组织唯一性、角色归属约束、账号开通方式和页面布局细节，且 Sprint 规划仍是旧的五阶段划分；接口文档未说明不提供自助注册和组织负责人唯一性；技术设计缺少角色-归属校验、对应 DDL 约束、关键接口 99% 成功率与易用性验收；项目计划未安排易用性测试和组织约束测试。现在补齐这些偏差，可使设计、契约、实现和验收重新以 PRD 为单一基线。

## What Changes

- 顶层设计文档补充单创始人/单部门老总/单团队长、角色与组织归属约束、管理员统一开通账号且不支持自助注册、四个页面的布局与日历细节，并将 Sprint 规划改为与项目计划一致的 16 Sprint、M1–M9 基线。
- 后端接口文档明确不提供注册接口、账号由管理员创建，并补充组织负责人唯一性和角色-组织归属校验规则及冲突响应。
- 技术设计文档补充 `users` 角色-归属 CHECK 约束、用户接口校验规则、错误码、关键接口成功率 ≥ 99%、易用性指标和易用性测试行。
- 项目计划与里程碑补充 M8/Sprint 15 易用性测试，以及 Sprint 3/Sprint 12 组织唯一性与角色归属校验测试。
- 不修改产品需求文档，不实现运行时代码或数据库迁移。

## Capabilities

### New Capabilities

- `identity-and-organization`: 单公司单创始人、单部门单老总、单团队单团队长的组织唯一性，用户角色与组织归属的一致性，以及仅由管理员开通账号、不提供自助注册。
- `delivery-quality-standards`: 性能、关键接口成功率、易用性和 Android 分辨率验收标准，以及对应的测试覆盖要求。
- `delivery-planning`: 顶层设计与项目计划共用的 16 Sprint、M1–M9 排期基线，以及组织约束与易用性验证的排期。

### Modified Capabilities

- `task-presentation`: 明确视图页左上角的日/周/月视图选择入口，保持既有的日视图白底、日期范围含端点和绿色优先规则。

## Impact

- 更新 `documents/顶层设计文档.md`、`documents/后端接口文档.md`、`documents/技术设计文档.md`、`documents/项目计划与里程碑.md`。
- 新增本 change 的 proposal、design、specs 与 tasks；既有主规格 `task-management`、`task-presentation`、`company-priority-content` 的业务行为不变。
- 不涉及运行时代码、数据库迁移或已部署接口。
