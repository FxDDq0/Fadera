# Security policy

## Supported versions

Only the latest release receives fixes.

## Reporting a vulnerability

Please **do not** open a public issue for security problems. Use GitHub's private vulnerability reporting (*Security → Report a vulnerability* on this repository).

Include the Fadera version, the steps to reproduce and the possible impact. You will receive an answer as soon as possible; please allow time for a fix before any public disclosure.

## Scope and design notes

* Fadera communicates only on the local network, with UDP port 10023 of the mixer. It does not contact any Internet service, collect telemetry or check for updates.
* The OSC protocol of these mixers has no authentication or encryption: anyone on the same network can control the mixer. Keep the mixer on a trusted network.
* The built-in simulator listens only on 127.0.0.1.
* Preferences and logs are stored in `%APPDATA%\Fadera` and stay on the PC. Diagnostics files are created only when you export them.
