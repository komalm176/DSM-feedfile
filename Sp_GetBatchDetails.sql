CREATE OR ALTER PROCEDURE dbo.Sp_GetBatchDetails
    @FeedBatchFileId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Guard: Skip if batch is INIT or Created (not yet exported)
    IF EXISTS (
        SELECT 1 FROM dbo.FeedBatchFile
        WHERE Status IN ('INIT', 'Created')
    )
    BEGIN
        SET @FeedBatchFileId = NULL;
        RETURN;
    END

    SET @FeedBatchFileId = NEWID();

    -- Fetch TOP 1000 unprocessed reviewed records
    SELECT TOP 1000
        pd.ProviderId,
        pd.ProviewAssocId,
        pd.ProviewDocId,
        pd.Dium                     AS DocumentumId,
        drs.Status                  AS ReviewStatus,
        pd.DocumentType,
        sm.StateName                AS State,
        dr.ReviewedDateTime,
        NULL                        AS ExpirationDate,
        drrr.RejectReason,
        pd.Ingestionsource,
        NULL                        AS WQMIncidentNumber,
        dr.ProviderDocumentsId
    INTO #TempBatch
    FROM dbo.DocumentReview dr
    INNER JOIN dbo.ProviderDocuments pd
        ON dr.ProviderDocumentsId = pd.Id
    INNER JOIN dbo.DocumentReviewStatusMaster drs
        ON dr.DocumentReviewStatusMasterId = drs.Id
    LEFT JOIN dbo.DocumentReviewRejectReason drrr
        ON dr.DocumentReviewRejectReasonId = drrr.DocumentRejectReasonId
    LEFT JOIN dbo.StateMaster sm
        ON pd.StateId = sm.Id
    WHERE dr.IsExported = 0
      AND dr.DocumentReviewStatusMasterId IN (1, 3)
    ORDER BY dr.CreatedDateTime ASC;

    -- Insert batch header into FeedBatchFile
    INSERT INTO dbo.FeedBatchFile (
        FeedBatchFileId,
        Status,
        RecordCount,
        RetryCount,
        CreatedDateTime,
        UpdatedDateTime,
        [User]
    )
    VALUES (
        @FeedBatchFileId,
        'INIT',
        (SELECT COUNT(*) FROM #TempBatch),
        0,
        GETUTCDATE(),
        GETUTCDATE(),
        'Sp_GetBatchDetails'
    );

    -- Insert detail records into FeedBatchFileDetails
    INSERT INTO dbo.FeedBatchFileDetails (
        FeedBatchFileId,
        ProviderAttachmentID,
        CreatedDateTime
    )
    SELECT
        @FeedBatchFileId,
        ProviderDocumentsId,
        GETUTCDATE()
    FROM #TempBatch;

    -- Return all records to Azure Function
    SELECT
        @FeedBatchFileId        AS FeedBatchFileId,
        ProviderId,
        ProviewAssocId,
        ProviewDocId,
        DocumentumId,
        ReviewStatus,
        DocumentType,
        State,
        ReviewedDateTime,
        ExpirationDate,
        RejectReason,
        Ingestionsource,
        WQMIncidentNumber
    FROM #TempBatch;

    DROP TABLE #TempBatch;
END
