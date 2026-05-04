Create SCHEMA audit;

CREATE TABLE audit.bronze_deletes (
  logId      INT IDENTITY(1,1) PRIMARY KEY,
  tableName  NVARCHAR(100),
  resultId   INT,
  raceId     INT,
  driverId   INT,
  deletedAt  DATETIME2,
  deletedBy  NVARCHAR(128)
);
GO

CREATE TRIGGER trg_bronze_results_delete_log
  ON bronze.results
  AFTER DELETE
AS BEGIN
  SET NOCOUNT ON

  INSERT INTO audit.bronze_deletes
    (tableName, resultId, raceId, driverId, deletedAt, deletedBy)
  SELECT
    'bronze.results',
    d.resultId,
    d.raceId,
    d.driverId,
    GETUTCDATE(),
    SYSTEM_USER
  FROM deleted d

END
GO


