# 找成员1/成员5要的东西（Web 联调缺口清单）

> 成员3 Web 管理端只读日志与统计，其他不动。接口和字典到了只改 `src/api/client.ts`。

## 找成员1：接口契约（4 类）

```text
POST /api/auth/login        入参 {name}，出参 {token, name, role}，401 名字空/停用
GET  /api/users             出参 UserRow[]，管理员可见全公司
POST /api/users             入参 {name, dept, team, role}，重名 409
PATCH /api/users/:id        入参 {status}，启用/停用
DELETE /api/users/:id       真删除，有日志关联时 409 并提示
GET  /api/logs?scope=all    出参 LogRow[]，只读不可改
GET  /api/stats             出参 {submitRate, unsubmitted[]}，只读
```

分页/搜索先走前端本地，数据上千后再让后端加 `?q=&page=`。

## 找成员5：数据字典（5 张表字段名）

```text
users: id / name / dept / team / role(5种) / status(启用停用)
org: company / dept / team / leader(每队一个组长)
logs: id / author / date(当天) / summary(非空) / visible(直接上级可见)
reviews: 只有直接上级可发起，下级可回复，更上级不可见
stats: submitRate = 当天已提交/应提交，unsubmitted 名单
```

ER 图到了对照 `src/constants/roles.ts` 的 5 角色改展示名即可。

## 找成员2：墨刀链接

字段同一套：姓名/部门/团队/角色/日志内容/可见范围，别各做各的。

## 找成员4：用例模板

登录守卫、增删改、停用不可登录、只读不可改、404 回跳，5 条先自测。
