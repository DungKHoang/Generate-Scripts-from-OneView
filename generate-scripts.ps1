
# ------------------ Parameters
Param ( [string]$OVApplianceIP                  = "", 
        [string]$OVAdminName                    = "", 
        [string]$OVAdminPassword                = "",
        [string]$OVAuthDomain                   = "",
        [string]$OneViewModule                  = "HPOneView.410"
)

$DoubleQuote    = '"'
$CRLF           = "`r`n"
$Delimiter      = "\"   # Delimiter for CSV profile file
$SepHash        = ";"   # USe for multiple values fields
$Sep            = ";"
$hash           = '@'
$SepChar        = '|'
$CRLF           = "`r`n"
$OpenDelim      = "{"
$CloseDelim     = "}" 
$CR             = "`n"
$Comma          = ','
$Equal          = '='
$Dot            = '.'
$Underscore     = '_'

$Syn12K                   = 'SY12000' # Synergy enclosure type

$DriveTypeValues = @{
    "SasHDD"  = "SAS";
    "SataHDD" = "SATA";
    "SASSSD"  = "SASSSD";
    "SATASSD" = "SATASSD"
}

$HostOSList     = @{
    "Citrix Xen Server 5.x/6.x"             ="CitrixXen" ;
    "AIX"                                   ="AIX"       ;
    "IBM VIO Server"                        ="IBMVIO"    ;
    "RHE Linux (Pre RHEL 5)"                ="RHEL4"     ;
    "RHE Linux (5.x, 6.x)"                  ="RHEL"      ;
    "RHE Virtualization (5.x, 6.x)"         ="RHEV"      ;
    "ESX 4.x/5.x"                           ="VMware"    ;
    "VMware (ESXi)"                         = "VMware"   ;
    "Windows 2003"                          ="Win2k3"    ;
    "Windows 2008/2008 R2"                  ="Win2k8"    ;
    "Windows 2012 / WS2012 R2"              ="Win2k12"   ;
    "OpenVMS"                               ="OpenVMS"   ;
    "Egenera"                               ="Egenera"   ;
    "Exanet"                                ="Exanet"    ;
    "Solaris 9/10"                          ="Solaris10" ;
    "Solaris 11"                            ="Solaris11" ;
    "NetApp/ONTAP"                          ="ONTAP"     ;
    "OE Linux UEK (5.x, 6.x)"               ="OEL"       ;
    "HP-UX (11i v1, 11i v2)"                ="HPUX11iv2" ;
    "HP-UX (11i v3)"                        ="HPUX11iv3" ;
    "SuSE (10.x, 11.x)"                     ="SUSE"      ;
    "SuSE Linux (Pre SLES 10)"              ="SUSE9"     ;
    "Inform"                                = "InForm"
    }


## ---------------------------------------------------------------------------------------
##
##          Helper functions
##
## ---------------------------------------------------------------------------------------

# ----------------------- Rescontruct FW ISO filename
# When uploading the FW ISO file into OV, all the '.' chars are replaced with "_"
# so if the ISO filename is:        SPP_2018.06.20180709_for_HPE_Synergy_Z7550-96524.iso
# OV will show $fw.ISOfilename ---> SPP_2018_06_20180709_for_HPE_Synergy_Z7550-96524.iso
# 
# This helper function will try to re-build the original ISO filename

Function rebuild-fwISO ([string]$ISOfile)
{
    $newStr   = ""
    $subArray = @()
    $subindex = 3

    if ($ISOfile)
    {
        $StrArray   = $ISOFile.Split($underscore)
        # Rebuild the string starting from Subindex
            $subArray   = $subIndex..$strArray.Count | % { $strArray[$_]}  
            $subStr     = $subArray -join $underscore
            $subStr     = $substr.TrimEnd($underscore)
        $newStr         = $strArray[0] + $underscore + $strArray[1] + $dot + $strArray[2] + $Dot + $subStr
    }


    return $newStr
    
}

# ----------------------- Get name from URI
Function Get-NamefromUri([string]$uri)
{
    $name = ""

    if (-not [string]::IsNullOrEmpty($Uri))
        { $name   = (Send-HPOVRequest $Uri).Name }

    return $name

}


# ----------------------- Output code to file
Function Out-ToScriptFile ([string]$Outfile)
{
    if ($ScriptCode)
    {
        Prepare-OutFile -outfile $OutFile
        
        Add-Content -Path $OutFile -Value $ScriptCode
        

    } else 
    {
        Write-Host -ForegroundColor Yellow " No $ovObject found. Skip generating script..."
    }
}


# ------------------------- Beginning of PS script
Function Prepare-OutFile ([string]$Outfile)
{
    $filename   = $outFile.Split($Delimiter)[-1]
    $ovObject   = $filename.Split($Dot)[0] 
    Write-Host -ForegroundColor Cyan "Create PS Script  -->     $filename  "
    New-Item $OutFile -ItemType file -Force -ErrorAction Stop | Out-Null
    

    $ScriptCode = @"
if (-not(`$global:ConnectedSessions))
{
    cls
    `$title              = `@"
# --------------------------------------------------------------------------------
# 
#   Connect to target appliance to configure OneView resources
#
# --------------------------------------------------------------------------------

`"@
    write-host -foreground CYAN `$title
 

    `$OVApplianceIP         = Read-host 'Enter the host name of IP address of the target OneView instance'
    `$OVAuthDomain          = Read-host 'Enter the authentication domain (e.g. local or AD domain)'
    `$OVcredential          = get-credential


    Connect-HPOVMgmt -appliance `$OVApplianceIP -credential `$OVcredential -AuthLoginDomain `$OVAuthDomain -errorAction stop
    if (-not `$global:ConnectedSessions) 
    {
        Write-Host -foreground YELLOW "Login to Synergy Composer or OV appliance failed.  Exiting."
        Exit
    } 
}

"@
    

    Set-content -path $outFile -Value $ScriptCode
}


## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-fwBaseline-Script
## 
## -------------------------------------------------------------------------------------------------------------

Function Generate-fwBaseline-Script ([string]$outfile, $List)
{
    $scriptCode = @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to create FW baseline
##
## -------------------------------------------------------------------------------------------------------------

"@    


    foreach ($fwBase in $List)
    {
        $ISOfilename    = $fwBase.ISOfilename 
        $name           = $fwBase.Name

        # - OV strips the dot from the ISOfilename, so we have to re-construct it
        $filename   = rebuild-fwISO -ISOfile $ISOfilename 

        $scriptCode += @"
        
write-host -foreground CYAN " Adding FW baseline  --> $name ........ $CR "

`$filename               = '$filename'
`$isofolder              = read-host `" Provide the folder location for `$filename `" 
`$isofile                = if (`$isofolder[-1] -eq '\') { "`$isofolder`$filename`"} else { "`$isofolder\`$filename" }    
if (test-path `$isofile) `  
    { Add-HPOVBaseline -file `$isofile }
else ` 
    { write-host " SPP iso file `$isofile not found . Skip adding SPP ...." }
 
"@

    }

    Out-ToScriptFile -Outfile $outFile 
}


## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-Proxy-Script
## 
## -------------------------------------------------------------------------------------------------------------

Function Generate-proxy-Script ([string]$outfile, $List)
{
    $scriptCode = @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to create proxy
##
## -------------------------------------------------------------------------------------------------------------

"@    


    $proxy          = $List
    $server         = $proxy.Server
    if ($server)
    {
        $protocol       = $proxy.protocol 
        $port           = $proxy.port 
        $username       = $proxy.username 
        $server         = $server 

        $serverParam    = " -server `$server "
        $portParam      = " -port `$port "
        $credParam      = $credCode = ""
        if ($username )
        {
            $credParam   = " -username `$username -password `$password "
            $credCode   += @"
`$username               = '$username'            
`$password               = read-host -prompt " Enter password for user `$usernmae for proxy server " -AsSecureString
"@
        }

        $isHttps        = if ($protocol-eq 'Https') {1} else {0}
        $protocolParam  = " -Https:`$isHttps "


        $scriptCode    += @"
`$server                 = '$server' 
`$port                   = '$port'
$credCode
`$isHttps                = [Boolean]$isHttps

write-host -foreground CYAN " Configuring proxy ......."

Set-HPOVApplianceProxy -hostname `$server $userParam $portParam  $protocolParam 

"@


        Out-ToScriptFile -Outfile $outFile 
    }
    

}



## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-Alerts-Script
## 
## -------------------------------------------------------------------------------------------------------------

Function Generate-alerts-Script ([string]$outfile, $List)
{
    $scriptCode = @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to create alerts
##
## -------------------------------------------------------------------------------------------------------------

"@    


    $smtp                   = $List

    $alertEmailDisabled     = $smtp.alertEmailDisabled 
    if (-not $alertEmailDisabled)  
    {
        $senderemail        = $smtp.SenderEmailAddress 
        $smtpServer         = $smtp.SmtpServer 
        $smtpPort           = $smtp.Port
        $smtpProtocol       = $smtp.smtpProtocol
        $alertList          = $smtp.alertEmailFilters


        $portParam = $PortCode = ""
        if ($smtpPort)
        {
            $portParam      = " -Port `$smtpPort "
            $portCode       = "`$smtpPort              = $smtpPort "  
        }

        $connectionSecurity = "None"
        if ($smtpProtocol -ne 'PLAINTEXT')
        {
            $connectionSecurity = $smtpProtocol 
        }

        $senderParam        = " -SenderEmailAddress `$senderEmail -password `$password -AlertEmailEnabled "
        $serverParam        = " -server `$smtpServer " + $portParam
        $connectionParam    = " -ConnectionSecurity `$connectionSecurity "

        $scriptCode         += @"

write-host -foreground CYAN " Configuring smtp ......."

`$senderEmail            = '$senderEmail'
`$password               = read-host 'Enter password for senderEmail ' -AsSecureString
`$smtpServer             = '$smtpServer'
`$connectionSecurity     = '$connectionSecurity' 
$portCode

Set-HPOVSmtpConfig $SenderParam ``
$serverParam $connectionParam 

"@


        #--- Working on smtp Email Alert
        
        foreach ($AL in $alertList)
        {
            $name           = $AL.filterName
            $filter         = $AL.filter
            $emails         = $AL.emails
            $scope          = $AL.scopeQuery
            $preference     = $AL.preference
            
    
    
            $filterParam    = $filterCode = ""
            if ($filter)
            {
                $filterParam    = " -filter `$filter "
                $filter         = $filter -replace "'",""
                $filter         = $filter.TrimStart('(').TrimEnd(')')
                $filterCode     = "`$filter                 = `'$filter`'" 
            }
    
            $scopeParam             = ""
            $ops                    = ''
            if ($scope )                                        # scope looks like : scope:'Scope 1' OR scope:'server' 
            {
                $isOR               = $scope -match ' OR '
                $isAND              = $scope -match ' AND ' 
                $ops                = if ($isOR)    { 'OR' } else {''}
                $ops                = if ($isAND)   { 'AND'} else {$ops}

                $preferenceParam    = $preferenceCode = $scopeParam = $scopeCode = ""
                if ($ops)
                {
                    $preferenceParam    = " -ScopeMatchPreference `$preference "
                    $preferenceCode     = "`$preference             = `'$ops`'" 

                    $scopes             = $scope.split($ops) -replace 'scope:', ''
                    $scopeArray         = @()
                    foreach ($e in $scopes)
                    {
                        if ($e)
                            {   $scopeArray += $e } 
                    }
                    $scopeList          = $scopeArray -join $comma

                }
                else # Has only 1 scope
                {
                    $scopeList          = $scope.TrimStart(" ").TrimEnd(" ") -replace 'scope:', ''
                }

                $scopeParam         = " -scope `$scopeList "  + $preferenceParam  
                $scopeCode          = "`$scopeList              = @($scopeList) "    
                
            }

    
            $emailParam             = $emailCode = ""
            if ($emails)
            {
                $emails             = $emails | %{ "`'$_`'"}        # Add quote to string
                $emailList          = $emails -join $Comma
                $emailParam         = " -emails `$emailList "                
                $emailCode         = "`$emailList              = @($emailList)" 
            }
    
            $scriptCode += @"

write-host -foreground CYAN " Configuring smtp alert email ......."

`$name                   = '$name' 
$filterCode 
$preferenceCode 
$scopeCode
$emailCode

Add-HPOVSmtpAlertEmailFilter -Name `$name $emailParam ``
$scopeParam  $filterParam 

"@
    
        }
        
    }
    
    

    Out-ToScriptFile -Outfile $outFile 
}

## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-scope-Script
## 
## -------------------------------------------------------------------------------------------------------------

Function Generate-scope-Script ([string]$outfile, $List)
{
    $scriptCode = @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to create scope
##
## -------------------------------------------------------------------------------------------------------------

"@    



    $resources      = @()
    $descParam      = ""

    foreach  ($s in $List)
    {
        $name       = "`'" + $s.name + "`'"
        $desc       = $s.description
        $members    = $s.members

    
        $descParam = $descCode = ""
        if ($desc)
        {
            $desc       = "`'" + $desc + "`'"
            $descParam  =  " -description `$description " 
            $descCode   = "`$description           = $desc "  
        }

        
        $scriptCode     += @"
`$name                   = $name 
$descCode
`$thisScope              = New-HPOVScope -name `$name $descParam

"@


        if ($members)
        {
            $scriptCode   += @"

## ------ Create resources to be included in scope $name
`$resources             = @() 

"@

            foreach ($m in $members)
            {
                
                $m_name = "`'" + $m.name + "`'"
                $m_type = $m.type
                switch ($m_type) 
                {
                    'EthernetNetwork'           {   $scriptCode += "`$m_name                = $m_name " + $CR
                                                    $scriptCode += "`$resources             += Get-HPOVnetwork  -name `$m_name "   + $CR
                                                }

                    'FCoENetwork'               {   $scriptCode += "`$m_name                = $m_name "   + $CR
                                                    $scriptCode += "`$resources             += Get-HPOVnetwork  -name `$m_name "   + $CR
                                                }

                    'FCNetwork'                 {   $scriptCode += "`$m_name                = $m_name "   + $CR
                                                    $scriptCode += "`$resources             += Get-HPOVnetwork  -name `$m_name "  + $CR 
                                                }

                    'LogicalInterconnectGroup'  {   $scriptCode += "`$m_name                = $m_name "   + $CR
                                                    $scriptCode += "`$resources             += Get-HPOVLogicalInterconnectGroup  -name `$m_name "  + $CR
                                                }

                    'LogicalInterconnect'       {   $scriptCode += "`$m_name                = $m_name " + $CR
                                                    $scriptCode += "`$resources             += Get-HPOVLogicalInterconnect  -name `$m_name " + $CR
                                                }

                    'LogicalEnclosure'          {   $scriptCode += "`$m_name                = $m_name " + $CR
                                                    $scriptCode += "`$resources             += Get-HPOVLogicalEnclosure  -name `$m_name " + $CR
                                                }
                                                
                    'ServerProfileTemplate'     {   $scriptCode += "`$m_name                = $m_name " + $CR
                                                    $scriptCode += "`$resources             += Get-HPOVServerProfileTemplate  -name `$m_name " + $CR
                                                }

                    'ServerHardware'            {   $scriptCode += "`$m_name                = $m_name " + $CR
                                                    $scriptCode += "`$resources             += Get-HPOVServer  -name `$m_name "  + $CR
                                                }

                    'StorageVolumeTemplate'     {   $scriptCode += "`$m_name                = $m_name " + $CR
                                                    $scriptCode += "`$resources             += Get-HPOVStorageVolumeTemplate -name `$m_name " + $CR
                                                }

                    'StorageVolume'             {   $scriptCode += "`$m_name                = $m_name " + $CR
                                                    $scriptCode += "`$resources             += Get-HPOVStorageVolume -name `$m_name " + $CR
                                                }

                    'StoragePool'               {   $scriptCode += "`$m_name                = $m_name " + $CR
                                                    $scriptCode += "`$resources             += Get-HPOVStoragePool -name `$m_name " + $CR
                                                }

                    'FirmwareBundle'            {  $scriptCode += "`$m_name                = $m_name " + $CR
                                                    $scriptCode += "`$resources            += Get-HPOVbaseline -name `$m_name " + $CR
                                                }

                    default                     {}
                }
            }

            $scriptCode     += @"

write-host -foreground CYAN " Configuring scope ......."

Add-HPOVResourceToScope -scope `$thisScope -InputObject `$resources 

"@

        
        }
    }



    Out-ToScriptFile -Outfile $outFile 
}

## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-snmp-Script
## 
## -------------------------------------------------------------------------------------------------------------

Function Generate-snmp-Script ([string]$outfile, $List)
{
    $scriptCode = @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to create snmp
## 
## -------------------------------------------------------------------------------------------------------------

"@    

    
   
    $snmp            = $List
    if ($snmp)
    {
        $readCommunity      = $snmp.communitystring 

        #Trap destinations
        $trapDestinations   =   Get-HPOVApplianceTrapDestination

        foreach ($t in $trapDestinations)
        {
            $communitystr   = $t.communitystring 
            $destination    = $t.DestinationAddress
            $port           = $t.port
            $type           = $t.type
            

            
            $destParam = $formatParam = $communityParam = $portParam = ""
            $destCode = $formatCode = $communityCode = $portCode = ""
            if ($destination)
            {
                
                
                $destParam      = " -destination `$destination "
                $formatParam    = " -SnmpFormat `$type "
                $portParam      = " -port `$Port " 
                
                $destCode       += "#-- `tGenerating Trap destination object for $destination " + $CR
                $destCode       += "`$destination           = '$destination' " 
                $portCode        = "`$port                  = $port        "   

                if ($type -like 'snmpV1*')
                {
                    $communityCode  = "`$communitystring       = '$communitystr' " 
                    $communityParam = " -Community `$communitystring "
                    $type           = "SNMPv1"
                }
                else 
                {
                    $communityParam = ""
                    $type           = "SNMPv3"               
                }                
                $formatCode         = "`$type                  = '$type'         "    

                $scriptCode     += @"
                
write-host -foreground CYAN " Configuring snmp traps ......."

`$readCommunity         = '$readCommunity'
Set-HPOVSnmpReadCommunity -name `$readCommunity 
$destCode
$portCode
$formatCode 
$communityCode
New-HPOVSnmpTrapDestination $destParam $portParam ``
$communityParam  $FormatParam 

"@ 
            }

        }

    
    }

    
    Out-ToScriptFile -Outfile $outFile

}


## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-smtp-Script 
##
## -------------------------------------------------------------------------------------------------------------
#
Function Generate-smtp-Script ([string]$Outfile, $List)
{

    $scriptCode = @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to set smtp on the appliance
##
## -------------------------------------------------------------------------------------------------------------

"@    
    
        $smtp           = $list

        $Email          = $Smtp.senderEmailAddress
        $Server         = $Smtp.smtpServer
        $Port           = $Smtp.smtpPort

        # Code and Parameters
        if ($Email)
        {
            $scriptCode     += @"

write-host -foreground CYAN " Configuring smtp ......."

# -------------- Attributes for SMTP 
`$AlertEmailDisabled         = [Boolean]1
`$Email                      = '$Email' 
`$Port                       = [int32]$Port
`$Password                   = read-host "Please enter a password to connect to smtp Server " -AsSecureString 
`$server                     = '$server'

Set-HPOVSmtpConfig -SenderEmailAddress `$Email -password `$Password ``
-Server `$Server -Port `$Port 


"@            
        }

        Out-ToScriptFile -Outfile $outFile 

}

## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-TimeLocale-Script
##
## -------------------------------------------------------------------------------------------------------------
#
Function Generate-TimeLocale-Script ([string]$Outfile, $List)
{

    $scriptCode = @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to set Date and Time on the appliance
##
## -------------------------------------------------------------------------------------------------------------

"@    
    
        

        $timeLocale     = $list

        $Locale         = $TimeLocale.Locale
        $ntpServers     = $TimeLocale.NtpServers
        $pollingInterval= $timeLocale.pollingInterval

        $locale         = $locale.Split($dot)[0]
        $ntpParam       = $ntpCode = ""
        if ($ntpServers)
        {
            $ntpServers = $ntpServers | % { "`'$_`'"}
            $ntpServers = $ntpServers -join $Comma
            $ntpParam   = " -ntpServers `$ntpServers "
            $ntpCode    = "`$ntpServers                = @($ntpServers) "  
        }
      
        $pollingParam   = $pollingCode = ""
        if ($pollingInterval)
        {
            $pollingCode  = "`$pollingInterval           = $pollingInterval " 
            $pollingParam = " -pollingInterval `$pollingInterval "
        }

        $scriptCode     += @"

write-host -foreground CYAN " Configuring date/time and locale ......."

# -------------- Attributes for date and time 
`$locale                     = '$locale' 
$ntpCode
$pollingCode
Set-HPOVApplianceDateTime -Locale `$Locale $ntpParam $pollingParam

"@

        Out-ToScriptFile -Outfile $outFile

}




## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-AddressPoolSubnet-Script
##
## -------------------------------------------------------------------------------------------------------------
#
Function Generate-AddressPoolSubnet-Script ([string]$outfile, $List)
{

    $scriptCode= @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to create AddressPoolSubnet
##
## -------------------------------------------------------------------------------------------------------------

"@    
    
        foreach ($subnet in $List)
        {
            $networkID      = $subnet.NetworkID
            $subnetmask     = $subnet.subnetmask
            $gateway        = $subnet.gateway
            $domain         = $subnet.domain
            $dns            = $subnet.dnsservers
            $rangeUris      = $subnet.rangeUris


            # Code and attribute parameters
            

            $dnsParam       = $dnsCode = ""
            if ($dns)
            {
                $dnsParam       = " -dnsServers `$dnsServers "
                $dnsServers     = $dns | % { "`'$_`'"} 
                $dnsServers     = $dnsServers -join $Comma
                $dnsCode        = "`$dnsServers                = @( $dnsServers )"
                
            }

            $domainParam        = $domainCode = ""
            if ($domain)
            {
                $domainParam    =  "  -domain `$domain " 
                $domainCode     = "`$domain                    = '$domain' "
            }

            $subnetMaskParam    = " -subnetmask `$subnetmask "
            $gatewayParam       = " -gateway `$gateway "

            $scriptCode     += @"

# -------------- Attributes for subnet  $networkID
`$networkID                  = '$networkID'
`$subnetmask                 = '$subnetmask'
`$gateway                    = '$gateway' 
$domainCode
$dnsCode

# --- Add logic to check whether addresspool subnet already exists 

write-host -foreground CYAN " Creating address pool subnet $networkID ........ "

`$thisSubnet                 = New-HPOVAddressPoolSubnet -networkID `$networkID ``
$subnetMaskParam $domainParam  $gatewayParam  $dnsParam

"@ 
   
            if ($rangeUris)
            {
                foreach ($rangeUri in $rangeUris)
                {
                    $range          = send-HPOVRequest -uri $rangeUri
                    $name           = $range.Name 
                    $startAddress   = $range.startAddress 
                    $endAddress     = $range.endAddress 

                    $scriptCode     += @"

# --- Attributes for Address Pool range associated with subnet $networkID  
`$name                       = '$name' 
`$startAddress               = '$startAddress'
`$endAddress                 = '$endAddress'

# --- Add logic to check whether addresspool range already exists

write-host -foreground CYAN " Creating address pool range  --> `$name ........ "

New-HPOVAddressPoolRange -IPV4Subnet `$thisSubnet -name `$name -start `$startAddress -end `$endAddress

"@ 
                }
            }
                
        }
        
        Out-ToScriptFile -Outfile $outFile
}


## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-AddressPool-Script
##
## -------------------------------------------------------------------------------------------------------------
#
Function Generate-AddressPool-Script ([string]$outfile, $list)
{

    $scriptCode = @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to create AddressPool of type VSN, vMAC, WWWWn
##
## -------------------------------------------------------------------------------------------------------------

"@    
    
    


        foreach ($range in $List)
        {
            $pooltype       = $range.Name  
            $rangeType      = $range.rangeCategory 
            $startAddress   = $range.startAddress
            $endAddress     = $range.endAddress
            $cat            = $range.category
                $category   = $cat.Split('-')[-1]       

            if (($category -ne 'IPv4') -and ($rangeType -eq 'Custom'))
            {    
                $rangeTypeParam = " -rangeType `$rangeType "
                $poolTypeParam  = " -poolType `$poolType "
                $startEndParam  = " -start `$startAddress -end `$endAddress  "
                $startendCode   = @"
`$startAddress               = '$startAddress' 
`$endAddress                 = '$endAddress'   
"@     
                


                $scriptCode     += @"
`$rangeType                  = '$rangeType' 
`$poolType                   = '$poolType'
$startendCode
# --- Add logic to check whether addresspool range already exists

write-host -foreground CYAN " Creating address pool range $rangeType ........ "

New-HPOVAddressPoolRange $poolTypeParam  $rangeTypeParam $startEndParam 

"@
            }

        }
        
        Out-ToScriptFile -Outfile $outFile 
}


# Region Storage

## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-SanManager-Script
##
## -------------------------------------------------------------------------------------------------------------
#
Function Generate-SanManager-Script ([string]$outfile, $list)
{

$title = @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to create San Manager
##
## -------------------------------------------------------------------------------------------------------------

"@    

    
    $scriptCode         = @()
    $Cmds               = ""

    $ListofSanManagers  = $list
    foreach ($SM in $ListofSanManagers)
    {
        $name           = $SM.name
        $displayName    = $sm.providerDisplayName
                        
        foreach ($CI in $SM.ConnectionInfo)
        {
            Switch ($CI.Name)
            {

                # ------ For HPE and Cisco 
                'SnmpPort'          { $Port             = $CI.Value}
                'SnmpUsername'      { $snmpUsername     = $CI.Value}
                'SnmpAuthLevel'     { 
                                        $v = $CI.Value

                                        if ($v -notlike 'AUTH*')
                                            { $AuthLevel     = 'None'}
                                        else 
                                            {
                                                if ($v -eq 'AUTHNOPRIV')
                                                    {$AuthLevel = 'AuthOnly'}
                                                else
                                                    {$AuthLevel = 'AuthAndPriv'}
                                            }
                                    }  

                'SnmpAuthProtocol'  { $AuthProtocol  = $CI.Value}
                'SnmpPrivProtocol'  { $PrivProtocol  = $CI.Value}

                #---- For Brocade 
                'Username'          { $username  = $CI.Value}
                'UseSSL'            { $UseSSL  = if ($CI.Value) { 1} else {0}   }
                'Port'              { $Port  = $CI.Value}
            }


        }

        $credParam = $credCode = ""

        if ($displayName -eq 'BNA')
        {
            $credParam       = " -username `$username -password `password  -useSSL:`$useSSL"
            $credCode        = @"
`$username                   = '$username'
`$password                   = read-host "Provide password for user to connect to SANManager  `$username  "    -asSecureString
`$useSSL                     = [Boolean]$useSSL   
"@
        }
        else    # Cisco or HPE 
        {
            $authProtocolParam = " -SnmpAuthLevel `$snmpAuthLevel -Snmpusername `$snmpUsername -SnmpAuthPassword `$snmpAuthPassword -snmpAuthProtocol `$snmpAuthProtocol "
            $authProtocolCode  = @"
`$snmpAuthLevel              = '$authLevel'
`$snmpAuthProtocol           = '$AuthProtocol'
`$snmpAuthPassword           = read-host "Provide authentication password for user `$snmpUsername "  -asSecureString
"@
            $privProtocolParam = $privProtocolCode = ""
            if ($authLevel -eq 'AuthAndPriv')
            {   
                $privProtocolParam = " -SnmpPrivPassword `$snmpPrivPassword -snmpPrivProtocol `$snmpPrivProtocol "
                $privProtocolCode  = @"
`$snmpPrivProtocol           = '$privProtocol'
`$snmpPrivPassword           = read-host "Provide privacy password for user "   -asSecureString
"@
            }
            $credParam       = $authProtocolParam + $privProtocolParam
            $credCode        = @"
`$snmpUsername               = '$snmpUsername'  
$authProtocolCode
$privProtocolCode    
"@
        }
        
        $scriptCode          += @"
# -------------- Attributes for  San Manager $name

write-host -foreground CYAN " Creating SAN Manager  --> $name ........ "

`$name                       = '$name'
`$type                       = '$displayName'
`$port                       = $port
$credCode

`$sanM                       = Get-HPOVSanManager | where name -eq `$name
if (-not `$sanM)
{
    add-HPOVSanManager -hostname `$name -type `$type -port `$port ``
    $credParam
}
else
{
    write-host -foreground CYAN "SAn Manager `$name already exists. Skip adding it.... "
}

"@


    }

    Out-ToScriptFile -Outfile $outFile 

}




## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-StorageSystem-Script
##
## -------------------------------------------------------------------------------------------------------------
#
Function Generate-StorageSystem-Script ([string]$outfile, $list)
{

    $scriptCode = @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to create storage System
##
## -------------------------------------------------------------------------------------------------------------

"@    




    $listofStorageSystem = $list

    foreach ($StS in $ListofStorageSystem)
    {
        $StoragePorts        = @()
        $storageSystemPorts  = ""

        $hostName            = $Sts.hostname
        $Username            = $Sts.Credentials.username
        $family              = $sts.family
        $DomainName          = if ($family -eq 'StoreServ' ) { $Sts.deviceSpecificAttributes.managedDomain } else {''}


        $portList            = $Sts.Ports | where status -eq 'OK' | sort Name

        foreach ($MP in $portList) 
        {
            if ($family -eq 'StoreServ')
                { $Thisname    = $MP.actualSanName }
            else 
                { $Thisname    = $MP.ExpectedNetworkName  }
            if ($Thisname)
            {
                $Port           = "`'" + $MP.Name + "`'" +'=' + "`'" + $Thisname + "`'"     # Build Port syntax '0:1:2'= 'VSAN10'
                $StoragePorts  += $Port
            }
        }

        if ($DomainName)
        {
            $domainParam     = " -domain `$domainName "
            $domainNameCode  = @"
`$domainName                 = '$domainName'
"@      
        }

        if ($storagePorts)
        {
            # ---- Igore StoragePorts for now
            $storagePortsParam  = ""
            #$storagePortsParam  = " -Ports `$storageSystemPorts "
            $storageSystemPorts = $storagePorts -join ';'
            $storagePortsCode  = @"
`$storageSystemPorts         = @{$storageSystemPorts}
"@      
        }

    $scriptCode     += @"

# -------------- Attributes for StorageSystem `$hostname

write-host -foreground CYAN " Creating storage System  --> $hostname ........ "


`$hostname                   = '$hostname'
`$family                     = '$family'
$domainNameCode 
$storagePortsCode

`$sts                        = Get-HPOVstorageSystem | where hostname -eq  `$hostname
if (-not `$sts)
{
    write-host -foreground CYAN "Provide credential for storage system $hostname "
    `$cred                       = get-credential 
    Add-HPOVStorageSystem -hostname `$hostName -credential `$cred -family `$family  ``
    $domainParam $storagePortsParam 
}
else
{
    write-host -foreground CYAN " storage System `$hostname already exists. Skip adding it....."
}

"@

    }
    
    Out-ToScriptFile -Outfile $outFile 

    

}

## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-StoragePool-Script
##
## -------------------------------------------------------------------------------------------------------------
#
Function Generate-StoragePool-Script ([string]$outfile, $list)
{

    $scriptCode = @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to create storage Pool
##
## -------------------------------------------------------------------------------------------------------------

"@    



    $list = $list | where state -eq 'Managed'

    $PoolArray          = @()
    foreach ($pool in $list)
    {
        $name           = $pool.name
        $description    = $pool.description
        $stsUri         = $pool.StorageSystemUri 

        # --- Storage System
        if ($stsUri)
        {
            $sts        = send-HPOVRequest -uri $stsUri
            $stsName    = $sts.name

        }
        $PoolArray      += "'$name'"


    }

    if ($poolArray)
    {
        $poolList       = $PoolArray -join $Comma
        $scriptCode     += @"

# -------------- Attributes for Storage Pool
`$pArray                     = @($poolList)
`$stsName                    = '$stsName'
`$storageSystem              = Get-HPOVStorageSystem | where name -eq  `$stsName
if (`$storageSystem)
{
    # --- Add logic to check whether storage pools already exist 
    
    write-host -foreground CYAN " Creating storage pool for storage system --> `$stsName........ "

    write-host -foreground CYAN " Building new storage pool list...  "

    `$poolList                   = `$managedPoolname    = `$managedPool = @()                 
    foreach (`$pname in `$pArray)
    {
        `$thispool                   = get-HPOVstoragePool -name `$pname
        if (-not `$thispool)
        {
             `$poolList            += `$pname
        }
        else
        {
            if (`$thispool.state -eq 'Discovered')
            {
                `$Managedpoolname   += `$pname
            }
        }
    }
    
    

    if (`$poolList)
    {
        write-host -foreground CYAN " `n Adding storage pools `$poolList........ "
        Add-HPOVStoragePool -StorageSystem `$storageSystem -Pool `$poolList
    }

    if (`$managedPoolname)
    {
        `$managedPool = `$managedPoolName | % { Get-HPOVStoragePool -name `$_}
        write-host -foreground CYAN " `n Change state to Managed for storage pool ........ "
        Set-HPOVStoragePool -inputObject `$managedPool -Managed:`$true
    }

} 
else
{
    write-host -foreground Yellow "No storage system found that is associated with storage pools. Skip adding storage pools.... "
}

"@
        Out-ToScriptFile -Outfile $outFile 
    }

}


## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-StorageVolumeTemplate-Script
##
## -------------------------------------------------------------------------------------------------------------
#
Function Generate-StorageVolumeTemplate-Script ([string]$outfile, $list)
{

    $title = @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to create storage Volume Template
##
## -------------------------------------------------------------------------------------------------------------

"@    

    $scriptCode         = @()
    $Cmds               = ""

    $scriptCode         += "`n$title" + $CR

    $listofVolTemplates = $list

    foreach ($Template in $ListofVolTemplates)
    {
        $name               = $Template.Name
        $description        = $Template.Description

        $stsUri             = $Template.compatibleStorageSystemsUri
        $p                  = $template.Properties
            $size           = $p.size.default / 1GB
            $isShareable    = if ($p.isShareable.default)       {1} else {0}
            $PoolUri        = $p.storagePool.default 
            $SnapshotUri    = $p.snapshotPool.default 
            $isDeduplicated = if ($p.isDeduplicated.default)    {1} else {0}
            $provisionType  = $p.provisioningType.default 

        $descParam = $descCode = ""
        if ($description)
        {
            $descParam      = " -description `$description "
            $descCode       = @"
`$description                = '$description'
"@
        }

        $sts                = Send-HPOVRequest -uri $stsUri
        $stsName            = $sts.members.displayName
        $poolName           = Get-NamefromUri -uri $PoolUri
        $snapshotName       = Get-NamefromUri -uri $snapshotUri

        $scriptCode         += @"
#------ Attributes for storage volume template $name
`$name                       = '$name'
`$poolName                   = '$poolName'
`$storagePool                = Get-HPOVStoragePool -name `$poolName
`$size                       = $size
$descCode
`$snapshotName               = '$snapshotName'
`$snapshotStoragePool        = Get-HPOVStoragePool -name `$snapshotName
`$storageSystemName          = '$stsName'
`$storageSystem              = Get-HPOVStorageSystem -name `$storageSystemName
`$provisioningType           = '$provisionType'
`$isDeduplicated             = [Boolean]$isDeduplicated
`$isShareable                = [Boolean]$isShareable

write-host -foreground CYAN " Creating storage volume template  --> `$name ........ "
`$svt                        = Get-HPOVstorageVolumeTemplate | where name -eq  `$name
if (-not `$svt)
{
    new-HPOVStorageVolumeTemplate -name `$name -storagePool `$storagePool -Capacity `$size $descParam ``
    -SnapshotStoragePool `$snapShotStoragePool -StorageSystem `$storageSystem ``
    -ProvisioningType `$ProvisioningType -EnableDeduplication:`$isDeduplicated -Shared:`$isShareable
}
else
{
    write-host -foreground CYAN " stroage volume template `$name already exists. Skip creating it...."
}

"@
        
    }

    Out-ToScriptFile -Outfile $outFile 

}



## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-StorageVolume-Script
##
## -------------------------------------------------------------------------------------------------------------
#
Function Generate-StorageVolume-Script ([string]$outfile, $list)
{

    $title = @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to create storage Volume 
##
## -------------------------------------------------------------------------------------------------------------

"@    

    $scriptCode             = @()
    $Cmds                   = ""

    $scriptCode             += "`n$title" + $CR

    $listofStorageVolumes   = $list

    foreach ($SV in $ListofStorageVolumes)
    {
        $name               = $SV.name
        $description        = $SV.description
        $poolUri            = $SV.storagePoolUri
        $size               = $SV.provisionedCapacity / 1GB
        $volTemplateUri     = $SV.volumeTemplateUri
        $provisionType      = $SV.provisioningType
        $isShareable        = if ($SV.isShareable)          {1} else {0}
        $p                  = $SV.deviceSpecificAttributes
            $isCompressed   = if ($p.isCompressed)          {1} else {0}
            $isDeduplicated = if ($p.isDeduplicated)        {1} else {0}
            $snapshotUri    = $p.snapshotPoolUri
        

        $descParam = $descCode = ""
        if ($description)
        {
            $descParam      = " -description `$description "
            $descCode       = @"
`$description                = '$description'
"@
        }

        $volumeParam      = $volumeCode      = ""
        if ($volTemplateUri)
        {
            $volumeParam     = " -volumeTemplate `$volumeTemplate "
            $volTemplateName = get-namefromUri -uri $volTemplateUri  
            $volumeCode      = @"
`$volumeTemplateName         = '$volTemplateName'
`$volumeTemplate             = get-HPOVStorageVolumeTemplate -name '$volTemplateName'
"@
        }
        else # volume created without template
        {
            $volumeParam        = @"
-StoragePool `$storagePool -snapshotStoragePool `$snapshotStoragePool -ProvisioningType `$provisioningType  ``
-capacity `$size -EnableCompression:`$isCompressed -EnableDeduplication:`$isDeduplicated -Shared:`$isShareable
"@
            $poolName           = Get-NamefromUri -uri $PoolUri   
            $snapshotName       = Get-NamefromUri -uri $snapshotUri
            $volumeCode         = @"
`$poolName                   = '$poolName'
`$storagePool                = Get-HPOVStoragePool -name `$poolName
`$size                       = $size
`$snapshotName               = '$snapshotName'
`$snapshotStoragePool        = Get-HPOVStoragePool -name `$snapshotName
`$provisioningType           = '$provisionType'
`$isDeduplicated             = [Boolean]$isDeduplicated
`$isShareable                = [Boolean]$isShareable
`$isCompressed               = [Boolean]$isCompressed
"@
        }

        $scriptCode         += @"
#------ Attributes for storage volume  '$name'
`$name                       = '$name'
$descCode
$volumeCode

write-host -foreground CYAN " Creating storage volume   --> `$name ........ "
`$stsvolume                  = get-HPOVstorageVolume | where name -eq  `$name
if (-not `$stsvolume)
{
    new-HPOVStorageVolume -name `$name ``
    $volumeParam
}
else
{
    write-host -foreground CYAN " storage volume`$name already exists. Skip creating it...."
}

"@

    }


    Out-ToScriptFile -Outfile $outFile 
}


## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-EthernetNetwork-Script
##
## -------------------------------------------------------------------------------------------------------------
#
Function Generate-EthernetNetwork-Script ([string]$outfile, $list)
{

$title = @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to create Ethernet networks
##
## -------------------------------------------------------------------------------------------------------------

"@    

    
    $scriptCode     = @()
    $Cmds           = ""
 
    $scriptCode     += "`n$title" + $CR
    $listofNetworks = $list
    foreach ($net in $listofNetworks)
    {
        # ----------------------- Construct Network information
        $name        = $net.name
        $type        = $net.type.Split("-")[0]   # Value is like ethernet-v30network

        $vLANType    = $net.ethernetNetworkType
        $vLANID      = $net.vLanId

        $pBandwidth  = [string]$net.DefaultTypicalBandwidth
        $mBandwidth  = [string]$net.DefaultMaximumBandwidth
        $smartlink   = if ($net.SmartLink) {1} else {0}
        $Private     = if ($net.PrivateNetwork) {1} else {0}
        $purpose     = $net.purpose

        $subnetURI   = $net.subnetURI 
        # Valid only for Synergy Composer
        $subnetIDparam = ""
        if ($global:ApplianceConnection.ApplianceType -eq 'Composer')
        {
            if ($subnetURI) 
            {
                $subnet         = send-HPOVRequest -uri $subnetURI
                $ThisSubnetID   = $subnet.NetworkID
                $subnetName     = $subnet.Name
                $subnetIDparam  = " -subnet `$ThisSubnetID "    
            }
                           
        }
        
        $pBWparam = $pBWCode = ""
        $mBWparam = $mBWCode = ""
        if ($PBandwidth) 
        {
            $pBWparam = " -typicalBandwidth `$pBandwidth "
            $pBWcode  = "`$pBandwidth                 = $pBandwidth"
        }
        
        if ($MBandwidth) 
        {
            $mBWparam = " -maximumBandwidth `$mBandwidth "
            $mBWcode  = "`$mBandwidth                 = $mBandwidth"
        }
        
        $subnetCode = ""
        if ($subnetURI)
        {
            $subnetCode += @"
`$subnetName                 = '$subnetName'
`$subnet                     = Get-HPOVAddressPoolSubnet -name `$subnetName
`$subnetID                   = `$subnet.ID
"@
        }


        $vLANIDparam = $vLANIDcode = ""
        if ($vLANType -eq 'Tagged')
        { 
            if (($vLANID) -and ($vLANID -gt 0)) 
            {
                $vLANIDparam =   " -vLanID `$VLANID "  
                $vLANIDCode += @"
`$vLANid                     = $vLANID 
"@
            }
        }


        
        $scriptCode     += @"
# -------------- Attributes for Ethernet networks  $name 
`$name                       = '$name' 
`$type                       = '$type'
$vLANIDCode
`$vLANType                   = '$vLANType'
$subnetCode
$pBWcode
$mBWcode
`$PLAN                       = [Boolean]$Private
`$smartLink                  = [Boolean]$smartLink 
`$purpose                    = '$purpose'

write-host -foreground CYAN " Creating network   --> `$name ........ "

`$net                        = Get-HPOVnetwork | where name -eq `$name
if (-not `$net)
{
    New-HPOVNetwork -name `$name -type `$Type ``
    -privateNetwork `$PLAN -smartLink `$smartLink -VLANType `$VLANType ``
    $vLANIDparam $pBWparam $mBWparam $subnetIDparam  -purpose `$purpose 
}
else
{
    write-host -foreground CYAN " Network `$name already exists. Skip creating it...."
}

"@

    }
   
    Out-ToScriptFile -Outfile $outFile 
}


## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-FCNetwork-Script   
##
## -------------------------------------------------------------------------------------------------------------
#
Function Generate-FCNetwork-Script ([string]$outfile, $list)
{

    $title = @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to create FC networks
##
## -------------------------------------------------------------------------------------------------------------

"@    

    $scriptCode     = @()
    $Cmds           = ""

    $scriptCode     += "`n$title" + $CR
    $listofNetworks = $list


    foreach ($net in $listofNetworks)
    {
        $name                   = $net.name
        $description            = $net.description
        $type                   = $net.type.Split("-")[0]   # Value is 'fcoe-networksV300
        $fabrictype             = $net.fabrictype
        $pBandwidth             = $net.defaultTypicalBandwidth
        $mBandwidth             = $net.defaultMaximumBandwidth
        $sanURI                 = $net.ManagedSANuri
        $linkStabilityTime      = if ($net.linkStabilityTime) { $net.linkStabilityTime} else {30}
        $autologinredistribution= if ($net.autologinredistribution) {1} else {0}
        # fcoe network
        $VLANID                 = $net.VLANID
        $fabricUri              = $net.fabricUri 




        $descParam = $descCode = ""
        if ($description) 
        {
            $descparam = " -description `$description "
            $descCode  = "`$description                = '$description'"
        }

        $pBWparam = $pBWCode = ""
        $mBWparam = $mBWCode = ""
        if ($PBandwidth) 
        {
            $pBWparam = " -typicalBandwidth `$pBandwidth "
            $pBWcode  = "`$pBandwidth                 = $pBandwidth"
        }
        
        if ($MBandwidth) 
        {
            $mBWparam = " -maximumBandwidth `$mBandwidth "
            $mBWcode  = "`$mBandwidth                 = $mBandwidth"
        }


        if ($type -match 'fcoe') #FCOE network
        {
            $FCparam          = $FCcode = ""
            $vLANIDparam      = $vLANIDcode = ""
            if (($vLANID) -and ($vLANID -gt 0)) 
            {
                $vLANIDparam =   " -vLanID `$VLANID "  
                $vLANIDCode  = "`$vLANid                     = $vLANID " 
            }


                              
        }
        else  # FC network
        {

            $autologinParam   = $autologinCode = ""
            $linkParam        = $linkCode = ""

            $vLANIDparam      = $vLANIDcode = ""
            $FCparam          = " -FabricType `$fabricType "
            $FCcode           = "`$fabricType                = '$fabricType'"
            
            if ($fabrictype -eq 'FabricAttach')
            {
                if ($autologinredistribution)
                {
                    $autologinCode      = "`$autologinredistribution    = [Boolean]$autologinredistribution"
                    $autologinParam     = " -AutoLoginRedistribution `$autologinredistribution "
                }
                if ($linkStabilityTime) 
                {
                    $linkParam  = " -LinkStabilityTime `$LinkStabilityTime "
                    $linkCode   = "`$LinkStabilityTime          = $LinkStabilityTime "
                }
                $FCparam              += $autologinParam + $linkParam 
                $FCcode         = @"
$FCCode
$autologinCode
$linkCode
"@
                
            }
        }

        $sanParam   = $sanCode = ""
        if($sanURI)
        { 
            $ManagedSAN         = Send-HPOVRequest -uri $sanURI 
            $SANname            = $ManagedSAN.Name 
            $SANmanagerName     = $ManagedSAN.devicemanagerName
            

            $SANparam   = " -ManagedSAN `$managedSAN "
            $SANcode    = @"
`$SANname                    = '$SANname'
`$SANmanagerName             = '$SANmanagerName'
`$managedSAN                 = Get-HPOVManagedSAN | where name -eq `$SANname | where deviceManagerName -eq `$SANmanagerName
"@

        }

        $scriptCode     += @"
# -------------- Attributes for FibreChannel networks  $name
`$name                       = '$name' 
$descCode
`$type                       = '$type'
$mBWcode
$pBWcode
$fcCode
$vLANIDCode
$SANcode


write-host -foreground CYAN " Creating FC/FCOE network  --> `$name ........ "

`$net                        = get-HPOVnetwork | where name -eq `$name
if (-not `$net)
{ 
    if (`$managedSAN)
    {
        New-HPOVNetwork -name `$name -type `$Type $descparam  ``
        $pBWparam $mBWparam $FCparam``
        $vLANIDparam $SANparam   
    }
    else
    {
        New-HPOVNetwork -name `$name -type `$Type $descparam  ``
        $pBWparam $mBWparam $FCparam``
        $vLANIDparam 
    }
}
else
{
    write-host -foreground CYAN " Network `$name already exists. Skip creating it...."
}

"@

    }
    
    Out-ToScriptFile -Outfile $outFile 
}


## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-NetworkSet-Script
##
## -------------------------------------------------------------------------------------------------------------
#
Function Generate-NetworkSet-Script ([string]$outfile, $list)
{

    $title = @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to create network sets
##
## -------------------------------------------------------------------------------------------------------------

"@    

    $scriptCode     = @()
    $Cmds           = ""

    $scriptCode     += "`n$title" + $CR

    $listofNetworkSets = $list
    foreach ($ns in $listofNetworkSets)
    {
        $nsname             = $ns.name
        $nsdescription      = $ns.description
        $PBandwidth         = $ns.TypicalBandwidth 
        $Mbandwidth         = $ns.MaximumBandwidth 
        $untaggednetworkURI = $ns.nativeNetworkUri
        $networkURIs        = $ns.networkUris


        
        $pBWparam = $pbWCode = ""
        $mBWparam = $mBWCode = ""
        if ($PBandwidth) 
        {
            $pBWparam = " -typicalBandwidth `$pBandwidth "
            $pBWcode  = "`$pBandwidth                 = $pBandwidth"
        }
        
        if ($MBandwidth) 
        {
            $mBWparam = " -maximumBandwidth `$mBandwidth "
            $mBWcode  = "`$mBandwidth                 = $mBandwidth"
        }
        

        $untaggedParam  = $untaggednetworkname  =  $untaggednetCode = ""
        if ($untaggednetworkURI) 
        {
            $untaggedParam          =  " -untaggedNetwork `$untaggednetworkname "
            $untaggednetwork        = Send-HPOVRequest -uri  $untaggednetworkURI
            $untaggednetworkname    = $untaggednetwork.Name
            $untaggednetCode += @"
`$untaggednetworkname        = '$untaggednetworkname'
`$untaggednetwork            = get-HPOVnetwork -name `$untaggednetworkname
"@
        }
        
        $netParam = $netCode = ""
        if ($networkURIs) 
        {
            $netParam     = " -networks `$networks "
            #Serialize Array
            $arr = @()
            foreach ($el in $networkURIs)
            { 
                $name  = Get-NamefromUri -uri $el
                $arr += "`'$name`'"  
            }   # Add quote to string 
            $networks      = $arr -join $Comman
            $netCode      += @"
`$networks                  = @($networks)
"@
        }
    

        $scriptCode     += @"
# -------------- Attributes for Network set  $nsname 
`$nsname                     = '$nsname' 
$netCode
$untaggednetCode
$pbWcode
$mBWcode

write-host -foreground CYAN " Creating network set   --> `$nsName ........ "
`$ns                        = get-HPOVnetworkSet | where name -eq `$nsName
if (-not `$ns)
{
    new-HPOVnetworkSet -name `$nsName $pBWparam $mBWparam ``
    $netParam $untaggedParam
}
else
{
    write-host -foreground CYAN " networkset `$nsName already exists. Skip creating it...."
}

"@

    }
    
    Out-ToScriptFile -Outfile $outFile 
}


## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-LogicalInterConnectGroup-Script
##
## -------------------------------------------------------------------------------------------------------------

Function Generate-LogicalInterConnectGroup-Script ([string]$OutFile, $List) 
{
    

    $ICModuleTypes            = @{
        "VirtualConnectSE40GbF8ModuleforSynergy"    =  "SEVC40f8" ;
        "Synergy20GbInterconnectLinkModule"         =  "SE20ILM";
        "Synergy10GbInterconnectLinkModule"         =  "SE10ILM";
        "VirtualConnectSE16GbFCModuleforSynergy"    =  "SEVC16GbFC";
        "Synergy12GbSASConnectionModule"            =  "SE12SAS"
    }

    $FabricModuleTypes       = @{
        "VirtualConnectSE40GbF8ModuleforSynergy"    =  "SEVC40f8" ;
        "Synergy12GbSASConnectionModule"            =  "SAS";
        "VirtualConnectSE16GbFCModuleforSynergy"    =  "SEVCFC";
    }

    $ICModuleToFabricModuleTypes = @{
        "SEVC40f8"                                  = "SEVC40f8" ;
        "SEVC16GbFC"                                = "SEVCFC" ;
        "SE12SAS"                                   = "SAS"
    }

    #------------------- Interconnect Types
    $ICTypes         = @{
    "571956-B21" =  "FlexFabric" ;
    "455880-B21" =  "Flex10"     ;
    "638526-B21" =  "Flex1010D"  ;
    "691367-B21" =  "Flex2040f8" ;
    "572018-B21" =  "VCFC20"     ;
    "466482-B21" =  "VCFC24"     ;
    "641146-B21" =  "FEX"
}

$title = @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to create Logical Interconnect Groups
##
## -------------------------------------------------------------------------------------------------------------

"@    

    $scriptCode     = @()
    $Cmds           = ""

    $scriptCode     += "`n$title" + $CR

    $ListofLIGs     = $list
    foreach ($lig in $listofLIGs)
    {
        $name                   = $lig.Name
        $enclosureType          = $lig.enclosureType
        $description            = $lig.description

        $internalNetworkUris    = $lig.InternalNetworkUris

        $uplinkSets             = $lig.uplinksets | sort Name

        $fastMacCacheFailover   = if ($lig.ethernetSettings.enableFastMacCacheFailover) {1} else {0}
         $macrefreshInterval    = $lig.ethernetSettings.macRefreshInterval

        $igmpSnooping           = if ($lig.ethernetSettings.enableIGMPSnooping) {1} else {0}
        $igmpIdleTimeout        = $lig.ethernetSettings.igmpIdleTimeoutInterval

        $networkLoopProtection  = if ($lig.ethernetSettings.enablenetworkLoopProtection) {1} else {0}

        $PauseFloodProtection   = if ($lig.ethernetSettings.enablePauseFloodProtection) {1} else {0}

        $redundancyType         = $lig.redundancyType

        $EnableRichTLV          = if ($lig.EthernetSettings.enableRichTLV) {1} else {0}

        $LDPTagging             = if ($lig.EthernetSettings.enableTaggedLldp) {1} else {0}

        $Telemetry              = $lig.telemetryConfiguration
         $sampleCount           = $Telemetry.sampleCount
         $sampleInterval        = $Telemetry.sampleInterval

         $snmp                  = $lig.snmpConfiguration

        
         $FrameCount             = $InterconnectBaySet = ""
        if ($enclosureType -eq $Syn12K)
        {
            $FrameCount             = $lig.EnclosureIndexes.Count
            $InterconnectBaySet     = $lig.interconnectBaySet
        }


        # ----------------------------
        #     Find Internal networks
        $intNetworks            = @()
        $intNetworkNames        = @()
        
        foreach ( $uri in $internalNetworkUris)
        {
            $net                = send-hpovRequest -uri $uri
            $netname            = $net.name
            $netname            = "`'$netname`'"
            $intNetworkNames   += $netname
            $intNetworks       += $net

        }

 


        # ----------------------------
            #     Find Interconnect devices
            $Bays         = @()
            $UpLinkPorts  = @()
            $Frames       = @()

            $LigInterConnects = $lig.interconnectmaptemplate.interconnectmapentrytemplates
            foreach ($ligIC in $LigInterConnects | Where-Object permittedInterconnectTypeUri -ne $NULL)
            {
                # -----------------
                # Locate the Interconnect device and its position
                $ICTypeuri  = $ligIC.permittedInterconnectTypeUri

                if ($enclosureType -eq $Syn12K)
                {
                    $ICtypeName     = Get-NamefromUri -uri $ICTypeUri
                    $ICtypeName     = $ICtypeName -replace '\s','' # remove Spaces
                    $ICmoduleName   = $ICModuleTypes[$ICtypeName]

                    $BayNumber    = ($ligIC.logicalLocation.locationEntries | Where-Object Type -eq "Bay").RelativeValue
                    $FrameNumber  = ($ligIC.logicalLocation.locationEntries | Where-Object Type -eq "Enclosure").RelativeValue
                    $FrameNumber = [math]::abs($FrameNumber)
                    $Bays += "Frame$FrameNumber" + $Delimiter + "Bay$BayNumber"+ "=" +  "`"$ICmoduleName`""   # Format is Frame##\Bay##=InterconnectType

                }
                else # C7K
                {
                    $PartNumber     = (send-hpovRequest $ICTypeuri ).partNumber
                    $ICmoduleName   = $ICTypes[$PartNumber]
                    $BayNumber      = ($ligIC.logicalLocation.locationEntries | Where-Object Type -eq "Bay").RelativeValue
                    $Bays          += "$BayNumber=$ICmoduleName"  # Format is xx=Flex Fabric
                    $BayConfig      = "@(" + $($Bays -join $Comma) + ")"
                }


               
            }


            #Code and parameters

            [Array]::Sort($Bays)


            if ($enclosureType -eq $Syn12K)  # Synergy
            {
                # Determine Fabric Module Type using 1st element
                $icModuleType  = $Bays[0].Split($Equal)[1]  # Format is Frame1\Bay3=SECVC40F8 
                $icModuleType = $icModuleType -replace '"', '' 
                $fabricModuleType   = $ICModuleToFabricModuleTypes[$icModuleType] 

                $BayConfigperFrame = @()
                $CurrentFrame      = ""
                $bayConfig  = ""

                foreach ($bayConf in $Bays)  #Frame ##\Bay##
                {
                    $a          = $bayConf.split($Delimiter)
                    $thisFrame  = $a[0]
                    $thisBay    = $a[1]

                    if (-not $CurrentFrame)
                    {
                        $currentFrame       = $thisFrame
                        $bayConfig   = $hash + $OpenDelim + $currentFrame + $Equal +$hash + $OpenDelim +  $thisBay + $SepHash     # Start a new hash table for frame and 1st frame  
                    }
                    else 
                    {
                        if ($thisFrame -eq $currentFrame)
                        {
                            $bayConfig += $thisBay # Same frame, just add Bay information
                        }    
                        else 
                        {
                            $bayConfig   += $CloseDelim # Close hashtable for Bays
                            $bayConfig   += $sepHash  # Start new frame
                            $currentFrame = $thisFrame
                            $bayConfig   += $CurrentFrame  + $Equal + $Hash + $OpenDelim + $thisBay + $SepHash      # Start a new hash table for frame   
                            
                        }

                    }
                }
                $bayConfig += $CloseDelim + $CloseDelim # Last element so close up the hash tables


                if ($redundancyType)
                {
                    $redundancyParam        = " -fabricredundancy `$redundancyType "

                    $redundancyCode         = @"
`$redundancyType         = '$redundancyType'
"@
                }

                $FabricModuleTypeParam  = " -FabricModuleType `$fabricModuleType "
                $FrameCountParam        = " -FrameCount `$frameCount "
                $ICBaySetParam          = " -InterConnectBaySet `$InterconnectBaySet "

                $SynergyCode     = @"
$redundancyCode         
`$fabricModuleType       = '$fabricModuleType'  
`$frameCount             = $frameCount 
`$InterconnectBaySet     = $InterconnectBaySet
"@          



                #-------Clear out parameters used for Synergy
                $PauseFloodProtectionParam = $macRefreshIntervalParam = $fastMacCacheParam = ""
            }
            else # C7K
            {
                $PartNumber = (send-hpovRequest $ICTypeuri ).partNumber
                $ThisICType = $ICTypes[$PartNumber]
                $BayNumber    = ($LigInterconnect.logicalLocation.locationEntries | Where-Object Type -eq "Bay").RelativeValue
                $Bays += "$BayNumber=$ThisICType"  # Format is xx=Flex Fabric
            
                #Parameters valid only for C7000
                if ([Boolean]$fastMacCacheFailover)
                {
                    $macRefreshIntervalParam    = $macRefreshIntervalCode   = ""
                    if ($macRefreshInterval)
                    {
                        $macRefreshIntervalParam    = " -macRefreshInterval `$macReFreshInterval "
                        $macRefreshIntervalCode     = @"
`$macRefreshInterval     = $macRefreshInterval
"@
                    }

                    $fastMacCacheParam = " -enableFastMacCacheFailover:`$fastMacCacheFailover " + $FastMacCacheIntervalParam
                }    
    
                $PauseFloodProtectionParam = " -enablePauseFloodProtection:`$pauseFloodProtection "

                # -------Clear out parameters used for Synergy
                $RedundancyParam        = ""
                $FabricModuleTypeParam  = ""
                $FrameCountParam        = $ICBaySetParam = ""
        

            }



            # Code and Parameters

            # ---- Bay config
            $baysParam              = " -Bays `$bayConfig "

            # ---- Description
            $descParam = $descCode = ""
            if ($description ) 
            {
                $descParam   = " -description `$description "
                $descCode    = @"
`$description            = '$description'
"@
            }

            # ---- igmp
            $igmpIdleTimeoutParam = $igmpIdleTimeoutCode = ""
            if ($igmpIdletimeOut)
            { 
                $igmpIdleTimeoutParam = " -IgmpIdleTimeOutInterval $igmpIdleTimeout " 
                $igmpIdleTimeoutCode  = @"
`$igmpIdletimeOut        = $igmpIdletimeOut
"@
            }
                
            $igmpParam                  = " -enableIGMP:`$igmpSnooping " + $igmpIdleTimeoutParam
            
            $networkLoopProtectionParam = " -enablenetworkLoopProtection:`$networkLoopProtection "

            $EnhancedLLDPTLVParam       = " -enableEnhancedLLDPTLV:`$EnableRichTLV"

            $LDPtaggingParam            = " -EnableLLDPTagging:`$LDPtagging "

            # --- Internal networks 
            $intnetParam                = $intnetCode = ""
            if ($intNetworkNames)
            {
                $intNetnames            = $intNetworkNames -join $Comma
                $intNetParam            = " -InternalNetworks `$intNetnames "
                $intnetCode             = @"
`$intNetnames            = @($intNetnames)
"@ 
            }

            

            $scriptCode     += @"
# -------------- Attributes for Logical Interconnect Group  $name
`$name                   = '$name'
$descCode
`$bayConfig              = $bayConfig 
$SynergyCode
$C7000Code
`$igmpSnooping           = [Boolean]$igmpSnooping
$igmpIdleTimeoutCode
`$EnableRichTLV          = [Boolean]$EnableRichTLV
`$LDPtagging             = [Boolean]$LDPtagging
`$networkLoopProtection  = [Boolean]$networkLoopProtection
$intnetCode
"@
        

            # -----------------
            # SNMP attributes
            $snmpParam         = ""
            if ($snmp)          # SAS Lig does not have snmpconfig
            {
                $isV1Snmp           = $snmp.enabled
                $isV3Snmp           = $snmp.v3Enabled

                $readCommunity      = $snmp.readCommunity 
                $contact            = $snmp.systemContact

                $readCommunityParam = ""
                if ($Contact)
                {
                    $snmpUsers          = $snmp.snmpUsers
                    $trapdestinations   = $snmp.trapDestinations
                    $scriptCode         += @"
`$trapDestinations       = @()        
"@
                    
                    foreach ($t in $trapdestinations)
                    {
                        $port           = $t.port
                        $inform         = if ($t.inform) { 1} else {0}
                    
                        $scriptCode     += @"
#--   Generating Trap destination object for $destination
`$destination            = $destination 
`$trapFormat             = $trapformat
`$port                   = $port 
`$inform                 = [Boolean]$inform
"@
                        
                        $communityParam = ""
                        if ($isV1Snmp)
                        {
                            $scriptCode      += @"
`$communitystring        = '$communitystr'
"@
                            $communityParam  = "  -Community `$communitystring "
                        }

                        $destParam      = " -destination `$destination "
                        $formatParam    = " -SnmpFormat `$trapformat "
                        $portParam      = " -port `$Port " 
                        $informParam    = " -NotificationType `$inform "

                        $scriptCode     += @"
`$trapDestinations       += New-HPOVSnmpTrapDestination $destParam $portParam ``
$communityParam $FormatParam $importParam

#------------------------------------ 


"@ 

                    }

                    $readCommunityParam     = " -readCommunity `$readCommunity "
                    $contactParam           = " -contact `$contact "
                    
                    if ($trapDestinations)
                    {
                        $trapdestParam          = " -trapDestinations `$trapDestinations "
                    }
                

                    $scriptCode     += @"
#-- Generating snmp object for LIG  
`$readCommunity          = '$readCommunity'
`$contact                = $destination

`$snmpConfig            += new-HPOVSnmpConfiguration $readCommunityParam  $contactParam $trapdestParam
                    
"@

                    $snmpParam      = " -snmp `$snmpConfig "
                
                }


            }
 

            $scriptCode     += @"

write-host -foreground CYAN " Creating logical Interconnect Group  --> `$name ........ "

`$lig                    = Get-HPOVLogicalInterconnectGroup | where name -eq `$name
if (-not `$lig)
{
    New-HPOVLogicalInterConnectGroup -name `$name  $descriptionParam ``
    $baysParam $fabricModuleTypeParam $redundancyParam $FrameCountParam $ICBaySetParam   ``
    $IgmpParam  $FastMacCacheParam  $networkLoopProtectionParam  $PauseFloodProtectionParam  ``
    $EnhancedLLDPTLVParam $LDPTaggingParam $intNetParam  $snmpParam
}
else
{
    write-host -foreground CYAN "Logical Interconnect group `$name already exists. Skip creating it...."
}

"@

        

        }
    
        Out-ToScriptFile -Outfile $outFile 



}




## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-uplinkSet-Script
##
## -------------------------------------------------------------------------------------------------------------

Function Generate-uplinkSet-Script ([string]$outfile, $list)
{
    
    $title = @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to create uplink sets
##
## -------------------------------------------------------------------------------------------------------------

"@    

    $scriptCode     = @()
    $Cmds           = ""

    $scriptCode     += "`n$title" + $CR

    $ListofLIGs     = $list
    foreach ($lig in $listofLIGs)
    {
        $ligName        = $lig.Name
        $enclosureType  = $lig.enclosureType
        $uplinkSets     = $lig.uplinksets | sort-object Name


        foreach ($upl in $uplinkSets)
        {
            $uplName            = $Upl.name
            $upLinkType         = $Upl.networkType
            $ethMode            = $Upl.mode
            $nativenetURIs      = $Upl.nativeNetworkUri
            $netTagtype         = $Upl.ethernetNetworkType
            $lacpTimer          = $Upl.lacpTimer
            $networkURIs        = $upl.networkUris
            $uplLogicalPorts    = $Upl.logicalportconfigInfos

            # ----------------------------
            # Find native Ethernet networks
            $nativeNamesArray = @()
            $nativeNamesArray = ""
            foreach ($nativeuri in $nativenetUris)
            {
                $nativeNetname      = Get-NamefromUri -uri $nativeuri
                $nativenetName      = "`'$nativenetname`'"
                $nativeNamesArray   += $nativeNetname
            }
            if ($nativeNamesArray)
                { $nativenetworkNames = $nativeNamesArray -join $Comma }

            # ----------------------------
            # Find networks
            $netNamesArray   = @()
            $networkNames    = ""
            foreach ($neturi in $networkUris)
            {
                $netName        = Get-NamefromUri -uri $neturi
                $netName        = "`'$netName`'"
                $netNamesArray  += $netName
            }
            if ($netNamesArray)
                { $networkNames = $netNamesArray -join $Comma }

            if ($uplinkType -eq 'FibreChannel')
            {
                    $fcSpeed    = if ($Upl.FCSpeed) { $Upl.FCSpeed } else { 'Auto' }
                    
            }

            
            # ----------------------------
            #     Find uplink ports
            $SpeedArray  = @()
            $UpLinkArray = @()

            $LigInterConnects = $lig.interconnectmaptemplate.interconnectmapentrytemplates

            foreach ($LigIC in $LigInterConnects | Where-Object permittedInterconnectTypeUri -ne $NULL )
            {
                # -----------------
                # Locate the Interconnect device
                $PermittedInterConnectType = Send-HPOVRequest $LigIC.permittedInterconnectTypeUri

                # 1. Find port numbers and port names from permittedInterconnectType
                $PortInfos     = $PermittedInterConnectType.PortInfos

                # 2. Find Bay number and Port number on uplinksets
                $ICLocation    = $LigIC.LogicalLocation.LocationEntries
                $ICBay         = ($ICLocation | Where-Object Type -eq "Bay").relativeValue
                $ICEnclosure   = ($IClocation | Where-Object Type -eq "Enclosure").relativeValue

                foreach ($logicalPort in $uplLogicalPorts)
                {
                    $ThisLocation     = $Logicalport.logicalLocation.locationEntries
                    $ThisBayNumber    = ($ThisLocation | Where-Object Type -eq "Bay").relativeValue
                    $ThisPortNumber   = ($ThisLocation | Where-Object Type -eq "Port").relativeValue
                    $ThisEnclosure    = ($ThisLocation | Where-Object Type -eq "Enclosure").relativeValue
                    $ThisPortName     = ($PortInfos    | Where-Object PortNumber -eq $ThisPortNumber).PortName

                    if (($ThisBaynumber -eq $ICBay) -and ($ThisEnclosure -eq $ICEnclosure))
                    {
                        if ($ThisEnclosure -eq -1)    # FC module
                        {
                            $UpLinkArray     += $("Bay" + $ThisBayNumber +":" + $ThisPortName)   # Bay1:1
                            $s               = $Logicalport.DesiredSpeed
                            $s               = if ($s) { $s } else {'Auto'}
                            $SpeedArray      += $s.TrimStart('Speed').TrimEnd('G')
                            # Don't sort UpLinkArray as it is linked to FCSpeedArray
                        }
                        else  # Synergy Frames or C7000
                        {
                            if ($enclosureType -eq $Syn12K) 
                            {
                                $ThisPortName    = $ThisPortName -replace ":", "."    # In $POrtInfos, format is Q1:4, output expects Q1.4
                                $UpLinkArray     += $("Enclosure" + $ThisEnclosure + ":" + "Bay" + $ThisBayNumber +":" + $ThisPortName)   # Ecnlosure#:Bay#:Q1.3
                            }
                            else # C7000
                            {
                                $UpLinkArray     += $("Bay" + $ThisBayNumber +":" + $ThisPortName)   # Ecnlosure#:Bay#:Q1.3
                            }
                            [Array]::Sort($UplinkArray)
                        }
                    }
                }
                $Uplinks        = @()
                foreach ($u in $UplinkArray)
                    { $Uplinks += "`'$u`'"}
                $UplinkPorts    = $Uplinks -join $Comma
                #$FCSpeed       = $SpeedArray  -join $Comma

            }



            # Uplink Ports
            $uplinkPortParam    = $uplinkPortCode    = ""
            if ($UplinkArray) 
            {
                $uplinkPortParam    = " -UplinkPorts `$uplinkPorts"
                $uplinkPortCode     = @"
`$uplinkPorts            = @($uplinkPorts) 
"@
            }
                
            # Networks
            $uplNetworkParam    = $uplNetworkCode = ""
            if ($netNamesArray)
            { 
                $uplNetworkParam    = " -Networks `$networks "
                $uplNetworkCode     = @"
`$networkNames           = @($networkNames)
`$networks               = `$networkNames  | % { Get-HPOVNetwork -name `$_}
"@
            }
            
            # Uplink Type
            if ($uplinkType -eq 'Ethernet')
            {
                $uplNativeNetParam      = $uplNativeNetCode = ""
                if ($nativeNamesArray)
                { 
                    $uplNativeNetParam    = " -nativeEthnetwork `$nativenetworks "
                    $uplNativeNetCode     = @"
`$nativeNetworkNames     = @($nativeNetworkNames) 
`$nativeNetworks         = `$nativenetworkNames  | % { Get-HPOVNetwork -name `$_} 
"@
                }

                $lacpTimerParam  =  $netAttributesParam  = $lacpTimerCode = $fcSpeedCode  = ""
                if ($lacpTimer) 
                { 
                    $lacpTimerParam         = " -lacptimer `$lacpTimer "
                    $netAttributesParam     = " -EthMode `$ethMode " + $uplNativeNetParam + $lacpTimerParam
                    $lacpTimerCode          = @"
`$ethMode                = '$ethMode'
`$lacpTimer              = '$lacpTimer' 
"@
                }
            }
            else # FC
            {
                $netAttributesParam     = " -fcUplinkSpeed `$FCSpeed "
                $fcSpeedCode            = @"
`$fcSpeed                = '$fcSpeed'
"@
            }

            $scriptCode         += @"
# -------------- Attributes for Uplink Set '$uplName' associated to lig '$ligName'
`$uplName                = '$uplName'
`$uplinkType             = '$uplinkType'
`$ligName                = '$ligName'
`$thisLIG                = Get-HPOVLogicalInterConnectGroup | where name -eq `$ligname 
$uplinkPortCode  
$uplNetworkCode
$uplNativeNetCode
$lacpTimerCode
$FCspeedCode

write-host -foreground CYAN " Creating uplink set   --> $uplname on lig ---> $ligname ........ "
`$upl                    = `$thisLIG.Uplinksets |  where name -eq `$uplName
if (-not `$upl)
{
    New-HPOVUplinkSet -lig `$thisLIG -name `$uplName -Type `$uplinkType ``
    $uplNetworkParam  $netAttributesParam  $uplinkPortParam
}
else
{
    write-host -foreground CYAN " Uplinkset `$uplName already exists. Skip creating it...."
}

"@
        }

    }
    
    Out-ToScriptFile -Outfile $outFile 




}

## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-EnclosureGroup-Script 
## 
## -------------------------------------------------------------------------------------------------------------

Function Generate-EnclosureGroup-Script ([string]$outfile, $list)
{
    
    $scriptCode  = @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to create Enclosure Group
##
## -------------------------------------------------------------------------------------------------------------

"@    
   
    $Cmds = ""
    $listofEncGroups     = $list


    foreach ($EG in $ListofEncGroups)
    {
        $name                   = $EG.name
        $description            = $EG.description
        $enclosureCount         = $EG.enclosureCount
        $powerMode              = $EG.powerMode

        $manageOSDeploy         = $EG.osDeploymentSettings.manageOSDeployment
        $deploySettings         = $EG.osDeploymentSettings.deploymentModeSettings
        $deploymentMode         = $deploySettings.deploymentMode

        $ipV4AddressType        = $EG.ipAddressingMode
        $ipRangeUris            = $EG.ipRangeUris
        $ICbayMappings          = $EG.InterConnectBayMappings
        $enclosuretype          = $EG.enclosureTypeUri.Split('/')[-1]

        # --- Find Enclosure Bay MApping

        ###
        if ($ICbayMappings )
        {
            $ICArray        = @()
            $ICperFrame     = $ICEthernet = $EGLigMapping = "" 

            if ($enclosuretype -eq $SYN12K)
            {
                $isMultipleInterconnect = $ICBayMappings[0].psObject.Properties.Name -contains 'EnclosureIndex'

                $ICbayMappings  = $ICBayMappings | sort enclosureIndex,interconnectBay

                foreach ($IC in $ICBayMappings  )                            # Entry looks like: enclosureIndex BayInterconnect Uri 
                {
                    $thisIndex  = $IC.enclosureIndex 
                    $thisIC     = Get-NamefromUri -uri $IC.logicalInterconnectGroupURI
                    $thisIC     = "`'$thisIC`'"
                    $thisIC     = [string]$thisIndex + $comma + $thisIC

                    if ($ICArray -notcontains $thisIC )                         # Same Interconnect Type?
                        {  $ICArray  += $thisIC  }                              # Build Array of typ Frame1|Uri with unique URi
                }


                if ($isMultipleInterconnect)
                {
                    $CurrentFrame           = $ICperframe = ""
                    [string[]]$FrameConfig  = @()

                    foreach ($IC in $ICArray)
                    {
                        $frame , $ICname    = $IC.Split($comma)
                        if ($FrameConfig.Count -eq 0)                               # First element
                        {
                            $ICperFrame     = "Frame$frame=$ICName$comma"         # Build format : Frame1=ICname1|ICname2
                            $CurrentFrame   = $frame
                            $frameConfig    = $ICperFrame
                        }
                        else  # Frame already registered
                        {
                            if ($frame -ne $currentFrame)
                            {
                                $CurrentFrame       = $frame
                                $frameConfig[-1]    = $ICperFrame.TrimEnd($comma)     # New frame then work on previous ICperframe
                                                                                        # remove $comma from last element
                                if ($frame)                                             
                                {
                                    $ICperframe     = "Frame$frame=$ICName$comma"     # Build format : Frame1=ICname1,ICname2
                                    $frameConfig    += $ICperFrame
                                }
                                else 
                                {
                                    $ICethernet     = $ICname                           # store ICname for VC 40GBF8 if there is any
                                    $ICperFrame     = ""    
                                }
                            }
                            else # same frame
                            {
                                $ICperFrame += $IcName + $comma                       # Add new ICname to existing element Frame1=Icname1,Icname2
                            }
                        }

                    }
                    if ($ICethernet)
                    {
                        $frameConfig = $frameConfig | % { $_ + $comma + $ICethernet}  # Add IC name for VC 40Gb if existed
                    }
                }
                        
                else # same Interconnect Type across frames
                {
                    $FrameConfig    =   $ICarray.TrimStart($Comma)                    # Build simple array and remove extra $sep at the beginning of string
                }

            } # end SY12000
            else    # C7000
            {
                $ICbayMappings  = $ICBayMappings | sort interconnectBay
                foreach ($IC in $ICBayMappings  )                               # Entry looks like: enclosureIndex BayInterconnect Uri 
                {
                    $thisBay    = $IC.InterconnectBay 
                    $thisIC     = Get-NamefromUri -uri $IC.logicalInterconnectGroupURI
                    $thisIC     = [string]$thisBay + $Equal + $thisIC
                    $ICArray    += $thisIC                                      # Build Array of type 1=Lig1 2=Lig1 5=Lig2 6=Lig2
                }

                $ICMappings      = $ICarray -join $Sep

            }

        }


        $descriptionParam = $desscriptionCode = ""
        if ($description) 
        {
            $descriptionParam       = " -description `$description "
            $descriptionCode        = @"
`$description            = '$description' 
"@
        }

        $ligMappingParam  = $ligMappingCode = ""
        if ($ICbayMappings)
        {
            $ligMappingParam        =  " -LogicalInterconnectGroupMapping `$ICMappings" 
            if ($enclosuretype -eq $Syn12K)
            {
                $ligperFrame = @()
                if ($Frameconfig[0] -like "Frame*")
                {
                    foreach ($config in $frameConfig)
                    {
                        $frame , $IClist = $config.Split($equal)
                        $index          = $frame[-1]

                        $ligMappingCode  = @"
`$lignames$index              = @($ICList)
`$ligs$index                  = `$lignames$index | % {Get-HPOVLogicalInterconnectGroup -name `$_ }
"@ 
                        $ligperFrame   += "$frame$equal`$ligs$index"
                    }
                    $ligperFrame        = $ligperFrame -join $SepHash
                    $ligMappingCode     += @"

`$ICMappings             = @{ $ligperFrame }
"@
                }
            
                else 
                {
                    $IClist = $frameConfig -join $Comma
                    $ligMappingCode  = @"
`$lignames               = @($IClist)
`$ligs                   = `$lignames| % {Get-HPOVLogicalInterconnectGroup -name `$_ }  
`$ICMappings             = `$ligs  
"@
                        
                }
            }
            else #C7K
            {
                $ligMappingCode  = @"
`$ICMappings              = @{$ICMappings}
"@
            }
        }


        #---- IP Address Pool
        $addressPoolParam       = $addressPoolCode     = ""
        if($ipV4AddressType -eq 'IPpool')
        {
            foreach ($rangeUri in $ipRangeUris)
            {
                $range          = Get-HPOVAddressPoolRange | where uri -eq $rangeUri
                $ipRangeNames   += "`'" + $range.name + "`'" 
            }
            $addressPoolNames    = $ipRangeNames -join $Comma
            $addressPoolParam    = " -addressPool `$addressPool "
            $addressPoolCode     = @"
`$addressPoolNames       = @($addressPoolNames)
`$addressPool            = `$addressPoolNames | % { Get-HPOVAddressPoolRange | where name -eq `$_}             
"@
        }

        # --- OS Deployment with IS
        $OSdeploymentParam           = $OSdeploymentCode          = ""
        if ($manageOSDeploy)
        {
                $OSdeploymentParam      = " -DeploymentNetworkType `$deploymentMode "
                $OSdeploymentCode       = @"
`$deploymentMode         = '$deploymentMode' 
"@
                if ($deploymentMode -eq 'External')
                {
                $deploynetworkname      = Get-NamefromUri -uri $deploySettings.deploymentNetworkUri
                $OSdeploymentParam     += " -deploymentnetwork `$deploymentnetwork  " 
                $OSdeploymentCode       = @"
`$deploynetworkname      = '$deploynetworkname'  
`$deploymentnetwork      = Get-HPOVnetwork -name `$deploynetworkname 
"@
                }

        }


        $enclosureCountParam    = " -enclosureCount `$enclosureCount "
        $powerModeParam         = " -PowerRedundantMode `$powerMode "
        
        
        

        $scriptCode         += @"
# -------------- Attributes for enclosure group $name 
`$name                   = '$name' 
$descriptionCode
$ligMappingCode
`$enclosureCount         =  $enclosureCount 
`$powerMode              = '$powerMode' 
`$ipV4AddressType        = '$ipV4AddressType' 
$addressPoolCode
$OSDeploymentCode

write-host -foreground CYAN " Creating enclosure group  --> `$name ........ "

`$eg                    = Get-HPOVEnclosureGroup | where name -eq `$name
if ( -not `$eg)
{
    New-HPOVEnclosureGroup -name $name $descParam $enclosureCountParam  $powerModeParam ``
    $liGMappingParam  $addressPoolParam  $OSdeploymentParam 
}
else 
{
    write-host -foreground CYAN "Enclosure Group `$name already exists. Skip creating it..."
}

"@ 
         
    }

     Out-ToScriptFile -Outfile $outFile 
}


## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-LogicalEnclosure-Script 
##
## -------------------------------------------------------------------------------------------------------------

Function Generate-LogicalEnclosure-Script ([string]$outfile, $list)
{
    
    $title = @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to create logical Enclosure
##
## -------------------------------------------------------------------------------------------------------------

"@    
   

    $ScriptCode = ""
    $Cmds       = ""

    $scriptCode                 += "`n$title" + $CR
    $listoflogicalenclosure     = $list
    foreach ($LE in $listoflogicalenclosure)
    {
        $name               = $LE.name
        $enclUris           = $LE.enclosureUris
        $EncGroupUri        = $LE.enclosuregroupUri
        $FWbaselineUri      = $LE.firmware.firmwareBaselineUri
        $FWinstall          = if ($LE.firmware.forceInstallFirmware) {1} else { 0 }

        $EGName             = Get-NamefromUri -uri $EncGroupUri
        $enclNames          = $enclUris | % { "`'" + $(Get-NamefromUri -uri $_) + "`'"}

        $enclNames          = $enclNames -join $Comma
        $egParam            = " -EnclosureGroup `$eg "
        $enclParam          = " -Enclosure `$enclosures[0] "
        
        $fwparam = $fwCode = ""
        if ($FWbaselineUri)
        {
            $fwName         = Get-NamefromUri -uri $FWbaselineUri
            $fwparam        = " -FirmwareBaseline `$fwBaseline -ForceFirmwareBaseline `$fwInstall"
            $fwCode         = @"
`$fwName             = '$fwName'
`$fwBaseline         =  Get-HPOVBaseline  -SPPname  `$fwName
`$fwInstall          = [Boolean]$fwInstall
"@   
        }

            $scriptCode     += @"

# -------------- Attributes for logical enclosure $name 
`$name               = '$name'
`$egName             = '$egName'    
`$eg                 = get-HPOVEnclosureGroup -name `$egName 
`$enclNames          = @($enclNames)
`$enclosures         = `$enclNames | % { Get-HPOVenclosure -name `$_} 
$fwCode

# --- Add logic to check whether logical enclosure already exists

write-host -foreground CYAN " Creating logical enclosure  --> `$name ........ "
`$encl              = Get-HPOVLogicalEnclosure | where name -eq  `$name 
if (-not `$encl)
{
    New-HPOVLogicalEnclosure -name `$name $enclParam $egParam $fwParam
}
else 
{
    write-host -foreground CYAN  "Logical enclosure `$name already exists. Skip creating it..."
}
"@

    }
   
    Out-ToScriptFile -Outfile $outFile 
}

## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-NetConnection-Script
##
## -------------------------------------------------------------------------------------------------------------
## 
Function Generate-NetConnection-Script 
{
    Param ( $ListofConnections)

    $ScriptConnection       = @()
    $ConnectionCmds         = ""
    $ConListArray           = @()

    foreach ($Conn in $ListofConnections)
    {
        $connID             = $Conn.id
        $connName           = $Conn.name
        $ConnType           = $Conn.functionType
        $netUri             = $Conn.networkUri
            $ThisNetwork    = Get-HPOVNetwork | where uri -eq $netUri
            if (-not $ThisNetwork)                      # could be networkset
            {
                $ThisNetwork    = Get-HPOVNetworkSet | where uri -eq $netUri
            }
            $netName        = $thisNetwork.name 
        $portID             = $Conn.portID
        $requestedVFs       = $Conn.requestedVFs
        $macType            = $Conn.macType
            $mac            = ""
            if ( ($connType -eq 'Ethernet') -and ($macType -eq "UserDefined"))
            {   
                $mac        = $Conn.mac -replace '[0-9a-f][0-9a-f](?!$)', '$&:'
            }

        $wwpnType           = $Conn.wwpnType
            $wwpn           = $wwnn = ""
            if (($connType -eq 'FibreChannel') -and ($wpnType -eq "UserDefined"))
            {   
                $mac        = $Conn.mac  -replace '[0-9a-f][0-9a-f](?!$)', '$&:'   # Format 10:00:11
                $wwpn       = $Conn.wwpn -replace '[0-9a-f][0-9a-f](?!$)', '$&:'
                $wwnn       = $Conn.wwnn -replace '[0-9a-f][0-9a-f](?!$)', '$&:'
            }

        $requestedMbps      = $Conn.requestedMbps 
        $allocatededMbps    = $Conn.allocatedMbps
        $maximumMbps        = $Conn.maximumMbps
        $lagName            = $Conn.lagName
        $bootPriority       = $Conn.boot.priority   
        $bootVolumeSource   = $Conn.boot.bootVolumeSource
        
        $mbpsParam = $mbpsCode = ""
        if ( ($requestedMbps -eq 'Auto') -and ($connType -eq 'FibreChannel'))
        {
            $requestedMbps      = 16000
        }
            $mbpsParam          = " -RequestedBW `$requestedMbps "
            $mbpsCode           = @"
`$requestedMbps         = $requestedMbps
"@          
  


        #--- MAC
        $userDefined           = $false
        $macParam              = $macCode = ''
        if ($mac)
        {
            $macParam          = " -userDefined -mac `$mac"
            $userDefined       = $true
            $macCode           = @"
`$mac               = '$mac'
"@          
        }

        #--- wwnn
        $wwwnParam  = $wwwNCode = ""
        if ($wwpn)
        {
            if ($userDefined)
            {
                $wwnParam          = " -wwpn `$wwpn -wwnn `$wwnn "
            }
            else 
            {
                $wwnParam          = " -userDefined -wwpn `$wwpn -wwnn `$wwnn "
            }
            $wwwNCode          = @"
`$wwpn                  = '$wwpn'
`$wwnn                  = '$wwnn'
"@
        }

        #--- Virtual Functions
        $requestedVfsParam   = $requestedVfsCode  = ""
        if ($requestedVFs)
        {
                $requestedVfsParam   = " -Virtualfunctions `$requestedVFs "
                $requestedVfsCode    = @"
`$requestedVFs          = $RequestedVFs
"@
        }

        # ---- lag
        $lagParam            = $lagCode = ""
        if ($lagName)
        {
            $lagParam            = " -lagName `$lagName "
            $lagCode             = @"
`$lagName               = '$lagName' 
"@
        }

###


        #--- bootable
        $bootableParam  = $bootableCode = ""
        if ($bootPriority) 
        {
            $bootableParam       = " -priority `$bootpriority "
            $bootableCode        = @"
`$bootPriority          = '$bootPriority'
"@
            $BootVolumeSourceCode =  ""
            if ($bootPriority -ne  "NotBootable")
            {
                $bootableParam        += " -bootable -bootVolumeSource `$bootVolumeSource " 
                $BootVolumeSourceCode = @"
`$bootVolumeSource      = '$bootVolumeSource'
"@
            
                if ($bootVolumeSource -eq 'UserDefined')
                {
                    $targets            = $Conn.boot.targets
                    $ovLibVersion       = (Get-HPOVVersion).LibraryVersion
                    $libVersion         = "$($ovLibVersion.Major).$($ovLibVersion.Minor)"

                    $elementArray       = @()
                    foreach ($t in $targets)
                    {
                        $wwpn           = $t.arrayWwpn -replace '[0-9a-f][0-9a-f](?!$)', '$&:'
                        $lun            = $t.lun
                        $elementArray   += "@{ wwpn = `'$wwpn`' ; lun= $lun } "
                    }
                    if ($libVersion -ge '4.1')
                    {
                        $elementStr         = $elementArray -join ","
                        $ScriptConnection  +=@"
`$targets               = @($elementStr)
"@
                        # TBD Parameters to be defined here
                    }
                    else 
                    {
                        $targetWwpn     = $targets[0].arrayWwpn -replace '[0-9a-f][0-9a-f](?!$)', '$&:'
                        $lun            = $targets[0].lun
                    
                        #Code and parameters
                        $ScriptConnection  += @"
`$targetwwpn            = '$targetWwpn'
`$lun                   = $lun 
"@
                        $bootableParam      += " -targetWwpn `$Targetwwpn -LUN `$lunID "
                    }
                
                }         
            }
        }


###


        $ScriptConnection   += @"
# -------------- Attributes for connection $connID
`$connID                = $ConnID 
`$connName              = '$ConnName'
`$netName               = '$netName'
`$ThisNetwork           = Get-HPOVNetwork | where name -eq `$netName
if ( -not `$ThisNetwork )
    {`$ThisNetwork      = Get-HPOVNetworkSet | where name -eq `$netName }       # Try NetworkSet
`$portID                = '$PortID'
#`$name 
$mbpsCode
$macCode
$wwwNCode
$requestedVfsCode  
$bootableCode 
$bootVolumeSourceCode
$lagCode
`$Con$connID            = New-HPOVServerProfileConnection -ConnectionID `$connID -name `$connName ``
-Network `$ThisNetwork -PortId `$portID $macParm  $wwnParam ``
$requestedVFsParam    $mbpsParam $lagParam $bootableParam 

"@
    

        $ConListArray           += "`$Con$connID"
    }
    

    $ConnectionList      = $ConListArray -join $Comma
    $ScriptConnection   += @"

    # List of network connections for profile is
`$connectionList        = @($ConnectionList)
    
"@

    return $ScriptConnection , "connectionList"
}

## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-LocalStorage-Script
##
## -------------------------------------------------------------------------------------------------------------

Function Generate-LocalStorage-Script 
{
    Param ( $list)

    $ScriptController        = @()
    $ControllerArray         = @()
    $controllerParam         = ""
    $i                       = 100    # This is just for embeddded drive so uses  count down to avoid interfering with logical disks created externally 
    $listofControllers       = $list.controllers
    $listofSASJBODs          = $list.sasLogicalJBODs

    foreach ($cont in $listofControllers)
    {
        $deviceSlot          = $cont.deviceSlot
        $mode                = $cont.mode
        $initialize          = if ($cont.initialize) {1} else {0}
        $importConfiguration = if ($cont.importConfiguration) {1} else {0}
        $logicalDrives       = $cont.logicalDrives

         ###
         $listofSASJBODs | % { $dt = $_.driveTechnology ; $_.driveTechnology = if ($dt) {$DriveTypeValues[$dt]} else {$dt} }
      
        if ($logicalDrives)
        {
            $ldIndex   = $logicalDrives| where deviceSlot -ne 'Embedded'  | % { $_.sasLogicalJBODId}
            if ($ldIndex)
            {
                $JBODList     =  $listofSASJBODs | where {$ldIndex -notcontains $_.id}
            }
        }
        else 
        {
            $JBODList     =  $listofSASJBODs 
        }

        write-host "new JBODList"
        $JBODList | Out-Host

         ###
         $elementArray        = @()
         $logicalDiskCode      =   ""

        $index = @()
        $JBODList = $NULL  
        if ($logicalDrives)
        {             
            foreach ($ld in $logicalDrives )
            {
                
                $raidLevel        = $ld.raidLevel
                $bootable         = if ($ld.bootable) {1} else {0} 
                $sasLogJBODId     = $ld.sasLogicalJBODId
                $accelerator      = $ld.accelerator

                $name             = $ld.name
                $numPhysDrives    = $ld.numPhysicalDrives
                $driveTechnology  = $ld.driveTechnology
                $driveNumber      = $i++  
                
                 ## BIG ASUMPTION HERE
                 $driveSelection  = 'SizeAndTechnology'

                 $ldParams = ""
                if ($deviceSlot -ne 'Embedded')
                {
                    # Collect SasLogicalJBODID
                    $index            += $sasLogJBODId

                    # Get Ld attributes from SASlogJBOD
                    $thisld           = $listofSASJBODs | where Id -match  $sasLogJBODId             
                        $name            = $thisld.name
                        $driveNumber     = $thisld.Id  
                        $numPhysDrives   = $thisld.numPhysicalDrives
                        $driveMinSizeGB  = $thisld.driveMinSizeGB 
                        $driveMaxSizeGB  = $thisld.driveMaxSizeGB 
                        $driveTechnology = $thisld.driveTechnology
                        $eraseData       = if ($thisld.eraseData) {1} else {0} 
                    $ldParams            = " -MinDriveSize `$driveMinSizeGB -MaxDriveSize `$driveMaxSizeGB  -eraseDataonDelete `$eraseData -driveSelectionBy `$driveSelection "
                }
                else 
                {
                    if ($driveTechnology)
                    {
                        $driveTechnology = $DriveTypeValues[$driveTechnology]
                    }  
                }




                $logicalDiskCode += @"
`$name                  = '$name'
`$bootable              = [Boolean]$bootable
`$raidLevel             = '$raidLevel'
`$numPhysDrives         = $numPhysDrives
`$driveTechnology       = '$driveTechnology'
`$driveMinSizeGB        = $driveMinSizeGB
`$driveMaxSizeGB        = $driveMaxSizeGB
`$driveSelection        = '$driveSelection'
`$eraseData             = [Boolean]$eraseData


      
`$ld$driveNumber        =  New-HPOVServerProfileLogicalDisk -Name `$name -raid `$raidLevel -bootable `$bootable ``
-driveType `$driveTechnology  $ldParams ``
 -numberofDrives `$numPhysDrives  

"@

                $elementArray     += "`$ld$driveNumber" 
            }

            
        }


        if ( $importConfig -and ($deviceSlot -notlike 'Mezz*') )
        {
            $diskControllerCode     = @"
`$importConfig          = [Boolean]$importConfig
`$Controller$i          = new-HPOVServerProfileLogicalDiskController -ControllerID `$deviceSlot ``
-mode `$mode -initialize:`$initialize -ImportExistingConfiguration `$importConfig
"@
        }
        else 
        {
            if ($elementArray)
            {
                $elementArrayStr    = $elementArray -join $comma
                $diskControllerCode = @"
$logicalDiskCode
`$driveList             = @($elementArrayStr)
`$Controller$i          = new-HPOVServerProfileLogicalDiskController -ControllerID `$deviceSlot ``
-mode `$mode -initialize:`$initialize  -logicalDisk  `$driveList 
"@
            }
        }
 
        $ScriptController  +=$Controller
        $ControllerArray   += "`$Controller$i "
        $i++
    

    $ScriptController    += @"
# ----------- Local Storage Controller '$deviceSlot' Attributes
`$deviceSlot            = '$deviceSlot'          
`$mode                  = 'RAID'            # Temporarily set to RAID. Query retruns in variable `$mode  which is set to mixed               
`$initialize            = [Boolean]$initialize
$diskControllerCode

"@
    } # end foreach

    if ($ControllerArray)
    {
        $ControllerArrayStr     = $controllerArray -join $Comma
        $ScriptController    += @"

            
        # List of local storage connections for profile is
`$controllerList        = @($ControllerArrayStr)

"@
    }

    return $ScriptController, "controllerList"
}


## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-SANStorage-Script
##
## -------------------------------------------------------------------------------------------------------------

Function Generate-SANStorage-Script  
{
    Param ( $list, $profilename)

    $SANstorageList             = $list
    foreach ($sts in $SANstorageList)
    {
        $hostOSType             = $sts.hostOSType
            $hostOSType         = $HostOSList[$hostOSType]
        $IsManagedSAN           = $sts.manageSanStorage
            $manageSanStorage   = if ($IsManagedSAN) {1} else {0}
        $volumeAttachment       = $sts.volumeAttachments
        foreach ($vol in $volumeAttachment)
        {
            $volID              = $vol.id
            $isBootVolume       = if ($vol.isBootVolume) { 1} else {0}
            $lunType            = $vol.lunType
            if ($lunType -ne 'Auto')
            {
                $lunID          = $vol.lun
            }
            $volProperty        = $vol.volume.properties
                $name           = $volProperty.name
                $description    = $volProperty.description
                $size           = $vol.Property.size/ 1GB
                $isShareable    = if ($volProperty.isShareable) {1} else {0}
                $isDeduplicated = if ($volProperty.isDeduplicated) {1} else {0}
                $provisionType  = $volProperty.provisioningType
                $storagepoolUri = $volProperty.storagePool

            $templateUri        = $vol.volume.templateUri 
        
            
            # LunId and lunIdType
            $lunTypeParam       = " -lunIDType `$lunIdType "
            if ($lunType -ne 'Auto')
            {
                $lunParam       += " -lunID `$lunID "
                $lunIDcode      = @"
`$lunID                = $lunID
"@
            }
            $lunTypeCode        = @"
`$lunIdType            = '$lunType'
$lunIDcode
"@
            # Volume Template
            if ($templateUri)
            {
                $template       = send-HPOVRequest -uri $templateUri
                $isRoot         = $template.isRoot
                if (-not $isRoot)
                {
                    $volumeParam        = $volumeCode = ""
                    $volTemplateName    = $template.name
                    $volTemplateParam   = " -name `$name -VolumeTemplate `$volumeTemplate "
                    $volTemplateCode    = @"
`$volTemplateName      = '$volTemplateName'  
`$volumeTemplate       = Get-HPOVStorageVolumeTemplate -name `$volTemplateName
"@
                }
                else 
                {
                    $volTemplateParam   =  $volTemplateCode = ""

                    ## 2 scenarios here. Either it's new volume or existing volume
                    $thisVolume         = get-HPOVStorageVolume  |where name -eq "$name"
                    if ($thisVolume)
                    {
                        $volumeParam        = " -volume `$name "
                        $volumeCode         = ""
                    }
                    else
                    {
                        $storagePoolName    = get-NamefromUri -uri $storagepoolUri 
                        $volumeParam        = " -Name `$name  -storagePool  `$storagePool"
                        $volumeCode         = @"
`$storagePoolName      = '$storagePoolName'
`$storagePool          = Get-HPOVStoragePool -name `$storagePoolName
"@
                    }


                }
            }


            $ScriptSANstorage     += @"

# ----------- SAN volume attributes for profile '$profilename'
`$name                 = '$name'
$volTemplateCode
$volumeCode
`$profilename          = '$profilename'
`$profile              = get-HPOVserverProfileTemplate -name `$profilename # Try template first
if ( -not `$profile)
{
    `$profile          = get-HPOVserverProfile -name `$profilename # Try profile
}
`$volumeID             = $volID
`$capacity             = $size
`$provisioningType     = '$provisionType'
$lunTypeCode
`$hostOStype           = '$hostOStype'
`$isBootVolume         = [Boolean]$isBootVolume

new-HPOVServerProfileAttachVolume $volTemplateParam $volumeParam  -ServerProfile `$profile ``
-VolumeID `$volumeID -Capacity `$size $LunTypeParam -HostOStype `$HostOSType -BootVolume:`$isBootVolume

"@
        } # end of foreach volattachment
    }

    return $scriptSANstorage

}

## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-Profile-Script
##
## -------------------------------------------------------------------------------------------------------------

Function Generate-Profile-Script ( $List ,$outFile)
{

    $scriptCode = @"
## -------------------------------------------------------------------------------------------------------------
##
##                    Code to create server profile
##
## -------------------------------------------------------------------------------------------------------------

"@    



        foreach ($SPT in $List)
        {
            # ------- Network Connections

            $netConnectionParam                 = $netConnectionCode = ""
            $ListofConnections                  = $SPT.connectionSettings.connections
            if ($listofConnections)
            {
                $netConnectionCode, $varstr      = Generate-NetConnection-Script -ListofConnections $ListofConnections 
                $netConnectionParam              = "  -connections `$$varstr "
            }

                

            # ------- Local Storage Connections

            $LOCALStorageCode                   = $LOCALStorageParam = ''
            $ListoflocalStorage                 = $SPT.localStorage
            if ($ListoflocalStorage )
            {
                $LOCALStorageCode, $varstr      = Generate-LocalStorage-Script -list  $listoflocalStorage
                $LOCALStorageParam              = " -LocalStorage:`$true -StorageController `$$varstr " 
            }

            # ---------- SAN storage Connection
            $SANStorageList = $SPT.SanStorage
            $ManagedStorage = $SPT.SanStorage.manageSanStorage

            # ---------- 
            $name           = $SPT.Name   
            $description    = $SPT.Description 
            $serverUri      = $SPT.serverHardwareUri
            $templateUri    = $SPT.serverProfileTemplateUri 
            $egUri          = $SPT.enclosureGroupUri
            $EnclosureBay   = $SPT.EnclosureBay
            $shtUri         = $SPT.ServerHardwareTypeUri
            $affinity       = $SPT.affinity 
            
            $fw                 = $SPT.firmware
            $isFwManaged        = $fw.manageFirmware
            $fwManaged          = 0
            if ($isFwManaged)
            {
                $fwManaged      = 1
                $fwInstallType  = $fw.firmwareInstallType
                $fwForceInstall = if ($fw.forceInstallFirmware ) {1} else {0}
                $fwActivation   = $fw.firmwareActivationType
                $dtFw           = ''
                if ($fwActivation -eq 'Scheduled')
                {
                    $dtFw       = $fw.firmwareScheduleDateTime
                }

                $fwBaseUri      = $fw.firmwareBaselineUri
                    $fwBase     = Send-HPOVRequest -uri $fwBaseUri
                    $sppName    = $fwBase.name
                
            }

            $bm                 = $SPT.bootMode
            $isbootModeManaged  = $bm.manageMode
            if ($isbootModeManaged)
            {
                $bootMode       = $bm.mode
                $bootPXE        = $bm.pxeBootPolicy
                $bootSecure     = $bm.secureBoot
            }

            $bo                 = $SPT.boot
            $isBootManaged      = $bo.manageBoot
            $bootManaged        = 0
            if ($isBootManaged)
            {
                $bootManaged    =  1
                $orderArray     = $bo.order
                $orderArray     = $OrderArray | % { "'" + $_ + "'" }
                $order          = $orderArray -join $comma

            }

            # -------------- description
            if ($desc)
            { 
            $descParm      = " -description `$description "
            $ScriptCode    += @"
`$description            = '$description'  
"@ 
            }
            
            # --------------------------- Server Hardware
            $serverCode      = ""
            $assignmentParam = "-AssignmentType `$assignmentType " 
            if ($serverUri)
            {               
                $thisServer  = send-HPOVRequest $serverUri
                $serverName  = $thisServer.Name

                $ServerParam     = " -server `$server $assignmentParam  " 

                $ServerCode      = @"
`$serverName             = '$serverName'
`$server                 = Get-HPOVServer -name `$serverName
`$assignmentType         = 'server'
"@                 
            }
            else 
            {
                $ServerCode     = @"
`$assignmentType         = 'unassigned'  
"@ 
                $ServerParam     = $assignmentParam 
                $EnclosureBayParam = $SHTParam = ""
            }

            # --------------------------- Created from template?
            
            if ($templateUri)
            {
                $connectionParam = $connectionCode  = ""
                # --------------------------- Server Template                 
                $thisTemplate       = send-HPOVRequest -uri $templateUri
                $templateName       = $thisTemplate.Name

                $TemplateParam      = " -ServerProfileTemplate `$template "
                $templateCode       = @"
`$templateName           = '$templateName'
`$template               = Get-HPOVServerProfileTemplate -Name `$templateName 
"@

                $enclosureBayParam  = $enclosureBayCode = ""
                $shtParam           =  $shtCode         = ""
                $affinityParam      = $affinityCode     = ""

            } # end of template 
            
            else    # Create profile from scratch
            {
                $templateParam  = $templateCode           = ""

                # ------------------------------- Connections
                $connectionParam = $netConnectionParam + $LOCALStorageParam 
                $connectionCode = @"
#       Network Connection
$netConnectionCode
#       Local Storage
$LOCALstorageCode
"@

                # ------------------------------- San Storage
                if ( (-not $templateParam) -and ($ManagedStorage) )
                {
                $storageCode           = Generate-SANStorage-Script -list $SANstorageList -profilename $name
                $SANstorageCode        = @"

write-host -foreground CYAN " Attaching SAN storage to profile `$name ..."

$storageCode

"@
                }

                # ------------------------------- Enclosure Group and Enclosure Bay
                $thisEG             = send-HPOVRequest -uri $egUri
                $egName             = $thisEG.Name


                $enclosureBayParam  = " -Enclosure `$enclosure -EnclosureBay `$EnclosureBay " 
                $enclosureBayCode   = @"
`$egName                 = '$egName'
`$enclosure              = Get-HPOVEnclosureGroup -name `$egName 
`$EnclosureBay           = $EnclosureBay 
"@ 

                # ------------------------------- SHT
                $thisSHT            = send-HPOVRequest -uri $shtUri
                $shtName            = $thisSHT.name
                
                $BIOSsettingID = @()
                    $Model          = $ThisSHT.Model
                    $IsDL           = $Model -like '*DL*'
                    $ThisSHT.BIOSSettings | % { $BIOSsettingID += $_.ID}  # Collect BIOSSettings ID
                
                $shtParam           = " -Serverhardwaretype `$sht "
                $shtCode            = @"
`$shtName                = '$shtName'
`$sht                    =  Get-HPOVServerHardwareType -name `$shtName 
"@
                            
                # --------------------------- Affinity
                $affinityParam      = " -affinity `$affinity "
                $affinityCode       = @"
`$affinity               = '$affinity' 
"@ 
     
                # ---------------------------- Firmware Baseline
                $fwParam = $fwCode = ""
                if ($fwBaseUri)
                {
                    $fwParam        = " -firmware:`$fwManaged -Baseline `$fwbaseline "
                    $fwParam        += " -FirmwareInstallMode `$fwInstallType -ForceInstallFirmware:`$fwForceInstall "
                    $fwParam        += " -FirmwareActivationMode `$fwActivation "
                    
                    #--- Active Date time
                    $dtFWCode        = ""
                    if ($dtFw)
                    {
                        $FWParam     += " -FirmwareActivateDateTime `$firmwareActiveDate " 
                        $dtFWcode    = @"
`$firmwareActiveDate     = [DateTime]'$dtFW' 
"@
                    }

$fwCode         = @"
`$fwManaged              = [Boolean]$fwManaged
`$sppName                = '$sppName'
`$fwBaseline             = Get-HPOVbaseline -SPPname `$sppName
`$fwInstallType          = '$fwInstallType'
`$fwForceInstall         = [Boolean]$fwforceInstall
`$fwActivation           = '$fwActivation'
$dtFWCode
"@ 
                }

                # Managed Boot
                $bootModeManagedParam =$bootModeManagedCode    = $bootPXEcode = ""
                if ($isBootModeManaged)
                {
                    $bootModeManagedParam   = " -bootMode `$bootMode -SecureBoot `$bootSecure "
                    if ($bootPXE)
                    {
                        $bootModeManagedParam += "  -PxeBootPolicy `$bootPXE "
                        $bootPXECode         = @"
`$bootPXE            = '$bootPXE'
"@
                    }
                $bootModeManagedCode     = @"
`$bootMode           = '$bootMode'
$bootPXECode
`$bootSecure         = '$bootSecure'
"@
                }


                # ---- Boot Order
                $bootOrderParam = $bootOrderCode = ""
                if ($isBootManaged)
                {
                    $bootOrderParam     = " -Manageboot:`$bootManaged -BootOrder `$bootOrder"
                    $bootOrderCode      = @"
`$bootManaged        = [Boolean]$BootManaged
`$bootOrder          = @($order)
"@
                }

            } # end of create standalone profile

            ##

            $ScriptCode            += @"
# -------------- Attributes for server profile '$name' 
$connectionCode
`$name                   = '$name'
$descCode
$serverCode
$templateCode
$enclosureBayCode
$shtCode
$affinityCode
$fwCode
$bootModeManagedCode 
$bootOrderCode


write-host -foreground CYAN " Creating server profile   --> `$name ........ "
`$thisprofile        = Get-HPOVServerProfile | where name -eq  `$name
if (-not `$thisprofile)
{
    if (`$server.PowerState -eq 'On')
    {
        stop-HPOVserver -inputobject `$server
    }
    
    `$sprofile = New-HPOVServerProfile -name `$name $descParam $serverParam $templateParam ``
$enclosureBayParam $shtParam $affinityParam ``
$fwParam ``
$bootModeManagedParam $bootOrderParam `` 
$ConnectionParam  

    if (`$sprofile.taskState -eq 'Error')
    {
        `$sprofile.taskErrors | fl *
    }
    else
    {
        $SANstorageCode        
    }

}
else
{
    write-host -foreground CYAN " profile '`$name' already exists. Skip creating this..."
   
}

"@
             
             

        }

        Out-ToScriptFile -Outfile $outFile 
} 



## -------------------------------------------------------------------------------------------------------------
##
##                     Function Generate-ProfileTemplateScript
##
## -------------------------------------------------------------------------------------------------------------

Function Generate-ProfileTemplate-Script ( $List ,$outFile)
{

    $scriptCode      = @"

## -------------------------------------------------------------------------------------------------------------
##
##                    Code to create server profile template
##
## -------------------------------------------------------------------------------------------------------------

"@    


    foreach ($SPT in $List)
    {
        # ------- Network Connections

        $netConnectionParam                 = $netConnectionCode = ""
        $ListofConnections                  = $SPT.connectionSettings.connections
        if ($listofConnections)
        {
            $netConnectionCode, $varstr      = Generate-NetConnection-Script -ListofConnections $ListofConnections 
            $netConnectionParam              = " -manageConnections:`$true  -connections `$$varstr "
        }

            
        # ------- Local Storage Connections

        $LOCALStorageCode                   = $LOCALStorageParam = ''
        $ListoflocalStorage                 = $SPT.localStorage
        if ($ListoflocalStorage )
        {
            $LOCALStorageCode, $varstr      = Generate-LocalStorage-Script -list  $listoflocalStorage
            $LOCALStorageParam              = " -LocalStorage:`$true -StorageController `$$varstr " 
        }


        # ---------- SAN storage Connection
        $SANStorageList = $SPT.SanStorage
        $ManagedStorage = $SPT.SanStorage.manageSanStorage

            $name               = $SPT.Name   
            $description        = $SPT.Description 
            $spDescription      = $SPT.serverprofileDescription
            $shtUri             = $SPT.serverHardwareTypeUri
            $egUri              = $SPT.enclosureGroupUri
            $affinity           = $SPT.affinity 
            $hideFlexNics       = if ($SPT.hideUnusedFlexNics) {1} else {0}
            $macType            = $SPT.macType
            $wwnType            = $SPT.wwnType
            $snType             = $SPT.serialNumberType       
            $iscsiType          = $SPT.iscsiInitiatorNameType 
            $osdeploysetting    = $SPT.osDeploymentSettings

            $fw                 = $SPT.firmware
            $isFwManaged        = $fw.manageFirmware
            $fwManaged          = 0
            if ($isFwManaged)
            {
                $fwManaged      = 1
                $fwInstallType  = $fw.firmwareInstallType
                $fwForceInstall = if ($fw.forceInstallFirmware ) {1} else {0}
                $fwActivation   = $fw.firmwareActivationType

                $fwBaseUri      = $fw.firmwareBaselineUri
                    $fwBase          = Send-HPOVRequest -uri $fwBaseUri
                    $sppName         = $fwBase.name
            
            }
        

            $bm                 = $SPT.bootMode
            $isbootModeManaged  = $bm.manageMode
            if ($isbootModeManaged)
            {
                $bootMode       = $bm.mode
                $bootPXE        = $bm.pxeBootPolicy
                $bootSecure     = $bm.secureBoot
            }

            $bo                 = $SPT.boot
            $isBootManaged      = $bo.manageBoot
            $bootManaged        = 0
            if ($isBootManaged)
            {
                $bootManaged    =  1
                $orderArray     = $bo.order
                $orderArray     = $OrderArray | % { "'" + $_ + "'" }
                $order          = $orderArray -join $comma

            }

            $bios               = $SPT.bios
            $isBiosManaged      = $bios.manageBios
            $biosManaged        = 0
            if ($isBiosManaged)
            {
                $biosManaged    = 1
                $settingArray   = $bios.overridenSettings
                $settingArray   = $settingArray | % { "'" + $_ + "'" }
                $settings       = $settingArray -join $comma
            }

        
            # Param and code

            $sht                = send-HPOVRequest  -uri $shtUri
            $shtName            = $sht.name
            
            $eg                 = send-hpovRequest -uri $egUri
            $egName             = $eg.name

            $descriptionParam   = $descriptionCode = ""
            if ($description)
            {
                $descriptionParam = " -description `$description "
                $descriptionCode  = @"
`$description        = '$description' 
"@
            }

            $spdescriptionParam = $spdescriptionCode = ""
            if ($spdescription)
            {
                $spdescriptionParam = " -serverprofiledescription `$spdescription "
                $spdescriptionCode  = @"
`$spdescription      = '$spdescription' 
"@
            }

            # --- FW 
            $fwParam = $fwCode = ""
            if ($isFWmanaged)
            {
                $fwParam        = " -firmware:`$fwManaged -Baseline `$fwbaseline "
                $fwParam        += " -FirmwareInstallMode `$fwInstallType -ForceInstallFirmware:`$fwForceInstall "
                $fwParam        += " -FirmwareActivationMode `$fwActivation "
                


$fwCode         = @"
`$fwManaged           = [Boolean]$fwManaged
`$sppName             = '$sppName'
`$fwBaseline          = Get-HPOVbaseline -SPPname `$sppName
`$fwInstallType       = '$fwInstallType'
`$fwForceInstall      = [Boolean]$fwforceInstall
`$fwActivation        = '$fwActivation'
"@ 
            }

            # ---- Boot Order
            $bootOrderParam = $bootOrderCode = ""
            if ($isBootManaged)
            {
                $bootOrderParam     = " -Manageboot:`$bootManaged -BootOrder `$bootOrder"
                $bootOrderCode      = @"
`$bootManaged        = [Boolean]$bootManaged
`$bootOrder          = @($order)
"@
            }

            # Managed Boot
            $bootModeManagedParam =$bootModeManagedCode    = $bootPXEcode = ""
            if ($isBootModeManaged)
            {
                $bootModeManagedParam   = " -bootMode `$bootMode -SecureBoot `$bootSecure "
                if ($bootPXE)
                {
                    $bootModeManageParam += "  -PxeBootPolicy `$bootPXE "
                    $bootPXECode         = @"
`$bootPXE            = '$bootPXE'
"@
                }
                $bootModeManagedCode     = @"
`$bootMode           = '$bootMode'
$bootPXECode
`$bootSecure         = '$bootSecure'
"@

            }

            # ---- BIOS
            $biosParam              = $biosCode = ""
            if ($isBiosManaged)
            {
                $biosCode       = @"
`$biosManaged        = '[Boolean]$biosManaged'
`$biossettings       = @($biosSettings)
"@
            }

            
            # ------------------------------- Connections
            $connectionParam = $netConnectionParam + $LOCALStorageParam 
            $connectionCode = @"
#       Network Connection
$netConnectionCode
#       Local Storage
$LOCALstorageCode
"@

            # ------------------------------- San Storage
            if  ($ManagedStorage) 
            {
            $storageCode           = Generate-SANStorage-Script -list $SANstorageList -profilename $name
            $SANstorageCode        = @"

write-host -foreground CYAN " Attaching SAN storage to profile `$name ..."

$storageCode

"@
            }
            
            $scriptCode         += @"

# -------------- Attributes for profile template '$name' 
#       Network Connection - Local Storage
$ConnectionCode

`$name               = '$name'
`$shtName            = '$shtName'
`$sht                = Get-HPOVServerHardwareType | where name -eq `$shtName
$descriptionCode    
$spdescriptionCode  
`$egName             = '$egName'
`$eg                 = Get-HPOVEnclosureGroup | where name -eq `$egName
$fwCode
$biosCode
$bootOrderCode
$bootModeManagedCode
`$affinity           = '$affinity'
`$hideFlexNics       = [Boolean]$hideFlexNics
`$macType            = '$macType'
`$wwnType            = '$wwnType'
`$snType             = '$snType'
`$iscsiType          = '$iscsiType'


write-host -foreground CYAN " Creating server profile template --> `$name ........ "
`$thisSPT            = Get-HPOVServerProfileTemplate | where name -eq  `$name
if (-not `$thisSPT)
{ 
    `$spt = New-HPOVServerProfileTemplate -Name `$name  ``
    -ServerHardwareType `$sht -EnclosureGroup `$eg ``
    $descriptionParam $spdescriptionParam ``
    $netConnectionParam $LOCALStorageParam ``
    $fwParam $biosParam ``
    -affinity `$affinity -HideUnusedFlexNics `$hideFlexNics  ``
    $bootModeManagedParam $bootOrderParam ``
    -MacAssignment `$macType -WwnAssignment `$wwnType -SnAssignment `$snType

    if (`$spt.taskState -eq 'Error')
    {
        `$spt.taskErrors | fl *
    }
    else
    {
        $SANstorageCode        
    }
}
else
{
    write-host -foreground CYAN " Server profile template `$name already exists. Skip creating it.... "
}
"@

        }

        Out-ToScriptFile -Outfile $outFile 
}









# -------------------------------------------------------------------------------------------------------------
#
#       Main Entry
#
# -------------------------------------------------------------------------------------------------------------

# ---------------- Unload any earlier versions of the HPOneView POSH modules
#
Remove-Module -ErrorAction SilentlyContinue HPOneView.120
Remove-Module -ErrorAction SilentlyContinue HPOneView.200
Remove-Module -ErrorAction SilentlyContinue HPOneView.300
Remove-Module -ErrorAction SilentlyContinue HPOneView.310
Remove-Module -ErrorAction SilentlyContinue HPOneView.400

$testedVersion  = [int32] ($OneviewModule.Split($Dot)[1])

if ( ($testedVersion -ge 400) -or  (-not (get-module $OneViewModule)) )
{
    Import-Module -Name $OneViewModule
}
else 
{
    write-host -ForegroundColor YELLOW "Oneview module not found or version is lower than v4.0. The script is not developed for downlevel version of Oneview. Exiting now. "
    exit
}

# ---------------- Connect to Synergy Composer
#
if (-not $ConnectedSessions)
{
    if ((-not $OVApplianceIP) -or (-not $OVAdminName) -or (-not $OVAdminPassword))
    {

        $OVApplianceIP      = Read-Host 'Synergy Composer IP Address'
        $OVAdminName        = Read-Host 'Administrator Username'
        $OVAdminPassword    = Read-Host 'Administrator Password' -AsSecureString	 
    } 
	
    $ApplianceConnection = Connect-HPOVMgmt -appliance $OVApplianceIP -user $OVAdminName -password $OVAdminPassword  -AuthLoginDomain $OVAuthDomain -errorAction stop

}

if (-not $global:ConnectedSessions) 
{
    Write-Host "Login to Synergy Composer or OV appliance failed.  Exiting."
    Exit
} 
else 
{

    $scriptPath                             = "$PSscriptRoot\Scripts"
    if (-not (Test-path $scriptPath))
        {   $scriptFolder = md $scriptPath}

    $OVEthernetNetworksPS1                  = "$scriptPath\EthernetNetwork.PS1"
    $OVNetworkSetPS1                        = "$scriptPath\NetworkSet.PS1"
    $OVFCNetworksPS1                        = "$scriptPath\FCNetwork.PS1"

    $OVLogicalInterConnectGroupPS1          = "$scriptPath\LogicalInterConnectGroup.PS1"
    $OVUplinkSetPS1                         = "$scriptPath\UpLinkSet.PS1"

    $OVEnclosureGroupPS1                    = "$scriptPath\EnclosureGroup.PS1"
    $OVEnclosurePS1                         = "$scriptPath\Enclosure.PS1"
    $OVLogicalEnclosurePS1                  = "$scriptPath\LogicalEnclosure.PS1"
    $OVDLServerPS1                          = "$scriptPath\DLServers.PS1"

    $OVProfilePS1                           = "$scriptPath\ServerProfile.PS1"
    $OVProfileTemplatePS1                   = "$scriptPath\ServerProfileTemplate.PS1"
    $OVProfileConnectionPS1                 = "ProfileConnection.PS1"
    $OVProfileLOCALStoragePS1               = "ProfileLOCALStorage.PS1"
    $OVProfileSANStoragePS1                 = "ProfileSANStorage.PS1"

    $OVProfileTemplateConnectionPS1         = "ProfileTemplateConnection.PS1"
    $OVProfileTemplateLOCALStoragePS1       = "ProfileTemplateLOCALStorage.PS1"
    $OVProfileTemplateSANStoragePS1         = "ProfileTemplateSANStorage.PS1"

    $OVSanManagerPS1                        = "$scriptPath\SANManager.PS1"
    $OVStorageSystemPS1                     = "$scriptPath\StorageSystem.PS1"
    $OVStoragePoolPS1                       = "$scriptPath\StoragePool.PS1"
    $OVStorageVolumeTemplatePS1             = "$scriptPath\StorageVolumeTemplate.PS1"
    $OVStorageVolumePS1                     = "$scriptPath\StorageVolume.PS1"

    $OVAddressPoolPS1                       = "$scriptPath\AddressPool.PS1"
    $OVAddressPoolSubnetPS1                 = "$scriptPath\AddressPoolSubnet.PS1"


    $OVTimeLocalePS1                        = "$scriptPath\TimeLocale.PS1"
    $OVSmtpPS1                              = "$scriptPath\SMTP.PS1"
    $OVsnmpPS1                              = "$scriptPath\snmp.PS1"
    $OValertsPS1                            = "$scriptPath\Alerts.PS1"
    $OVScopesPS1                            = "$scriptPath\Scopes.PS1"
    $OVProxyPS1                             = "$scriptPath\Proxy.PS1"
    $OVfwBaselinePS1                        = "$scriptPath\fwBaseline.PS1"

    #$OVOSDeploymentPS1                      = "$scriptPath\OSDeployment.PS1"
    #$OVUsersPS1                             = "$scriptPath\Users.PS1"
    #$OVBackupConfig                         = "$scriptPath\BackupConfiguration.PS1"
    #$OVRSConfig                             = "$scriptPath\OVRSConfiguration.PS1"
    #OVLdapPS1                              = "$scriptPath\LDAP.PS1"
    #$OVLdapGroupsPS1                        = "$scriptPath\LDAPGroups.PS1"
    
    


    $sanManagerList                             = Get-HPOVSanManager 
    if ($sanManagerList)
    {
        Generate-sanManager-Script              -OutFile $OVsanManagerPS1                   -List  $sanManagerList 
    } 

    $storageSystemList                          = get-HPOVStorageSystem
    if ($storageSystemList)
    {
        Generate-StorageSystem-Script           -OutFile $OVstorageSystemPS1                -List $storageSystemList
    }

    $storagePoolList                        = Get-HPOVStoragePool | where state -eq 'Managed'
    if ($storagePoolList)
    {
        Generate-StoragePool-Script         -OutFile $OVstoragePoolPS1                      -List $storagePoolList
    }

    $storageVolumeTemplateList                  = get-HPOVStorageVolumeTemplate
    if ($storageVolumeTemplateList)
    {
        Generate-StorageVolumeTemplate-Script   -OutFile $OVStorageVolumeTemplatePS1        -List $storageVolumeTemplateList
    }

    $storageVolumeList                          = get-HPOVStorageVolume
    if ($storageVolumeList)
    {
        Generate-StorageVolume-Script           -OutFile $OVStorageVolumePS1                -List $storageVolumeList
    }

    $ethernetNetworkList                        = Get-HPOVNetwork -Type Ethernet
    if ($ethernetNetworkList)
    {
        Generate-EthernetNetwork-Script         -OutFile $OVEthernetNetworksPS1             -List $ethernetNetworkList 
    } 

    $fcNetworkList                              = Get-HPOVNetwork | Where-Object Type -like "Fc*"
    if ($FCnetworkList)
    {
        Generate-FCNetwork-Script               -OutFile $OVFCNetworksPS1                   -List $fcNetworkList 
    }

    $networksetList                             = Get-HPOVnetworkset
    if ($networksetList)
    {
        Generate-NetworkSet-Script              -Outfile $OVNetworkSetPS1                   -List $networksetList
    }

    $ligList                                    = Get-HPOVLogicalInterConnectGroup | sort-object Name
    if ($ligList)
    {
        Generate-LogicalInterConnectGroup-Script -OutFile $OVLogicalInterConnectGroupPS1    -List $ligList
        Generate-UplinkSet-Script                -OutFile $OVUplinkSetPS1                   -List $ligList
    }

    $egList                                     = Get-HPOVEnclosureGroup | sort-object Name
    if ($egList)
    {
        Generate-EnclosureGroup-Script          -Outfile $OVEnclosureGroupPS1               -List $egList
    }
    
    $leList                                     = Get-HPOVlogicalEnclosure | sort-object Name
    if ($leList) 
    {
        Generate-LogicalEnclosure-Script        -Outfile $OVLogicalEnclosurePS1             -List $leList 
    }

    $serverprofileTemplateList                  = get-HPOVserverProfileTemplate
    if ($serverprofileTemplateList)
    {
        Generate-ProfileTemplate-Script         -OutFile $OVprofileTemplatePS1              -List $serverProfileTemplateList 
    }


    $serverProfileList                          = Get-HPOVServerProfile
    if ($serverProfileList)
    { 
        Generate-Profile-Script                 -OutFile $OVprofilePS1                      -List $serverProfileList 
    }


    $smtpConfigList                             = Get-HPOVSMTPConfig
    if ($smtpConfigList.SenderEmailAddress )
    {
        Generate-smtp-Script                    -Outfile $OVsmtpPS1                         -List $smtpConfigList
        Generate-Alerts-Script                  -Outfile $OValertsPS1                       -List $smtpConfigList
    }

    $snmpList                                   = Get-HPOVSnmpReadCommunity
    if ($snmpList )
    {
        Generate-Snmp-Script                    -Outfile $OVsnmpPS1                         -List $snmpList
    }
    
    $addressPoolSubnetList                      = Get-HPOVAddressPoolSubnet
    if ($addressPoolSubnetList)
    {
        Generate-AddressPoolSubnet-Script       -Outfile $OVAddressPoolSubnetPS1            -List $addressPoolSubnetList
    }

    $addressPoolList                            = Get-HPOVAddressPoolRange
    if ($addressPoolList)
    {
        Generate-AddressPool-Script             -Outfile $OVAddressPoolPS1                  -List $addressPoolList
    }

    $timelocaleList                             = Get-HPOVApplianceDateTime 
    if ($timelocaleList)
    {
        Generate-TimeLocale-Script               -OutFile $OVTimeLocalePS1                  -List $timelocaleList 
    }   

    $scopeList                                  = Get-HPOVScope
    if ($scopeList)
    {
        Generate-Scope-Script                   -Outfile $OVScopesPS1                       -List $scopeList
    }

    $proxyList                                  = Get-HPOVApplianceProxy
    if ($proxyList )
    {
        Generate-proxy-Script                   -OutFile $OVproxyPS1                        -List $proxyList 
    }

    $fwList                                     = Get-HPOVbaseLine
    if ($fwList)
    {
        Generate-fwBaseline-Script              -OutFile $OVfwBaselinePS1                   -List $fwList
    }

    #-------------------- All-in-One Script
    $OneScript                          = "$scriptPath\all-in-One.PS1"
    Prepare-OutFile -outfile $OneScript
    $ScriptCode = @"

# ------------------------------------------------
# 
#   Configure OneView settings
#
# ------------------------------------------------
if (test-path $OVsnmpPS1)
{
    write-host -foreground CYAN "1. Configure appliance SNMP"
    $OVsnmpPS1
}

if (test-path $OVsmtpPS1)
{
    write-host -foreground CYAN "2. Configure appliance smtp"
    $OVsmtpPS1
}

if (test-path $OValertsPS1)
{
    write-host -foreground CYAN "3. Configure appliance alerts"
    $OValertsPS1
}

if (test-path $OVAddressPoolPS1)
{
    write-host -foreground CYAN "4. Configure appliance address pool"
    $OVAddressPoolPS1
}

if (test-path $OVAddressPoolSubnetPS1)
{
    write-host -foreground CYAN "5. Configure appliance address pool and subnet"
    $OVAddressPoolSubnetPS1
}


if (test-path $OVTimeLocalePS1)
{
    write-host -foreground CYAN "6. Configure appliance time locale"
$OVTimeLocalePS1
}


if (test-path $OVproxyPS1)
{
    write-host -foreground CYAN "7. Configure appliance proxy"
    $OVproxyPS1
}

if (test-path $OVfwBaselinePS1)
{
    write-host -foreground CYAN "8. Configure FW baseline"
$OVfwBaselinePS1
}

# ------------------------------------------------
# 
#   Create OneView resources
#
# ------------------------------------------------

if (test-path $OVSanManagerPS1)
{
    write-host -foreground CYAN "21. Create San Manager "
    $OVSanManagerPS1
}

if (test-path $OVStorageSystemPS1)
{ 
    write-host -foreground CYAN "22. Create Storage Systems "
    $OVStorageSystemPS1
}

if (test-path $OVStoragePoolPS1)
{
    write-host -foreground CYAN "23. Create Storage Pool "
    $OVStoragePoolPS1
}

if (test-path $OVStorageVolumeTemplatePS1)
{
    write-host -foreground CYAN "24. Create Storage Volume Template "
    $OVStorageVolumeTemplatePS1
}

if (test-path $OVStorageVolumePS1)
{
    write-host -foreground CYAN "25. Create Storage Volumes "
    $OVStorageVolumePS1
}

if (test-path $OVEthernetNetworksPS1)
{
    write-host -foreground CYAN "26. Create Ethernet networks" 
    $OVEthernetNetworksPS1
}

if (test-path $OVFCNetworksPS1)
{
    write-host -foreground CYAN "27. Create FC/FCOE networks"
    $OVFCNetworksPS1
}

if (test-path $OVNetworkSetPS1)
{
    write-host -foreground CYAN "28. Create NetworkSet "
    $OVNetworkSetPS1
}

if (test-path $OVLogicalInterConnectGroupPS1)
{
    write-host -foreground CYAN "29. Create LogicalInterconnectGroup "
    $OVLogicalInterConnectGroupPS1
}

if (test-path $OVUplinkSetPS1)
{
    write-host -foreground CYAN "30. Create UplinkSet "
    $OVUplinkSetPS1
}

if (test-path $OVEnclosureGroupPS1)
{
    write-host -foreground CYAN "31. Create EnclosureGroup"
    $OVEnclosureGroupPS1
}

if (test-path $OVLogicalEnclosurePS1)
{
    write-host -foreground CYAN "32. Create Logical Enclosure "
    $OVLogicalEnclosurePS1
}

if (test-path $OVprofileTemplatePS1)
{
    write-host -foreground CYAN "33. Create Server Profile Template"
    $OVprofileTemplatePS1 
}

if (test-path $OVprofilePS1)
{
    write-host -foreground CYAN "34. Create Server Profile"
    $OVprofilePS1 
}


if (test-path $OVScopesPS1)
{
    write-host -foreground CYAN "40. Configure appliance scope"
    $OVScopesPS1
}


Disconnect-HPOVMgmt
"@


    Add-Content -path $OneScript -Value $ScriptCode
    disconnect-hpovmgmt



}


