# Security Policy

## Supported versions

Security fixes are released for the latest version of PSCloudPC on the [PowerShell Gallery](https://www.powershellgallery.com/packages/PSCloudPC). Please update before reporting an issue:

```powershell
Update-Module -Name PSCloudPC
```

## Reporting a vulnerability

**Please do not report security vulnerabilities through public GitHub issues, discussions or pull requests.**

Email your report to **mail@stefandingemanse.com** and include:

- A description of the issue and its potential impact
- Steps to reproduce it, or a proof of concept
- The affected PSCloudPC version, PowerShell version and operating system

You can expect an acknowledgement within five working days. We will keep you informed while we investigate and work on a fix, and we will credit you in the release notes unless you prefer to stay anonymous.

## Scope

In scope:

- The PSCloudPC module code in this repository, for example how it handles access tokens, client secrets and certificates

Out of scope:

- Vulnerabilities in Microsoft Graph, Windows 365 or other Microsoft services. Report these to the [Microsoft Security Response Center](https://msrc.microsoft.com/report).
- Vulnerabilities in third-party dependencies such as `Microsoft.Graph.Authentication`. Report these to their maintainers.

## Handling credentials safely

When you use PSCloudPC, especially in automation:

- Prefer certificate authentication over client secrets.
- Run `Disconnect-Windows365` when you are done, so the session and token cache are cleared.
- Keep secrets in a secure store such as Azure Key Vault or `Microsoft.PowerShell.SecretManagement`, never in scripts.
- Grant the app registration only the [permissions](README.md#permissions) your scripts actually need.
