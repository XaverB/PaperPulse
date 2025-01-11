# Set your variables
$ENV_NAME="dev2"
$LOCATION="eastus2"

# Deploy the bicep template
az deployment sub create `
    --name "doc-processor-deployment" `
    --location $LOCATION `
    --template-file ./main.bicep `
    --parameters environmentName=$ENV_NAME location=$LOCATION