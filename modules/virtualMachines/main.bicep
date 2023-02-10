@description('The name of the Azure Virtual Machine.')
param name string

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Username for the Virtual Machine.')
param adminUsername string

@description('Type of authentication to use on the Virtual Machine. SSH key is recommended.')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string = 'password'

@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param adminPasswordOrKey string

@description('')
param subnetId string

@description('Optional. The Id of the Public IP Address.')
param publicIpId string = ''

param networkSecurityGroupId string = ''

@description('The size of the VM')
param vmSize string = 'Standard_B1ms'

param osDiskType string = 'Standard_LRS'

param customData string = ''

var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}

resource vm_nic 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: '${name}-vm-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: !empty(publicIpId) ? {
            id: publicIpId
          } : null
        }
      }
    ]
    networkSecurityGroup: !empty(networkSecurityGroupId) ? {
      id: networkSecurityGroupId
    } : null
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-focal'
        sku: '20_04-lts-gen2'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vm_nic.id
        }
      ]
    }
    osProfile: {
      computerName: name
      adminPassword: adminPasswordOrKey
      adminUsername: adminUsername
      linuxConfiguration: ((authenticationType == 'password') ? null : linuxConfiguration)
      customData: !empty(customData) ? customData : null // loadFileAsBase64('../../cloud-init-ado.yml')
    }
  }
}
