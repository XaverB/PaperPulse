using System.Net;
using Azure.Storage.Blobs;
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
        var stream = req.Body;
        var blobName = $"{Guid.NewGuid()}.pdf";
        var blobClient = containerClient.GetBlobClient(blobName);

        await blobClient.UploadAsync(stream, overwrite: true);

        var response = req.CreateResponse(HttpStatusCode.OK);
        await response.WriteAsJsonAsync(new { blobName = blobName });
        return response;
    }
}