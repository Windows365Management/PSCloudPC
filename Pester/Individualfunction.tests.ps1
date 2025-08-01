
$individualfunctionslocation = Join-Path -Path (Join-Path ".././" -ChildPath "PSCloudPC") -ChildPath "Source/tests"

foreach ($file in Get-ChildItem $individualfunctionslocation) {

    Invoke-Pester -Path $file.FullName -Output Detailed
}