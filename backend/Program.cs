using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Azure.AI.FormRecognizer;
using PaperPulse.Functions.Services;
using Azure;
using Microsoft.Extensions.Logging;
using Microsoft.Azure.Functions.Worker;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults(workerApplication =>
    {
        workerApplication.UseFunctionExecutionMiddleware();
    })
    .ConfigureServices((context, services) =>
    {
        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();
        
        // Configure Form Recognizer client
        services.AddSingleton(sp =>
        {
            var endpoint = Environment.GetEnvironmentVariable("FormRecognizerEndpoint");
            var credential = new AzureKeyCredential(
                Environment.GetEnvironmentVariable("FormRecognizerKey")!);
            return new FormRecognizerClient(new Uri(endpoint!), credential);
        });

        // Register the document processor service
        services.AddSingleton<DocumentProcessor>();
    })
    .Build();

await host.RunAsync();