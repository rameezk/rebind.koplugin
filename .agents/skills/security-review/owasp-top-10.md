# OWASP Top 10 (2021) - the security baseline

The fixed baseline the [security review](SKILL.md) matches every diff against. Work through it category by category. Each reads *what it is* then *what to look for*; on each finding, cite the OWASP category **and** the precise **CWE ID**, so the finding names both the class and the concrete weakness.

A category with no concrete, triggerable instance in the diff is not a finding. Skip anything a scanner or linter already enforces in CI - report what judgement adds.

## A01 Broken Access Control

CWE-284 (improper access control), CWE-639 (IDOR), CWE-862 (missing authorization).

Missing or broken authorization checks, privilege escalation, insecure direct object references, path traversal reaching restricted resources, trusting client-supplied identity or roles.

## A02 Cryptographic Failures

CWE-327 (weak algorithm), CWE-798 (hardcoded credentials), CWE-330 (weak randomness).

Broken or weak algorithms (MD5/SHA1 for security, DES), hardcoded keys or IVs, insecure randomness for security-sensitive values, sensitive data or PII sent or stored without encryption, improper TLS or certificate handling.

**Secrets live here.** Hardcoded API keys, tokens, passwords, private keys, or connection strings committed to source, logged, or dropped into config, env files, or fixtures. Report location and type only, and **redact the value** - all but the last few characters.

## A03 Injection

CWE-89 (SQL), CWE-78 (command), CWE-79 (XSS), CWE-943 (NoSQL).

Any untrusted input reaching an interpreter, query, shell, or template unsanitised; unsafe HTML rendering; missing output encoding.

## A04 Insecure Design

CWE-657 (violation of secure design principles), CWE-602 (client-side enforcement of server-side security).

A missing control the design should have had - no rate limiting on a sensitive action, a trust boundary drawn in the wrong place, a security decision made client-side. A flaw in the shape, not the code.

## A05 Security Misconfiguration

CWE-16 (configuration), CWE-611 (XXE).

Insecure defaults, debug or verbose modes left on, permissive CORS, disabled security headers, overly broad permissions or IAM policies, XML parsers with external entities enabled.

## A06 Vulnerable and Outdated Components

CWE-1035, CWE-1104 (use of unmaintained third-party components).

Newly added or upgraded dependencies with known vulnerabilities. Note package and version and whether a known CVE applies; use available tooling (`pip-audit`, `npm audit`, lockfile inspection) in read-only mode only.

## A07 Identification and Authentication Failures

CWE-287 (improper authentication), CWE-384 (session fixation), CWE-521 (weak password requirements).

Missing or broken authentication, weak credential or session handling, missing brute-force protection, predictable or unrotated session tokens.

## A08 Software and Data Integrity Failures

CWE-502 (unsafe deserialization), CWE-829 (inclusion of functionality from an untrusted source).

Unsafe deserialization of untrusted data, unsigned or unverified updates or plugins, CI/CD or dependency sources that could inject code.

## A09 Security Logging and Monitoring Failures

CWE-778 (insufficient logging), CWE-532 (insertion of sensitive information into a log).

Security-relevant events left unlogged, or the opposite - sensitive data or secrets written into logs or error messages.

## A10 Server-Side Request Forgery (SSRF)

CWE-918.

User-controlled URLs fetched server-side without allow-listing; open redirects; requests that can reach internal services or cloud metadata endpoints.
