-- ============================================================
-- V16__fix_task_handover_consistency.sql
--
-- 1. 为每条 task assignment 增加独立截止时间
-- 2. 使用原 task.deadline 回填历史 assignment
-- 3. 放宽 progress note 长度，避免任务交接自动拼接说明后越界
--
-- 注意：
-- deadline 暂时保持 nullable，等后端全部改为写 assignment.deadline
-- 后再考虑下一版迁移改成 NOT NULL。
-- ============================================================


-- ============================================================
-- 1. Assignment-level deadline
-- ============================================================

ALTER TABLE task_assignments
ADD COLUMN IF NOT EXISTS deadline timestamp without time zone;


-- Existing assignments inherit the parent task deadline.
UPDATE task_assignments a
SET deadline = t.deadline
FROM tasks t
WHERE t.id = a.task_id
  AND a.deadline IS NULL;


-- Calendar / task-list queries frequently use assignment deadline.
CREATE INDEX IF NOT EXISTS idx_task_assignments_deadline
ON task_assignments(deadline);


-- ============================================================
-- 2. Progress note length
-- ============================================================

ALTER TABLE task_progress_updates
DROP CONSTRAINT IF EXISTS chk_task_progress_note_length;

ALTER TABLE task_progress_updates
ADD CONSTRAINT chk_task_progress_note_length
CHECK (char_length(note) <= 2000);