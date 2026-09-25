# Supplemental notices — editor.1

The original euddraft ZIP and all original notices remain intact except the
documented library updater replacement. These additional notices fill gaps in
the original package's notice collection. All notice text is preserved; package
assembly normalizes CRLF to LF for reproducible hashes.

| Notice | Source |
| --- | --- |
| Python-3.13.5.txt | LICENSE.txt from https://www.python.org/ftp/python/3.13.5/python-3.13.5-embed-amd64.zip; SHA-256 7d2650fd9d1b9d002d4a315d5f354247fd6a44f30517c7ef577b08f57a0fb6d9 |
| eudplib-0.80.6.txt | licenses/LICENSE from the official 0.80.6 Windows wheel; SHA-256 9248b4ea16b3a61cc3a559e56e0be90422c1a77c5b14006c41353bf3d684a30e |
| Pygments-2.19.2.txt | https://raw.githubusercontent.com/pygments/pygments/2.19.2/LICENSE |
| OpenSSL-3.0.16.txt | https://raw.githubusercontent.com/openssl/openssl/openssl-3.0.16/LICENSE.txt |
| libffi-3.4.4.txt | https://raw.githubusercontent.com/libffi/libffi/v3.4.4/LICENSE |
| StormLib.txt | src/rust/stormlib-rs/deps/StormLib/LICENSE in eudplib 0.80.6 source distribution |
| Rust-Cargo-notices.txt | All 65 registry crates in src/rust/Cargo.lock of that source distribution, individually verified against its SHA-256 checksums. Includes build/non-Windows dependencies as a conservative superset. |

Official eudplib source distribution metadata: https://pypi.org/pypi/eudplib/0.80.6/json
Source archive SHA-256: 5be90f655d29198ef9ab6b4f59c51b1fad62b504752fcf51c1c05461fab71da2.
Each crate's download URL and checksum appears in Rust-Cargo-notices.txt.
Two crates omit their license files; their .cargo_vcs_info.json identifies the
exact source commits used for those notices:

- https://raw.githubusercontent.com/ogham/rust-number-prefix/eb6ebd215d50df1b199737f0356b988bebaedc84/LICENCE
- https://raw.githubusercontent.com/bytecodealliance/wit-bindgen/f2393e6e98fa5f9236cac580db8a3fc9de6a4b70/LICENSE-MIT

The r-efi notice is in the crate's AUTHORS file; its MIT alternative is selected.
MIT is selected wherever offered as a license alternative. Original additional
license texts are preserved, not removed. This source inventory does not prove
which optional Rust dependencies were linked into the publisher's binary.

VC runtime files retain their upstream Microsoft notices. On 2026-09-25 the ten
root runtime DLLs matched SHA-256 hashes of Visual Studio 2022 Community's
VC/Redist/MSVC/14.44.35112/x64/Microsoft.VC143.CRT files (file version 14.44.35211.0).
The other two root runtime DLLs, vcomp140.dll and vcamp140.dll, match the same
installation's x64/Microsoft.VC143.OpenMP and x64/Microsoft.VC143.CXXAMP files.
Microsoft's redistribution terms remain applicable:
https://learn.microsoft.com/en-us/visualstudio/releases/2022/redistribution
https://learn.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files

freezeMpq is retained from the hash-pinned official euddraft distribution under
its supplied program license; the different binary in the source tag is not
substituted. Reproducible native-source builds and full third-party binary
provenance attestation are not claimed by this package.
