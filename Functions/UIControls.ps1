
#region FUNCTION: Builds dynamic variables in form with alias
Function Get-UIVariable{
    param(
        [Parameter(Mandatory = $true, Position=0)]
        [string]$Prefix,
        [Parameter(Mandatory = $true, Position=1)]
        [string]$Name,
        [switch]$Wildcard

    )
    $UIVars = Get-Variable $Prefix*
    If($Wildcard){
        Return [array]($UIVars | Where {$_.Name -like ($Prefix + '*' + $Name + '*')}).Value
    }
    Else{
        Return [array]($UIVars | Where Name -eq ($Prefix + $Name)).Value
    }
}
#endregion

Function Get-UIHashVariable{
    param(
        [Parameter(Mandatory = $true, Position=0)]
        [string]$HashName,
        [Parameter(Mandatory = $true, Position=1)]
        [string]$Name,
        [switch]$Wildcard

    )
    $UIVars = Get-Variable $HashName -ValueOnly
    If($Wildcard){
        Return [array]($UIVars.GetEnumerator() | Where {$_.Name -like "*$name*"}).Value
    }
    Else{
        Return [array]($UIVars.GetEnumerator() | Where Name -eq $Name).Value
    }
}
#endregion

#region FUNCTION: Action for Next & back button to change tab
function Switch-UITabItem {
    param(
        [Parameter(Mandatory = $true, Position=0)]
        [System.Windows.Controls.TabControl]$TabControlObject,
        [Parameter(Mandatory = $true, Position=1,ParameterSetName="index")]
        [int]$increment,
        [Parameter(Mandatory = $true, Position=1,ParameterSetName="name")]
        [string]$name
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If ($PSCmdlet.ParameterSetName -eq "index") {
        #Add index number to current tab
        $newtab = $TabControlObject.SelectedIndex + $increment
        #ensure number is not greater than tabs
        If ($newtab -ge $TabControlObject.items.count) {
            $newtab=0
        }
        elseif ($newtab -lt 0) {
            $newtab = $TabControlObject.SelectedIndex - 1
        }
        #Set new tab index
        $TabControlObject.SelectedIndex = $newtab

        $message = ("index [{0}]" -f $newtab)
    }
    ElseIf($PSCmdlet.ParameterSetName -eq "name"){
        $newtab = $TabControlObject.items | Where Header -eq $name
        $newtab.IsSelected = $true

        $message = ("name [{0}]" -f $newtab.Header)

    }
}
#endregion

#region FUNCTION: Populates Intune URI in Hash table
Function Get-IntuneHash {
    param(
        [ValidateSet('WorldWide','DoD','GCC','GCC High','China','Germany')]
        [string]$Selection
    )
    switch($Selection){

        'WorldWide'
        {
            $IntuneService = @{
                serviceFilter = 'Intune Endpoints'
                sourceUri = "https://docs.microsoft.com/en-us/mem/intune/fundamentals/intune-endpoints"
                mdUri = "https://raw.githubusercontent.com/MicrosoftDocs/memdocs/master/memdocs/intune/fundamentals/intune-endpoints.md"
                mdOfflinePath = Join-Path -Path $EndPointTablesPath -ChildPath 'intune-endpoints.md'
            }
        }

        'DoD'
        {
            $IntuneService = @{
                serviceFilter = 'Intune Endpoints'
                sourceUri = "https://docs.microsoft.com/en-us/mem/intune/fundamentals/intune-us-government-endpoints"
                mdUri = "https://raw.githubusercontent.com/MicrosoftDocs/memdocs/master/memdocs/intune/fundamentals/intune-us-government-endpoints.md"
                mdOfflinePath = Join-Path -Path $EndPointTablesPath -ChildPath 'intune-endpoints.md'
            }
        }

        'GCC'
        {
            $IntuneService = @{
                serviceFilter = 'Intune Endpoints'
                sourceUri = "https://docs.microsoft.com/en-us/mem/intune/fundamentals/intune-us-government-endpoints"
                mdUri = "https://raw.githubusercontent.com/MicrosoftDocs/memdocs/master/memdocs/intune/fundamentals/intune-us-government-endpoints.md"
                mdOfflinePath = Join-Path -Path $EndPointTablesPath -ChildPath 'intune-endpoints.md'
            }
        }

        'GCC High'
        {
            $IntuneService = @{
                serviceFilter = 'Intune Endpoints'
                sourceUri = "https://docs.microsoft.com/en-us/mem/intune/fundamentals/intune-us-government-endpoints"
                mdUri = "https://raw.githubusercontent.com/MicrosoftDocs/memdocs/master/memdocs/intune/fundamentals/intune-us-government-endpoints.md"
                mdOfflinePath = Join-Path -Path $EndPointTablesPath -ChildPath 'intune-endpoints.md'
            }
        }

        'China'
        {

            $IntuneService = @{
                serviceFilter = 'Intune Endpoints'
                sourceUri = "https://docs.microsoft.com/en-us/mem/intune/fundamentals/china-endpoints"
                mdUri = "https://raw.githubusercontent.com/MicrosoftDocs/memdocs/master/memdocs/intune/fundamentals/intune-us-government-endpoints.md"
                mdOfflinePath = Join-Path -Path $EndPointTablesPath -ChildPath 'china-endpoints.md'
            }
        }

        'Germany'
        {
            $IntuneService = @{
                serviceFilter = 'Intune Endpoints'
                sourceUri = "https://docs.microsoft.com/en-us/mem/intune/fundamentals/intune-us-government-endpoints"
                mdUri = "https://raw.githubusercontent.com/MicrosoftDocs/memdocs/master/memdocs/intune/fundamentals/intune-us-government-endpoints.md"
                mdOfflinePath = Join-Path -Path $EndPointTablesPath -ChildPath 'intune-endpoints.md'
            }
        }

        default
        {
            $IntuneService = @{
                serviceFilter = 'Intune Endpoints'
                sourceUri = "https://docs.microsoft.com/en-us/mem/intune/fundamentals/intune-endpoints"
                mdUri = "https://raw.githubusercontent.com/MicrosoftDocs/memdocs/master/memdocs/intune/fundamentals/intune-endpoints.md"
                mdOfflinePath = Join-Path -Path $EndPointTablesPath -ChildPath 'intune-endpoints.md'
            }
        }
    }
    return $IntuneService
}
#endregion

#region FUNCTION: Populates M365 URI in Hash table
Function Get-M365Hash {
    param(
        [ValidateSet('WorldWide','DoD','GCC','GCC High','China','Germany')]
        [string]$Selection
    )
    switch($Selection){

        'WorldWide'
        {
            $M365CommonService = @{
                serviceFilter = "Microsoft 365 Common and Office Online"
                sourceUri = "https://docs.microsoft.com/en-us/microsoft-365/enterprise/urls-and-ip-address-ranges?view=o365-worldwide"
                mdUri = "https://raw.githubusercontent.com/MicrosoftDocs/microsoft-365-docs/public/microsoft-365/includes/office-365-worldwide-endpoints.md"
                mdOfflinePath = Join-Path -Path $EndPointTablesPath -ChildPath 'office-365-worldwide-endpoints.md'
            }
        }

        'DoD'
        {
            $M365CommonService = @{
                serviceFilter = "Microsoft 365 Common and Office Online"
                sourceUri = "https://docs.microsoft.com/en-us/microsoft-365/enterprise/microsoft-365-u-s-government-dod-endpoints?view=o365-worldwide"
                mdUri = "https://raw.githubusercontent.com/MicrosoftDocs/microsoft-365-docs/public/microsoft-365/includes/office-365-u.s.-government-dod-endpoints.md"
                mdOfflinePath = Join-Path -Path $EndPointTablesPath -ChildPath 'office-365-u.s.-government-dod-endpoints.md'
            }
        }

        'GCC'
        {
            $M365CommonService = @{
                serviceFilter = "Microsoft 365 Common and Office Online"
                sourceUri = "https://docs.microsoft.com/en-us/microsoft-365/enterprise/urls-and-ip-address-ranges?view=o365-worldwide"
                mdUri = "https://raw.githubusercontent.com/MicrosoftDocs/microsoft-365-docs/public/microsoft-365/includes/office-365-worldwide-endpoints.md"
                mdOfflinePath = Join-Path -Path $EndPointTablesPath -ChildPath 'office-365-worldwide-endpoints.md'
            }
        }

        'GCC High'
        {
            $M365CommonService = @{
                serviceFilter = "Microsoft 365 Common and Office Online"
                sourceUri = "https://docs.microsoft.com/en-us/microsoft-365/enterprise/microsoft-365-u-s-government-gcc-high-endpoints?view=o365-worldwide"
                mdUri = "https://raw.githubusercontent.com/MicrosoftDocs/microsoft-365-docs/public/microsoft-365/includes/office-365-u.s.-government-gcc-high-endpoints.md"
                mdOfflinePath = Join-Path -Path $EndPointTablesPath -ChildPath 'office-365-u.s.-government-gcc-high-endpoints.md'
            }
        }

        'China'
        {
            $M365CommonService = @{
                serviceFilter = "Microsoft 365 Common and Office Online"
                sourceUri = "https://docs.microsoft.com/en-us/microsoft-365/enterprise/microsoft-365-u-s-government-dod-endpoints?view=o365-worldwide"
                mdUri = "https://raw.githubusercontent.com/MicrosoftDocs/microsoft-365-docs/public/microsoft-365/includes/office-365-u.s.-government-dod-endpoints.md"
                mdOfflinePath = Join-Path -Path $EndPointTablesPath -ChildPath 'office-365-u.s.-government-dod-endpoints.md'
            }
        }

        'Germany'
        {
            $M365CommonService = @{
                serviceFilter = "Microsoft 365 Common and Office Online"
                sourceUri = "https://docs.microsoft.com/en-us/microsoft-365/enterprise/microsoft-365-germany-endpoints?view=o365-worldwide"
                mdUri = "https://raw.githubusercontent.com/MicrosoftDocs/microsoft-365-docs/public/microsoft-365/includes/office-365-germany-endpoints.md"
                mdOfflinePath = Join-Path -Path $EndPointTablesPath -ChildPath 'office-365-germany-endpoints.md'
            }
        }

        default
        {
            $M365CommonService = @{
                serviceFilter = "Microsoft 365 Common and Office Online"
                sourceUri = "https://docs.microsoft.com/en-us/microsoft-365/enterprise/urls-and-ip-address-ranges?view=o365-worldwide"
                mdUri = "https://raw.githubusercontent.com/MicrosoftDocs/microsoft-365-docs/public/microsoft-365/includes/office-365-worldwide-endpoints.md"
                mdOfflinePath = Join-Path -Path $EndPointTablesPath -ChildPath 'office-365-worldwide-endpoints.md'
            }
        }
    }
    return $M365CommonService
}
#endregion

#region FUNCTION: Action for Next & back button to change tab
function Switch-RunspaceTabItem {
    param(
        [Parameter(Mandatory = $true, Position=0)]
        $RunspaceHash,
        [Parameter(Mandatory = $true)]
        $TabControl = 'menuNavigation',
        [Parameter(Mandatory = $true,ParameterSetName="index")]
        [int]$increment,
        [Parameter(Mandatory = $true,ParameterSetName="name")]
        [string]$name
    )

    $RunspaceHash.Window.Dispatcher.invoke([action]{
        If ($PSCmdlet.ParameterSetName -eq "index") {
            #Add index number to current tab
            $newtab = $RunspaceHash.$TabControl.SelectedIndex + $increment
            #ensure number is not greater than tabs
            If ($newtab -ge $RunspaceHash.$TabControl.items.count) {
                $newtab=0
            }
            elseif ($newtab -lt 0) {
                $newtab = $RunspaceHash.$TabControl.SelectedIndex - 1
            }
            #Set new tab index
            $RunspaceHash.$TabControl.SelectedIndex = $newtab
            $message = ("index [{0}]" -f $newtab)
        }
        ElseIf($PSCmdlet.ParameterSetName -eq "name"){
            $newtab = $RunspaceHash.$TabControl.items | Where Header -eq $name
            $newtab.IsSelected = $true
            $message = ("name [{0}]" -f $newtab.Header)
        }
    })
}
#endregion

Function Get-UIFieldElement {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true, Position=0,ParameterSetName="name",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [object[]]$Name
    )
    Begin{
        ## Get the name of this function
        [string]${CmdletName} = $MyInvocation.MyCommand

        $objects = @()
    }
    Process{
        Foreach($item in $Name){
            If($null -ne (Get-UIVariable $item -Wildcard)){
                $FieldObject = (Get-UIVariable $item -Wildcard)
                $Objects += $FieldObject
                If($DebugPreference){Write-LogEntry ("Found field object [{0}]" -f $FieldObject.Name) -Source ${CmdletName} -Severity 5 -Outhost}
            }
            Else{
                If($DebugPreference){Write-LogEntry ("Field object [{0}] does not exist" -f $FieldObject.Name) -Source ${CmdletName} -Severity 5 -Outhost}
            }
        }

    }
    End{
        Return $Objects
    }
}



Function Update-UIProgress{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [String]$Message,
        [Parameter(Mandatory = $False, ParameterSetName="Progress")]
        [int]$Step = '0',
        [Parameter(Mandatory = $False, ParameterSetName="Progress")]
        [int]$MaxStep = '0',
        [Parameter(Mandatory = $false, ParameterSetName="Indeterminate")]
        [switch]$Indeterminate,
        [Parameter(Mandatory=$true)]
        $ProgressBarObject,
        [Parameter(Mandatory=$true)]
        $ProgressTextObject,
        [Parameter(Mandatory = $true, ParameterSetName="Progress")]
        $ProgressNumberObject,
        #[ValidateSet('LightGreen','Yellow','Red')]
        [string]$Color = "LightGreen"
    )
    $Percentage = [math]::Round((($Step / $MaxStep) * 100),0 )

    if($PSBoundParameters['Indeterminate']){
        $ProgressBarObject.IsIndeterminate = $True
        $ProgressBarObject.Foreground=$Color
        If($ProgressTextObject){$ProgressTextObject.Text= $Message}
        If($ProgressNumberObject){$ProgressNumberObject.Text=' '}
    }
    else{
        if(($Percentage -ge 0) -and ($Percentage -le 100)){
            $ProgressBarObject.IsIndeterminate = $False
            $ProgressBarObject.Value = $Percentage
            $ProgressBarObject.Foreground = $Color
            $ProgressTextObject.Text = $Message
            $ProgressNumberObject.Text = ('' + $Percentage +'%')

        }
        else{
            Write-Warning "Out of range"
        }
    }
}

Function Update-RunspaceProgress{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position=0)]
        $RunspaceHash,
        [Parameter(Mandatory = $False, ParameterSetName="Progress")]
        [int]$Step,
        [Parameter(Mandatory = $true, ParameterSetName="Progress")]
        [int]$MaxStep,
        [Parameter(Mandatory = $false, ParameterSetName="Indeterminate")]
        [switch]$Indeterminate,
        [Parameter(Mandatory=$false)]
        $ProgressBar = 'progressBar',
        [Parameter(Mandatory=$false)]
        $ProgressText = 'progressText',
        [Parameter(Mandatory = $false, ParameterSetName="Progress")]
        $ProgressNumber = 'progressNumber',
        [Parameter(Mandatory=$false)]
        [String]$Message,
        #[ValidateSet('LightGreen','Yellow','Red')]
        [string]$Color = "LightGreen"
    )
    $Percentage = [math]::Round((($Step / $MaxStep) * 100),0 )

    if($PSBoundParameters['Indeterminate']){
         $RunspaceHash.$ProgressBar.Dispatcher.Invoke("Normal",[action]{
    			$RunspaceHash.$ProgressBar.IsIndeterminate = $True
    			$RunspaceHash.$ProgressBar.Foreground = $Color
    			$RunspaceHash.$ProgressText.Text = $Message
                $RunspaceHash.$ProgressNumber.Text = ' '
        })
    }
    else{
        if(($Percentage -ge 0) -and ($Percentage -le 100)){
            $RunspaceHash.$ProgressBar.Dispatcher.Invoke("Normal",[action]{
                    $RunspaceHash.$ProgressBar.IsIndeterminate = $False
                    $RunspaceHash.$ProgressBar.Value = $Percentage
                    $RunspaceHash.$ProgressBar.Foreground = $Color
                    $RunspaceHash.$ProgressText.Text = $Message
                    $RunspaceHash.$ProgressNumber.Text = ('' + $Percentage +'%')
            })
        }
        else{
            Write-Warning "Out of range"
        }
    }
}

function Format-Text{
    [CmdletBinding(
        ConfirmImpact='Medium',
        HelpURI='http://vcloud-lab.com'
    )]
    Param (
        [parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$Text,
        [Switch]$Bold, #https://docs.microsoft.com/en-us/uwp/api/windows.ui.text.fontweights
        [Switch]$Italic, #https://docs.microsoft.com/en-us/uwp/api/windows.ui.text.fontstyle
        [String]$TextDecorations, #https://docs.microsoft.com/en-us/uwp/api/windows.ui.text.textdecorations
        [Int]$FontSize,
        [String]$Foreground,
        [String]$Background,
        [Switch]$NewLine
    )
    Begin {
        #https://docs.microsoft.com/en-us/uwp/api/windows.ui.text
        $ObjRun = New-Object System.Windows.Documents.Run
        function TextUIElement {
            Param (
                    [parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
                    [String]$PropertyName
                )
            $Script:PropValue = $PropertyName
            Switch ($PropertyName) {
                'Bold' {'FontWeight'} #Thin, SemiLight, SemiBold, Normal, Medium, Light, ExtraLight, ExtraBold, ExtraBlack, Bold, Black
                'Italic' {'FontStyle'} #Italic, Normal, Oblique
                'TextDecorations' {'TextDecorations'} #None, Strikethrough, Underline
                'FontSize' {'FontSize'}
                'Foreground' {'Foreground'}
                'Background' {'Background'}
                'NewLine' {'NewLine'}
            }
        }
    }
    Process {
        if ($PSBoundParameters.ContainsKey('NewLine')) {
            $ObjRun.Text = "`n$Text "
        }
        else  {
            $ObjRun.Text = $Text
        }
        $AllParameters = $PSBoundParameters.Keys | Where-Object {$_ -ne 'Text'}

        foreach ($SelectedParam in $AllParameters) {
            $Prop = TextUIElement -PropertyName $SelectedParam
            if ($PSBoundParameters[$SelectedParam] -eq [System.Management.Automation.SwitchParameter]::Present) {
                $ObjRun.$Prop = $PropValue
            }
            else {
                $ObjRun.$Prop = $PSBoundParameters[$Prop]
            }
        }
        $ObjRun
    }
}

function Format-RichTextBox {
    #https://msdn.microsoft.com/en-us/library/system.windows.documents.textelement(v=vs.110).aspx#Propertiesshut
    param (
        [parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [System.Windows.Controls.RichTextBox]$RichTextBoxControl,
        [String]$Text,
        [String]$ForeGroundColor = 'Black',
        [String]$BackGroundColor = 'White',
        [String]$FontSize = '12',
        [String]$FontStyle = 'Normal',
        [String]$FontWeight = 'Normal',
        [Switch]$NewLine
    )
    $ParamOptions = $PSBoundParameters
    $RichTextRange = New-Object System.Windows.Documents.TextRange(<#$RichTextBoxControl.Document.ContentStart#>$RichTextBoxControl.Document.ContentEnd, $RichTextBoxControl.Document.ContentEnd)
    if ($ParamOptions.ContainsKey('NewLine')) {
        $RichTextRange.Text = "`n$Text"
    }
    else  {
        $RichTextRange.Text = $Text
    }

    $Defaults = @{ForeGroundColor='Black';BackGroundColor='White';FontSize='12'; FontStyle='Normal'; FontWeight='Normal'}
    foreach ($Key in $Defaults.Keys) {
        if ($ParamOptions.Keys -notcontains $Key) {
            $ParamOptions.Add($Key, $Defaults[$Key])
        }
    }

    $AllParameters = $ParamOptions.Keys | Where-Object {@('RichTextBoxControl','Text','NewLine') -notcontains $_}
    foreach ($SelectedParam in $AllParameters) {
        if ($SelectedParam -eq 'ForeGroundColor') {$TextElement = [System.Windows.Documents.TextElement]::ForegroundProperty}
        elseif ($SelectedParam -eq 'BackGroundColor') {$TextElement = [System.Windows.Documents.TextElement]::BackgroundProperty}
        elseif ($SelectedParam -eq 'FontSize') {$TextElement = [System.Windows.Documents.TextElement]::FontSizeProperty}
        elseif ($SelectedParam -eq 'FontStyle') {$TextElement = [System.Windows.Documents.TextElement]::FontStyleProperty}
        elseif ($SelectedParam -eq 'FontWeight') {$TextElement = [System.Windows.Documents.TextElement]::FontWeightProperty}
        $RichTextRange.ApplyPropertyValue($TextElement, $ParamOptions[$SelectedParam])
    }
}

Function Update-RunspaceLogging{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position=0)]
        $RunspaceHash,

        [Parameter(Mandatory = $false, Position=1)]
        $LoggingBox = 'Logging',

        [Parameter(Position=2,Mandatory=$true)]
        [String]$Message
    )

    $RunspaceHash.Window.Dispatcher.invoke([action]{
        $RunspaceHash.$LoggingBox.AppendText("`n$Message")
        $RunspaceHash.$LoggingBox.ScrollToEnd()
    })
}

Function Update-RunspaceElement{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position=0)]
        $RunspaceHash,

        [Parameter(Mandatory=$true)]
        [String]$ElementName,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Visibility','Text','Content','Foreground','Background','IsReadOnly','IsChecked','IsEnabled','Fill','BorderThickness','BorderBrush')]
        [String]$Property,

        [Parameter(,Mandatory=$true)]
        [String]$Value
    )

    $RunspaceHash.Window.Dispatcher.invoke([action]{
        $RunspaceHash.$ElementName.$Property=$Value
    })
}

Function Update-UIElementProperty{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [String]$ElementName,

        [Parameter(Position=1,Mandatory=$true)]
        [ValidateSet('Visibility','Text','Content','Foreground','Background','IsReadOnly','IsChecked','IsEnabled','Fill','BorderThickness','BorderBrush')]
        [String]$Property,

        [Parameter(Position=3,Mandatory=$true)]
        [String]$Value
    )

    $Global:uiHash.$ElementName.Dispatcher.Invoke("Normal",[action]{
        $Global:uiHash.$ElementName.$Property=$Value
    })
}

function Start-UI
{
    param(
        [Parameter(Mandatory = $true, Position=0)]
        $RunspaceHash
    )
    #launch the modal window with the progressBar
    $Script:Pwshell.Runspace = $Script:uiScriptBlock
    $Script:Handle = $Script:Pwshell.BeginInvoke()

    # we need to wait that all elements are loaded
    While (!($RunspaceHash.Window.IsInitialized)) {
        Start-Sleep -Milliseconds 500
    }
}

function Close-UI
{
    param(
        [Parameter(Mandatory = $true, Position=0)]
        $RunspaceHash
    )
    #Invokes UI to close
    $RunspaceHash.Window.Dispatcher.Invoke("Normal",[action]{$RunspaceHash.Window.close()})
    $Script:Pwshell.EndInvoke($Script:Handle) | Out-Null

    #Closes and Disposes the UI objects/threads
    $Script:Pwshell.Runspace.Close()
	$Script:Pwshell.Dispose()
}

Function Show-UIMenu{
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If($Global:HostOutput){Write-Host ("=============================================================") -ForegroundColor Green}
    #Slower method to present form for non modal (no popups)
    #$UI.ShowDialog() | Out-Null

    #Console control
    # Credits to - http://powershell.cz/2013/04/04/hide-and-show-console-window-from-gui/
    Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'
    # Allow input to window for TextBoxes, etc
    [Void][System.Windows.Forms.Integration.ElementHost]::EnableModelessKeyboardInterop($UI)

    If(!(Test-IsISE)){
        $code = {
            If(Test-KeyPress -Keys F10)
            {
                $CloseTheSplashScreen = $True
                If($UI.Topmost){
                    $UI.Topmost = $false
                    If($CloseTheSplashScreen){Close-UISplashScreen; $CloseTheSplashScreen = $false}
                }
                Else{
                    $UI.Topmost = $True
                }
            }
        }
        $null = $UI.add_KeyDown($code)
    }
    Else{

        #for ISE testing only: Add ESC key as a way to exit UI
        $code = {
            [System.Windows.Input.KeyEventArgs]$esc = $args[1]
            if ($esc.Key -eq 'ESC')
            {
                $UI.Close()
                [System.Windows.Forms.Application]::Exit()
                #this will kill ISE
                [Environment]::Exit($ExitCode);
            }
        }
        $null = $UI.add_KeyUp($code)
    }

    $UI.Add_Closing({
        [System.Windows.Forms.Application]::Exit()
    })

    $async = $UI.Dispatcher.InvokeAsync({
        #make sure this display on top of every window
        $UI.Topmost = $true
        # Running this without $appContext & ::Run would actually cause a really poor response.
        $UI.Show() | Out-Null
        # This makes it pop up
        $UI.Activate() | Out-Null

        #$UI.window.ShowDialog()
    })
    $async.Wait() | Out-Null

    ## Force garbage collection to start form with slightly lower RAM usage.
    [System.GC]::Collect() | Out-Null
    [System.GC]::WaitForPendingFinalizers() | Out-Null

    # Create an application context for it to all run within.
    # This helps with responsiveness, especially when Exiting.
    $appContext = New-Object System.Windows.Forms.ApplicationContext
    [void][System.Windows.Forms.Application]::Run($appContext)

    #[Environment]::Exit($ExitCode);
}
#endregion

Function Update-UIText {
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [String]$Content,
        [switch]$AppendContent,
        [Parameter(Mandatory=$true)]
        $TextObject
    )
    $TextObject.Dispatcher.invoke([action]{
        If ($PSBoundParameters['AppendContent']) {
            $TextObject.AppendText($Content)
        } Else {
            $TextObject.Text = $Content
        }
    },
    "Normal")
}