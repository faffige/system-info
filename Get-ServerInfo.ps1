#REQUIRES -Version 3.0
<#
.SYNOPSIS
    Get key details for systems
.DESCRIPTION
    Outputs information about the system
.NOTES
    File Name      : get-server-info-dev.ps1
    Author         : Peter Wilson
    Prerequisite   : PowerShell V3 and later, Windows 8 or Later. Will not work on Win 7/2008 etc
.EXAMPLE
    N/A
#>

#region Modules
#Loads Active Directory module. This is used to get the computer description from AD
Import-Module ActiveDirectory
#endregion

#region Clear Variables
#Just hear for ease of use
#Remove-Variable * -ErrorAction SilentlyContinue
#endregion

#region Object Construction
#Build new object called objSystem to hold system details
$objSystem = New-Object -TypeName PSObject
#endregion

#region Construct Table
$systemsTable = New-Object System.Data.DataTable
#build columns: hostname, serial, Manufacture,Model,IP,OS,SP,ADDesc
$systemsTable.Columns.Add((New-Object System.Data.DataColumn 'HostName', ([string])))
$systemsTable.Columns.Add((New-Object System.Data.DataColumn 'Serial', ([string])))
$systemsTable.Columns.Add((New-Object System.Data.DataColumn 'Manufacture', ([string])))
$systemsTable.Columns.Add((New-Object System.Data.DataColumn 'Model', ([string])))
$systemsTable.Columns.Add((New-Object System.Data.DataColumn 'IP', ([string])))
$systemsTable.Columns.Add((New-Object System.Data.DataColumn 'OS', ([string])))
$systemsTable.Columns.Add((New-Object System.Data.DataColumn 'SP', ([string])))
$systemsTable.Columns.Add((New-Object System.Data.DataColumn 'Description', ([string])))
#endregion

<# This is all the row constructs used in the for each loop. This should remain commented out and used for reference only
$row = $systemsTable.NewRow()
$row.'HostName' = $objSystem.systemHostName
$row.'Serial' = $objSystem.systemSerial
$row.'Manufacture' = $objSystem.systemManufacture
$row.'Model' = $objSystem.systemModel
$row.'IP' = $objSystem.systemIPAddr
$row.'OS' = $objSystem.systemOS
$row.'SP' = $objSystem.systemSP
$row.'Description' = $objSystem.systemDescription
$systemsTable.Rows.Add($row)
#>

#region Target Device
#[string[]]$targetServers = 
$targetServers = @()
#should probably make the search base a variable
$targetServers = Get-ADComputer -Filter * -SearchBase "" | Select-Object -Expand Name
#endregion

#region Check Online
#checks if servers are up or down by using test connection
#create empty hash table to store resuts
$serverOnline = @{ }
#loop through servers and ping, then add to has table
foreach ($targetServer in $targetServers)
{
	$serverResponse = Test-Connection $targetServer -Quiet -Count 1
	$serverOnline.Add($targetServer, $serverResponse)
}
#endregion

#region Get Server Info
foreach ($targetServer in $targetServers)
{
	if ($serverOnline.Get_Item($targetServer) -eq $true)
	{
		
		$row = $systemsTable.NewRow()
		
		#region Get Information
		$objWin32_bios = Get-CimInstance -classname win32_bios -computername $targetServer
		$objWin32_CS = Get-WmiObject -Class Win32_ComputerSystem -computername $targetServer
		$objIPaddr = Resolve-DnsName $targetServer
		$objDesc = Get-ADComputer $targetServer -Properties Description
		$objOS = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $targetServer
		#endregion
		
		#region Name
		Add-Member -InputObject $objSystem -MemberType NoteProperty -Name systemHostName -Value $objWin32_CS.Name -Force
		$row.'HostName' = $objSystem.systemHostName
		#endregion
		
		#region Serial
		Add-Member -InputObject $objSystem -MemberType NoteProperty -Name systemSerial -Value $objWin32_bios.SerialNumber -Force
		$row.'Serial' = $objSystem.systemSerial
		#endregion
		
		#region Manufacture
		Add-Member -InputObject $objSystem -MemberType NoteProperty -Name systemManufacture -Value $objWin32_CS.Manufacturer -Force
		$row.'Manufacture' = $objSystem.systemManufacture
		#endregion
		
		#region Model
		Add-Member -InputObject $objSystem -MemberType NoteProperty -Name systemModel -Value $objWin32_CS.Model -Force
		$row.'Model' = $objSystem.systemModel
		#endregion
		
		#region IP
		Add-Member -InputObject $objSystem -MemberType NoteProperty -Name systemIPAddr -Value $objIPaddr.IPAddress -Force
		$row.'IP' = $objSystem.systemIPAddr
		#endregion
		
		#region OS and patch level
		Add-Member -InputObject $objSystem -MemberType NoteProperty -Name systemOS -Value $objOS.Caption -Force
		$row.'OS' = $objSystem.systemOS
		Add-Member -InputObject $objSystem -MemberType NoteProperty -Name systemSP -Value $objOS.CSDVersion -Force
		$row.'SP' = $objSystem.systemSP
		#endregion
		
		#region Description
		Add-Member -InputObject $objSystem -MemberType NoteProperty -Name systemDescription -Value $objDesc.Description -Force
		$row.'Description' = $objSystem.systemDescription
		#endregion
		
		$systemsTable.Rows.Add($row)
	}
	Else
	{
		$row = $systemsTable.NewRow()
		
		#region Name
		$row.'HostName' = $targetServer
		#endregion	
		
		#region IP
		$row.'IP' = "Offline"
		#endregion
		
		$systemsTable.Rows.Add($row)
	}
}
#endregion

$systemsTable | Format-Table