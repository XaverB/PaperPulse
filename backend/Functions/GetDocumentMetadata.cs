using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using PaperPulse.Functions.Models;

namespace PaperPulse.Functions;

public class GetDocumentMetadata
{
    private readonly ILogger<GetDocumentMetadata> _logger;

    public GetDocumentMetadata(ILogger<GetDocumentMetadata> logger)
    {
        _logger = logger;
    }

    [Function(nameof(GetDocumentMetadata))]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "get", Route = "documents/{id}")] HttpRequestData req,
        [CosmosDBInput("PaperPulse", "Metadata",
            Connection = "CosmosDBConnection",
            Id = "{id}",
            PartitionKey = "{id}")] DocumentMetadata metadata,
        string id)
    {
        _logger.LogInformation($"Retrieving metadata for document: {id}");

        if (metadata == null)
        {
            var notFoundResponse = req.CreateResponse(HttpStatusCode.NotFound);
            await notFoundResponse.WriteAsJsonAsync(new { message = "Document not found" });
            return notFoundResponse;
        }

        var response = req.CreateResponse(HttpStatusCode.OK);
        await response.WriteAsJsonAsync(metadata);
        return response;
    }
}