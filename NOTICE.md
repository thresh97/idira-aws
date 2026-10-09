# Notice

## Third-party software

This repository redistributes `aws-cli-utilities-master.zip`, CyberArk's `aws-cli-utilities`
(the "AWS CLI - Idaptive V1" Python tool and an unused PowerShell variant).

- Copyright 2019 CyberArk, LLC.
- Licensed under the Apache License, Version 2.0: http://www.apache.org/licenses/LICENSE-2.0
- The license text and copyright notices are retained unmodified inside the zip (`LICENSE.md` in each tool folder and the
  headers of each source file). One source file also carries a "Copyright 2018 core Corporation" header under the same license.
- The zip is the unmodified upstream archive.

## Modifications

The patches in `patches/` modify these upstream files: `AWSCLI.py`, `core/auth.py`, `core/authresponse.py`,
`core/restclient.py`, `core/samlapp.py` and `core/uprest.py`. The changes make the tool work with current CyberArk
Identity responses (MFA menu robustness, printing the Mobile Authenticator number-match value), make MFA polling
robust (pacing, retries, timeout), handle apps without IAM roles, tighten input checks, and reduce what is written to the log. `patches/change-notices.patch` adds a notice
to each modified file stating this, as Apache-2.0 section 4(b) requires. `install.sh` applies the patches at install
time; the modified files are not stored in this repository.

## Trademarks and affiliation

CyberArk, Idaptive and Idira are trademarks of their respective owners. This project is not affiliated with,
endorsed by, or supported by CyberArk, Amazon Web Services, or any employer of its contributors. The names are used
only to describe compatibility.

## Support status

Unsupported community example. No warranty, SLA, or support of any kind is offered by the authors or by any
company they are associated with. Nothing here is an official product, tool, or reference architecture.

## Original work

All other files are licensed under the MIT License; see `LICENSE`.
