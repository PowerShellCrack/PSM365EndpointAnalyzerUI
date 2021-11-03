function Test-IsUri {
    param($targetUri)

    [System.Uri]::IsWellFormedUriString($targetUri, 'Absolute')
}



Function ConvertFrom-Markdown {
    [CmdletBinding()]
    [OutputType([PSObject])]
    Param (
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true
        )]
        $InputObject
    )

    Begin {
        $items = @()
    }

    Process {
        $mddata = $InputObject -split "`n"
        $data = $mddata | Where-Object {$_ -notmatch "-" }
        $items += ($data).Trim('|')
    }

    End {
       $object = $items | ConvertFrom-Csv -Delimiter '|'
       $object
    }
}


Function ConvertFrom-MarkdownTable {

    [CmdletBinding()]
    [OutputType([PSObject])]
    Param (
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ParameterSetName = 'Object'
        )]
        $InputObject,

        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ParameterSetName = 'Path'
        )]
        $Path,

        [switch]$SkipTableHeader
    )

    Begin {
        If($PSCmdlet.ParameterSetName -eq 'Object'){
            $mdContent = $InputObject
        }

        If($PSCmdlet.ParameterSetName -eq 'Path'){
            if (Test-IsUri $Path) {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                $mdContent = Invoke-RestMethod $Path
            }
            else {
                $mdContent = Get-Content $Path
            }
        }

        $items = @()
    }

    Process {
        $LineContent = $mdContent -split "`n"
        $Num = 0
        foreach($line in $LineContent)
        {
            $NotesFound = $false
            $Num ++
            If($VerbosePreference -eq 'Continue'){Write-host ("Processing line: {0}" -f $line) -ForegroundColor Gray}

            #look for Name,Notes,Protocols
            switch -Regex ($line){
                "^##" {
                        #assume most markdown tables will have a title above it
                        $NameFound = $true
                        If($VerbosePreference -eq 'Continue'){Write-host ("Name is now: {0}" -f $line.replace('##','').Trim())}
                        $Name = $line.replace('##','').Trim()
                }

                "\|" {
                        #assume header is found first
                        If($SkipTableHeader){
                            If($VerbosePreference -eq 'Continue'){Write-host ("Ignoring Table header from line: {0}" -f $Num) -ForegroundColor Cyan}
                            #build the header Array
                            #$TableHeaderArray = $TableHeader.split('|').Trim()
                            $SkipTableHeader = $false
                        }
                        ElseIf($line -match "-{2,}?"){
                            If($VerbosePreference -eq 'Continue'){Write-host ("Ignoring table separator from line: {0}" -f $Num) -ForegroundColor Cyan}
                            #ignore markdown separator which not needed
                        }
                        #in markdown
                        #the first lines with multiple | is column headers
                        #the second is separator (--) which not needed
                        #the lines after is data
                        ElseIf( $mdtablerow = ($line | Where-Object {($_ -match "\|") -and ($_ -notmatch "-{2,}?")}) ){
                            #some values will have a value with \|, 
                            #its an escape character to separate values but not be part of table format
                            #Replace \| with a ! to be used as diff delimiter
                            $mdtablerow = $mdtablerow.replace('\|','!')
                            #then convert all | to comma
                            $mdtablerow = $mdtablerow.replace('|','~')
                            #then convert ! back to |
                            $mdtablerow = $mdtablerow.replace('!','|')

                            #if the name/desc was found (has value),label the next line that has ! in it as the header
                            #if the name does not have value, assume the next line are the rows in columns
                            #If Category was not found,make a header, then mark it used
                            IF($NameFound -eq $true){$NameText='Name';$NameFound=$false}Else{$NameText="$Name"}

                            #sometimes markdown tables have starting |, if so build new row appropriately
                            If($mdtablerow -match "^~"){$Delimiter = ''}Else{$Delimiter = '~'}
                            $data = $NameText + $Delimiter + $mdtablerow
                            $items += ($data).Trim('~')

                            write-verbose ('Processed row on line [{0}]: {1}' -f $Num, $line)
                            If($VerbosePreference -eq 'Continue'){Write-host ('Added item to list [{0}]' -f ($data.replace('~',','))) -ForegroundColor Cyan}

                            #Clear the name and desc after building the header
                            #$name = $null
                        }
                        Else{
                            write-verbose ('Skipped line [{0}]: {1}' -f $Num, $line)
                            Continue
                        }
                }

            } #end of switch
        }
    }
    End{
        #convert items to object
       $object = $items | ConvertFrom-Csv -Delimiter '~'
       #only return if key is not null or default and Name is not default
       return $object
    }
}

Function ConvertFrom-M365Table {

    [CmdletBinding()]
    [OutputType([PSObject])]
    Param (
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true
        )]
        $InputObject,

        [ValidateSet('Commercial','Government','China')]
        [string]$AzureCloud,

        [string]$TenantName,
        
        [switch]$ShowProgress
    )

    Begin {
        #remove any empty line
        $mdContent = $InputObject -creplace '(?m)^\s*\r?\n',''
        #split into an array based on each line
        [array]$LineContent = $mdContent -split "`n"

        $TableHeader = 'Name | Category | Importance | ExpressRoute | Notes | Domains | IPv4Addresses | IPv6Addresses | Protocol | Ports'
        $TableHeaderFormatted = $TableHeader.replace('|',',').replace(' ','').Trim()
        $tabledata = @()

        Switch($PSBoundParameters.AzureCloud){
            'Commercial' {$TopLevelDomains = @('.com','.net','.org','.edu')}
            'Government' {$TopLevelDomains = @('.us','.gov','.mil')}
            'China' {$TopLevelDomains = @('.com','.net','.cn','.io')}
            default {$TopLevelDomains = @('.com','.net','.org','.edu')}
        }
    }

    Process {
        <#
        Tests
        #test sample data
        $line = "## Exchange Online"
        $line = ""
        $line = "ID | Category | ER | Addresses | Ports"
        $line = "--- | --------------------------------------------------------------- | --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -----------------"
        $line = "1 | Optimize<BR>Required | Yes | `outlook.office.com, outlook.office365.com`<BR>`13.107.6.152/31, 13.107.18.10/31, 13.107.128.0/22, 23.103.160.0/20, 40.96.0.0/13, 40.104.0.0/15, 52.96.0.0/14, 131.253.33.215/32, 132.245.0.0/16, 150.171.32.0/22, 204.79.197.215/32, 2603:1006::/40, 2603:1016::/36, 2603:1026::/36, 2603:1036::/36, 2603:1046::/36, 2603:1056::/36, 2603:1096::/38, 2603:1096:400::/40, 2603:1096:600::/40, 2603:1096:a00::/39, 2603:1096:c00::/40, 2603:10a6:200::/40, 2603:10a6:400::/40, 2603:10a6:600::/40, 2603:10a6:800::/40, 2603:10d6:200::/40, 2620:1ec:4::152/128, 2620:1ec:4::153/128, 2620:1ec:c::10/128, 2620:1ec:c::11/128, 2620:1ec:d::10/128, 2620:1ec:d::11/128, 2620:1ec:8f0::/46, 2620:1ec:900::/46, 2620:1ec:a92::152/128, 2620:1ec:a92::153/128, 2a01:111:f400::/48` | **TCP:** 443, 80"
        $line = "3 | Default<BR>Required | No | `r1.res.office365.com, r3.res.office365.com, r4.res.office365.com` | **TCP:** 443, 80"
        $line = "5 | Allow<BR>Optional<BR>**Notes:** Exchange Online IMAP4 migration | Yes | `*.outlook.office.com, outlook.office365.com`<BR>`13.107.6.152/31, 13.107.18.10/31, 13.107.128.0/22, 23.103.160.0/20, 40.96.0.0/13, 40.104.0.0/15, 52.96.0.0/14, 131.253.33.215/32, 132.245.0.0/16, 150.171.32.0/22, 204.79.197.215/32, 2603:1006::/40, 2603:1016::/36, 2603:1026::/36, 2603:1036::/36, 2603:1046::/36, 2603:1056::/36, 2603:1096::/38, 2603:1096:400::/40, 2603:1096:600::/40, 2603:1096:a00::/39, 2603:1096:c00::/40, 2603:10a6:200::/40, 2603:10a6:400::/40, 2603:10a6:600::/40, 2603:10a6:800::/40, 2603:10d6:200::/40, 2620:1ec:4::152/128, 2620:1ec:4::153/128, 2620:1ec:c::10/128, 2620:1ec:c::11/128, 2620:1ec:d::10/128, 2620:1ec:d::11/128, 2620:1ec:8f0::/46, 2620:1ec:900::/46, 2620:1ec:a92::152/128, 2620:1ec:a92::153/128, 2a01:111:f400::/48` | **TCP:** 143, 993"
        $line = "8 | Default<BR>Required | No | `*.outlook.com, *.outlook.office.com, attachments.office.net` | **TCP:** 443, 80"
        $line = "9 | Allow<BR>Required | Yes | `*.protection.outlook.com`<BR>`40.92.0.0/15, 40.107.0.0/16, 52.100.0.0/14, 52.238.78.88/32, 104.47.0.0/17, 2a01:111:f403::/48` | **TCP:** 443"
        $line = "10 | Allow<BR>Required | Yes | `*.mail.protection.outlook.com`<BR>`40.92.0.0/15, 40.107.0.0/16, 52.100.0.0/14, 104.47.0.0/17, 2a01:111:f400::/48, 2a01:111:f403::/48` | **TCP:** 25"
        $line = "154 | Default<BR>Required | No | `autodiscover.<tenant>.onmicrosoft.com` | **TCP:** 443, 80"
        $line = "74 | Default<BR>Optional<BR>**Notes:** Remote Connectivity Analyzer - Initiate connectivity tests. | No | `testconnectivity.microsoft.com` | **TCP:** 443, 80"
        $line = "75 | Default<BR>Optional<BR>**Notes:** Graph.windows.net, Office 365 Management Pack for Operations Manager, SecureScore, Azure AD Device Registration, Forms, StaffHub, Application Insights, captcha services | No | `*.hockeyapp.net, *.sharepointonline.com, cdn.forms.office.net, dc.applicationinsights.microsoft.com, dc.services.visualstudio.com, forms.microsoft.com, mem.gfx.ms, office365servicehealthcommunications.cloudapp.net, osiprod-cus-daffodil-signalr-00.service.signalr.net, osiprod-neu-daffodil-signalr-00.service.signalr.net, osiprod-weu-daffodil-signalr-00.service.signalr.net, osiprod-wus-daffodil-signalr-00.service.signalr.net, signup.microsoft.com, staffhub.ms, staffhub.uservoice.com, staffhubweb.azureedge.net, watson.telemetry.microsoft.com` | **TCP:** 443"
        $line = "31 | Optimize<BR>Required | Yes | `<tenant>.sharepoint.com, <tenant>-my.sharepoint.com`<BR>`13.107.136.0/22, 40.108.128.0/17, 52.104.0.0/14, 104.146.128.0/17, 150.171.40.0/22, 2620:1ec:8f8::/46, 2620:1ec:908::/46, 2a01:111:f402::/48` | **TCP:** 443, 80"
        #>

        $Num = 0
        foreach($line in $LineContent)
        {
            $NotesFound = $false
            $Num ++
            #If($ShowProgress){Set-UIStatus -Message ("Processing line: {0}" -f $line) -Step $Num -MaxStep $LineContent.Count -UpdateUI:$true}
            If($VerbosePreference -eq 'Continue'){Write-host ("Processing line: {0}" -f $line) -ForegroundColor Gray}
            
            $line = $line.Replace('`','')
            
            #look for Name,Notes,Protocols
            Try{
                switch -Regex ($line){
                    "^##" {
                            #assume most markdown tables will have a title above it
                            $NameFound = $true
                            If($VerbosePreference -eq 'Continue'){Write-host ("Name is now: {0}" -f $line.replace('##','').Trim())}
                            $Name = $line.replace('##','').Trim()
                            $SkipTableHeader = $true
                    }
    
                    "\|" {
                            #assume header is found first
                            If($SkipTableHeader){
                                If($VerbosePreference -eq 'Continue'){Write-host ("Ignoring Table header from line: {0}" -f $Num) -ForegroundColor Cyan}
                                #build the header Array
                                #$TableHeaderArray = $TableHeader.split('|').Trim()
                                If($VerbosePreference -eq 'Continue'){Write-host ("Header is now: {0}" -f $TableHeaderFormatted) -ForegroundColor Yellow}
                                $SkipTableHeader = $false
                            }
                            ElseIf($line -match "-{2,}?"){
                                If($VerbosePreference -eq 'Continue'){Write-host ("Ignoring table separator from line: {0}" -f $Num) -ForegroundColor Cyan}
                                #ignore markdown separator which not needed
                            }
                            Else{
                                #in markdown
                                #the first lines with multiple | is column headers
                                #the second is separator (--) which not needed
                                #the lines after is data
                                #First check if line has **; this will eithe rbe notes or protocols
                                If($line -match '\*\*'){
                                    If( $NotesFound = ($line.split('**')[2].Trim()) -match 'Note'){
                                        #Grab just the Category part
                                        $CategoryPart=$line.split('**')[0].Trim()
                                        $pos = $CategoryPart.IndexOf("|")
                                        $CatAndImp = $CategoryPart.Substring($pos+1).replace('<BR>','|')
                                        $Category = $CatAndImp.split('|')[0].Trim()
                                        $Importance = $CatAndImp.split('|')[1].Trim()
                                        If($VerbosePreference -eq 'Continue'){Write-host ("Category is now: {0}" -f $Category) -ForegroundColor Yellow}
                                        If($VerbosePreference -eq 'Continue'){Write-host ("Importance is now: {0}" -f $Importance) -ForegroundColor Yellow}
        
                                        #Grab just the note part
                                        $NotesPart=$line.split('**')[4].Trim()
                                        $pos = $NotesPart.IndexOf("|")
                                        $Notes = $NotesPart.Substring(0, $pos).Trim()
                                        If($VerbosePreference -eq 'Continue'){Write-host ("Notes is now: {0}" -f $Notes) -ForegroundColor Yellow}
                                        #make the notes text a separator
                                        $line = $line.replace('<BR>**Notes:**','|')
                                        #$line = $line.replace($Category,'').replace($Importance,'').replace($Notes,'')
                                    }
        
                                    #look for protocols and ports
                                    If( ($line -split '\*\*')[1].Trim() -match '(TCP)|(UDP)'){
                                        $Protocol=$matches[0]
                                        [array]$Ports = ($line -split $Protocol)[1].replace(':','').replace('*','').Trim().Split(',').Trim()
                                        If($VerbosePreference -eq 'Continue'){Write-host ("Protocol is now: {0}" -f $Protocol) -ForegroundColor Yellow}
                                        If($VerbosePreference -eq 'Continue'){Write-host ("Ports is now: {0}" -f ($Ports -join ',')) -ForegroundColor Yellow}
                                        $ThisSection = $line.split("|")[-1]
                                        $line = $line.replace($ThisSection,'')
                                    }
                                }
                                #anything in the line that has <br> will be column
                                $line = $line.replace('<BR>',' | ').Trim('|')
    
                                # check the entire line  for domain name and Ip address
                                $domains = @()
                                $IPv4 = @()
                                $IPv6 = @()
    
                                $Data = $line.split('|').split(',').Trim()
                                foreach ($item in $Data)
                                {
                                    #check if its a value IP address
                                    If( (Test-IsIPv4Address $item) -or (Test-IsIPv6Address $item) ){
                                        #check IPv4 or 6
                                        If( (Test-IpAddress $item -Version) -eq 'IPv4'){
                                            #[array]$IPv4 += (Test-IpAddress $item -Detailed).IPAddressToString
                                            [array]$IPv4 += $item 
                                            #remove the item from the list
                                            $line = $line.replace($item,'')
                                        }
                                        ElseIf( (Test-IpAddress $item -Version) -eq 'IPv6'){
                                            #[array]$IPv6 += (Test-IpAddress $item -Detailed).IPAddressToString
                                            $IPv6 += $item 
                                            $line = $line.replace($item,'')
                                        }
                                    }
                                    #check if item is domain and is in top level
                                    ElseIf( ($TopLevelDomains | %{$item -match $_}) -contains $true){
                                        #Add to domains list, be sure to replace Tenant variable
                                        $Domains += $Item.Replace('<tenant>',$TenantName)
                                        $line = $line.replace($item,'')
                                    }
                                    Else{
                                        #do nothing to the next line
                                        If($VerbosePreference -eq 'Continue'){Write-host ("{0} is not a domain,ipv4 or ipv6" -f $item) -ForegroundColor Yellow}
                                    }
    
                                }#end of data loop
    
                                #whats left in the line, remove anything is not a word or integer
                                $CleanLine = @()
                                $CleanLine = $line.split('|').Trim() -match '\w'
    
                                If($NotesFound){
                                    $CleanLine = $CleanLine | Where-Object { $_ -ne $Notes }
                                    #$CleanLine += $Notes
                                }Else{
                                    #$CleanLine += 'Null'
                                }
    
                                #Follow this format: 'Name | Category | Importance | ExpressRoute | Notes | Domains | IP Address v4 | IP Address v6 | Protocol | Ports'
                                $FormatLine = ("{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}|{8}{9}" -f $Name,$Category,$Importance,$CleanLine[3],$Notes,$domains,$ipv4,$ipv6,$Protocol,$Ports)
    
                                #create a object to collect all data
                                $info = "" | Select Name,Category,Importance,ExpressRoute,Notes,Domains,IPv4Addresses,IPv6Addresses,Protocol,Ports
                                $info.Name = $Name
                                $info.Category = $Category
                                $info.Importance = $Importance
                                $info.ExpressRoute = $CleanLine[3]
                                $info.Notes = $Notes
                                $info.Domains = $Domains
                                $info.IPv4Addresses = $IPv4
                                $info.IPv6Addresses = $IPv6
                                $info.Protocol = $Protocol
                                $info.Ports = $Ports
    
                                $tabledata += $info
                                If($VerbosePreference -eq 'Continue'){Write-host ("Added data to Object: {0}" -f $FormatLine) -ForegroundColor Cyan}
                                #now that we're done with this dataset, time to reset value and start ove
    
                            }
                    }
    
                } #end of switch
            }
            Catch{
                If($VerbosePreference -eq 'Continue'){Write-host (" Errored at Line [{0}] = {1}; {2}" -f $Num,$line,$_.exception.message) -ForegroundColor Red}
            }
        } #end line loop
        
    }
    End{
        return $tabledata
    }
}



Function ConvertFrom-M365Table2 {

    [CmdletBinding()]
    [OutputType([PSObject])]
    Param (
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true
        )]
        $InputObject,

        $filter = '*',

        [ValidateSet('Commercial','Government','China')]
        [string]$AzureCloud,

        [string]$TenantName,

        [array]$TableHeader,

        [switch]$ShowProgress
    )

    Begin {
        #remove any empty line
        $mdContent = $InputObject -creplace '(?m)^\s*\r?\n',''
        #split into an array based on each line
        [array]$LineContent = $mdContent -split "`n"
        $tabledata = @()

        Switch($PSBoundParameters.AzureCloud){
            'Commercial' {$TopLevelDomains = @('.com','.net','.org','.edu')}
            'Government' {$TopLevelDomains = @('.us','.gov','.mil')}
            'China' {$TopLevelDomains = @('.com','.net','.cn','.io')}
            default {$TopLevelDomains = @('.com','.net','.org','.edu')}
        }
    }

    Process {
        <#
        Tests
        #test sample data
        $line = "## Exchange Online"
        $line = ""
        $line = "ID | Category | ER | Addresses | Ports"
        $line = "--- | --------------------------------------------------------------- | --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -----------------"
        $line = "1 | Optimize<BR>Required | Yes | `outlook.office.com, outlook.office365.com`<BR>`13.107.6.152/31, 13.107.18.10/31, 13.107.128.0/22, 23.103.160.0/20, 40.96.0.0/13, 40.104.0.0/15, 52.96.0.0/14, 131.253.33.215/32, 132.245.0.0/16, 150.171.32.0/22, 204.79.197.215/32, 2603:1006::/40, 2603:1016::/36, 2603:1026::/36, 2603:1036::/36, 2603:1046::/36, 2603:1056::/36, 2603:1096::/38, 2603:1096:400::/40, 2603:1096:600::/40, 2603:1096:a00::/39, 2603:1096:c00::/40, 2603:10a6:200::/40, 2603:10a6:400::/40, 2603:10a6:600::/40, 2603:10a6:800::/40, 2603:10d6:200::/40, 2620:1ec:4::152/128, 2620:1ec:4::153/128, 2620:1ec:c::10/128, 2620:1ec:c::11/128, 2620:1ec:d::10/128, 2620:1ec:d::11/128, 2620:1ec:8f0::/46, 2620:1ec:900::/46, 2620:1ec:a92::152/128, 2620:1ec:a92::153/128, 2a01:111:f400::/48` | **TCP:** 443, 80"
        $line = "3 | Default<BR>Required | No | `r1.res.office365.com, r3.res.office365.com, r4.res.office365.com` | **TCP:** 443, 80"
        $line = "5 | Allow<BR>Optional<BR>**Notes:** Exchange Online IMAP4 migration | Yes | `*.outlook.office.com, outlook.office365.com`<BR>`13.107.6.152/31, 13.107.18.10/31, 13.107.128.0/22, 23.103.160.0/20, 40.96.0.0/13, 40.104.0.0/15, 52.96.0.0/14, 131.253.33.215/32, 132.245.0.0/16, 150.171.32.0/22, 204.79.197.215/32, 2603:1006::/40, 2603:1016::/36, 2603:1026::/36, 2603:1036::/36, 2603:1046::/36, 2603:1056::/36, 2603:1096::/38, 2603:1096:400::/40, 2603:1096:600::/40, 2603:1096:a00::/39, 2603:1096:c00::/40, 2603:10a6:200::/40, 2603:10a6:400::/40, 2603:10a6:600::/40, 2603:10a6:800::/40, 2603:10d6:200::/40, 2620:1ec:4::152/128, 2620:1ec:4::153/128, 2620:1ec:c::10/128, 2620:1ec:c::11/128, 2620:1ec:d::10/128, 2620:1ec:d::11/128, 2620:1ec:8f0::/46, 2620:1ec:900::/46, 2620:1ec:a92::152/128, 2620:1ec:a92::153/128, 2a01:111:f400::/48` | **TCP:** 143, 993"
        $line = "8 | Default<BR>Required | No | `*.outlook.com, *.outlook.office.com, attachments.office.net` | **TCP:** 443, 80"
        $line = "9 | Allow<BR>Required | Yes | `*.protection.outlook.com`<BR>`40.92.0.0/15, 40.107.0.0/16, 52.100.0.0/14, 52.238.78.88/32, 104.47.0.0/17, 2a01:111:f403::/48` | **TCP:** 443"
        $line = "10 | Allow<BR>Required | Yes | `*.mail.protection.outlook.com`<BR>`40.92.0.0/15, 40.107.0.0/16, 52.100.0.0/14, 104.47.0.0/17, 2a01:111:f400::/48, 2a01:111:f403::/48` | **TCP:** 25"
        $line = "154 | Default<BR>Required | No | `autodiscover.<tenant>.onmicrosoft.com` | **TCP:** 443, 80"
        $line = "74 | Default<BR>Optional<BR>**Notes:** Remote Connectivity Analyzer - Initiate connectivity tests. | No | `testconnectivity.microsoft.com` | **TCP:** 443, 80"
        $line = "75 | Default<BR>Optional<BR>**Notes:** Graph.windows.net, Office 365 Management Pack for Operations Manager, SecureScore, Azure AD Device Registration, Forms, StaffHub, Application Insights, captcha services | No | `*.hockeyapp.net, *.sharepointonline.com, cdn.forms.office.net, dc.applicationinsights.microsoft.com, dc.services.visualstudio.com, forms.microsoft.com, mem.gfx.ms, office365servicehealthcommunications.cloudapp.net, osiprod-cus-daffodil-signalr-00.service.signalr.net, osiprod-neu-daffodil-signalr-00.service.signalr.net, osiprod-weu-daffodil-signalr-00.service.signalr.net, osiprod-wus-daffodil-signalr-00.service.signalr.net, signup.microsoft.com, staffhub.ms, staffhub.uservoice.com, staffhubweb.azureedge.net, watson.telemetry.microsoft.com` | **TCP:** 443"

        #>
        $Num = 0
        foreach($line in $LineContent)
        {
            $NotesFound = $false
            $Num ++
            If($ShowProgress){Set-UIStatus -Message ("Processing line: {0}" -f $line) -Step $Num -MaxStep $LineContent.Count -UpdateUI:$true}
            If($VerbosePreference -eq 'Continue'){Write-host ("Processing line [{0}]: {1}" -f $Num,$line) -ForegroundColor Gray}

            #look for Name,Notes,Protocols
            If($line -match "^##"){
                #assume most markdown tables will have a title above it
                $NameFound = $true
                If($VerbosePreference -eq 'Continue'){Write-host ("Name is now: {0}" -f $line.replace('##','').Trim())}
                $Name = $line.replace('##','').Trim()
            }
            ElseIf(($NameFound -eq $true) -and ($Name -notlike "*$filter*")){
                Continue
            }
            ElseIf($line -match "-{2,}?"){
                If($VerbosePreference -eq 'Continue'){Write-host ("Ignoring table separator from line [{0}]: {1}" -f $Num,$line) -ForegroundColor Cyan}
                #ignore markdown separator which not needed
            }
            ElseIf($line -match "\|"){
                #assume header is found first
                #skip the md header if provided in cmdlet
                If($PSBoundParameters.ContainsKey('TableHeader') -and [string]::IsNullOrEmpty($UseTableHeader)){
                    If($VerbosePreference -eq 'Continue'){Write-host ("Ignoring table header from line [{0}]: {1}" -f $Num,$line) -ForegroundColor Cyan}
                    If($VerbosePreference -eq 'Continue'){Write-host ("Header is now: {0}" -f ($TableHeader -join ',')) -ForegroundColor Yellow}
                    $UseTableHeader = $TableHeader
                }
                ElseIf($UseTableHeader.count -eq 0){
                    #build the header Array
                    [Array]$TableHeader = $Line.Trim('|').split('|').Trim()
                    If($VerbosePreference -eq 'Continue'){Write-host ("Header is now: {0}" -f ($TableHeader -join ',')) -ForegroundColor Yellow}
                    $UseTableHeader = $TableHeader
                }
                Else{
                    #in markdown
                    #the first lines with multiple | is column headers
                    #the second is separator (--) which not needed
                    #the lines after is data
                    If( $NotesFound = ($line.split('**')[2].Trim()) -match 'Note'){
                        #Grab just the Category part
                        $CategoryPart=$line.split('**')[0].Trim()
                        $pos = $CategoryPart.IndexOf("|")
                        $CatAndImp = $CategoryPart.Substring($pos+1).replace('<BR>','|')
                        $Category = $CatAndImp.split('|')[0].Trim()
                        $Importance = $CatAndImp.split('|')[1].Trim()
                        If($VerbosePreference -eq 'Continue'){Write-host ("Category is now: {0}" -f $Category) -ForegroundColor Yellow}
                        If($VerbosePreference -eq 'Continue'){Write-host ("Importance is now: {0}" -f $Importance) -ForegroundColor Yellow}

                        #Grab just the note part
                        $NotesPart=$line.split('**')[4].Trim()
                        $pos = $NotesPart.IndexOf("|")
                        $Notes = $NotesPart.Substring(0, $pos).Trim()
                        If($VerbosePreference -eq 'Continue'){Write-host ("Notes is now: {0}" -f $Notes) -ForegroundColor Yellow}
                        #make the notes text a separator
                        $line = $line.replace('<BR>**Notes:**','|')
                        #$line = $line.replace($Category,'').replace($Importance,'').replace($Notes,'')
                    }

                    #look for protocols and ports
                    If( ($line -split '\*\*')[1].Trim() -match '(TCP)|(UDP)'){
                        $Protocol=$matches[0]
                        [array]$Ports = ($line -split $Protocol)[1].replace(':','').replace('*','').Trim().Split(',').Trim()
                        If($VerbosePreference -eq 'Continue'){Write-host ("Protocol is now: {0}" -f $Protocol) -ForegroundColor Yellow}
                        If($VerbosePreference -eq 'Continue'){Write-host ("Ports is now: {0}" -f ($Ports -join ',')) -ForegroundColor Yellow}
                        $ThisSection = $line.split("|")[-1]
                        $line = $line.replace($ThisSection,'')
                    }

                    #anything in the line that has <br> will be column
                    $line = $line.replace('<BR>',' | ').Trim('|')

                    # check the entire line  for domain name and Ip address
                    $domains = @()
                    $IPv4 = @()
                    $IPv6 = @()

                    $Data = $line.split('|').split(',').Trim()
                    foreach ($item in $Data)
                    {
                        $item = $item.Trim('`')
                        #check IPv4 or 6
                        If( (Test-IpAddress $item -Version) -eq 'IPv4'){
                            [array]$IPv4 += (Test-IpAddress $item -Detailed).IPAddressToString
                            #remove the item from the list
                            $line = $line.replace($item,'')
                        }
                        ElseIf( (Test-IpAddress $item -Version) -eq 'IPv6'){
                            [array]$IPv6 += (Test-IpAddress $item -Detailed).IPAddressToString
                            $line = $line.replace($item,'')
                        }
                        #check for domains
                        ElseIf( ($TopLevelDomains | %{$item -match $_}) -contains $true){
                            #Add to domains list, be sure to replace Tenant variable
                            $Domains += $Item.Replace('<tenant>',$TenantName)
                            $line = $line.replace($item,'')
                        }
                        Else{
                            #do nothing to the next line
                        }
    
                    }#end of data loop
    
                    #whats left in the line, remove anything is not a word or integer
                    $CleanLine = @()
                    $CleanLine = $line.split('|').Trim() -match '\w'
    
                    If($NotesFound){
                        $CleanLine = $CleanLine | Where-Object { $_ -ne $Notes }
                        #$CleanLine += $Notes
                    }Else{
                        #$CleanLine += 'Null'
                    }
    
                    #Follow this format: 'Name | Category | Importance | ExpressRoute | Notes | Domains | IP Address v4 | IP Address v6 | Protocol | Ports'
                    $FormatLine = ("{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}|{8}{9}" -f $Name,$Category,$Importance,$CleanLine[3],$Notes,$domains,$ipv4,$ipv6,$Protocol,$Ports)
    
                    #create a object to collect all data
                    $info = "" | Select $UseTableHeader
                    $info.Name = $Name
                    $info.Category = $Category
                    $info.Importance = $Importance
                    $info.ExpressRoute = $CleanLine[3]
                    $info.Notes = $Notes
                    $info.Domains = $Domains
                    $info.IPv4Addresses = $IPv4
                    $info.IPv6Addresses = $IPv6
                    $info.Protocol = $Protocol
                    $info.Ports = $Ports
    
                    $tabledata += $info
                    If($VerbosePreference -eq 'Continue'){Write-host ("Added data to Object: {0}" -f $FormatLine) -ForegroundColor Cyan}
                    #now that we're done with this dataset, time to reset value and start ove
    
                }
            }Else{
                Continue
            }
        }
    }
    End{
        return $tabledata
    }
}