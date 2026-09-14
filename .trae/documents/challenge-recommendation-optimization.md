# 挑战页推荐算法优化

## Context（背景与目标）

当前挑战页推荐算法在 [challenge_repository.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/challenge/data/challenge_repository.dart) 中，核心逻辑是 `_selectCategories()`：当用户相册照片 ≥5 张时，**优先推荐「未尝试过的大类」**（探索型），已尝试大类作为回落。

用户的痛点：该 app 是拍照工具，用户会带着明确主题进来（例如"我就是来拍人像的"）。若挑战却推"静物/风光"等用户从不拍或不喜欢的类，会强烈反感。

**目标新行为**：
1. 每日挑战**锚定用户偏好大类**，在大类内换不同风格的题去尝试（而非跨大类探索）。
2. 只有用户**确实拍过其他大类**时，才**少量掺入**那些相关大类的挑战。
3. 用户**从未拍过的大类，不再进入候选**。
4. 附加挑战（支线）遵循同样的"偏好为主 + 少量已拍大类"原则。

### 关键事实约束（已调研确认）

- 用户照片分类来自 `gallery_items → scene_id JOIN scenes.related_category`，值域就是 7 个"大类"（`portrait/landscape/food/street/night/macro/still-life`），与 `ChallengeCategory` 是同一套。**相册数据感知不到大类之下的子类型/风格**。
- 挑战题库 [challenge_pool.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/challenge/data/challenge_pool.dart) 每个大类下有 6 道题，同一大类内不同题目（title/tags 各异）即代表"该大类的不同子风格"。
- 模板另有四级分类体系（type/majorStyle/subStyle/method），是另一套，不承载照片归类，本次**不引入**。

因此"偏好大类内的其他子类型风格"，在挑战场景的落地形式 = **在偏好大类内随机抽不同风格的题（且尽量避开今天已选/已完成的同题）**。

## 目标推荐行为（用户确认）

| 诉求 | 决策 |
|------|------|
| 每日 3 候选分配 | **2 个来自偏好大类 + 1 个来自已拍的其他大类**（若没拍过其他大类，第 3 个回落到偏好大类） |
| 未拍过大类 | **完全不推荐**（保底：全部大类从未拍过时仍需给候选，否则挑战页为空） |
| 偏好大类界定 | 取相册 `countByCategory()` 中照片最多的单一 `topCategory` |

## 实现方案

### 修改文件

核心改动集中在 **`lumira_app_flutter/lib/features/challenge/data/challenge_repository.dart`**，不动 UI / DAO / 数据库 / 题库数据。

#### 1) 重写 `_selectCategories(UserShootingProfile, Random) → List<String>`

将当前"未尝试优先"逻辑替换为"偏好锚定"：

```
# 无照片（totalPhotos == 0）：保底
随机取 3 个大类（全部未拍的极端情况，也要能出候选）
# 有照片：
固定前 2 个大类 = topCategory
第 3 个大类 = offered:
    - 若 triedCategories 中除 topCategory 外还有其他大类（用户拍过别的）
        → 从这批「已拍的其他大类」随机挑 1 个
    - 否则 → 回落 topCategory
未拍过的大类（untriedCategories）绝不选入
```

#### 2) 调整 `getDailyCandidates()` 抽题逻辑

现有实现是对每个大类 `random.nextInt(pool.length)` 单独抽，**同一大类出现多次时会抽到重复题**。改为：

- 先 `_selectCategories` 得到候选大类序列（可含重复的偏好大类）。
- 再对每个候选大类，在**其题库中取一道尚未被本批选中的题**（`shuffle` 后按序挑未用题），保证 3 道候选互不重复。
- 若因某大类题数不足导致不足 3 道，则从剩余**已拍大类**的题库补齐；极端情况下才借任意大类的题保底（保证挑战页永远有候选）。

#### 3) 调整 `getSubChallenges(String dailyCategory)` → 偏好为主

将签名改为内部不再依赖"除主分类外随机 2 类"，而是：

- 读取 `topCategory` 与"已拍的其他大类"（复用 `_buildProfile()`）。
- 排除**今天已选/已完成的题**（复用现有 `getDailyByDate(today)` 拿到今日主挑战 id，结合今日 `doneIds`）避免与主线撞题、避免重复提交。
- 生成 2 个附加挑战：
  - 1 个 = 偏好大类的另一风格题（避开主挑战那题）
  - 1 个 = 已拍的其他大类某题（若用户只拍过偏好大类，则回落到偏好大类的另一道不同风格题）
- 保持附加挑战奖励口径不变（`subChallengeRewardXP`，主挑战 60%）。

`SubChallenge` 的 icon/tag 由 `_categoryIcon` / `_tagColor` 渲染，已覆盖全部 7 类，无需改动。

### 不改动范围

- 用户画像数据源（`_buildProfile`）结构不变，仅消费逻辑变化。
- `UserShootingProfile` / 模型 / DAO / 题库 / UI 页面均不改。

## 测试

新增单元测试覆盖核心推荐逻辑（放 `test/features/challenge/`）：

- `_selectCategories` / `getDailyCandidates`：构造不同的 `categoryCounts`（全未拍 / 只拍过偏好大类 / 拍过多大类），断言
  1. 有照片且只拍 1 类 → 3 候选全部来自该大类；
  2. 拍过多大类 → 候选含偏好大类（≥2）+ 已拍的其他大类（≤1），**不含任何未拍大类**；
  3. 候选 3 道题 id 互不重复；
  4. 全部未拍（totalPhotos==0）→ 仍返回 3 候选（保底）。
- `getSubChallenges`：断言附加挑战与今日主挑战不撞题、奖励=60%。

现有 UI 测试（`challenge_page_test.dart`）通过 mock repository 驱动，内部算法改动不影响其断言，应保持通过。

## 验证

- `flutter analyze`（确认无新增告警/错误）。
- `flutter test test/features/challenge/`（新增推荐逻辑单测 + 现有挑战测试通过）。
- 手动核验（真机/模拟器）：相册只拍人像 → 每日挑战 3 候选全为人像不同风格题；再拍几张静物后重启 → 候选变为 2 人像 + 1 静物。