// Day 8: one Bicep module. Run `az bicep build` locally.
// On Azure, run `az deployment sub what-if`. That preview does not create the group.
// `az deployment sub create` does create it and can bill nested resources later.

targetScope = 'subscription'

@description('Name of the ShopSphere lab resource group')
param name string

@description('Azure region, for example eastus')
param location string

@description('Cost owner tag')
param owner string = 'shopsphere-lab'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: name
  location: location
  tags: {
    project: 'shopsphere'
    owner: owner
    purpose: 'lab'
  }
}

output resourceGroupName string = rg.name
