# Distribution assets

Repository files and finished release ZIPs must contain only original source
and assets with an established redistribution grant. Player ROM imports and
derived caches stay local after installation and are never bundled.

CI checks Git-tracked files and a source ZIP. Release workflows also check
every member of the finished installable ZIP before upload; manual releases
must run the same ZIP check. It rejects ROM/patch/archive files, generated-cache paths, game
screenshots, embedded media URLs, and binary/media files without an exact reviewed hash and licence
in `.github/distribution-assets.json`. Required notices must accompany assets.
A changed or new asset needs source and licence review before updating that ledger.
Text/code contributions also need author permission and preserved notices;
passing a binary check cannot establish the authorship of source code.

Run `python3 .github/scripts/distribution_guard.py` for the repository, or add
`--zip path/to/release.zip` to check a finished distribution. Do not run the
repository check against an installed game folder: local imports are intentional.
