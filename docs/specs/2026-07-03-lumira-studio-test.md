# 画集 Lumira Studio — 前端测试文档

> 配套文档：[前端设计文档](./2026-07-03-lumira-studio-frontend.md) · [PRD](../superpowers/specs/2026-07-03-lumira-studio-prd.md)
> 测试范围：页面跳转、按钮/手势交互、**API 接口数据获取**
> 产品特性：**联网社区平台**，账号体系、模板市场、作品社区、云端 AI、创作者生态
> 最后更新：2026-07-03

---

## 0. 文档说明

### 0.1 测试分层

| 层级 | 工具建议 | 覆盖内容 |
|---|---|---|
| 单元测试 | Vitest | Store actions、工具函数、API 封装、拦截器 |
| 组件测试 | Vitest + @vue/test-utils | 组件渲染、Props/Emits、交互 |
| 接口测试 | Vitest + MSW（Mock）/ 联调环境 | 请求参数、响应解析、错误码、分页、鉴权 |
| E2E | 自动化 / 手工 | 登录→购买→拍摄→发布→互动全链路 |
| 手工回归 | 本文档用例清单 | 真机、支付、推送、AI 异步任务 |

### 0.2 用例编号规则

`LS-{模块}-{类型}-{序号}`
- 模块：`AUTH`(认证) `HOME`(首页) `MKT`(市场) `CAP`(拍摄/AI) `COMM`(社区) `CRT`(创作者) `PRF`(我的/钱包) `NAV`(导航) `API`(接口)
- 类型：`NAV`(跳转) `UI`(交互) `DATA`(接口数据) `ERR`(异常)

### 0.3 优先级

- **P0**：核心链路（登录、模板购买、作品发布、社区浏览、拍摄）
- **P1**：主要功能（评论点赞、挑战赛、创作者看板、钱包）
- **P2**：次要/边缘（设置、空态、极端异常）

### 0.4 接口测试通用约定

所有 `DATA` 类接口用例，除特定断言外，均需验证以下**通用项**：

| 通用项 | 断言 |
|---|---|
| 请求地址 | `baseURL = https://api.lumira-studio.com/v1` |
| 鉴权头 | 已登录时请求头含 `Authorization: Bearer {token}` |
| 成功响应 | `code === 0`，`data` 结构符合类型定义 |
| 失败响应 | `code !== 0`，`message` 有可读文案，触发统一错误处理 |
| 超时 | 15s 超时触发重试/提示，不永久 loading |
| 分页 | 列表接口返回 `{items,total,page,pageSize,hasMore}` |
| Loading 态 | 请求期间显示骨架屏/加载指示 |
| 空态 | `items` 为空时显示空态占位 |

---

## 1. 全局导航测试

### 1.1 悬浮 Tab 栏（中央拍摄凸起）

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LS-NAV-NAV-001 | P0 | 切换首页 | 点「首页」 | 跳转 `/pages/home/index`，图标转暖橙 + 文字 |
| LS-NAV-NAV-002 | P0 | 切换市场 | 点「市场」 | 跳转 `/pages/marketplace/index` |
| LS-NAV-NAV-003 | P0 | 中央拍摄键 | 点中央凸起 ◉ | 触发 `on-capture`，跳转 `/pages/capture/index` |
| LS-NAV-NAV-004 | P0 | 切换社区 | 点「社区」 | 跳转 `/pages/community/index` |
| LS-NAV-NAV-005 | P0 | 切换我的 | 点「我的」 | 跳转 `/pages/profile/index` |
| LS-NAV-UI-006 | P1 | 中央键动效 | 按中央拍摄键 | `:active scale(0.92)` + 暖橙涟漪，松手回弹 |
| LS-NAV-UI-007 | P1 | 中央键凸起 | 查看 Tab 栏 | 拍摄键直径 56px 圆，凸起于胶囊上方 20px，暖橙实底 + 柔光阴影 |
| LS-NAV-UI-008 | P1 | 选中态动效 | 点任一侧 Tab | 图标 `scale(1.08)` + 文字淡入 200ms |
| LS-NAV-UI-009 | P1 | 悬浮固定 | 滚动内容 | Tab 栏固定悬浮，底部距 `safe-area + 12px` |
| LS-NAV-UI-010 | P2 | 内容避让 | 滚动至底 | 内容底部预留 100px，不被 Tab/中央键遮挡 |

### 1.2 登录态守卫

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LS-NAV-NAV-011 | P0 | 未登录访问受限页 | 未登录点「发布作品」 | 拦截并跳转 `/pages/auth/login`，登录后回跳原页 |
| LS-NAV-DATA-012 | P0 | Token 过期 | 携带过期 token 请求 | 响应 401，触发 `refresh`；刷新失败则登出跳登录页 |
| LS-NAV-NAV-013 | P1 | 游客可浏览 | 未登录浏览首页/市场/社区 | 可浏览列表；触发购买/点赞/评论时才要求登录 |

---

## 2. 认证模块（Auth）

### 2.1 登录页 `/pages/auth/login`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LS-AUTH-NAV-001 | P1 | 去注册 | 点「注册」 | 跳转 `/pages/auth/register` |
| LS-AUTH-NAV-002 | P1 | 找回密码 | 点「忘记密码」 | 跳转 `/pages/auth/forgot` |
| LS-AUTH-DATA-003 | P0 | 手机号登录 | 输入手机号+验证码点登录 | `POST /v1/auth/login`；成功 `data.token` 存入 authStore，回跳首页 |
| LS-AUTH-UI-004 | P1 | 微信登录 | 点「微信登录」 | 唤起微信授权，回调后 `POST /v1/auth/login`，登录成功 |
| LS-AUTH-UI-005 | P1 | Apple 登录 | iOS 点「Apple 登录」 | 唤起 Apple 授权，登录成功 |
| LS-AUTH-ERR-006 | P0 | 错误凭证 | 输入错误验证码 | 响应 `code!==0`，提示「验证码错误」，不跳转 |
| LS-AUTH-ERR-007 | P1 | 网络异常登录 | 断网点登录 | 提示「网络连接失败」，按钮恢复可点 |
| LS-AUTH-UI-008 | P2 | 表单校验 | 手机号格式错误 | 前端即时校验，提示格式错误，禁用登录按钮 |

### 2.2 注册 / 找回

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LS-AUTH-DATA-009 | P0 | 注册新用户 | 填资料提交 | `POST /v1/auth/register`；成功自动登录并回跳 |
| LS-AUTH-ERR-010 | P1 | 手机号已注册 | 用已注册号注册 | 提示「该手机号已注册」 |
| LS-AUTH-DATA-011 | P1 | 重置密码 | 找回流程提交新密码 | 请求成功，提示已重置，返回登录 |
| LS-AUTH-DATA-012 | P0 | 获取用户信息 | 登录后 | `GET /v1/auth/profile` 返回用户资料，写入 authStore |

---

## 3. 首页模块（Home）

### 3.1 首页 `/pages/home/index`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LS-HOME-DATA-001 | P0 | 首页数据加载 | 进入首页 | 加载 Bento（本周精选/挑战/榜单）+ 推荐流；Loading 骨架→内容 |
| LS-HOME-NAV-002 | P0 | 打开搜索 | 点搜索框 | 跳转 `/pages/home/search` |
| LS-HOME-NAV-003 | P0 | 点推荐模板 | 点推荐卡片 | 跳转 `/pages/marketplace/detail`，携带模板 id |
| LS-HOME-NAV-004 | P1 | 点本周挑战 | 点挑战 Bento | 跳转 `/pages/community/challenge` |
| LS-HOME-NAV-005 | P1 | 打开通知 | 点 🔔 | 打开通知列表 |
| LS-HOME-UI-006 | P1 | 新晋创作者横滑 | 左右滑头像列 | 横向滚动流畅，点头像进创作者主页 |
| LS-HOME-DATA-007 | P1 | 下拉刷新 | 首页下拉 | 重新拉取推荐数据，更新列表 |
| LS-HOME-DATA-008 | P1 | 上拉加载 | 推荐流滚到底 | `hasMore` 为真时加载下一页，追加内容 |
| LS-HOME-DATA-009 | P2 | 通知红点 | 有未读通知 | `GET /v1/notifications` 未读数驱动铃铛红点 |

### 3.2 搜索页 `/pages/home/search`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LS-HOME-DATA-010 | P1 | 搜索模板 | 输入关键词搜索 | `GET /v1/templates?keyword=` 返回结果列表 |
| LS-HOME-UI-011 | P2 | 搜索历史 | 进入搜索页 | 显示本地搜索历史，可点击复用/清除 |
| LS-HOME-UI-012 | P2 | 空结果 | 搜无匹配词 | 显示空态「未找到相关内容」 |

---

## 4. 模板市场模块（Marketplace）

### 4.1 市场页 `/pages/marketplace/index`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LS-MKT-DATA-001 | P0 | 模板列表加载 | 进入市场页 | `GET /v1/templates?page=1` 返回分页列表，双列渲染 |
| LS-MKT-UI-002 | P0 | 排序切换 | 点「热门/新品/免费/榜单」 | 带对应排序参数重新请求，列表刷新 |
| LS-MKT-UI-003 | P1 | 分类筛选 | 点品类标签（人像等） | 带 `category` 参数请求，列表过滤，标签用专属色高亮 |
| LS-MKT-NAV-004 | P0 | 打开模板详情 | 点模板卡片 | 跳转 `/pages/marketplace/detail`，携带 id |
| LS-MKT-NAV-005 | P1 | 上传模板 | 点「上传模板」（创作者） | 跳转 `/pages/marketplace/upload` |
| LS-MKT-NAV-006 | P1 | 我的购买 | 点「我的购买」 | 跳转 `/pages/marketplace/my-purchases` |
| LS-MKT-DATA-007 | P1 | 上拉分页 | 滚到底 | `page+1` 请求，`hasMore=false` 时显示「没有更多」 |
| LS-MKT-UI-008 | P1 | 卡片信息完整 | 查看卡片 | 显示缩略图/名称/作者头像/价格/点赞数/评分 |

### 4.2 模板详情 `/pages/marketplace/detail`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LS-MKT-DATA-009 | P0 | 详情加载 | 进入详情页 | `GET /v1/templates/:id` 返回完整数据，渲染预览/作者/评价 |
| LS-MKT-DATA-010 | P0 | 购买模板（余额足） | 点「购买」→确认 | `POST /v1/templates/:id/purchase`；成功扣款，加入我的模板库，按钮变「拍同款」 |
| LS-MKT-DATA-011 | P0 | 购买（余额不足） | 余额不足时购买 | 检测余额不足，引导跳 `/pages/profile/wallet` 充值 |
| LS-MKT-NAV-012 | P0 | 拍同款 | 已购点「拍同款」 | 跳转 `/pages/capture/index`，加载该模板 |
| LS-MKT-UI-013 | P1 | 免费模板领取 | 免费模板点「获取」 | 直接入库，无扣款 |
| LS-MKT-NAV-014 | P1 | 进作者主页 | 点作者头像 | 跳转创作者主页 |
| LS-MKT-DATA-015 | P2 | 版本历史 | 点「版本历史」 | `GET /v1/templates/:id/versions` 返回版本列表 |
| LS-MKT-ERR-016 | P1 | 重复购买 | 购买已购模板 | 提示「已拥有」，不重复扣款 |

### 4.3 模板上传 `/pages/marketplace/upload`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LS-MKT-DATA-017 | P0 | 上传模板 | 填资料+选文件提交 | 先 OSS 上传素材，再 `POST /v1/templates`；成功进审核态 |
| LS-MKT-ERR-018 | P1 | 表单不完整 | 缺必填提交 | 前端校验拦截，标红缺失项 |
| LS-MKT-ERR-019 | P1 | 上传中断 | 上传大文件断网 | 提示失败可重试，草稿保留 |
| LS-MKT-DATA-020 | P2 | 下架模板 | 创作者下架 | `DELETE /v1/templates/:id`，列表移除 |

---

## 5. 拍摄与 AI 模块（Capture / AI）

> 拍摄基础交互同单机版（取景器/快门/构图叠图/参数），复用 [如画测试文档 §2](./2026-07-03-lumira-test.md)。本节仅列联网差异——AI 能力。

### 5.1 拍摄页 `/pages/capture/index`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LS-CAP-NAV-001 | P0 | 进入 AI 辅助 | 点「AI 辅助」 | 跳转 `/pages/capture/ai-assist` |
| LS-CAP-UI-002 | P0 | 快门拍摄 | 点中央/快门 | 拍摄成功进入预览（同单机） |

### 5.2 AI 辅助 `/pages/capture/ai-assist`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LS-CAP-DATA-003 | P0 | 场景识别 | 开启 AI 场景 | `POST /v1/ai/scene-recognition` 返回场景标签，界面提示推荐参数 |
| LS-CAP-DATA-004 | P0 | 构图评分 | 取景中请求评分 | `POST /v1/ai/composition-score` 返回分数，实时显示评分条 |
| LS-CAP-DATA-005 | P1 | 姿态评估 | 人像姿态检测 | `POST /v1/ai/pose-evaluate` 返回建议，叠加提示 |
| LS-CAP-DATA-006 | P0 | 智能修图（异步） | 拍后点 AI 增强 | `POST /v1/ai/enhance` 返回任务 id；轮询/WS 获取进度；完成后下载结果显示 |
| LS-CAP-DATA-007 | P1 | 人像分割 | AI 抠图 | `POST /v1/ai/portrait-segment` 返回蒙版，应用背景处理 |
| LS-CAP-ERR-008 | P0 | AI 请求超时 | AI 服务慢/超时 | 15s 超时提示「AI 处理超时，请重试」，保留原图，不卡死 |
| LS-CAP-ERR-009 | P1 | AI 异步任务失败 | 增强任务返回失败态 | 轮询到失败状态时提示并停止轮询 |
| LS-CAP-ERR-010 | P1 | 弱网降级 | 弱网使用 AI | 提示网络不佳；可回退纯本地参数拍摄 |

---

## 6. 社区模块（Community）

### 6.1 社区页 `/pages/community/index`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LS-COMM-DATA-001 | P0 | 作品瀑布流加载 | 进入社区页 | `GET /v1/works?page=1` 返回分页，Masonry 双列不等高渲染 |
| LS-COMM-UI-002 | P1 | 频道切换 | 点「关注/推荐/挑战赛/附近」 | 带对应参数请求，列表刷新 |
| LS-COMM-NAV-003 | P0 | 打开作品详情 | 点作品卡片 | 跳转 `/pages/community/detail`，携带 id |
| LS-COMM-NAV-004 | P0 | 发布作品 | 点「+ 发布」 | 未登录拦截；已登录跳 `/pages/community/publish` |
| LS-COMM-NAV-005 | P1 | 拍同款 | 卡片点「拍同款」 | 跳 `/pages/marketplace/detail` 或直接加载模板拍摄 |
| LS-COMM-DATA-006 | P1 | 上拉分页 | 滚到底 | 加载下一页作品 |
| LS-COMM-DATA-007 | P1 | 下拉刷新 | 下拉 | 重新拉取最新作品流 |

### 6.2 作品详情 `/pages/community/detail`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LS-COMM-DATA-008 | P0 | 详情加载 | 进入作品详情 | `GET /v1/works/:id` + `GET /v1/works/:id/comments` 渲染作品与评论 |
| LS-COMM-DATA-009 | P0 | 点赞/取消 | 点♥ | `POST /v1/works/:id/like`；图标弹性动效变色，点赞数 +1/-1（乐观更新，失败回滚） |
| LS-COMM-DATA-010 | P0 | 发表评论 | 输入评论提交 | `POST /v1/works/:id/comments`；成功插入评论列表顶部 |
| LS-COMM-DATA-011 | P1 | 删除评论 | 删除自己的评论 | `DELETE /v1/comments/:id`，列表移除 |
| LS-COMM-DATA-012 | P2 | 举报作品 | 点「举报」 | `POST /v1/works/:id/report`，提示已提交 |
| LS-COMM-ERR-013 | P1 | 空评论态 | 无评论作品 | 显示「暂无评论，快来抢沙发」 |
| LS-COMM-ERR-014 | P1 | 点赞未登录 | 游客点赞 | 拦截跳登录，登录后回到详情 |

### 6.3 发布作品 `/pages/community/publish`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LS-COMM-DATA-015 | P0 | 发布流程 | 选模板+选图+填文案发布 | 先 OSS 上传照片，再 `POST /v1/works`；成功跳详情/社区，新作品可见 |
| LS-COMM-ERR-016 | P1 | 未选图发布 | 未选照片点发布 | 校验拦截，提示需选择照片 |
| LS-COMM-ERR-017 | P1 | 上传失败 | OSS 上传失败 | 提示重试，文案草稿保留 |

### 6.4 挑战赛 `/pages/community/challenge` · `challenge-submit`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LS-COMM-DATA-018 | P1 | 挑战列表/详情 | 进入挑战赛 | `GET /v1/challenges` / `GET /v1/challenges/:id` 渲染 |
| LS-COMM-NAV-019 | P1 | 去参赛 | 点「参赛」 | 跳 `/pages/community/challenge-submit` |
| LS-COMM-DATA-020 | P1 | 提交参赛 | 提交作品 | `POST /v1/challenges/:id/submit`，成功进入排行 |
| LS-COMM-DATA-021 | P1 | 排行榜 | 查看排行 | `GET /v1/challenges/:id/rankings` 返回榜单 |
| LS-COMM-DATA-022 | P2 | 投票 | 给参赛作品投票 | `POST /v1/challenges/:id/vote`，票数更新（防重复投票） |

---

## 7. 创作者模块（Creator）

### 7.1 创作者看板 `/pages/creator/dashboard`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LS-CRT-DATA-001 | P1 | 看板数据 | 进入看板 | `GET /v1/creator/dashboard` 返回收益/粉丝/模板/销量，Bento 渲染 |
| LS-CRT-UI-002 | P2 | 隐藏悬浮 Tab | 进入看板 | 深度页不显示悬浮 Tab 栏 |
| LS-CRT-NAV-003 | P1 | 进收益页 | 点「收益」 | 跳 `/pages/creator/earnings` |
| LS-CRT-NAV-004 | P1 | 进粉丝页 | 点「粉丝」 | 跳 `/pages/creator/fans` |
| LS-CRT-NAV-005 | P2 | 进认证页 | 点「认证」 | 跳 `/pages/creator/certification` |

### 7.2 收益 / 粉丝 / 认证

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LS-CRT-DATA-006 | P1 | 收益明细 | 进收益页 | `GET /v1/creator/earnings` 返回明细，分页展示 |
| LS-CRT-DATA-007 | P0 | 提现 | 填金额提现 | `POST /v1/creator/withdraw`；成功提示，余额更新 |
| LS-CRT-ERR-008 | P1 | 提现超额 | 提现超余额 | 拦截提示「超出可提现余额」 |
| LS-CRT-DATA-009 | P1 | 粉丝列表 | 进粉丝页 | `GET /v1/creator/followers` 返回列表，分页 |
| LS-CRT-DATA-010 | P2 | 提交认证 | 提交认证资料 | `POST /v1/creator/certify`，进入审核态 |

---

## 8. 我的与钱包模块（Profile / Wallet）

### 8.1 我的 `/pages/profile/index`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LS-PRF-DATA-001 | P1 | 个人信息加载 | 进入我的页 | 渲染 authStore 用户资料（头像/昵称/统计） |
| LS-PRF-NAV-002 | P1 | 进设置 | 点「设置」 | 跳 `/pages/profile/settings` |
| LS-PRF-NAV-003 | P0 | 进钱包 | 点「钱包」 | 跳 `/pages/profile/wallet` |
| LS-PRF-NAV-004 | P1 | 进订单 | 点「订单」 | 跳 `/pages/profile/orders` |
| LS-PRF-NAV-005 | P1 | 进会员 | 点「会员中心」 | 跳 `/pages/profile/membership` |
| LS-PRF-NAV-006 | P1 | 进创作者中心 | 点「创作者中心」 | 跳 `/pages/creator/dashboard` |

### 8.2 钱包 / 订单

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LS-PRF-DATA-007 | P0 | 钱包信息 | 进钱包页 | `GET /v1/wallet` 返回余额，正确显示 |
| LS-PRF-DATA-008 | P0 | 充值 | 选金额充值支付 | `POST /v1/wallet/recharge` 创建订单→唤起支付→成功后余额更新 |
| LS-PRF-ERR-009 | P1 | 支付取消 | 支付中途取消 | 订单为未支付态，余额不变，提示已取消 |
| LS-PRF-DATA-010 | P1 | 订单列表 | 进订单页 | `GET /v1/orders` 返回购买记录，分页 |
| LS-PRF-DATA-011 | P2 | 退出登录 | 设置页点退出 | 清空 authStore/token，回到游客态，跳首页 |

---

## 9. 接口层专项测试（API）

### 9.1 拦截器与鉴权

| 编号 | 优先级 | 场景 | 预期结果 |
|---|---|---|---|
| LS-API-DATA-001 | P0 | Token 注入 | 已登录请求头自动带 `Authorization: Bearer {token}` |
| LS-API-DATA-002 | P0 | 401 刷新 | 收到 401 触发 `POST /v1/auth/refresh`，成功后重放原请求 |
| LS-API-ERR-003 | P0 | 刷新失败登出 | refresh 也失败则清 token，跳登录页 |
| LS-API-DATA-004 | P1 | 响应解构 | 拦截器返回 `res.data`，业务层直接拿 data |
| LS-API-ERR-005 | P0 | 统一错误处理 | 非 0 code 走 `handleApiError`，弹统一错误提示 |

### 9.2 网络异常与容错

| 编号 | 优先级 | 场景 | 预期结果 |
|---|---|---|---|
| LS-API-ERR-006 | P0 | 断网请求 | 捕获网络错误，提示「网络连接失败」，不白屏 |
| LS-API-ERR-007 | P1 | 超时（>15s） | 触发超时处理，结束 loading，可重试 |
| LS-API-ERR-008 | P1 | 5xx 服务端错误 | 提示「服务开小差」，不暴露原始错误 |
| LS-API-ERR-009 | P1 | 分页越界 | 请求超出总页返回空，`hasMore=false` |
| LS-API-DATA-010 | P2 | 幂等/防抖 | 快速重复提交（点赞/购买）做防抖，避免重复请求 |
| LS-API-DATA-011 | P2 | OSS 上传 | 图片先传 OSS 得 URL 再提交业务接口；上传进度可见 |

---

## 10. 冒烟测试清单（发布前必过 P0）

- [ ] 手机号登录成功 → 用户信息加载
- [ ] 首页 Bento + 推荐流加载正常，下拉刷新有效
- [ ] 市场列表加载 → 打开详情 → 购买模板（余额足）成功入库
- [ ] 余额不足购买 → 正确引导充值
- [ ] 中央拍摄键 → 拍摄 → AI 场景识别/构图评分返回
- [ ] AI 智能修图异步任务完成并显示结果
- [ ] 社区瀑布流加载 → 作品详情 → 点赞 + 评论成功
- [ ] 发布作品：选模板+图 → OSS 上传 → 发布成功可见
- [ ] 钱包充值支付成功 → 余额更新
- [ ] Token 过期自动刷新，刷新失败正确登出
- [ ] 五 Tab 切换 + 中央拍摄凸起键交互正常
