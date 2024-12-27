using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using PaperPulse.Functions.Models;

namespace PaperPulse.Functions;

public class ListDocuments
{
    private readonly ILogger<ListDocuments> _logger;

    public ListDocuments(ILogger<ListDocuments> logger)
    {
        _logger = logger;
    }

    [Function(nameof(ListDocuments))]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "get", Route = "documents")] HttpRequestData req,
        [CosmosDBInput("PaperPulse", "Metadata",
            Connection = "CosmosDBConnection",
            SqlQuery = "SELECT * FROM c ORDER BY c.ProcessedDate DESC")] IEnumerable<DocumentMetadata> documents)
    {
        _logger.LogInformation("Retrieving all documents");

        var response = req.CreateResponse(HttpStatusCode.OK);
        await response.WriteAsJsonAsync(documents);
        return response;
    }
}