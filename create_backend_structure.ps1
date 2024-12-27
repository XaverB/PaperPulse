# Create backend directory
mkdir backend
cd backend

# Create Function App using dotnet CLI
dotnet new func -n PaperPulse.Functions
cd PaperPulse.Functions

# Install required packages
dotnet add package Azure.AI.FormRecognizer --version 4.1.0
dotnet add package Microsoft.Azure.Functions.Worker.Extensions.Storage --version 6.2.0
dotnet add package Microsoft.ApplicationInsights.WorkerService --version 2.21.0
dotnet add package Microsoft.Azure.Functions.Worker.ApplicationInsights --version 1.0.0