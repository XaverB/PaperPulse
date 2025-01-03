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
    [CosmosDBOutput(databaseName: "PaperPulse", containerName: "Metadata",
        Connection = "CosmosDBConnection",
        CreateIfNotExists = true)]
    public async Task<DocumentMetadata> Run(
        [BlobTrigger("documents/{name}", Connection = "AzureWebJobsStorage")] Stream document,
        string name)
    {
        _logger.LogInformation($"Processing document: {name}");

        try
        {
            // Log document stream details
            _logger.LogInformation($"Document stream length: {document.Length}, Position: {document.Position}, CanRead: {document.CanRead}");

            // Reset stream position if needed
            if (document.Position > 0)
            {
                document.Position = 0;
            }

            // Add additional logging before processing
            _logger.LogInformation($"Starting document processing with DocumentProcessor for {name}");

            var metadata = await _documentProcessor.ProcessDocumentAsync(document, name);

            // Log successful processing details
            _logger.LogInformation($"Document processed successfully: {name}. Status: {metadata.Status}");

            return metadata;
        }
        catch (Exception ex)
        {
            // Enhanced error logging
            _logger.LogError(ex, $"Error processing document: {name}. Error Type: {ex.GetType().Name}. Message: {ex.Message}");

            if (ex.InnerException != null)
            {
                _logger.LogError($"Inner Exception: {ex.InnerException.Message}");
            }

            throw; // Rethrow to maintain the original behavior
        }
    }
}