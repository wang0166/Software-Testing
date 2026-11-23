-- v2.0 daily-todo UI: persist pastel colour, optional local time range and
-- per-day drag ordering so the same view is restored on every device.
ALTER TABLE daily_items
  ADD COLUMN color_value BIGINT NOT NULL DEFAULT 4294957543,
  ADD COLUMN start_time TIME,
  ADD COLUMN end_time TIME,
  ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0,
  ADD CONSTRAINT chk_daily_items_time_range CHECK (
    (start_time IS NULL AND end_time IS NULL)
    OR (start_time IS NOT NULL AND end_time IS NOT NULL AND end_time > start_time)
  ),
  ADD CONSTRAINT chk_daily_items_sort_order CHECK (sort_order >= 0);

CREATE INDEX idx_daily_items_user_date_order
  ON daily_items(user_id, item_date, sort_order, id);
