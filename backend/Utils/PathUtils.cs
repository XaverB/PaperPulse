using Azure.AI.FormRecognizer;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace backend.Utils
{
    internal class PathUtils
    {
        internal static string GetContentTypeFromExtension(string extension) => 
            extension.ToLowerInvariant() switch
            {
                ".pdf" => "application/pdf",
                ".doc" => "application/msword",
                ".docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                ".txt" => "text/plain",
                _ => "application/octet-stream"
            };

        internal static FormContentType GetFormContentTyp(string contentType) =>
            contentType switch
            {
                "application/pdf" => FormContentType.Pdf,
                _ => FormContentType.Json
            };
    }
}
