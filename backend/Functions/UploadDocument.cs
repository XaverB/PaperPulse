using System.Net;
using Azure.Storage.Blobs;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using System.Net.Http.Headers;

namespace PaperPulse.Functions;

public class UploadDocument
{
    private readonly ILogger<UploadDocument> _logger;

    public UploadDocument(ILogger<UploadDocument> logger)
    {
        _logger = logger;
    }

    [Function(nameof(UploadDocument))]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "documents/upload")] HttpRequestData req,
        [BlobInput("documents", Connection = "AzureWebJobsStorage")] BlobContainerClient containerClient)
    {
        try
        {
            _logger.LogInformation("Processing document upload request");

            // Get original filename from Content-Disposition header
            string originalFileName = GetFileName(req);
            if (string.IsNullOrEmpty(originalFileName))
            {
                _logger.LogWarning("No filename provided in request");
                var badResponse = req.CreateResponse(HttpStatusCode.BadRequest);
                await badResponse.WriteAsJsonAsync(new { error = "No filename provided" });
                return badResponse;
            }

            // Get file extension from original filename
            string extension = Path.GetExtension(originalFileName);
            if (string.IsNullOrEmpty(extension))
            {
                extension = ".dat"; // Default extension if none provided
            }

            // Create unique blob name with original extension
            var blobName = $"{Guid.NewGuid()}{extension.ToLowerInvariant()}";
            var blobClient = containerClient.GetBlobClient(blobName);

            _logger.LogInformation($"Uploading file {originalFileName} as blob {blobName}");

            var stream = req.Body;
            await blobClient.UploadAsync(stream, overwrite: true);

            var response = req.CreateResponse(HttpStatusCode.OK);
            await response.WriteAsJsonAsync(new
            {
                blobName = blobName,
                originalFileName = originalFileName
            });

            return response;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error uploading document");
            var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
            await errorResponse.WriteAsJsonAsync(new { error = "Error uploading document" });
            return errorResponse;
        }
    }

    private string GetFileName(HttpRequestData req)
    {
        // Try to get filename from Content-Disposition header
        if (req.Headers.TryGetValues("Content-Disposition", out var contentDisposition))
        {
            var disposition = ContentDispositionHeaderValue.Parse(contentDisposition.First());
            if (!string.IsNullOrEmpty(disposition.FileName))
            {
                return disposition.FileName.Trim('"');
            }
        }

        // Try to get filename from custom header
        if (req.Headers.TryGetValues("X-File-Name", out var fileName))
        {
            return fileName.First();
        }

        return string.Empty;
    }
}