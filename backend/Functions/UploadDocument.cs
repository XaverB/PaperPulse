using System.Net;
using System.Net.Http.Headers;
using Azure.Storage.Blobs;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

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
        _logger.LogInformation("Processing upload request");

        try
        {
            var body = await new StreamReader(req.Body).ReadToEndAsync();
            var boundary = GetBoundary(req.Headers);

            if (string.IsNullOrEmpty(boundary))
            {
                var badRequest = req.CreateResponse(HttpStatusCode.BadRequest);
                await badRequest.WriteAsJsonAsync(new { message = "Missing content boundary" });
                return badRequest;
            }

            var reader = new MultipartReader(boundary, new MemoryStream(System.Text.Encoding.UTF8.GetBytes(body)));
            var section = await reader.ReadNextSectionAsync();

            if (section == null)
            {
                var badRequest = req.CreateResponse(HttpStatusCode.BadRequest);
                await badRequest.WriteAsJsonAsync(new { message = "No files were uploaded" });
                return badRequest;
            }

            var fileName = GetFileName(section.ContentDisposition);
            var blobName = $"{Guid.NewGuid()}{Path.GetExtension(fileName)}";

            // Upload to blob storage
            var blobClient = containerClient.GetBlobClient(blobName);
            await using var stream = section.Body;
            await blobClient.UploadAsync(stream, overwrite: true);

            // Return success response with blob name
            var response = req.CreateResponse(HttpStatusCode.OK);
            await response.WriteAsJsonAsync(new
            {
                message = "File uploaded successfully",
                blobName = blobName,
                originalFileName = fileName
            });
            return response;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing upload request");
            var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
            await errorResponse.WriteAsJsonAsync(new { message = "Error uploading file" });
            return errorResponse;
        }
    }

    private static string GetBoundary(HttpHeadersCollection headers)
    {
        var contentType = headers.GetValues("Content-Type").FirstOrDefault();
        if (string.IsNullOrEmpty(contentType)) return null;

        var contentTypeHeader = MediaTypeHeaderValue.Parse(contentType);
        var boundary = contentTypeHeader.Parameters
            .FirstOrDefault(p => string.Equals(p.Name, "boundary", StringComparison.OrdinalIgnoreCase))
            ?.Value.Trim('"');

        return boundary;
    }

    private static string GetFileName(string contentDisposition)
    {
        var contentDispositionHeader = ContentDispositionHeaderValue.Parse(contentDisposition);
        return contentDispositionHeader.FileNameStar ?? contentDispositionHeader.FileName?.Trim('"')
            ?? "unnamed-file";
    }
}