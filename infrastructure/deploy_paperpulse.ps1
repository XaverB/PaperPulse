# Login to Azure
az login

# Set variables
$ENV_NAME="dev"
$LOCATION="euwest"

# Deploy the infrastructure
az deployment sub create \
  --name "doc-processor-deployment" \
  --location $LOCATION \
  --template-file main.bicep \
  --parameters environmentName=$ENV_NAME location=$LOCATION