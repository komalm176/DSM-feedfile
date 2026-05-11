CREATE OR ALTER PROCEDURE dbo.Sp_UpdateFeedBatchFileCreated
    @FeedBatchFileId    UNIQUEIDENTIFIER,
    @FileName           NVARCHAR(255),
    @BlobPath           NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.FeedBatchFile
    SET
        FileName        = @FileName,
        BlobPath        = @BlobPath,
        Status          = 'Created',
        UpdatedDateTime = GETUTCDATE(),
        [User]          = 'FeedFileTimerFunction'
    WHERE FeedBatchFileId = @FeedBatchFileId;

    -- Verify update was successful
    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('FeedBatchFile record not found for FeedBatchFileId: %s', 16, 1,
            @FeedBatchFileId);
        RETURN;
    END
END
