// Services/DocumentProcessor.cs
using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Azure.AI.FormRecognizer;
using Microsoft.Extensions.Logging;
using PaperPulse.Functions.Models;

namespace PaperPulse.Functions.Services;

public class DocumentProcessor
{
    private readonly FormRecognizerClient _formRecognizerClient;
    private readonly ILogger<DocumentProcessor> _logger;

    public DocumentProcessor(FormRecognizerClient formRecognizerClient, ILogger<DocumentProcessor> logger)
    {
        _formRecognizerClient = formRecognizerClient;
        _logger = logger;
    }

    public async Task<DocumentMetadata> ProcessDocumentAsync(Stream documentStream, string fileName)
    {
        var metadata = new DocumentMetadata
        {
            FileName = fileName,
            ContentType = Path.GetExtension(fileName).ToLowerInvariant()
        };

        try
        {
            _logger.LogInformation($"Starting document processing for {fileName}");
            
            var operation = await _formRecognizerClient.StartRecognizeContentAsync(documentStream);
            var result = await operation.WaitForCompletionAsync();

            foreach (var page in result.Value)
            {
                metadata.ExtractedMetadata.Add($"Page{page.PageNumber}", 
                    string.Join(" ", page.Lines.Select(l => l.Text)));
            }

            metadata.Status = "Processed";
            _logger.LogInformation($"Successfully processed document {fileName}");
        }
        catch (Exception ex)
        {
            metadata.Status = "Error";
            metadata.ExtractedMetadata.Add("Error", ex.Message);
            _logger.LogError(ex, $"Error processing document {fileName}");
        }

        return metadata;
    }
}