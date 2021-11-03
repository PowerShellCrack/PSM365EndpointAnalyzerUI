#Requires -Version 2.0
function Test-IpAddress {
 
    <#
    .SYNOPSIS
        Tests one or more IP Addresses to determine if they are valid.

    .DESCRIPTION
        Test-MrIpAddress is an advanced function that tests one or more IP Addresses to determine if
        they are valid. The detailed parameter can be used to return additional information about the IP.

    .PARAMETER IpAddress
        One or more IP Addresses to test. This parameter is mandatory.

    .PARAMETER Detailed
        Switch parameter to return detailed infomation about the IP Address instead of a boolean.
      
    .PARAMETER Version
        Switch parameter to return version of IP (either IPv4 or IPv6).

    .EXAMPLE
         Test-IpAddress -IpAddress '192.168.0.1', '192.168.0.256'

    .EXAMPLE
         Test-IpAddress -IpAddress '192.168.0.1' -Detailed

    .EXAMPLE
         '::1', '192.168.0.256' | Test-MrIpAddress

    .INPUTS
        String

    .OUTPUTS
        Boolean

    .NOTES
        Author:  Mike F Robbins
        Website: http://mikefrobbins.com
        Twitter: @mikefrobbins
    #>

        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true,
                       ValueFromPipeLine=$true)]
            [string[]]$IpAddress,
            [switch]$Version,
            [switch]$Detailed
        )

        Process {
            foreach ($Ip in $IpAddress) {
                If($Ip -match '\/'){$Ip = $Ip.split('/')[0]}

                try {
                    $Results = $Ip -match ($DetailedInfo = [IPAddress]$Ip)
                }
                catch {
                    Return $false
                    #Continue
                }

                if (-not($PSBoundParameters.Detailed)){
                    if ($PSBoundParameters.Version -and $Results){
                        If($DetailedInfo.AddressFamily -eq 'InterNetworkV6'){Return 'IPv6'}Else{Return 'IPv4'}
                    }Else{
                        Return $Results
                    }
                }
                else {
                    Return $DetailedInfo
                }

            }
        }
    }

Function Test-IsIPv4Address{
    <#
    ip address validation solution reference (Kamil Tatar):
    #https://powershell.org/forums/topic/detecting-if-ip-address-entered/
    #>
    [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true,
                       ValueFromPipeLine=$true)]
            [string]$IpAddress
        )

    #immediately check if cider exists
    if($IpAddress -match '\/'){
        $Network = $IpAddress.split("/")
        $Cidr = $Network[1]
        $IpAddress = $Network[0]
        if([int]$Cidr -eq '0' -or [int]$Cidr -gt '32'){
            Return $False
        }
    }
    
    #check if its a range
    If($IpAddress -like "*-*"){
        $ip = $IpAddress.split("-")
        $ip1 = $ip[0] -as [IPaddress] -as [Bool]
        $ip2 = $ip[1] -as [IPaddress] -as [Bool]
        if($ip -and $ip){
            Return $true
        }
        else{
            Return $False
        }
    }
    ElseIf(($IpAddress -as [IPaddress]) -as [Bool]){
        Return $true
    }
    else {
        Return $False
    }
}

function Test-IsIPv6Address {
    param(
        [Parameter(Mandatory=$true,HelpMessage='Enter IPv6 address to verify')]
        [string]$IpAddress
    )
    #immediately check if cider exists
    if($IpAddress -match '\/'){
        $Network = $IpAddress.split("/")
        $Cidr = $Network[1]
        $IpAddress = $Network[0]
        if([int]$Cidr -eq '0' -or [int]$Cidr -gt '128'){
            Return $False
        }
    }
  
    #build range
    $IPv4Regex = '(((25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})\.){3}(25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))'
    $G = '[a-f\d]{1,4}'
    # In a case sensitive regex, use:
    #$G = '[A-Fa-f\d]{1,4}'
    $Tail = @(":",
        "(:($G)?|$IPv4Regex)",
        ":($IPv4Regex|$G(:$G)?|)",
        "(:$IPv4Regex|:$G(:$IPv4Regex|(:$G){0,2})|:)",
        "((:$G){0,2}(:$IPv4Regex|(:$G){1,2})|:)",
        "((:$G){0,3}(:$IPv4Regex|(:$G){1,2})|:)",
        "((:$G){0,4}(:$IPv4Regex|(:$G){1,2})|:)")
    [string] $IPv6RegexString = $G
    $Tail | foreach { $IPv6RegexString = "${G}:($IPv6RegexString|$_)" }
    $IPv6RegexString = ":(:$G){0,5}((:$G){1,2}|:$IPv4Regex)|$IPv6RegexString"
    $IPv6RegexString = $IPv6RegexString -replace '\(' , '(?:' # make all groups non-capturing
    [regex] $IPv6Regex = $IPv6RegexString
  
    if ($IpAddress -imatch "^$IPv6Regex$") {
        return $true
    } else {
        return $false
    }
}



# Test if a number is a multiple of 
Function Test-IsMultipleOf ([int]$Multiple,[int]$Number)
{
    while ( $Number -gt 0 ){
        $Number = $Number - $Multiple;
    }
    if ( $Number -eq 0 ){
        return $True
    }
    return $false
}