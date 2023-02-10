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

@secure()
param patToken string

var addressPrefix = '10.1.0.0/16'
var subnetAddressPrefix = '10.1.0.0/24'

// https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/v2-linux?view=azure-devops#unattended-config
var values = {
  adoOrganizationUrl: 'https://dev.azure.com/JeroenTrimbach'
  adoPatToken: patToken
  adoPoolName: 'selfhosted'
  adoAgentName: 'ubuntu'
  adoUser: adminUsername
}

var cloudInit = loadTextContent('cloud-init-ado-param.yml')

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
    customData: base64(format(cloudInit, values.adoOrganizationUrl, values.adoPatToken, values.adoPoolName, values.adoAgentName, values.adoUser))
  }
}

output sshCommand string = 'ssh ${adminUsername}@${publicIP.properties.dnsSettings.fqdn}'
