-- lumira-server/packages/backend/src/database/migrations/019_template_category_description.sql
-- 模板分类新增「简短描述」字段（可为空），仅用于一/二级分类。
-- 幂等：由 _migrations 表记录，仅执行一次。
-- 注意：MySQL TEXT 列不支持字面量默认值，需用括号表达式形式 DEFAULT ('').
ALTER TABLE template_categories
  ADD COLUMN description TEXT NOT NULL DEFAULT ('');