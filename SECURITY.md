# Security policy

## Supported versions

The latest published 0.1.x version receives security fixes. Older prerelease or local HAR builds are not supported.

## Reporting a vulnerability

Do not open a public issue for vulnerabilities, credentials or private business data. Use GitHub's **Security → Report a vulnerability** flow for this repository and include:

- affected `@hmkit/form` and `@hmkit/validator` versions;
- HarmonyOS API level and device/emulator environment;
- a minimal reproduction without real user data;
- impact, attack prerequisites and any known workaround.

You should receive an acknowledgement within seven days. A confirmed issue will be handled with a compatible patch when possible; affected versions and migration steps will be documented before or with the fix.

`@hmkit/form` is a client-side UI/state library. Applications remain responsible for server-side authorization, input validation, secure storage and redacting sensitive values from logs.
