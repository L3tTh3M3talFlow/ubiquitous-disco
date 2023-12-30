<#
.SYNOPSIS
    Uploads files to a storage account.

.DESCRIPTION
    This script checks if storage account containers already exist with the provided client list ($clientList), creates any containers not present, and uploads files with 
    the latest version.

.PARAMETER StorageAccountName
    The Azure storage account. Value provided ADO pipeline variable group.

.PARAMETER SasToken
    The storage account token. Value provided ADO pipeline variable group.

.PARAMETER Environment
    The deployment environment. Value provided ADO pipeline variable group.

.EXAMPLE
    Upload-AllClientConfigs.ps1 -StorageAccountName $(StorageAccountName) -SasToken $(SasToken) -Environment $(Environment)

.INPUTS
    None.

.OUTPUTS
    None.

.LINK
    https://churchillsblog.com/post-tbd

.NOTES
    NAME: Upload-AllClientConfigs.ps1
    AUTHOR: Edward Bernard
    CREATED: 12/29/2023
    LAST EDIT: 
    VERSION: 1.0.0
#>

[CmdletBinding()]
param (
    $Environment,    
    $StorageAccountName,
    $SasToken
)

#region Return ADO variable group parameter values
Write-Host "Environment: $($Environment)"
Write-Host "StorageAccountName: $($StorageAccountName)"
#endregion Return ADO variable group parameter values

#region Install required software
Install-Module -Name Azure.Storage -AllowClobber -Force -Scope CurrentUser
Import-Module -Name Azure.Storage
Get-Module -Name Azure.Storage | Format-Table -Property Name,Version,ModuleType
#endregion Install required software

#region Get storage account context
Set-Item -Path Env:\SuppressAzureRmModulesRetiringWarning -Value $true
Write-Host "Checking storage context..."
$storageAccountContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -SasToken $SasToken

if (-not $storageAccountContext)
{
    Write-Host "Unable to retrieve storage account context."
}
else {
    Write-Host "Retrieved storage account context."
}
#endregion Get storage account context

#region Update when new clients are onboarded
# Source files
$sourceFileRootDirectory = "Configuration/$($Environment)"

$clientList = @('client-contoso-eu',
'client-contoso-us',
'client-contoso-gb')

# Client folders in repo
$folderList = Get-ChildItem $sourceFileRootDirectory -Directory
Write-Host "Repo folder list: $folderList"
#endregion Update when new clients are onboarded

#region Work section
foreach ($folder in $folderList)
{
    # Compare $clientList against $folderList in repo (Configuration/<Env>/*) 
    if ($clientList -contains $folder)
    {
        Write-Host "`nChecking for storage container: $folder"
        $container = Get-AzureStorageContainer -Context $storageAccountContext | Where-Object { $_.Name -eq $folder }
        if (-not $container)
        {
            Write-Host "$folder does not exist - creating..."
            New-AzureStorageContainer -Name $folder -Context $storageAccountContext -Permission Off
        }
        else {
            Write-Host "`tContainer is already present."
        }        
        
        $path = $sourceFileRootDirectory + "/" + $folder
        $path = Resolve-Path -Path $path

        # Upload data from folder list in repo to blob storage        
        Write-Host "*** Start container upload: $folder ***"
        Get-ChildItem -File -Recurse $path | ForEach-Object {
            Set-AzureStorageBlobContent -Container $folder -File $_.FullName -Context $storageAccountContext `
            -Blob $_.FullName.Substring($path.Path.Length + 1) -Confirm:$false -Force
        }
        Write-Host "*** End container upload: $folder ***"
    }
}
#endregion Work section
