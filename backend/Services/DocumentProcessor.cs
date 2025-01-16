using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Azure.AI.FormRecognizer;
using Azure.AI.FormRecognizer.Models;
using backend.Utils;
using Google.Protobuf;
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
        _logger.LogInformation($"Starting document processing for {fileName}");

        var metadata = new DocumentMetadata
        {
            id = Guid.NewGuid().ToString(),
            PartitionKey = "/id",
            FileName = fileName,
            ContentType = Path.GetExtension(fileName).ToLowerInvariant(),
            ProcessedDate = DateTime.UtcNow
        };

        try
        {
            if (!documentStream.CanRead)
            {
                throw new InvalidOperationException("Document stream is not readable");
            }

            _logger.LogInformation($"Stream position: {documentStream.Position}, Length: {documentStream.Length}");

            // Reset stream position
            if (documentStream.Position > 0)
            {
                documentStream.Position = 0;
            }

            // Try to analyze document type
            var documentType = await AnalyzeDocumentTypeAsync(documentStream, PathUtils.GetContentTypeFromExtension(Path.GetExtension(fileName).ToLowerInvariant()));
            metadata.DocumentType = documentType;

            // Reset stream position for content analysis
            documentStream.Position = 0;

            // Process based on document type
            switch (documentType)
            {
                case "Invoice":
                    await ProcessInvoiceAsync(documentStream, metadata);
                    break;
                case "Receipt":
                    await ProcessReceiptAsync(documentStream, metadata);
                    break;
                case "BusinessCard":
                    await ProcessBusinessCardAsync(documentStream, metadata);
                    break;
                default:
                    await ProcessGeneralDocumentAsync(documentStream, metadata);
                    break;
            }

            metadata.Status = "Processed";
            _logger.LogInformation($"Successfully processed {documentType} document: {fileName}");
        }
        catch (Exception ex)
        {
            metadata.Status = "Error";
            metadata.ExtractedMetadata.Add("Error", ex.Message);
            _logger.LogError(ex, $"Error processing document {fileName}. Error details: {ex.Message}");

            if (ex.InnerException != null)
            {
                _logger.LogError($"Inner Exception: {ex.InnerException.Message}");
                metadata.ExtractedMetadata.Add("InnerError", ex.InnerException.Message);
            }
            throw;
        }

        return metadata;
    }

    private async Task<string> AnalyzeDocumentTypeAsync(Stream documentStream, string contentType)
    {
        try
        {
            byte[] documentBytes = new byte[documentStream.Length];
            await documentStream.ReadAsync(documentBytes, 0, (int)documentStream.Length);

            using (var invoiceStream = new MemoryStream(documentBytes))
            {
                var invoiceOperation = await _formRecognizerClient.StartRecognizeInvoicesAsync(invoiceStream, new()
                {
                    ContentType = PathUtils.GetFormContentTyp(contentType)
                });
                var invoiceResult = await invoiceOperation.WaitForCompletionAsync();
                if (invoiceResult.Value.Count > 0 && invoiceResult.Value[0].Fields.Count > 0)
                {
                    return "Invoice";
                }
            }

            using (var receiptStream = new MemoryStream(documentBytes))
            {
                var receiptOperation = await _formRecognizerClient.StartRecognizeReceiptsAsync(receiptStream, new()
                {
                    ContentType = PathUtils.GetFormContentTyp(contentType)
                });
                var receiptResult = await receiptOperation.WaitForCompletionAsync();
                if (receiptResult.Value.Count > 0 && receiptResult.Value[0].Fields.Count > 0)
                {
                    return "Receipt";
                }
            }

            using (var businessStream = new MemoryStream(documentBytes))
            {
                // Try business card
                var businessCardOperation = await _formRecognizerClient.StartRecognizeBusinessCardsAsync(businessStream, new()
                {
                    ContentType = PathUtils.GetFormContentTyp(contentType)
                });
                var businessCardResult = await businessCardOperation.WaitForCompletionAsync();
                if (businessCardResult.Value.Count > 0 && businessCardResult.Value[0].Fields.Count > 0)
                {
                    return "BusinessCard";
                }
            }

            return "General";
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Error during document type analysis, defaulting to General type");
            return "General";
        }
    }

    private async Task ProcessInvoiceAsync(Stream documentStream, DocumentMetadata metadata)
    {
        var operation = await _formRecognizerClient.StartRecognizeInvoicesAsync(documentStream, new()
        {
            ContentType = PathUtils.GetFormContentTyp(PathUtils.GetContentTypeFromExtension(metadata.ContentType))
        });
        var result = await operation.WaitForCompletionAsync();

        foreach (var invoice in result.Value)
        {
            if (invoice.Fields.TryGetValue("InvoiceId", out var invoiceId))
                metadata.ExtractedMetadata.Add("InvoiceId", invoiceId.Value.ToString() ?? "");

            if (invoice.Fields.TryGetValue("InvoiceTotal", out var total))
                metadata.ExtractedMetadata.Add("Total", total.Value.ToString() ?? "");

            if (invoice.Fields.TryGetValue("InvoiceDate", out var date))
                metadata.ExtractedMetadata.Add("Date", date.Value.ToString() ?? "");

            // Add vendor information if available
            if (invoice.Fields.TryGetValue("VendorName", out var vendorName))
                metadata.ExtractedMetadata.Add("VendorName", vendorName.Value.ToString() ?? "");
        }
    }

    private async Task ProcessReceiptAsync(Stream documentStream, DocumentMetadata metadata)
    {
        var operation = await _formRecognizerClient.StartRecognizeReceiptsAsync(documentStream, new()
        {
            ContentType = PathUtils.GetFormContentTyp(PathUtils.GetContentTypeFromExtension(metadata.ContentType))
        });
        var result = await operation.WaitForCompletionAsync();

        foreach (var receipt in result.Value)
        {
            if (receipt.Fields.TryGetValue("MerchantName", out var merchantName))
                metadata.ExtractedMetadata.Add("MerchantName", merchantName.Value.ToString() ?? "");

            if (receipt.Fields.TryGetValue("Total", out var total))
                metadata.ExtractedMetadata.Add("Total", total.Value.ToString() ?? "");

            if (receipt.Fields.TryGetValue("TransactionDate", out var date))
                metadata.ExtractedMetadata.Add("Date", date.Value.ToString() ?? "");
        }
    }

    private async Task ProcessBusinessCardAsync(Stream documentStream, DocumentMetadata metadata)
    {
        var operation = await _formRecognizerClient.StartRecognizeBusinessCardsAsync(documentStream, new()
        {
            ContentType = PathUtils.GetFormContentTyp(PathUtils.GetContentTypeFromExtension(metadata.ContentType))
        });
        var result = await operation.WaitForCompletionAsync();

        foreach (var card in result.Value)
        {
            if (card.Fields.TryGetValue("ContactNames", out var names))
                metadata.ExtractedMetadata.Add("Name", names.Value.ToString() ?? "");

            if (card.Fields.TryGetValue("CompanyNames", out var companies))
                metadata.ExtractedMetadata.Add("Company", companies.Value.ToString() ?? "");

            if (card.Fields.TryGetValue("Emails", out var emails))
                metadata.ExtractedMetadata.Add("Email", emails.Value.ToString() ?? "");

            if (card.Fields.TryGetValue("PhoneNumbers", out var phones))
                metadata.ExtractedMetadata.Add("Phone", phones.Value.ToString() ?? "");
        }
    }

    private async Task ProcessGeneralDocumentAsync(Stream documentStream, DocumentMetadata metadata)
    {
        var operation = await _formRecognizerClient.StartRecognizeContentAsync(documentStream, new()
        {
            ContentType = PathUtils.GetFormContentTyp(PathUtils.GetContentTypeFromExtension(metadata.ContentType))
        });
        var result = await operation.WaitForCompletionAsync();

        foreach (var page in result.Value)
        {
            var pageText = string.Join(" ", page.Lines.Select(l => l.Text));
            _logger.LogInformation($"Processed page {page.PageNumber}: Found {page.Lines.Count} lines");
            metadata.ExtractedMetadata.Add($"Page{page.PageNumber}", pageText);
        }
    }
}