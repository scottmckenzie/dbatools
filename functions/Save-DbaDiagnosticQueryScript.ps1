function Save-DbaDiagnosticQueryScript {
    <#
    .SYNOPSIS
        Save-DbaDiagnosticQueryScript downloads the most recent version of all Glenn Berry DMV scripts

    .DESCRIPTION
        The dbatools module will have the diagnostic queries pre-installed. Use this only to update to a more recent version or specific versions.

        This function is mainly used by Invoke-DbaDiagnosticQuery, but can also be used independently to download the Glenn Berry DMV scripts.

        Use this function to pre-download the scripts from a device with an Internet connection.

        The function Invoke-DbaDiagnosticQuery will try to download these scripts automatically, but it obviously needs an internet connection to do that.

    .PARAMETER Path
        Specifies the path to the output

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Diagnostic, DMV, Troubleshooting
        Author: Andre Kamman (@AndreKamman), http://clouddba.io

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Save-DbaDiagnosticQueryScript -Path c:\temp

        Downloads the most recent version of all Glenn Berry DMV scripts to the specified location.
        If Path is not specified, the "My Documents" location will be used.

#>
    [CmdletBinding()]
    param (
        [System.IO.FileInfo]$Path = [Environment]::GetFolderPath("mydocuments"),
        [Alias('Silent')]
        [switch]$EnableException
    )
    function Get-WebData {
        param ($uri)
        try {
            try {
                $data = (Invoke-TlsWebRequest -uri $uri -ErrorAction Stop)
            } catch {
                (New-Object System.Net.WebClient).Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                $data = (Invoke-TlsWebRequest -uri $uri -ErrorAction Stop)
            }
            return $data
        } catch {
            Stop-Function -Message "Invoke-TlsWebRequest failed: $_" -Target $data -ErrorRecord $_
            return
        }
    }

    if (-not (Test-Path $Path)) {
        Stop-Function -Message "Path does not exist or access denied" -Target $path
        return
    }

    Add-Type -AssemblyName System.Web
    $glenberryrss = "http://www.sqlskills.com/blogs/glenn/feed/"
    $glenberrysql = @()

    Write-Message -Level Output -Message "Downloading RSS Feed"
    $rss = [xml](get-webdata -uri $glenberryrss)
    $Feed = $rss.rss.Channel

    $glenberrysql = @()
    $RssPostFilter = "SQL Server Diagnostic Information Queries for*"
    $DropboxLinkFilter = "*dropbox.com*"
    $LinkTitleFilter = "*Diagnostic*"

    foreach ($post in $Feed.item) {
        if ($post.title -like $RssPostFilter) {
            # We found the first post that matches it, lets go visit and scrape.
            $page = Get-WebData -uri $post.link
            $glenberrysql += ($page.Links | Where-Object { $_.href -like $DropboxLinkFilter -and $_.innerText -like $LinkTitleFilter } | ForEach-Object {
                    [pscustomobject]@{
                        URL        = $_.href
                        SQLVersion = $_.innerText -replace " Diagnostic Information Queries", "" -replace "SQL Server ", "" -replace ' ', ''
                        FileYear   = ($post.title -split " ")[-1]
                        FileMonth  = "{0:00}" -f [int]([CultureInfo]::InvariantCulture.DateTimeFormat.MonthNames.IndexOf(($post.title -split " ")[-2]))
                    }
                })
            break
        }
    }
    Write-Message -Level Output -Message "Found $($glenberrysql.Count) documents to download"
    foreach ($doc in $glenberrysql) {
        try {
            Write-Message -Level Output -Message "Downloading $($doc.URL)"
            $filename = "{0}\SQLServerDiagnosticQueries_{1}_{2}.sql" -f $Path, $doc.SQLVersion, "$($doc.FileYear)$($doc.FileMonth)"
            Invoke-TlsWebRequest -Uri $doc.URL -OutFile $filename -ErrorAction Stop
        } catch {
            Stop-Function -Message "Requesting and writing file failed: $_" -Target $filename -ErrorRecord $_
            return
        }
    }
}

