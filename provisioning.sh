#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

# Read Tenant ID and Subscription ID from current subscription
read TENANT_ID SUBSCRIPTION_ID <<< $(az account show --query '{tenantId:tenantId,id:id}' -o tsv)


APP=`az ad app create --display-name $APP_NAME --identifier-uris https://$APP_NAME.azurewebsites.net \
    --app-roles @function-app-application/appRoles.json \
    --required-resource-accesses @function-app-application/requiredResourceAccesses.json \
    --reply-urls https://$APP_NAME.azurewebsites.net/.auth/login/aad/callback`


CLIENT_ID=`echo $APP | jq -r '.appId'`
CLIENT_SECRET=`az ad app credential reset --id $CLIENT_ID --append | jq -r '.password'`
APP_OID=`echo $APP | jq -r '.objectId'`
APP_ROLEASSIGMENT_ID=`echo $APP | jq -r '.appRoles[0].id'`

SP=`az ad sp create --id $CLIENT_ID`
SP_OID=`echo $SP | jq -r '.objectId'`
az ad sp update --id $SP_OID --set appRoleAssignmentRequired=true

RESOURCE_GROUP=$APP_NAME"-rg" 
az group create --location centralus --name $RESOURCE_GROUP
DEPLOYMENT_GROUP=`az deployment group create -g $RESOURCE_GROUP --template-file azuredeploy.json --parameters appName=$APP_NAME tenant-guid=$TENANT_ID client-id=$CLIENT_ID client-secret=$CLIENT_SECRET`
DEPLOYMENT_GROUP_NAME=`echo $DEPLOYMENT_GROUP | jq  -r '.name'`
ADF_SP_OID=`az deployment group show -n $DEPLOYMENT_GROUP_NAME -g $RESOURCE_GROUP | jq  -r '.properties.outputs.dataFactoryIdentityPrincipalId.value'`

# Get an AAD authentication token for ARM
# NB: $servicePrincipalId and $servicePrincipalKey passed as env vars
curl="curl --silent --show-error --fail"
armToken=`$curl -X POST \
	--data-urlencode "grant_type=client_credentials" \
	--data-urlencode "client_id=$servicePrincipalId" \
	--data-urlencode "client_secret=$servicePrincipalKey" \
	--data-urlencode "scope=https://graph.microsoft.com/.default" \
	"https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
| jq -r '.token_type + " " + .access_token'`

dataRAW='{
    "appRoleId": "'$APP_ROLEASSIGMENT_ID'",
    "principalId": "'$ADF_SP_OID'",
    "principalType": "ServicePrincipal",
    "resourceId": "'$SP_OID'"
}'
# Add the ADF MI to the Application (providing authorization to the function app)
curl -X POST "https://graph.microsoft.com/beta/servicePrincipals/$SP_OID/appRoleAssignedTo" \
--header 'Content-Type: application/json' \
--header "Authorization: $armToken" \
--data-raw "$dataRAW"

# Alternative PS Cmdlet 
#New-AzureADServiceAppRoleAssignment -ObjectId $ADF_SP_OID -PrincipalId $ADF_SP_OID -Id $APP_ROLEASSIGMENT_ID -ResourceId $SP_OID

# Set job variable from script, to be used by other scripts in the pipeline if needed
echo "##vso[task.setvariable variable=TENANT_ID]$TENANT_ID"
echo "##vso[task.setvariable variable=SUBSCRIPTION_ID]$SUBSCRIPTION_ID"
echo "##vso[task.setvariable variable=APP_SP_OID]$SP_OID"
echo "##vso[task.setvariable variable=APP_ROLEASSIGMENT_ID]$APP_ROLEASSIGMENT_ID"
echo "##vso[task.setvariable variable=ADF_SP_OID]$ADF_SP_OID"