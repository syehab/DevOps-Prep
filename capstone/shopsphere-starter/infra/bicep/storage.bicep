// Optional group-scope module. Use this after the resource group exists.
// Standard_LRS + TLS 1.2. Estimated cost if created: USD 0.05-0.40 per session.

targetScope = 'resourceGroup'

@description('Storage account name, 3-24 lowercase letters and numbers')
param name string

@description('Azure region')
param location string = resourceGroup().location

resource st 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
  tags: {
    project: 'shopsphere'
    purpose: 'lab'
  }
}

output id string = st.id
output name string = st.name
