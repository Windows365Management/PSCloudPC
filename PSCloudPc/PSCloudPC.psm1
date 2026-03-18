#Get public and private function definition files.
$Public = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )


#Dot source the files in the Public and Private folders.
foreach ($Import in @($Public + $Private)) {
    Try {
        . $Import.Fullname
        Write-Verbose -Message "Import function $($Import.Fullname): $_"
    }
    Catch {
        Write-Error -Message "Failed to import function $($Import.Fullname): $_"
    }
}

## Export all of the public functions making them available to the user
foreach ($file in $Public) {
    Export-ModuleMember -Function $file.BaseName
    Write-Verbose -Message "Export function $($file.BaseName): $_"
}