# Changelog

## [1.0.8]

- Address Dependabot security advisories in transitive dependencies by updating `Gemfile.lock`:
  - `rack` 3.1.16 → 3.1.22 (GHSA-6xw4-3v39-52mm, GHSA-r657-rxjc-j557, GHSA-wpv5-97wm-hp9c, GHSA-w9pc-fmgc-vxvw, GHSA-p543-xpfm-54cp, GHSA-mxw3-3hh2-x2mh, GHSA-whrj-4476-wvmp, GHSA-g2pf-xv49-m2h5, GHSA-q2ww-5357-x388, GHSA-qv7j-4883-hwh7, GHSA-8vqr-qjwx-82mw, GHSA-7mqq-6cf9-v2qp, GHSA-v569-hp3g-36wr, GHSA-qfgr-crr9-7r49, GHSA-vgpv-f759-9wx3, GHSA-v6x5-cg8r-vv6x, GHSA-x8cg-fq8g-mxfx, GHSA-q4qf-9j86-f5mh, GHSA-h2jq-g4cq-5ppq)
  - `faraday` 2.13.1 → 2.14.4 (GHSA-98m9-hrrm-r99r, GHSA-5rv5-xj5j-3484, GHSA-33mh-2634-fwr2)
  - `jwt` 2.10.1 → 2.10.3 (GHSA-c32j-vqhx-rx3x)
  - `json` 2.12.2 → 2.21.2 (GHSA-x2f5-4prf-w687)
  - `uri` 1.0.3 → 1.1.1 (GHSA-j4pr-3wm6-xx2r)

## [1.0.7]

- Fix the `tag-and-release` workflow to create the release tag with the `rewind-community-tagger` GitHub App token (`TAGGER_APP_ID`/`TAGGER_PRIVATE_KEY`) instead of the default `GITHUB_TOKEN`

## [1.0.6]

- Resolve CVE-2026-54603 by updating oauth2 to 2.0.25

## [1.0.5]

- Update Ruby version to 3.4.5 to address security vulnerabilities

## [1.0.4]

- Resolve CVE-2025-49007
- Update dependencies

## [1.0.3]

- Resolve CVE-2025-27111
- Update dependencies

## [1.0.2]

- Update Gem Metadata

## [1.0.1]

- Rename the entry point file

## [1.0.0]

- Initial Release
