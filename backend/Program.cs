using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Azure.AI.FormRecognizer;
using PaperPulse.Functions.Services;
using Azure;
using Microsoft.Extensions.Logging;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Configuration;

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
            var endpoint = Environment.GetEnvironmentVariable("FormRecognizerEndpoint")
                ?? throw new InvalidOperationException("FormRecognizerEndpoint is not configured in Key Vault");
            var key = Environment.GetEnvironmentVariable("FormRecognizerKey")
                ?? throw new InvalidOperationException("FormRecognizerKey is not configured in Key Vault");

            return new FormRecognizerClient(new Uri(endpoint), new AzureKeyCredential(key));
        });

        // Configure Cosmos DB client
        services.AddSingleton(sp =>
        {
            var connectionString = Environment.GetEnvironmentVariable("CosmosDBConnection")
                ?? throw new InvalidOperationException("CosmosDBConnection is not configured in Key Vault");

            var clientOptions = new CosmosClientOptions
            {
                ConnectionMode = ConnectionMode.Direct,
                SerializerOptions = new CosmosSerializationOptions
                {
                    PropertyNamingPolicy = CosmosPropertyNamingPolicy.CamelCase
                }
            };

            return new CosmosClient(connectionString, clientOptions);
        });

        // Register the document processor service
        services.AddSingleton<DocumentProcessor>();
    })
    .Build();

await host.RunAsync();