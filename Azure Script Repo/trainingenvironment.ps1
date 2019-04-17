# Training environment setup
# Needed to grant a large number of users access to my account for training and I didn't want to do so without limiting their acess.
# This creates Azure AD users, creates a resource group, limits those users to that resource group, creates a VM size limit for that group

Connect-AzAccount
Connect-AzureAD

#Variables
$location = "eastus2"
$RGName = "ABC-training-resource-group"
$client = "ABC"
$classSize = 18
$domain = "ABC"

#Set Subscription ID
$subscriptionId = (Get-AzSubscription).Id
$subScope = "/subscriptions/$subscriptionId"

#Create Resource Group
New-AzResourceGroup -Name "$RGName" -Location $location
$rg = Get-AzResourceGroup -Name $RGName

for($count=1; $count -le $classSize; $count++)
{
    $PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
    $PasswordProfile.Password = "Password$Count"

    $Name = "$client$count@$domain.onmicrosoft.com"

    New-AzureADUser -DisplayName "$client Training User $Count" -PasswordProfile $PasswordProfile -UserPrincipalName $Name -MailNickName "$client$count" -AccountEnabled $true

#Use if trying to assign access to the entire subscription
#   New-AzRoleAssignment -SignInName $Name `
#        -RoleDefinitionName "Reader" `
#        -Scope $subScope

#Assign access to the RG
    New-AzRoleAssignment -SignInName $Name `
        -RoleDefinitionName "Contributor" `
        -ResourceGroupName $RGName
}

#Create a policy to limit VM sizes
$definition = New-AzPolicyDefinition -Name 'RestrictVMSizes' -Description 'Policy to restrict VM sizes to predefined SKUs' -Policy '{
  "if": {
    "allOf": [
        {
        "field": "type",
        "equals": "Microsoft.Compute/virtualMachines"
        },
        {
        "not":
            {
            "field": "Microsoft.Compute/virtualMachines/sku.name",
            "in": ["Standard_B1s","Standard_B1ms","Standard_D1_v2","Standard_DS1","Standard_DS1"]
            }       
        }
    ]
  },
  "then":
    {
    "effect": "deny"
    }
}'

# Assign the policy to the resource group
New-AzPolicyAssignment -Name 'restrict-vm-size' -DisplayName 'restrict VM size' -Scope $rg.ResourceId -PolicyDefinition $definition
