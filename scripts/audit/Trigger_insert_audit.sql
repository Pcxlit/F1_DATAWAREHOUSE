CREATE TRIGGER trg_bronze_results_audit
  ON bronze.results
  AFTER INSERT
AS BEGIN
  SET NOCOUNT ON

  UPDATE bronze.results
  SET    ingested_at = GETUTCDATE()
  WHERE  resultId IN (SELECT resultId FROM inserted)

END