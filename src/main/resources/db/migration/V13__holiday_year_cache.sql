-- 节假日年度缓存：按年保存数据来源、原始同步时间与归一化结果。
-- 外部接口不可用时直接读缓存，未公布年份也能保留“尚未公布”的明确状态。
CREATE TABLE holiday_year_cache (
  year       INTEGER PRIMARY KEY,
  published  BOOLEAN NOT NULL,
  complete   BOOLEAN NOT NULL DEFAULT TRUE,
  source     VARCHAR(200) NOT NULL,
  source_url VARCHAR(500),
  payload    TEXT NOT NULL,
  synced_at  TIMESTAMPTZ NOT NULL
);
