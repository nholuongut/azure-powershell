﻿# ----------------------------------------------------------------------------------
#
# Copyright Microsoft Corporation
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ----------------------------------------------------------------------------------

<#
.SYNOPSIS
Tests creating new simple resource group.
#>
function Test-CreatesNewSimpleResourceGroup
{
    # Setup
    $rgname = Get-ResourceGroupName
    $location = Get-ProviderLocation ResourceManagement

    try 
    {
        # Test
        $actual = New-AzureRmResourceGroup -Name $rgname -Location $location -Tags @{Name = "testtag"; Value = "testval"} 
        $expected = Get-AzureRmResourceGroup -Name $rgname

        # Assert
        Assert-AreEqual $expected.ResourceGroupName $actual.ResourceGroupName	
        Assert-AreEqual $expected.Tags[0]["Name"] $actual.Tags[0]["Name"]
    }
    finally
    {
        # Cleanup
        Clean-ResourceGroup $rgname
    }
}

<#
.SYNOPSIS
Tests updates existing resource group.
#>
function Test-UpdatesExistingResourceGroup
{
    # Setup
    $rgname = Get-ResourceGroupName
    $location = Get-ProviderLocation ResourceManagement

    try 
    {
        # Test update without tag
        Assert-Throws { Set-AzureRmResourceGroup -Name $rgname -Tags @{"testtag" = "testval"} } "ResourceGroupNotFound: Resource group '$rgname' could not be found."
        
        $new = New-AzureRmResourceGroup -Name $rgname -Location $location
        
        # Test update with bad tag format
        Assert-Throws { Set-AzureRmResourceGroup -Name $rgname -Tags @{"testtag" = "testval"} } "Invalid tag format. Expect @{Name = `"tagName`"} or @{Name = `"tagName`"; Value = `"tagValue`"}"
        # Test update with bad tag format
        Assert-Throws { Set-AzureRmResourceGroup -Name $rgname -Tags @{Name = "testtag"; Value = "testval"}, @{Name = "testtag"; Value = "testval2"} } "Invalid tag format. Ensure that each tag has a unique name. Example: @{Name = `"tagName1`"; Value = `"tagValue1`"}, @{Name = `"tagName2`"; Value = `"tagValue2`"}"
            
        $actual = Set-AzureRmResourceGroup -Name $rgname -Tags @{Name = "testtag"; Value = "testval"} 
        $expected = Get-AzureRmResourceGroup -Name $rgname

        # Assert
        Assert-AreEqual $expected.ResourceGroupName $actual.ResourceGroupName	
        Assert-AreEqual 0 $new.Tags.Count
        Assert-AreEqual $expected.Tags[0]["Name"] $actual.Tags[0]["Name"]
    }
    finally
    {
        # Cleanup
        Clean-ResourceGroup $rgname
    }
}

<#
.SYNOPSIS
Tests creating new simple resource group and deleting it via piping.
#>
function Test-CreatesAndRemoveResourceGroupViaPiping
{
    # Setup
    $rgname1 = Get-ResourceGroupName
    $rgname2 = Get-ResourceGroupName
    $location = Get-ProviderLocation ResourceManagement

    # Test
    New-AzureRmResourceGroup -Name $rgname1 -Location $location
    New-AzureRmResourceGroup -Name $rgname2 -Location $location

    Get-AzureRmResourceGroup | where {$_.ResourceGroupName -eq $rgname1 -or $_.ResourceGroupName -eq $rgname2} | Remove-AzureRmResourceGroup -Force

    # Assert
    Assert-Throws { Get-AzureRmResourceGroup -Name $rgname1 } "Provided resource group does not exist."
    Assert-Throws { Get-AzureRmResourceGroup -Name $rgname2 } "Provided resource group does not exist."
}

<#
.SYNOPSIS
Tests getting non-existing resource group.
#>
function Test-GetNonExistingResourceGroup
{
    # Setup
    $rgname = Get-ResourceGroupName

    Assert-Throws { Get-AzureRmResourceGroup -Name $rgname } "Provided resource group does not exist."
}

<#
.SYNOPSIS
Negative test. New resource group in non-existing location throws error.
#>
function Test-NewResourceGroupInNonExistingLocation
{
    # Setup
    $rgname = Get-ResourceGroupName

    Assert-Throws { New-AzureRmResourceGroup -Name $rgname -Location 'non-existing' }
}

<#
.SYNOPSIS
Negative test. New resource group in non-existing location throws error.
#>
function Test-RemoveNonExistingResourceGroup
{
    # Setup
    $rgname = Get-ResourceGroupName

    Assert-Throws { Remove-AzureRmResourceGroup -Name $rgname -Force } "Provided resource group does not exist."
}

<#
.SYNOPSIS
Negative test. New resource group in non-existing location throws error.
#>
function Test-AzureTagsEndToEnd
{
    # Setup
    $tag1 = getAssetName
    $tag2 = getAssetName
    Clean-Tags

    # Create tag without values
    New-AzureRmTag $tag1

    $tag = Get-AzureRmTag $tag1
    Assert-AreEqual $tag1 $tag.Name

    # Add value to the tag (adding same value should pass)
    New-AzureRmTag $tag1 value1
    New-AzureRmTag $tag1 value1
    New-AzureRmTag $tag1 value2

    $tag = Get-AzureRmTag $tag1
    Assert-AreEqual 2 $tag.Values.Count

    # Create tag with values
    New-AzureRmTag $tag2 value1
    New-AzureRmTag $tag2 value2
    New-AzureRmTag $tag2 value3

    $tags = Get-AzureRmTag
    Assert-AreEqual 2 $tags.Count

    # Remove entire tag
    $tag = Remove-AzureRmTag $tag1 -Force -PassThru

    $tags = Get-AzureRmTag
    Assert-AreEqual $tag1 $tag.Name

    # Remove tag value
    $tag = Remove-AzureRmTag $tag2 value1 -Force -PassThru

    $tags = Get-AzureRmTag
    Assert-AreEqual 0 $tags.Count

    # Get a non-existing tag
    Assert-Throws { Get-AzureRmTag "non-existing" }

    Clean-Tags
}

<#
.SYNOPSIS
Tests registration of required template provider
#>
function Test-NewDeploymentAndProviderRegistration
{
    # Setup
    $rgname = Get-ResourceGroupName
    $rname = Get-ResourceName
    $location = Get-ProviderLocation ResourceManagement
    $template = "Microsoft.Cache.0.4.0-preview"
    $provider = "microsoft.cache"

    try 
    {
        # Unregistering microsoft.cache to have clean state
        $subscription = [Microsoft.WindowsAzure.Commands.Utilities.Common.AzureProfile]::Instance.CurrentSubscription
        $client = New-Object Microsoft.Azure.Commands.Resources.Models.ResourcesClient $subscription
         
        # Verify provider is registered
        $providers = [Microsoft.WindowsAzure.Commands.Utilities.Common.AzureProfile]::Instance.CurrentSubscription.RegisteredResourceProvidersList
        if( $providers -Contains $provider )
        {
            $client.UnregisterProvider($provider) 
        }

        # Test
        $deployment = New-AzureRmResourceGroup -Name $rgname -Location $location -GalleryTemplateIdentity $template -cacheName $rname -cacheLocation $location

        # Assert
        $client = New-Object Microsoft.Azure.Commands.Resources.Models.ResourcesClient $subscription
        $providers = [Microsoft.WindowsAzure.Commands.Utilities.Common.AzureProfile]::Instance.CurrentSubscription.RegisteredResourceProvidersList
        
        Assert-True { $providers -Contains $provider }

    }
    finally
    {
        # Cleanup
        Clean-ResourceGroup $rgname
    }
}

<#
.SYNOPSIS
Tests deployment delete is successful
#>
function Test-RemoveDeployment
{
    # Setup
    $deploymentName = "Test"
    $templateUri = "https://gallery.azure.com/artifact/20140901/Microsoft.ResourceGroup.1.0.0/DeploymentTemplates/Template.json"
    $rgName = "TestSDK0123"

    try
    {
        # Test
        New-AzureRmResourceGroup -Name $rgName -Location "East US"
        $deployment = New-AzureRmResourceGroupDeployment -ResourceGroupName $rgName -Name $deploymentName -TemplateUri $templateUri
        Assert-True { Remove-AzureRmResourceGroupDeployment -ResourceGroupName $deployment.ResourceGroupName -Name $deployment.DeploymentName -Force }
    }
    finally
    {
        # Cleanup
        Clean-ResourceGroup $rgName
    }
}

<#
.SYNOPSIS
Tests find resource group command
#>
function Test-FindResourceGroup
{
    # Setup
    $rgname = Get-ResourceGroupName
	$rgname2 = Get-ResourceGroupName
    $location = Get-ProviderLocation ResourceManagement
	$originalResorcrGroups = Find-AzureRmResourceGroup
	$originalCount = @($originalResorcrGroups).Count 

    try
    {
        # Test
        $actual = New-AzureRmResourceGroup -Name $rgname -Location $location -Tag @{ Name = "testtag"; Value = "testval" }
        $actual2 = New-AzureRmResourceGroup -Name $rgname2 -Location $location -Tag @{ Name = "testtag"; Value = "testval2" }

        $expected1 = Get-AzureRmResourceGroup -Name $rgname
        # Assert
        Assert-AreEqual $expected1.ResourceGroupName $actual.ResourceGroupName
        Assert-AreEqual $expected1.Tags[0]["Name"] $actual.Tags[0]["Name"]

		$expected2 = Get-AzureRmResourceGroup -Name $rgname2
        # Assert
        Assert-AreEqual $expected2.ResourceGroupName $actual2.ResourceGroupName
        Assert-AreEqual $expected2.Tags[0]["Name"] $actual2.Tags[0]["Name"]

		$expected3 = Find-AzureRmResourceGroup
		$expectedCount = $originalCount + 2
		# Assert
		Assert-AreEqual @($expected3).Count $expectedCount

		$expected4 = Find-AzureRmResourceGroup -Tag @{ Name = "testtag";}
        # Assert
        Assert-AreEqual @($expected4).Count 2

		$expected5 = Find-AzureRmResourceGroup -Tag @{ Name = "testtag"; Value = "testval" }
        # Assert
        Assert-AreEqual @($expected5).Count 1

		$expected6 = Find-AzureRmResourceGroup -Tag @{ Name = "testtag2"}
        # Assert
        Assert-AreEqual @($expected6).Count 0
    }
    finally
    {
        # Cleanup
        Clean-ResourceGroup $rgname
        Clean-ResourceGroup $rgname2
    }
}

<#
.SYNOPSIS
Tests remove non exist resource group and debug stream gets printed
#>
function Test-GetNonExistingResourceGroupWithDebugStream
{
    $ErrorActionPreference="Continue"
    $output = $(Get-AzureRmResourceGroup -Name "InvalidNonExistRocks" -Debug) 2>&1 5>&1 | Out-String
    $ErrorActionPreference="Stop"
    Assert-True { $output -Like "*============================ HTTP RESPONSE ============================*" }
}

<#
.SYNOPSIS
Tests export resource group template file.
#>
function Test-ExportResourceGroup
{
	# Setup
	$rgname = Get-ResourceGroupName
	$rname = Get-ResourceName
	$rglocation = Get-ProviderLocation ResourceManagement
	$apiversion = "2014-04-01"
	$resourceType = "Providers.Test/statefulResources"

	
	try
	{
		# Test
		New-AzureRmResourceGroup -Name $rgname -Location $rglocation
		$r = New-AzureRmResource -Name $rname -Location "centralus" -Tags @{Name = "testtag"; Value = "testval"} -ResourceGroupName $rgname -ResourceType $resourceType -PropertyObject @{"administratorLogin" = "adminuser"; "administratorLoginPassword" = "P@ssword1"} -SkuObject @{ Name = "A0" } -ApiVersion $apiversion -Force
		Assert-AreEqual $r.ResourceGroupName $rgname

		$exportOutput = Export-AzureRmResourceGroup -ResourceGroupName $rgname -Force
		Assert-NotNull $exportOutput
		Assert-True { $exportOutput.Path.Contains($rgname + ".json") }
	}
	
	finally
    {
        # Cleanup
        Clean-ResourceGroup $rgname
    }
}