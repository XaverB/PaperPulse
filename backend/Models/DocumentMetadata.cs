// Models/DocumentMetadata.cs
using System;
using System.Collections.Generic;

namespace PaperPulse.Functions.Models;

public class DocumentMetadata
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string FileName { get; set; } = string.Empty;
    public string ContentType { get; set; } = string.Empty;
    public DateTime ProcessedDate { get; set; } = DateTime.UtcNow;
    public string Status { get; set; } = string.Empty;
    public Dictionary<string, string> ExtractedMetadata { get; set; } = new();
    public Dictionary<string, float> Confidence { get; set; } = new();
}