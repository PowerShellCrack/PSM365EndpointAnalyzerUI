<#
.SYNOPSIS
    Checks all connections points fo M365

.DESCRIPTION
   Parses m365 Uri's for markdown tables; uses that list to check connectivity

.NOTES
    Authors		: Dick Tracy II <richard.tracy@microsoft.com>, Nicolas Riderelli <nicolas.riderelli@microsoft.com>
	Source	    : https://dev.azure.com/niridere/_git/Microsoft%20365%20Network%20checker?path=%2FResource%2FMainWindow.xaml
    Version		: 0.0.1a
    #Requires -Version 3.0
#>

param(
    [ValidateSet('WorldWide','DoD','GCC','GCC High','China','Germany')]
    [string]$Cloud = "WorldWide",
    [switch]$Offline,
    [switch]$Debug
)


#*=============================================
##* Runtime Function - REQUIRED
##*=============================================

#region FUNCTION: Check if running in ISE
Function Test-IsISE {
    # try...catch accounts for:
    # Set-StrictMode -Version latest
    try {
        return ($null -ne $psISE);
    }
    catch {
        return $false;
    }
}
#endregion

#region FUNCTION: Check if running in Visual Studio Code
Function Test-VSCode{
    if($env:TERM_PROGRAM -eq 'vscode') {
        return $true;
    }
    Else{
        return $false;
    }
}
#endregion

#region FUNCTION: Find script path for either ISE or console
Function Get-ScriptPath {
    <#
        .SYNOPSIS
            Finds the current script path even in ISE or VSC
        .LINK
            Test-VSCode
            Test-IsISE
    #>
    param(
        [switch]$Parent
    )

    Begin{}
    Process{
        if ($PSScriptRoot -eq "")
        {
            if (Test-IsISE)
            {
                $ScriptPath = $psISE.CurrentFile.FullPath
            }
            elseif(Test-VSCode){
                $context = $psEditor.GetEditorContext()
                $ScriptPath = $context.CurrentFile.Path
            }Else{
                $ScriptPath = (Get-location).Path
            }
        }
        else
        {
            $ScriptPath = $PSCommandPath
        }
    }
    End{

        If($Parent){
            Split-Path $ScriptPath -Parent
        }Else{
            $ScriptPath
        }
    }
}
#endregion

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
If ($PSBoundParameters['Debug']){$DebugMode = $true}Else{$DebugMode = $false}
#check if offline was called
If($PSBoundParameters.ContainsKey('Offline')){$OfflineMode = $true}Else{$OfflineMode = $false}
#region VARIABLES: Building paths & values
# Use function to get paths because Powershell ISE & other editors have differnt results
[string]$scriptPath = Get-ScriptPath
[string]$scriptName = [IO.Path]::GetFileNameWithoutExtension($scriptPath)
[string]$scriptFileName = Split-Path -Path $scriptPath -Leaf
[string]$scriptRoot = Split-Path -Path $scriptPath -Parent
[string]$invokingScript = (Get-Variable -Name 'MyInvocation').Value.ScriptName

[string]$FunctionPath = Join-Path -Path $scriptRoot -ChildPath 'Functions'
[string]$ResourcePath = Join-Path -Path $scriptRoot -ChildPath 'Resources'
[string]$XAMLFilePath = Join-Path -Path $ResourcePath -ChildPath 'MainWindow.xaml'
[string]$EndPointTablesPath = Join-Path -Path $ResourcePath -ChildPath 'EndpointTables'
#*=============================================
##* External Functions
##*=============================================
. "$FunctionPath\UIControls.ps1"

# Make PowerShell Disappear
If(Test-IsISE){
    $Windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    $asyncWindow = Add-Type -MemberDefinition $Windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
    $null = $asyncWindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)
}
#endregion

#=======================================================
# LOAD ASSEMBLIES
#=======================================================
[System.Reflection.Assembly]::LoadWithPartialName('WindowsFormsIntegration') | out-null # Call the EnableModelessKeyboardInterop
If(Test-IsISE){[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Application') | out-null} #Encapsulates a Windows Presentation Foundation application.
[System.Reflection.Assembly]::LoadWithPartialName('presentationframework') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('PresentationCore') | out-null


$Runspace = [runspacefactory]::CreateRunspace()
$Runspace.ApartmentState = "STA"
$Runspace.ThreadOptions = "ReuseThread"
$Runspace.Open()
#pass the variables above to variables in Code runspace
$Runspace.SessionStateProxy.SetVariable("XAMLFilePath",$XAMLFilePath)
$Runspace.SessionStateProxy.SetVariable("FunctionPath",$FunctionPath)
$Runspace.SessionStateProxy.SetVariable("ResourcePath",$ResourcePath)
#$Runspace.SessionStateProxy.SetVariable("m365Hash",$M365CommonService)
$Runspace.SessionStateProxy.SetVariable("intuneHash",$IntuneService)
$Runspace.SessionStateProxy.SetVariable("OfflineMode",$OfflineMode)
$Runspace.SessionStateProxy.SetVariable("CloudLocation",$Cloud)
$Runspace.SessionStateProxy.SetVariable("DebugMode",$DebugMode)

$code = {

    #=======================================================
    # FUNCTIONS INSIDE MAIN RUNSPACE
    #=======================================================
    . "$FunctionPath\UIControls.ps1"

    [string]$XAML = (get-content $XAMLFilePath -ReadCount 0) -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window' -replace 'Click=".*','/>'
    #convert XAML to XML just to grab info using xml dot sourcing (Not used to process form)
    [xml]$XML = $XAML

    #grab the list of merged dictionaries in XML, replace the path with Powershell
    $MergedDictionaries = $XML.Window.'Window.Resources'.ResourceDictionary.'ResourceDictionary.MergedDictionaries'.ResourceDictionary.Source
    #$XML.SelectNodes("//*[@Source]")

    #grab all style files
    $Resources = Get-ChildItem "$ResourcePath\Styles" -Filter *.xaml

    # replace the resource path
    foreach ($Source in $MergedDictionaries)
    {
        $FileName = Split-Path $Source -Leaf
        $ActualPath = $Resources | Where {$_.Name -match $FileName} | Select -ExpandProperty FullName
        $XAML = $XAML.replace($Source,$ActualPath) #  ($ActualPath -replace "\\","/")
    }
    $XAML = $XAML -Replace "@EndpointMenu",$SelectorMenu
    #convert XAML to XML
    [xml]$XAML = $XAML
    <#
    #Paste the GUI here
    [xml]$xaml = @"

"@
    #>
    $syncHash = [hashtable]::Synchronized(@{})
    $reader=(New-Object System.Xml.XmlNodeReader $xaml)
    try{
        $syncHash.Window=[Windows.Markup.XamlReader]::Load( $reader )
    }
    catch{
        $syncHash.critError = $true
        $syncHash.Error = $_.Exception.Message
        Exit
    }

    #*=============================================
    #* RUNSPACE FUNCTIONS
    #*=============================================
    Function Close-UI
    {
        if ($syncHash.hadCritError) { Write-Host -Message "Background thread had a critical error" -ForegroundColor red }
        #if runspace had errored Dispose the UI
        if (!($syncHash.isClosing)) { $syncHash.Window.Close() }
    }

    function Test-UIEndpointSelection
    {
        param($syncHash,$FunctionPath,$TenantName,$m365Hash,$IntuneHash,$ProductFilter,$CategoryFilter,$DomainBox,$IPv4Box,$Ipv6Box,$LoggingBox,$OfflineMode,$DebugMode)

        $syncHash.Host = $host
        $Runspace = [runspacefactory]::CreateRunspace()
        $Runspace.ApartmentState = "STA"
        $Runspace.ThreadOptions = "ReuseThread"
        $Runspace.Open()
        #pass the params above to variables in Code
        $Runspace.SessionStateProxy.SetVariable("syncHash",$syncHash)
        $Runspace.SessionStateProxy.SetVariable("FunctionPath",$FunctionPath)
        $Runspace.SessionStateProxy.SetVariable("TenantName",$TenantName)
        $Runspace.SessionStateProxy.SetVariable("m365Hash",$m365Hash)
        $Runspace.SessionStateProxy.SetVariable("IntuneHash",$IntuneHash)
        $Runspace.SessionStateProxy.SetVariable("ProductFilter",$ProductFilter)
        $Runspace.SessionStateProxy.SetVariable("CategoryFilter",$CategoryFilter)
        $Runspace.SessionStateProxy.SetVariable("DomainBox",$DomainBox)
        $Runspace.SessionStateProxy.SetVariable("IPv4Box",$IPv4Box)
        $Runspace.SessionStateProxy.SetVariable("Ipv6Box",$Ipv6Box)
        $Runspace.SessionStateProxy.SetVariable("LoggingBox",$LoggingBox)
        $Runspace.SessionStateProxy.SetVariable("OfflineMode",$OfflineMode)
        $Runspace.SessionStateProxy.SetVariable("DebugMode",$DebugMode)

        $code = {
             # Import Function in sub runspace
            . "$FunctionPath\Test-IpAddress.ps1"
            . "$FunctionPath\ConvertFrom-MarkdownTable.ps1"
            . "$FunctionPath\UIControls.ps1"

            Update-RunspaceProgress -RunspaceHash $syncHash -Message 'Populating Endpoint list...' -Indeterminate

            #if the offline mode is true, use local file
            If( [Boolean]::Parse($OfflineMode) ){
                Update-RunspaceLogging -RunspaceHash $syncHash -Message ("Populating Endpoint list from local md file: {0}" -f $m365Hash.mdOfflinePath)
                $Content = Get-Content $m365Hash.mdOfflinePath
            }
            Else{
                Update-RunspaceLogging -RunspaceHash $syncHash -Message ("Populating Endpoint list from url: {0}" -f $m365Hash.mdUri)
                $Page = Invoke-WebRequest $m365Hash.mdUri -UseBasicParsing
                $Content = $Page.Content
            }

            If($DebugMode){
                Update-RunspaceLogging -RunspaceHash $syncHash -Message ("`nGrabbed content: {0}" -f $Content)
            }
            Update-RunspaceProgress -RunspaceHash $syncHash -Message ("Building list of domains and Ip addresses for: {0}" -f $ProductFilter) -Indeterminate

            $tables = ConvertFrom-M365Table -InputObject $Content
            $ProductFilter = $ProductFilter.Replace('_',' ')

            Update-RunspaceLogging -RunspaceHash $syncHash -Message ("Endpoint filtered to: {0}" -f $ProductFilter)
            #$filter out the table based on product filter
            If($ProductFilter -ne "Full Microsoft 365"){
                $tables = $tables | Where {$_.Name -eq $ProductFilter}
            }

            #list selected options
            Update-RunspaceLogging -RunspaceHash $syncHash -Message ("Domain option set to: {0}`nIPv4 option set to: {1}`nIPv6 option set to: {2}" -f $DomainBox,$IPv4Box,$IPv6Box)

            $totalEndpoints = 0
            #If( [Boolean]::Parse($DomainBox) ){$DomainsToTest = $tables.domains; $totalEndpoints += $DomainsToTest.Count}
            #If( [Boolean]::Parse($IPv4Box) ){$IPv4ToTest = $tables.IPv4Addresses; $totalEndpoints += $IPv4ToTest.Count}
            #If( [Boolean]::Parse($IPv6Box) ){$IPv6ToTest = $tables.IPv6Addresses; $totalEndpoints += $IPv6ToTest.Count}
            #get all domains and ports, then find only unique
            If( [Boolean]::Parse($DomainBox) ){
                $DomainsToTest = @()
                Foreach($table in $tables){
                    Foreach($domain in $table.Domains){
                        Foreach($Port in $table.Ports){
                            If($domain -notmatch '\s'){
                                $DomainsToTest += ('{0}:{1}' -f $domain,$Port.ToString())
                            }
                        }
                    }
                }
                $DomainsToTest = $DomainsToTest | Select -Unique
                $totalEndpoints += $DomainsToTest.Count
            }

            #get all IPv4 and ports, then find only unique
            If( [Boolean]::Parse($IPv4Box) ){
                $IPv4ToTest = @()
                <#
                #grab each ipv4 with ports
                Foreach($table in $tables){
                    Foreach($ipv4 in $table.IPv4Addresses){
                        Foreach($Port in $table.Ports){
                            $IPv4ToTest+= ('{0}|{1}' -f $ipv4,$Port.ToString())
                        }
                    }
                }
                $IPv4ToTest= $IPv4ToTest | Select -Unique
                #>
                #find any unique ipv4 addresses
                $IPv4ToTest= $tables.IPv4Addresses | Select -Unique
                $totalEndpoints += $IPv4ToTest.Count
            }

            #get all IPv6 and ports, then find only unique
            If( [Boolean]::Parse($IPv6Box) ){
                $IPv6ToTest = @()
                <#
                #grab each ip with ports
                Foreach($table in $tables){
                    Foreach($ipv6 in $table.IPv6Addresses){
                        Foreach($Port in $table.Ports){
                            #combine IP with Ports; don't use : as separator
                            $IPv6ToTest+= ('{0}|{1}' -f $ipv6,$Port.ToString())
                        }
                    }
                }
                $IPv6ToTest= $IPv6ToTest | Select -Unique
                #>
                $IPv6ToTest= $tables.IPv6Addresses | Select -Unique
                $totalEndpoints += $IPv6ToTest.Count
            }

            Update-RunspaceLogging -RunspaceHash $syncHash -Message ("Found [{0}] endpoints to test connections" -f $totalEndpoints)

            $DNSCache = Get-DnsClientCache
            $i=0
            $d=0
            $SuccessDomain=0
            $FailedDomain=0
            #Update-RunspaceElement -RunspaceHash $syncHash -ElementName 'domainNum' -Wildcard -Property Text -Value $SuccessDomain
            Measure-Command {

                Foreach($domain in $DomainsToTest)
                {
                    Switch-RunspaceTabItem  -RunspaceHash $syncHash -TabControl 'menuNavigation' -Name 'Domain'
                    $i++
                    $d++
                    $Address = $domain.Split(':')[0]
                    $port = $domain.Split(':')[1]

                    #Attempt to get local cache
                    If($Address -match '^\*'){
                        If($DNSCache.Name | Where {$_ -like $Address}){
                            $Address = $DNSCache.Name | Where {$_ -like $Address}| Select -First 1
                        }Else{
                            $Address = $Address.replace('*','').Trim('.')
                        }
                    }

                    #replace tenant placeholder with tenant
                    If($Address -match '\<(.*?)\>'){$Address = $Address.replace($matches[0],$tenantName)}
                    #increment progress bar from total of all endpoints
                    Update-RunspaceProgress -RunspaceHash $syncHash -MaxStep $totalEndpoints -Step $i -Message ("Testing connection to domain: {0}" -f $Address)
                    #determine if port is there, if so use it in test
                    If($null -ne $port){
                        $Results = Test-NetConnection $Address -Port $port -WarningAction SilentlyContinue
                    }Else{
                        $Results = Test-NetConnection $Address -WarningAction SilentlyContinue
                    }

                    If($Results.TcpTestSucceeded){
                        $SuccessDomain++
                        $StatusMessage = 'Success'
                        Update-RunspaceElement -RunspaceHash $syncHash -ElementName 'domainNumSuccess' -Property Text -Value $SuccessDomain
                    }
                    Else{
                        $FailedDomain++
                        $StatusMessage = 'Failed'
                        Update-RunspaceElement -RunspaceHash $syncHash -ElementName 'domainNumFailed' -Property Text -Value $FailedDomain
                        Update-RunspaceLogging -RunspaceHash $syncHash -LoggingBox "domainTable" -Message ("Failed: {0}:{1}" -f $Address,$Port)
                    }
                    Update-RunspaceElement -RunspaceHash $syncHash -ElementName 'domainNumTotal' -Property Text -Value $d
                    Update-RunspaceLogging -RunspaceHash $syncHash -Message ("Tested connection to domain: {0}, Status: {1}" -f $Address,$StatusMessage)

                } #end Domain loop for set

                $v=0
                $SuccessIPv4=0
                $FailedIPv4=0
                $TestIPv4Connections = $false
                Foreach($IPv4 in $IPv4ToTest)
                {
                    Switch-RunspaceTabItem  -RunspaceHash $syncHash -TabControl 'menuNavigation' -Name 'IPv4'
                    $i++
                    $v++
                    $Address = $IPv4.Split('|')[0]
                    $port = $IPv4.Split('|')[1]
                    If($TestIPv4Connections){
                        #increment progress bar from total of all endpoints
                        Update-RunspaceProgress -RunspaceHash $syncHash -MaxStep $totalEndpoints -Step $i -Message ("Testing connection to IPv4 Address: {0}" -f $Address)
                        #determine if port is there, if so use it in test
                        If($null -ne $port){
                            $Results = Test-NetConnection $Address -Port $port -WarningAction SilentlyContinue
                        }Else{
                            $Results = Test-NetConnection $Address -WarningAction SilentlyContinue
                        }
                        If($Results.TcpTestSucceeded){
                            $SuccessIPv4++
                            $StatusMessage = 'Success'
                            Update-RunspaceElement -RunspaceHash $syncHash -ElementName 'ipv4NumSuccess' -Property Text -Value $SuccessIPv4
                        }
                        Else{
                            $FailedIPv4++
                            $StatusMessage = 'Failed'
                            Update-RunspaceElement -RunspaceHash $syncHash -ElementName 'ipv4NumFailed' -Property Text -Value $FailedIPv4
                            Update-RunspaceLogging -RunspaceHash $syncHash -LoggingBox "ipv4Table" -Message ("Failed: {0}:{1}" -f $Address,$Port)
                        }
                    }Else{
                        Update-RunspaceProgress -RunspaceHash $syncHash -MaxStep $totalEndpoints -Step $i -Message ("Adding IPv4 Address: {0} to list" -f $Address)
                        Update-RunspaceLogging -RunspaceHash $syncHash -LoggingBox "ipv4Table" -Message ("IPv4Address: {0}" -f $Address)
                    }

                    Update-RunspaceElement -RunspaceHash $syncHash -ElementName 'ipv4NumTotal' -Property Text -Value $v
                    Update-RunspaceLogging -RunspaceHash $syncHash -Message ("Tested connection to IPv4 Address: {0}, Status: {1}" -f $Address,$StatusMessage)
                } #end IPv4 loop for set

                $v=0
                $SuccessIPv6=0
                $FailedIPv6=0
                $TestIPv6Connections = $false
                Foreach($IPv6 in $IPv6ToTest)
                {
                    Switch-RunspaceTabItem  -RunspaceHash $syncHash -TabControl 'menuNavigation' -Name 'IPv6'
                    $i++
                    $v++
                    $Address = $IPv6.Split('|')[0]
                    $port = $IPv6.Split('|')[1]
                    If($TestIPv6Connections){
                        #increment progress bar from total of all endpoints
                        Update-RunspaceProgress -RunspaceHash $syncHash -MaxStep $totalEndpoints -Step $i -Message ("Testing connection to IPv6 Address: {0}" -f $Address)
                        #determine if port is there, if so use it in test
                        If($null -ne $port){
                            $Results = Test-NetConnection $Address -Port $port -WarningAction SilentlyContinue
                        }Else{
                            $Results = Test-NetConnection $Address -WarningAction SilentlyContinue
                        }
                        If($Results.TcpTestSucceeded){
                            $SuccessIPv6++
                            $StatusMessage = 'Success'
                            Update-RunspaceElement -RunspaceHash $syncHash -ElementName 'ipv6NumSuccess' -Property Text -Value $SuccessIPv6
                        }
                        Else{
                            $FailedIPv6++
                            $StatusMessage = 'Failed'
                            Update-RunspaceElement -RunspaceHash $syncHash -ElementName 'ipv6NumFailed' -Property Text -Value $FailedIPv6
                            Update-RunspaceLogging -RunspaceHash $syncHash -LoggingBox "ipv6Table" -Message ("Failed: {0}:{1}" -f $Address,$Port)
                        }
                    }
                    Else{
                        Update-RunspaceProgress -RunspaceHash $syncHash -MaxStep $totalEndpoints -Step $i -Message ("Adding IPv6 Address: {0} to list" -f $Address)
                        Update-RunspaceLogging -RunspaceHash $syncHash -LoggingBox "ipv6Table" -Message ("IPv6Address: {0}" -f $Address)
                    }
                    Update-RunspaceElement -RunspaceHash $syncHash -ElementName 'ipv6NumTotal' -Property Text -Value $v
                    Update-RunspaceLogging -RunspaceHash $syncHash -Message ("Tested connection to IPv6 Address: {0}, Status: {1}" -f $Address,$StatusMessage)

                } #end IPv6 loop for set
            } -OutVariable Measured | Out-Null
            Update-RunspaceProgress -RunspaceHash $syncHash -MaxStep 100 -Step 100 -Message ("Done. Elapsed time: {0}" -f $Measured.Time) -Color 'Blue'
        }
        $PSinstance = [powershell]::Create().AddScript($Code)
        $PSinstance.Runspace = $Runspace
        $job = $PSinstance.BeginInvoke()
    }

    function Update-UIEndpointList
    {
        param($syncHash,$m365Hash,$FunctionPath,$TargetPanel,$LoggingBox,$OfflineMode,$DebugMode)

        $syncHash.Host = $host
        $Runspace = [runspacefactory]::CreateRunspace()
        $Runspace.ApartmentState = "STA"
        $Runspace.ThreadOptions = "ReuseThread"
        $Runspace.Open()
        #pass the params above to variables in Code
        $Runspace.SessionStateProxy.SetVariable("syncHash",$syncHash)
        $Runspace.SessionStateProxy.SetVariable("FunctionPath",$FunctionPath)
        $Runspace.SessionStateProxy.SetVariable("m365Hash",$m365Hash)
        $Runspace.SessionStateProxy.SetVariable("TargetPanel",$TargetPanel)
        $Runspace.SessionStateProxy.SetVariable("LoggingBox",$LoggingBox)
        $Runspace.SessionStateProxy.SetVariable("OfflineMode",$OfflineMode)
        $Runspace.SessionStateProxy.SetVariable("DebugMode",$DebugMode)

        $code = {
            # Import Function in sub runspace
            . "$FunctionPath\Test-IpAddress.ps1"
            . "$FunctionPath\ConvertFrom-MarkdownTable.ps1"
            . "$FunctionPath\UIControls.ps1"


            Update-RunspaceProgress -RunspaceHash $syncHash -Message 'Populating Endpoint Selection...' -Indeterminate

            #if the offline mode is true, use local file
            If( [Boolean]::Parse($OfflineMode) ){
                Update-RunspaceLogging -RunspaceHash $syncHash -Message ("Populating Endpoint Selection local md file: {0}" -f $m365Hash.mdOfflinePath)
                $Content = Get-Content $m365Hash.mdOfflinePath
            }
            Else{
                Update-RunspaceLogging -RunspaceHash $syncHash -Message ("Populating Endpoint Selection from url: {0}" -f $m365Hash.mdUri)
                $Page = Invoke-WebRequest $m365Hash.mdUri -UseBasicParsing
                $Content = $Page.Content
            }

            If($Debug){
                Update-RunspaceLogging -RunspaceHash $syncHash -Message ("Grabbed content: {0}" -f $Content)
            }

            $tables = ConvertFrom-M365Table -InputObject $Content

            $EndpointCategories = @("Full Microsoft 365")
            $EndpointCategories += $tables.Name | Select -Unique

            Update-RunspaceLogging -RunspaceHash $syncHash -Message ("Found Categories: {0}" -f ($EndpointCategories -join ','))

            $i =0
            Foreach($Category in $EndpointCategories)
            {
                $i++
                Update-RunspaceProgress -RunspaceHash $syncHash -MaxStep $EndpointCategories.count -Step $i -Message ("Attempting to add to menu: {0}" -f $Category)
                $syncHash.Window.Dispatcher.Invoke([action]{
                    Try{
                        $NewRadioButton = New-Object System.Windows.Controls.RadioButton
                        $NewRadioButton.Name = $Category.Replace(' ','_')
                        $NewRadioButton.Content = $Category
                        $NewRadioButton.Height = 20
                        $NewRadioButton.HorizontalAlignment = "Left"
                        $NewRadioButton.VerticalContentAlignment="Center"
                        $NewRadioButton.VerticalAlignment="Top"
                        $NewRadioButton.FontSize="16"
                        $NewRadioButton.Height="30"
                        $NewRadioButton.Width="436"
                        $NewRadioButton.GroupName="endpoint"
                        $syncHash.$TargetPanel.AddChild($NewRadioButton)

                        $syncHash.$LoggingBox.AppendText(("`nAdded to menu: {0}" -f $NewRadioButton))
                    }
                    Catch{
                        $syncHash.$LoggingBox.AppendText(("`nError adding [{0}] to Menu to {1}: {2}" -f $NewRadioButton,$TargetPanel,$_))
                    }
                },"Normal")
                Start-Sleep -Milliseconds 600
            }


            If($EndpointCategories.count -gt 0){
                Update-RunspaceProgress -RunspaceHash $syncHash -MaxStep 100 -Step 100 -Message "Done. Select an Endpoint and click Run"
            }Else{
                Update-RunspaceProgress -RunspaceHash $syncHash -MaxStep 100 -Step 100 -Message ("Errors occurred when generating menu") -Color 'Red'
            }

            #Update-UIProgress -Indeterminate -ProgressBarObject $synHash.progressBar -ProgressTextObject $synHash.progressText -Message 'Populating Endpoint Selection...'

        }
        $PSinstance = [powershell]::Create().AddScript($Code)
        $PSinstance.Runspace = $Runspace
        $job = $PSinstance.BeginInvoke()

    }

    function NullCount {
        [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null
        [Microsoft.VisualBasic.Interaction]::MsgBox("Please select a ping count first",'OKOnly,Information',"Ping")
    }

    #*=============================================
    #* UI OBJECTS
    #*=============================================
    #canvas
    $syncHash.startCanvas = $syncHash.Window.FindName("startCanvas") #System.Windows.Controls.Canvas
    $syncHash.startCloudListBox = $syncHash.Window.FindName("startCloudListBox") #System.Windows.Controls.ListBox
    $syncHash.startBegin = $syncHash.Window.FindName("startBegin") #System.Windows.Controls.Button: Run Start
    $syncHash.startOfflineMode = $syncHash.Window.FindName("startOfflineMode") #System.Windows.Controls.CheckBox Content:Offline mode IsChecked:False

    # Tab 1
    $syncHash.endpointName = $syncHash.Window.FindName("endpointName") #System.Windows.Controls.TextBox
    $syncHash.optionsTab = $syncHash.Window.FindName("optionsTab") #System.Windows.Controls.TabItem Header:OptionsTab Content:
    $syncHash.endpointSelected = $syncHash.Window.FindName("endpointSelected") #System.Windows.Controls.TextBox
    $syncHash.endpointsPanel = $syncHash.Window.FindName("endpointsPanel") #System.Windows.Controls.StackPanel
    $syncHash.categoryPanel = $syncHash.Window.FindName("categoryPanel") #System.Windows.Controls.StackPanel
    $syncHash.categorySelected = $syncHash.Window.FindName("categorySelected") #System.Windows.Controls.TextBox
    $syncHash.connectionPanel = $syncHash.Window.FindName("connectionPanel") #System.Windows.Controls.StackPanel
    $syncHash.ipv4 = $syncHash.Window.FindName("ipv4") #System.Windows.Controls.CheckBox Content:IPv4 IsChecked:False
    $syncHash.ipv6 = $syncHash.Window.FindName("ipv6") #System.Windows.Controls.CheckBox Content:IPv6 IsChecked:False
    $syncHash.domain = $syncHash.Window.FindName("domain") #System.Windows.Controls.CheckBox Content:Domains IsChecked:False
    $syncHash.fullEndpoints = $syncHash.Window.FindName("fullEndpoints") #System.Windows.Controls.RadioButton Content:Full (Required + Optional) IsChecked:False
    $syncHash.requiredEndpoints = $syncHash.Window.FindName("requiredEndpoints") #System.Windows.Controls.RadioButton Content:Required endpoints IsChecked:False
    $syncHash.tenantName = $syncHash.Window.FindName("tenantName") #System.Windows.Controls.TextBox
    $syncHash.menuNavigation = $syncHash.Window.FindName("menuNavigation") #System.Windows.Controls.TabControl Items.Count:5
    $syncHash.offlineMode = $syncHash.Window.FindName("offlineMode") #System.Windows.Controls.CheckBox Content:Offline mode IsChecked:False
    $syncHash.offlineDesc = $syncHash.Window.FindName("offlineDesc")
    $syncHash.Run = $syncHash.Window.FindName("Run") #System.Windows.Controls.Button: Run

    # Tab 2 -domain
    $syncHash.domainTab = $syncHash.Window.FindName("domainTab") #System.Windows.Controls.TabItem Header:domainTab Content:
    $syncHash.domainTable = $syncHash.Window.FindName("domainTable") #System.Windows.Controls.RichTextBox
    $syncHash.domainBack = $syncHash.Window.FindName("domainBack") #System.Windows.Controls.Button: Back
    $syncHash.domainExport = $syncHash.Window.FindName("domainExport") #System.Windows.Controls.Button: Export List
    $syncHash.domainfailedReport = $syncHash.Window.FindName("domainfailedReport") #System.Windows.Controls.RadioButton Content:Failed Endpoint only IsChecked:False
    $syncHash.domainFullReport = $syncHash.Window.FindName("domainFullReport") #System.Windows.Controls.RadioButton Content:Full Report IsChecked:False
    $syncHash.domainNumFailed = $syncHash.Window.FindName("domainNumFailed") #System.Windows.Controls.TextBlock
    $syncHash.domainNumSuccess = $syncHash.Window.FindName("domainNumSuccess") #System.Windows.Controls.TextBlock
    $syncHash.domainNumTotal = $syncHash.Window.FindName("domainNumTotal") #System.Windows.Controls.TextBlock
    $syncHash.domainExportPanel = $syncHash.Window.FindName("domainExportPanel") #System.Windows.Controls.StackPanel
    $syncHash.domainExportSelected = $syncHash.Window.FindName("domainExportSelected") #System.Windows.Controls.TextBox

    # Tab 4 - IPv4
    $syncHash.ipv4Tab = $syncHash.Window.FindName("ipv4Tab") #System.Windows.Controls.TabItem Header:ipv4Tab Content:
    $syncHash.ipv4Table = $syncHash.Window.FindName("ipv4Table") #System.Windows.Controls.RichTextBox
    $syncHash.ipv4Back = $syncHash.Window.FindName("ipv4Back") #System.Windows.Controls.Button: Back
    $syncHash.ipv4Export = $syncHash.Window.FindName("ipv4Export") #System.Windows.Controls.Button: Export List
    $syncHash.ipv4ATPFormat = $syncHash.Window.FindName("ipv4ATPFormat") #System.Windows.Controls.RadioButton Content:Windows Firewall IsChecked:False
    $syncHash.ipv4UbiquitiFormat = $syncHash.Window.FindName("ipv4UbiquitiFormat") #System.Windows.Controls.RadioButton Content:Ubiquiti IsChecked:False
    $syncHash.ipv4F5Format = $syncHash.Window.FindName("ipv4F5Format") #System.Windows.Controls.RadioButton Content:F5 IsChecked:False
    $syncHash.ipv4PaloAltoFormat = $syncHash.Window.FindName("ipv4PaloAltoFormat") #System.Windows.Controls.RadioButton Content:Palo Alto IsChecked:False
    $syncHash.ipv4CiscoFormat = $syncHash.Window.FindName("ipv4CiscoFormat") #System.Windows.Controls.RadioButton ContentCisco IsChecked:False
    $syncHash.ipv4CSVFormat = $syncHash.Window.FindName("ipv4CSVFormat") #System.Windows.Controls.RadioButton Content:CSV IsChecked:False
    $syncHash.ipv4FormatPanel = $syncHash.Window.FindName("ipv4FormatPanel") #System.Windows.Controls.StackPanel
    $syncHash.ipv4FormatSelected = $syncHash.Window.FindName("ipv4FormatSelected") #System.Windows.Controls.TextBox
    $syncHash.ipv4NumTotal = $syncHash.Window.FindName("ipv4NumTotal") #System.Windows.Controls.TextBlock

    # Tab 4 - IPv6
    $syncHash.ipv6Tab = $syncHash.Window.FindName("ipv6Tab") #System.Windows.Controls.TabItem Header:ipv6Tab Content:
    $syncHash.ipv6Table = $syncHash.Window.FindName("ipv6Table") #System.Windows.Controls.RichTextBox
    $syncHash.ipv6Back = $syncHash.Window.FindName("ipv6Back") #System.Windows.Controls.Button: Back
    $syncHash.ipv6Export = $syncHash.Window.FindName("ipv6Export") #System.Windows.Controls.Button: Export List
    $syncHash.ipv6ATPFormat = $syncHash.Window.FindName("ipv6ATPFormat") #System.Windows.Controls.RadioButton Content:Windows Firewall IsChecked:False
    $syncHash.ipv6UbiquitiFormat = $syncHash.Window.FindName("ipv6UbiquitiFormat") #System.Windows.Controls.RadioButton Content:Ubiquiti IsChecked:False
    $syncHash.ipv6F5Format = $syncHash.Window.FindName("ipv6F5Format") #System.Windows.Controls.RadioButton Content:F5 IsChecked:False
    $syncHash.ipv6PaloAltoFormat = $syncHash.Window.FindName("ipv6PaloAltoFormat") #System.Windows.Controls.RadioButton Content:Palo Alto IsChecked:False
    $syncHash.ipv6CiscoFormat = $syncHash.Window.FindName("ipv6CiscoFormat") #System.Windows.Controls.RadioButton ContentCisco IsChecked:False
    $syncHash.ipv6CSVFormat = $syncHash.Window.FindName("ipv6CSVFormat") #System.Windows.Controls.RadioButton Content:CSV IsChecked:False
    $syncHash.ipv6FormatPanel = $syncHash.Window.FindName("ipv6FormatPanel") #System.Windows.Controls.StackPanel
    $syncHash.ipv6FormatSelected = $syncHash.Window.FindName("ipv6FormatSelected") #System.Windows.Controls.TextBox
    $syncHash.ipv6NumTotal = $syncHash.Window.FindName("ipv6NumTotal") #System.Windows.Controls.TextBlock

    #Tab 5 - logging
    $syncHash.Logging = $syncHash.Window.FindName("Logging") #System.Windows.Controls.RichTextBox
    $syncHash.loggingBack = $syncHash.Window.FindName("loggingBack") #System.Windows.Controls.Button: Back
    $syncHash.OutputQueueText = $syncHash.Window.FindName("OutputQueueText") #System.Windows.Controls.Label: 0

    #main window
    $syncHash.progressBar = $syncHash.Window.FindName("progressBar") #System.Windows.Controls.ProgressBar Minimum:0 Maximum:100 Value:0
    $syncHash.progressNumber = $syncHash.Window.FindName("progressNumber") #System.Windows.Controls.TextBlock
    $syncHash.progressText = $syncHash.Window.FindName("progressText") #System.Windows.Controls.TextBlock
    $syncHash.closeApp = $syncHash.Window.FindName("closeApp") #System.Windows.Controls.Button: Close

    $syncHash.Window.Topmost = $true

    $AppendName = ("(" +$CloudLocation + ")")
    $syncHash.Window.Title = ('M365 Endpoint Network Analyzer' + $AppendName)

    $syncHash.endpointName.Text = ($syncHash.endpointName.Text + ' '+ $AppendName)
    #TESTS
    $syncHash.Logging.AppendText(("`nXAML used: {0}" -f $XAMLFilePath))
    $syncHash.Logging.AppendText(("`nFunctionPath: {0}" -f $FunctionPath))
    $syncHash.Logging.AppendText(("`nResourcePath: {0}" -f $ResourcePath))
    $syncHash.Logging.AppendText(("`nOfflineMode: {0}" -f $OfflineMode))

    $syncHash.startOfflineMode.IsChecked = $OfflineMode
    #disable the ability to change the mode on option tab
    #if offline is true, otherwise hide the notification
    If($syncHash.startOfflineMode.IsChecked){
        $syncHash.offlineMode.IsChecked = $OfflineMode
        $syncHash.offlineMode.IsEnabled = $false
    }Else{
        $syncHash.offlineMode.Visibility = 'hidden'
        $syncHash.offlineDesc.Visibility = 'hidden'
    }

    @('WorldWide','DoD','GCC','GCC High','China','Germany') | ForEach-object {$syncHash.startCloudListBox.Items.Add($_)} | Out-Null

    $syncHash.startCloudListBox.SelectedItem = $CloudLocation

    $syncHash.domain.IsChecked = $True
    $syncHash.ipv4.IsChecked = $True
    $syncHash.ipv6.IsChecked = $True
    #$syncHash.fullEndpoints.IsChecked = $True

    If($DebugMode){
        $syncHash.endpointSelected.Visibility = 'Visible'
        $syncHash.categorySelected.Visibility = 'Visible'
        $syncHash.domainExportSelected.Visibility = 'Visible'
        $syncHash.ipv4FormatSelected.Visibility = 'Visible'
        $syncHash.ipv6FormatSelected.Visibility = 'Visible'
    }
    #========================
    # EVENT HANDLERS
    #========================
    ## Checked Events
    [System.Windows.RoutedEventHandler]$Script:CheckBoxChecked = {
        Update-RunspaceElement -RunspaceHash $syncHash -ElementName $This.Name -Property Visibility -Value 'Hidden'
        Update-RunspaceLogging -RunspaceHash $syncHash -Message ("{0} isChecked: {1}" -f $This.Name,$This.IsChecked)
        <#
        #Creates a Radio-like check boxes; if one is checked the others uncheck
        $syncHash.Content.Children | Where {
            $_ -is [System.Windows.Controls.CheckBox] -AND $This.Name -ne $_.Name
        } | ForEach {
            $_.IsChecked = $False
        }
        #>
    }

    #Get all check boxes and add event handler
    $syncHash.Content.Children | Where {
        $_ -is [System.Windows.Controls.CheckBox]
    } | ForEach {
        $_.AddHandler([System.Windows.Controls.CheckBox]::CheckedEvent, $CheckBoxChecked)
    }

    #build action for endpoint radio selection; currently fills in text box
    [System.Windows.RoutedEventHandler]$Script:EndpointSelectorEventHandler = {
        $syncHash.endpointSelected.Text = $_.source.name
        If($DebugMode){Update-RunspaceLogging -RunspaceHash $syncHash -Message ("{0} isSelected: {1}" -f  $_.source.name,$_.source.isChecked)}
        If(-not([string]::IsNullOrEmpty($syncHash.tenantName.Text)) -and $syncHash.endpointSelected.Text -and $syncHash.categorySelected.Text){
            $syncHash.run.IsEnabled = $True
        }Else{
            $syncHash.run.IsEnabled = $False
        }
    }
    #build event to check for selection in endpoint stack panel
    $syncHash.endpointsPanel.AddHandler([System.Windows.Controls.RadioButton]::CheckedEvent, $EndpointSelectorEventHandler)

    #build action for category radio selection; currently fills in text box
    [System.Windows.RoutedEventHandler]$Script:CategorySelectorEventHandler = {
        $syncHash.categorySelected.Text = $_.source.name
        If($DebugMode){Update-RunspaceLogging -RunspaceHash $syncHash -Message ("{0} isSelected: {1}" -f  $_.source.name,$_.source.isChecked)}
        If(-not([string]::IsNullOrEmpty($syncHash.tenantName.Text)) -and $syncHash.endpointSelected.Text -and $syncHash.categorySelected.Text){
            $syncHash.run.IsEnabled = $True
        }Else{
            $syncHash.run.IsEnabled = $False
        }
    }
    #build event to check for selection in category stack panel
    $syncHash.categoryPanel.AddHandler([System.Windows.Controls.RadioButton]::CheckedEvent, $CategorySelectorEventHandler)


    #build action for domain export radio selection; currently fills in text box
    [System.Windows.RoutedEventHandler]$Script:DomainSelectorEventHandler = {
        $syncHash.domainExportSelected.Text = $_.source.name
        If($DebugMode){Update-RunspaceLogging -RunspaceHash $syncHash -Message ("{0} isSelected: {1}" -f  $_.source.name,$_.source.isChecked)}
    }
    #build event to check for selection in domain export stack panel
    $syncHash.domainExportPanel.AddHandler([System.Windows.Controls.RadioButton]::CheckedEvent, $DomainSelectorEventHandler)

    #build action for ipv4 format radio selection; currently fills in text box
    [System.Windows.RoutedEventHandler]$Script:ipv4SelectorEventHandler = {
        $syncHash.ipv4FormatSelected.Text = $_.source.name
        If($DebugMode){Update-RunspaceLogging -RunspaceHash $syncHash -Message ("{0} isSelected: {1}" -f  $_.source.name,$_.source.isChecked)}
    }
    #build event to check for selection in ipv4 format panel
    $syncHash.ipv4FormatPanel.AddHandler([System.Windows.Controls.RadioButton]::CheckedEvent, $ipv4SelectorEventHandler)

    #build action for ipv6 format radio selection; currently fills in text box
    [System.Windows.RoutedEventHandler]$Script:ipv6SelectorEventHandler = {
        $syncHash.ipv6FormatSelected.Text = $_.source.name
        If($DebugMode){Update-RunspaceLogging -RunspaceHash $syncHash -Message ("{0} isSelected: {1}" -f  $_.source.name,$_.source.isChecked)}
    }
    #build event to check for selection in ipv6 format panel
    $syncHash.ipv6FormatPanel.AddHandler([System.Windows.Controls.RadioButton]::CheckedEvent, $ipv6SelectorEventHandler)

    # check tenant name if its changed
    $syncHash.tenantName.AddHandler(
        [System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent,
        [System.Windows.RoutedEventHandler]{
            If(-not([string]::IsNullOrEmpty($syncHash.tenantName.Text)) -and $syncHash.endpointSelected.Text -and $syncHash.categorySelected.Text){
                $syncHash.run.IsEnabled = $True
            }Else{
                $syncHash.run.IsEnabled = $False
            }
        }
    )

     # check tenant name if its changed
     $syncHash.startCloudListBox.AddHandler(
        [System.Windows.Controls.ListBox]::SelectionChangedEvent,
        [System.Windows.RoutedEventHandler]{
            $m365Hash = Get-M365Hash -Selection $_.source.SelectedItem
            $IntuneHash = Get-IntuneHash -Selection $_.source.SelectedItem
            Update-RunspaceLogging -RunspaceHash $syncHash -Message ("Selected Cloud endpoints from: {0}" -f $_.source.SelectedItem)
        }
    )


    #========================
    # CLICK ACTIONS
    #========================
    #back button actions
    (Get-UIHashVariable -HashName 'syncHash' -Name "Back" -Wildcard) | %{
        $_.Add_Click({
           Switch-UITabItem -TabControlObject $syncHash.menuNavigation -Name 'optionsTab'
        })
    }

    #run button
    $syncHash.Run.Add_Click({

        Test-UIEndpointSelection -syncHash $syncHash -FunctionPath $FunctionPath `
                -TenantName $syncHash.tenantName.Text `
                -m365Hash $m365Hash `
                -IntuneHash $IntuneHash `
                -CategoryFilter $syncHash.categorySelected.Text `
                -ProductFilter $syncHash.endpointSelected.Text `
                -DomainBox $syncHash.domain.IsChecked `
                -IPv4Box $syncHash.IPv4.IsChecked `
                -Ipv6Box $syncHash.IPv6.IsChecked `
                -OfflineMode $syncHash.offlineMode.IsChecked `
                -DebugMode $DebugMode
        })

    #start button
    $syncHash.startBegin.Add_Click({
        $syncHash.startCanvas.Visibility = 'hidden'
        
        Update-UIEndpointList -syncHash $syncHash `
                -m365Hash $m365Hash `
                -FunctionPath $FunctionPath `
                -TargetPanel 'endpointsPanel' `
                -LoggingBox 'Logging' `
                -OfflineMode $syncHash.offlineMode.IsChecked `
                -DebugMode $DebugMode
   })

    $syncHash.closeApp.Dispatcher.Invoke([action]{
        $syncHash.closeApp.Add_Click({
            $syncHash.Window.Dispatcher.Invoke([action]{ Close-UI })
            #$Script:Pwshell.EndInvoke($Handle) | Out-Null
            #$Script:uiScriptBlock.Close() | Out-Null
        })
    })

    $syncHash.Window.ShowDialog()
    $Runspace.Close()
    $Runspace.Dispose()
    $syncHash.Error = $Error
}

$PSinstance1 = [powershell]::Create().AddScript($Code)
$PSinstance1.Runspace = $Runspace
$job = $PSinstance1.BeginInvoke()

