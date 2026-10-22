## Why

文档基线已经对齐，但仓库尚无任何后端代码，Sprint 3 及之后的用户组织、日志、任务工作都缺少可启动的工程、数据库结构和认证入口。Sprint 1–2 的后端任务（`tasks.md` 1.1–2.6）是全部后续工作的前置依赖，需要先形成可运行、可迁移、可测试的后端纵切。

## What Changes

- 按技术设计的 `common/config/security/controller/service/mapper/entity/dto/job/audit` 分层建立 Maven + Spring Boot 工程骨架，提供统一响应、错误码、分页和全局异常处理。
- 使用 Flyway 建立版本化迁移：基础角色/权限/系统配置种子；用户、角色、权限、部门、团队、刷新会话表；任务六表、索引与组织唯一性约束。
- 实现账号密码登录、令牌刷新、登出、当前用户接口，以及 JWT 校验过滤器、BCrypt 密码校验、失败锁定和停用账号拒绝登录；不提供注册接口。
- 增加认证与迁移的自动化测试，以及供 Flutter/Web 使用的 API 契约样例。
- 不实现用户/组织管理接口（Sprint 3）和业务领域接口（Sprint 4 起）。

## Capabilities

### New Capabilities

- `backend-foundation`: 可启动的后端工程骨架、统一响应与错误码、Flyway 迁移与种子数据、契约测试样例。
- `authentication`: 账号密码登录、访问/刷新令牌、登出、当前用户、失败锁定与停用账号处理。

### Modified Capabilities

- `identity-and-organization`: 增加数据库层强制组织唯一性与角色-组织归属的要求，明确部分唯一索引、CHECK 约束与删除限制。

## Impact

- 新增后端源码树、Maven 配置、Flyway 迁移和测试；不修改 Flutter、React 客户端代码。
- 不修改 `documents/产品需求文档.md`、接口契约与技术设计；实现以现有文档为准。
- 完成后 Sprint 2 的 2.1–2.6 可勾选，Sprint 3 的用户/组织接口具备开工条件。
