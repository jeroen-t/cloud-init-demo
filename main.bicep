@description('The name of you Virtual Machine.')
param vmName string = 'UbuntuVM'

@description('Username for the Virtual Machine.')
param adminUsername string

@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param adminPasswordOrKey string

@description('Location for all resources.')
param location string = 'southcentralus'

@description('Unique DNS Name for the Public IP used to access the Virtual Machine.')
param dnsLabelPrefix string = toLower('${vmName}-${uniqueString(resourceGroup().id)}')

var addressPrefix = '10.1.0.0/16'
var subnetAddressPrefix = '10.1.0.0/24'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: 'virtualnetwork-01'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'subnet-01'
        properties: {
          addressPrefix: subnetAddressPrefix
        }
      }
    ]
  }
}

resource publicIP 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'publicIP'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
    idleTimeoutInMinutes: 4
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

module virtualMachine 'modules/virtualMachines/main.bicep' = {
  name: 'deploy-virtualMachine'
  params: {
    location: location
    adminPasswordOrKey: adminPasswordOrKey
    adminUsername: adminUsername
    name: vmName
    subnetId: resourceId('Microsoft.Network/VirtualNetworks/subnets', 'virtualnetwork-01', 'subnet-01')
    publicIpId: publicIP.id
    networkSecurityGroupId: nsg.id
    authenticationType: 'sshPublicKey'
  }
}

output sshCommand string = 'ssh ${adminUsername}@${publicIP.properties.dnsSettings.fqdn}'
