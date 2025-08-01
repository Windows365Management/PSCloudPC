
$individualfunctionslocation = Join-Path -Path (Join-Path ".././" -ChildPath "PSCloudPC") -ChildPath "source/tests"

foreach ($file in Get-ChildItem $individualfunctionslocation) {

    Invoke-Pester -Path $file.FullName -Output Detailed
}