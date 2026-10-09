# Contributing to PSCloudPC

Thanks for helping to improve PSCloudPC! This guide explains how to report issues, propose changes and get a pull request merged.

By taking part in this project you agree to follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## Ways to contribute

- **Report a bug**: use the [bug report form](https://github.com/Windows365Management/PSCloudPC/issues/new?template=BUG_REPORT.yml). Include the module version, PowerShell version and the exact command you ran.
- **Request a feature**: use the [feature request form](https://github.com/Windows365Management/PSCloudPC/issues/new?template=FEATURE.yml). A link to the relevant Microsoft Graph API documentation helps a lot.
- **Ask a question or share an idea**: start a thread in [Discussions](https://github.com/Windows365Management/PSCloudPC/discussions).
- **Improve the documentation**: typo fixes and better examples are always welcome.
- **Write code**: fix a bug or add a cmdlet. Issues labelled [`good first issue`](https://github.com/Windows365Management/PSCloudPC/labels/good%20first%20issue) and [`help wanted`](https://github.com/Windows365Management/PSCloudPC/labels/help%20wanted) are good places to start.

If you plan a larger change, open an issue or discussion first so we can agree on the approach before you invest time in it.

## Development setup

### Prerequisites

- PowerShell 7.2 or later
- [Pester](https://pester.dev) 5.x and [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer)
- `Microsoft.Graph.Authentication`
- A Windows 365 test tenant, if you want to try your changes against the real API

```powershell
Install-Module Pester, PSScriptAnalyzer, Microsoft.Graph.Authentication -Scope CurrentUser
```

### Get the code

1. Fork the repository and clone your fork. Keep the folder name `PSCloudPC`, because the tests resolve paths relative to it.
2. Create a branch from `develop`:

   ```powershell
   git switch develop
   git switch -c feature/<short-description>
   ```

   Use the prefix `feature/`, `fix/` or `docs/`.

3. Import your local copy of the module:

   ```powershell
   Import-Module ./PSCloudPc/PSCloudPC.psd1 -Force
   ```

## Repository layout

| Path | Contents |
|---|---|
| `PSCloudPc/Public/` | One file per exported cmdlet, named after the cmdlet |
| `PSCloudPc/Private/` | Internal helpers such as `Get-TokenValidity` and `Invoke-APIRequest` |
| `PSCloudPc/PSCloudPC.psd1` | Module manifest, including `FunctionsToExport` |
| `Pester/` | Module-wide tests: help, naming and manifest checks |
| `Tests/` | Behaviour tests for individual cmdlets |
| `.github/workflows/` | CI tests and the release pipeline |

## Adding or changing a cmdlet

1. **Name it correctly.** Use an [approved PowerShell verb](https://learn.microsoft.com/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands) and the `CPC` noun prefix, for example `Get-CPCSomething`. Use singular nouns.
2. **One cmdlet per file** in `PSCloudPc/Public/`, with the file named after the function.
3. **Write comment-based help** with `.SYNOPSIS`, `.DESCRIPTION`, a `.PARAMETER` entry for every parameter and at least one `.EXAMPLE`. **Every example must start with the cmdlet name**, because CI enforces this. Note the Graph endpoint and required permissions under `.NOTES`.
4. **Follow the existing pattern.** Call `Get-TokenValidity` in the `begin` block and build URLs with `$script:MSGraphVersion`. Use `-Verbose` output for request details.
5. **Export it.** Add the cmdlet to `FunctionsToExport` in `PSCloudPC.psd1`. If it is missing there, users cannot run it after installing the module.
6. **Add tests.** Add a Pester test in `Tests/` that mocks the Graph call and checks that the cmdlet sends the request you expect.
7. **Update the docs.** Add the cmdlet to the cmdlet tables in `README.md`, and add an entry to `CHANGELOG.md`.

Destructive cmdlets (`Remove-*`, reprovision, restore and so on) should support `-WhatIf` and `-Confirm` through `[CmdletBinding(SupportsShouldProcess)]`.

## Running the checks locally

Run these from the repository root. They are the same checks that CI runs on every pull request.

```powershell
# Static analysis
Invoke-ScriptAnalyzer -Path ./PSCloudPc/Public/*.ps1 -Recurse -ExcludeRule PSAvoidTrailingWhitespace

# Help, naming and manifest checks
Import-Module ./PSCloudPc/PSCloudPC.psd1 -Force
Invoke-Pester -Path ./Pester/Functions.tests.ps1 -Output Detailed

# Cmdlet behaviour tests
Invoke-Pester -Path ./Tests -Output Detailed
```

## Submitting a pull request

1. Push your branch and open a pull request against **`develop`**, not `main`.
2. Fill in the pull request template and link the issue it resolves, for example `Closes #123`.
3. Make sure all checks pass. A maintainer will review your change, and might ask for adjustments.
4. Maintainers add a label to every pull request, such as `feature`, `bug`, `breaking` or `documentation`. The labels are used to generate the release notes.

Keep pull requests focused: one feature or fix per pull request is much easier to review.

## Release process

Releases are handled by the maintainers:

1. `ModuleVersion` in `PSCloudPC.psd1` and `CHANGELOG.md` are updated for the new version on `develop`.
2. `develop` is merged into `main` through a pull request.
3. A `vX.Y.Z` tag is pushed on `main`. The release workflow checks that the tag matches `ModuleVersion`, creates the GitHub release with generated notes and publishes the module to the PowerShell Gallery.

## Questions?

If something in this guide is unclear, ask in [Discussions](https://github.com/Windows365Management/PSCloudPC/discussions). Improvements to this guide are contributions too.
