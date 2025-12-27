# Security Policy

This repository provides a Docker-based **build environment** for producing Signal Desktop Linux artifacts (AppImage/DEB/RPM) in a clean container, exporting only the resulting build outputs to the host (typically `./out`).

It does **not** maintain Signal Desktop itself. Security issues in Signal Desktop (the upstream application) should be reported upstream to Signal.

## Supported Versions

Only the **latest commit on the default branch** is considered supported for security-related fixes in this repository.
Older commits/tags/forks are not maintained.

## Reporting a Vulnerability

### Do not disclose sensitive details publicly

If your report involves any of the following, treat it as sensitive:

- credentials or tokens (e.g., `GH_TOKEN`)
- supply-chain concerns (dependency/download tampering)
- container escape / privilege escalation or host impact
- arbitrary file write outside the intended output directory (path traversal)
- anything that could realistically be weaponized

### Preferred: GitHub private vulnerability reporting

Use GitHub’s private vulnerability reporting if available:

1. Repository → **Security** → **Advisories**
2. **Report a vulnerability**

If you cannot use private reporting, open a public issue with **minimal** information (no PoC, no secrets) and state you can provide full details privately.

### What to include

- Affected file(s) and a concise description
- Steps to reproduce (as safely as possible)
- Expected vs. actual behavior
- Impact (what an attacker could do)
- Any mitigations or fixes you tested

## Scope

### In scope

- Dockerfile(s) used for the build container
- Helper/wrapper scripts (e.g., `build_signal-desktop.sh`)
- Logic that fetches sources/releases (e.g., “latest release” detection via GitHub API)
- Artifact export logic (permissions/ownership via `ARTIFACT_UID` / `ARTIFACT_GID`, path handling, cleanup)
- Documentation that recommends runtime flags or environment variables

### Out of scope

- Vulnerabilities in Signal Desktop itself or its upstream dependencies (report upstream as well)
- Misconfiguration or insecure deployment choices by downstream users
- Issues that require intentionally unsafe Docker settings (e.g., `--privileged`) unless the repo recommends them

## Handling and Disclosure

- Best effort will be made to acknowledge reports, but **no response time or fix timeline is guaranteed**.
- Fixes are typically delivered via commits to the default branch.
- If coordinated disclosure is needed, propose a date in your report.

## Operational Security Notes (for users)

- Treat `GH_TOKEN` as a secret. Do not commit it and do not paste it into logs/issues.
- Prefer building from pinned refs (`SIGNAL_REF`) when reproducibility matters (avoid “latest” if you need deterministic outputs).
- Review build container network access if used in high-assurance environments (the build pulls dependencies from the internet).
- Scan produced artifacts before redistribution if you integrate this into automated pipelines.
