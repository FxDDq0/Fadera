# Code signing and Windows SmartScreen

## Current status

Fadera's installer and executable are **not digitally signed**. No certificate is used, and none is simulated.

On first run Windows Defender SmartScreen may show **"Windows protected your PC"**. This does not mean the file is harmful; it means the file is not signed and has no download reputation yet.

To check that the file is the one published by the project:

```powershell
Get-FileHash .\Fadera-<version>-setup.exe -Algorithm SHA256
```

Compare the result with the `.sha256` file attached to the GitHub release. If they match, choose *More info → Run anyway*.

## Options for the future

| Option | Notes |
|---|---|
| Azure Trusted Signing (Microsoft) | Low monthly cost; requires identity validation of an individual or organisation; integrates with GitHub Actions. |
| OV code-signing certificate from a certificate authority | Yearly cost; the private key must be on a hardware token or cloud HSM, which makes CI signing more complex. |
| EV code-signing certificate | Highest cost; historically gave immediate SmartScreen reputation. |
| SignPath Foundation (for open-source projects) | Free signing for qualifying open-source projects; requires an OSI-approved license and an application. |

If a certificate is obtained, the workflow can sign `Fadera.exe` and the installer with `signtool` using secrets stored in GitHub (never in the repository).
