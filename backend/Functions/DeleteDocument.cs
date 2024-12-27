using System.Configuration;
using System.Net;
using Azure.Storage.Blobs;
using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using PaperPulse.Functions.Models;

namespace PaperPulse.Functions;

public class DeleteDocument
{
    private readonly CosmosClient _cosmosClient;
    private readonly ILogger<DeleteDocument> _logger;

    public DeleteDocument(CosmosClient cosmosClient, ILogger<DeleteDocument> logger)
    {
        _cosmosClient = cosmosClient;
        _logger = logger;
    }

    [Function(nameof(DeleteDocument))]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "delete", Route = "documents/{id}")] HttpRequestData req,
        [CosmosDBInput(
            databaseName: "PaperPulse",
            "Metadata",
            Connection = "CosmosDBConnection",
            Id = "{id}",
            PartitionKey = "{id}")] DocumentMetadata metadata,
        [BlobInput("documents/{id}", Connection = "AzureWebJobsStorage")] BlobClient blobClient,
        string id)
    {
        _logger.LogInformation($"Request to delete document: {id}");

        if (metadata == null)
        {
            var notFoundResponse = req.CreateResponse(HttpStatusCode.NotFound);
            await notFoundResponse.WriteAsJsonAsync(new { message = "Document not found" });
            return notFoundResponse;
        }

        try
        {
            // Delete from Cosmos DB using the client
            var container = _cosmosClient.GetContainer("PaperPulse", "Metadata");
            await container.DeleteItemAsync<DocumentMetadata>(id, new PartitionKey(id));

            // Delete from Blob Storage
            if (await blobClient.ExistsAsync())
            {
                await blobClient.DeleteAsync();
            }

            var response = req.CreateResponse(HttpStatusCode.OK);
            await response.WriteAsJsonAsync(new { message = "Document deleted successfully" });
            return response;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error deleting document: {id}");
            var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
            await errorResponse.WriteAsJsonAsync(new { message = "Error deleting document" });
            return errorResponse;
        }
    }
}