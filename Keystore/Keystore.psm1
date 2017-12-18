function Read-StoredKeyList{
    [CmdletBinding()]
    Param()
    Get-Item HKCU:\Software\Microsoft\Windows\PowerShell\Keys -ErrorAction SilentlyContinue | % { $_.GetValueNames() }
}

function Get-StoredKey {
    [CmdletBinding()]
    Param()
    DynamicParam {
        
        $settings = @(
            ($true | select @{
                    N="Name"
                    E={"KeyName"}
                },@{
                    N="SetScript"
                    E={
                        {
                            Read-StoredKeyList
                        }
                    }
                }
            )
        )

        $paramDictionary = New-Object -Type System.Management.Automation.RuntimeDefinedParameterDictionary

        $count = ($PSBoundParameters | measure).Count - 1
        $settings | %{
            $count++
            $attributes = New-Object System.Management.Automation.ParameterAttribute -Property @{ParameterSetName = "__AllParameterSets";Mandatory = $true;Position = $count;ValueFromPipeline = $true;ValueFromPipelineByPropertyName = $true}

            $attributeCollection = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
            $attributeCollection.Add($attributes)

            $ValidateSet = New-Object System.Management.Automation.ValidateSetAttribute($(& $_.SetScript))
            $attributeCollection.Add($ValidateSet)

            $ThisParam = New-Object -Type System.Management.Automation.RuntimeDefinedParameter($_.Name, [string], $attributeCollection)

            $paramDictionary.Add($_.Name, $ThisParam)
        }

        return $paramDictionary 
    }

    begin {
        $settings | %{
            New-Variable -Name $_.Name -Value $PSBoundParameters[$_.Name]
        }
    }
    process{
        if ($_){
            [System.Management.Automation.PSSerializer]::DeSerialize((Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\PowerShell\Keys" -Name $_.KeyName))
        } else {
            [System.Management.Automation.PSSerializer]::DeSerialize((Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\PowerShell\Keys" -Name $KeyName))
        }
    }
    end {}
}

function Initialize-StoredKey {
    Param(
    
		[Parameter(Position=0,
			Mandatory=$True,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$true)]
			[string]$KeyName,
        [Parameter(Position=1,
			Mandatory=$false)]
			[securestring]$Key=(Read-Host -AsSecureString -Prompt "Key:"),
		[Parameter(Position=2,
			Mandatory=$false,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$true)]
			[switch]$Force
    )
    DynamicParam {}

    begin {
        $RegPath = @('HKCU:','Software','Microsoft','Windows','PowerShell','Keys')

        0..($RegPath.Length-1) | %{
            $ThisLevel = (-join(($RegPath[0..$_] -join "\"),"\"))
            if (-not (Test-Path $ThisLevel)){
                Write-Verbose "Creating $ThisLevel"
                New-Item $ThisLevel -ItemType Directory | Out-Null
            }
        }
    }
    process{
        $PathQuery = @{
            Path = ($RegPath -join "\")
            Name = $KeyName
            Value = ([System.Management.Automation.PSSerializer]::Serialize($Key))
        }

        if ($KeyName -notin (Read-StoredKeyList) -or $Force){
            if (-not($Key)){
                $Key = (Read-Host -AsSecureString -Prompt "Key:")
            }
            if($Force) {
                Set-ItemProperty @PathQuery | Out-Null
            } else {
                $PathQuery.PropertyType = "String"
                New-ItemProperty @PathQuery | Out-Null
                
            }
        } else {
            @("Value","PropertyType") | %{
                $PathQuery.Remove($_)
            }
            
            $Exception = @{
                Message = (-join("A key with the name ",$KeyName," already exists."))
                RecommendedAction = "Choose another name or use the -Force flag to overwrite."
                Category = "WriteError"
                CategoryTargetName = (@($PathQuery.Path,$PathQuery.Name) -join " - ")
                CategoryTargetType = "RegistryKey Property"
                TargetObject = Get-ItemPropertyValue @PathQuery
            }
            Write-Error @Exception
        }
    }
    end {}
}

function Remove-StoredKey {
    [CmdletBinding(
        SupportsShouldProcess=$True
    )]
    Param()
    DynamicParam {
        
        $settings = @(
            ($true | select @{
                    N="Name"
                    E={"KeyName"}
                },@{
                    N="SetScript"
                    E={
                        {
                            Read-StoredKeyList
                        }
                    }
                }
            )
        )

        $paramDictionary = New-Object -Type System.Management.Automation.RuntimeDefinedParameterDictionary

        $count = ($PSBoundParameters | measure).Count - 1
        $settings | %{
            $count++
            $attributes = New-Object System.Management.Automation.ParameterAttribute -Property @{ParameterSetName = "__AllParameterSets";Mandatory = $true;Position = $count;ValueFromPipeline = $true;ValueFromPipelineByPropertyName = $true}

            $attributeCollection = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
            $attributeCollection.Add($attributes)

            $ValidateSet = New-Object System.Management.Automation.ValidateSetAttribute($(& $_.SetScript))
            $attributeCollection.Add($ValidateSet)

            $ThisParam = New-Object -Type System.Management.Automation.RuntimeDefinedParameter($_.Name, [string[]], $attributeCollection)

            $paramDictionary.Add($_.Name, $ThisParam)
        }

        return $paramDictionary 
    }

    begin {
        $settings | %{
            New-Variable -Name $_.Name -Value $PSBoundParameters[$_.Name] -WhatIf:$false
        }
        $KeyPath = "HKCU:\Software\Microsoft\Windows\PowerShell\Keys"
    }
    process{
        if ($_) {
            $_.KeyName | %{
                Remove-ItemProperty -Path $KeyPath -Name $_
            }
        } else {
            $KeyName | %{
                Remove-ItemProperty -Path $KeyPath -Name $_
            }
        }
    }
    end {}
}
