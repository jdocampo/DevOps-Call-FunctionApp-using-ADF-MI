# Tutorial: Authorize FunctionApp calls from Data Factory using Managed Identity

**Disclaimer**: For this tutorial to work, you should be **Owner of the Subscription** and you must have **Global Admin Role on the Directory** of the subscription, in order to create the Service Connection and provide it with the permission to create and modify applications. (Point 1.1)

The intent of this repository is to provide a how-to guide on the set-up of a DevOps Project that deploys and configures an Azure Solution, from which Azure Data Factory performs http calls to a function app using Managed Identity to authenticate and authorize those calls.

# Walkthrough
1.    Set-up an Azure DevOps project
2.    Import the repository
3.    Create and Execute the pipeline
4.    Execute Data Factory Pipeline

## 1. Create an Azure DevOps project

Enter https://dev.azure.com in your browser and log in with your Azure AD credentials. If prompted, Create a new Organization, or select an existing Organization if you're already part of one.
Then Create a new Project.

In order to connect our project with the Azure subscription, Navigate to Project settings > Service connections. 
Create a new service connection of type Azure Resource Manager (automatic). Select your subscription (you should its owner) and don't select any resource group. Name the connection ARMConnection and click Ok.
![NewServiceConnection](https://github.com/jdocampo/DevOps-Call-FunctionApp-using-ADF-MI/blob/master/images/NewServiceConnection.png)

When the service connection is created, click on its name, and on the overview pane, click on *Manage Service Principal* 
![ManageServiceConnection](https://github.com/jdocampo/DevOps-Call-FunctionApp-using-ADF-MI/blob/master/images/ManageServiceConnection.png)

### 1.1. Author the Service Connection Application
You should be granted the role of **Global Administrator** in the Directory to be able to perform this step. This is a requirement of the Graph API in order to assign applications to other applications, which means, authorizing Data Factory MI to call the Function App.

Go to the new App Registration if prompted on red, and from there, click on *API Permissions* on the left. Add *Application* type permissions of *Application.ReadWrite.All* for both Azure Active Directory Graph and Microsoft Graph, as we will need to create and configure the application that will provide the authentication and authorization for the function app.
![RequestAPIpermissionsAADG](https://github.com/jdocampo/DevOps-Call-FunctionApp-using-ADF-MI/blob/master/images/RequestAPIpermissionsAADG.png)
![RequestAPIpermissionsMG](https://github.com/jdocampo/DevOps-Call-FunctionApp-using-ADF-MI/blob/master/images/RequestAPIpermissionsMG.png)

Grant admin consent for both permissions. At the end, it should look like this (be aware of the green check under status).
![GrantAdminConsent02](https://github.com/jdocampo/DevOps-Call-FunctionApp-using-ADF-MI/blob/master/images/GrantAdminConsent02.png)

## 2.Import the repository
Return to the DevOps project.
Click on Repositories > Import (Under Import a Repository). Introduce the URL https://github.com/jdocampo/DevOps-Call-FunctionApp-using-ADF-MI.git and click *Import*

## 3.Create and Execute the pipeline
Go to Pipelines > Pipelines, click New Pipeline, select Azure Repos Git and select your repository. 
On the Configuration, click Existing Azure Pipelines YAML file, in the path select /azure-pipeline.yaml, and click continue.
The build pipeline definition file from source control will open. 
It contains a single script task that will perform the following:

1. Create and configure the service principal used by the function app to authenticate and authorize the requests
2. Create a deployment group that will:
   1. Deploy the Function App
      1. Configure its authentication/authorization with the previously created app
      2. Configure its content from [source control](https://github.com/jdocampo/node-function-app.git)(simple hello world node.js function app)
   2. Deploy the Data Factory
   3. Deploy the Data Factory contents (example pipeline)
3. Add AppRoleAssignment to the service principal so Data Factory is authorized.

![RenameFunctionApp](https://github.com/jdocampo/DevOps-Call-FunctionApp-using-ADF-MI/blob/master/images/RenameFunctionApp.png)

What you have to configure is the following:
* APP_NAME: Change it for the name of your own Function App (remember that it has to be unique)

Click Save and Run, commiting the changes to the master branch.

After less than 5 minutes, everything should be deployed successfully.

## 4.Execute Data Factory Pipeline

Go to the [Data Factory v2 portal](http://datafactoryv2.azure.com/), and select the Data Factory that was created, it should be named $(APP_NAME)-df.
Select Author > Pipelines > ExecuteFunctionApp. Click on Debug and it will execute the pipeline. See how the one that is configured with MSI executes correctly, but the one that isn't raises the error *"You do not have permission to view this directory or page"*.

### Note: Configuration of the Web Activity
In order to call the Function App, we use a Web Activity, with the following configuration:

* URL: url of the function App (you can get it from the Function App resource in Azure clicking the Get Function URL)
* Method and Body: Depends on the function you just created. Here we just use a POST Method with the key "name". Choose any value you prefer.
* Under *Advanced*: **MSI** as Authentication method, and under Resource, is the **Application ID URI** of the Application, which also matches the base url of the Function App. For example, if your function url is: https://<your-app-name>.azurewebsites.net/api/HttpTrigger the resource is  https://<your-app-name>.azurewebsites.net (beware of not ending the URL in slash (/), or the authentication will fail)


Congratulations, you have successfully completed the tutorial!