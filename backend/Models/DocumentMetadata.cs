using System;
using System.Collections.Generic;

namespace PaperPulse.Functions.Models;

public class DocumentMetadata
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string FileName { get; set; }
    public string ContentType { get; set; }
    public string DocumentType { get; set; } = "General";
    public string Status { get; set; } = "Pending";
    public DateTime ProcessedDate { get; set; } = DateTime.UtcNow;
    public Dictionary<string, string> ExtractedMetadata { get; set; } = new Dictionary<string, string>();
}