// Functions/ProcessDocument.cs
using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using PaperPulse.Functions.Models;
using PaperPulse.Functions.Services;

namespace PaperPulse.Functions;

public class ProcessDocument
{
    private readonly DocumentProcessor _documentProcessor;
    private readonly ILogger<ProcessDocument> _logger;

    public ProcessDocument(DocumentProcessor documentProcessor, ILogger<ProcessDocument> logger)
    {
        _documentProcessor = documentProcessor;
        _logger = logger;
    }

    [Function(nameof(ProcessDocument))]
    [CosmosDBOutput("PaperPulse", "Metadata",
        Connection = "CosmosDBConnection",
        CreateIfNotExists = true)]
    public async Task<DocumentMetadata> Run(
        [BlobTrigger("documents/{name}", Connection = "AzureWebJobsStorage")] Stream document,
        string name)
    {
        _logger.LogInformation($"Processing document: {name}");

        try
        {
            var metadata = await _documentProcessor.ProcessDocumentAsync(document, name);
            _logger.LogInformation($"Document processed successfully: {name}");
            return metadata;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error processing document: {name}");
            throw;
        }
    }
}