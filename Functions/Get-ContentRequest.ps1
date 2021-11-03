Function Get-ContentRequest {
    Param($url)
    $result = @()
    & {
        $myHttpWebRequest = [System.Net.WebRequest]::Create($url)
        $myHttpWebResponse = $myHttpWebRequest.GetResponse()
        $receiveStream = $myHttpWebResponse.GetResponseStream()
        $encode = [System.Text.Encoding]::GetEncoding("utf-8")
        $readStream = [System.IO.StreamReader]::new($receiveStream, $encode)
        while (-not $readStream.EndOfStream) {
            $readStream.ReadLine()
        }
        $myHttpWebResponse.Close()
        $readStream.Close()
    } | foreach {
        $result += $_
    }
    return $result
}

Function Merge-Hashtables([ScriptBlock]$Operator) {
    $Output = @{}
    ForEach ($Hashtable in $Input) {
        If ($Hashtable -is [Hashtable]) {
            ForEach ($Key in $Hashtable.Keys) {$Output.$Key = If ($Output.ContainsKey($Key)) {@($Output.$Key) + $Hashtable.$Key} Else  {$Hashtable.$Key}}
        }
    }
    If ($Operator) {ForEach ($Key in @($Output.Keys)) {$_ = @($Output.$Key); $Output.$Key = Invoke-Command $Operator}}
    $Output
}
#$InvokeService, $AddedService | Merge-Hashtables {$_ | Sort-Object}

function ConvertFrom-hashtable
{
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true, Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [hashtable]$hashtable
    )
    Begin{
        $object = New-Object PSObject
    }
    Process{
        ## Enumerate the hashtable keys
        $hashtable.GetEnumerator() | 
            ForEach-Object { Add-Member -inputObject $object -memberType NoteProperty -name $_.Name -value $_.Value }
    }
    End{
        return $object
    }
}