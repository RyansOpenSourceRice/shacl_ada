# THIRD_PARTY_NOTICES.md

> SPDX-License-Identifier: Apache-2.0
>
> Open-source license disclosure per preferences.md §29: this file records the licenses of third-party code and data that ships with, links against, or is embedded in this project.

## Current state

- **This project's code and files:** Apache License 2.0 (see `LICENSE`).
- **Vendored corpus:** the W3C SHACL test-suite data under `corpora/data-shapes-test-suite/tests/`, from the [w3c/data-shapes](https://github.com/w3c/data-shapes) repository at the commit recorded in `corpora/PIN.md`. All documents in that repository are licensed by contributors under the [W3C Software and Document License](http://www.w3.org/Consortium/Legal/copyright-software). The data is vendored verbatim (integrity manifest: `corpora/SHA256SUMS`); this project's additions around it are Apache-2.0.

## Runtime dependencies

None yet. The first runtime dependency (the planned RDF syntax layer) is documented in `DESIGN.md` and lands with its license entry in this file in the same change.

## In-app disclosure

Not applicable: shacl_ada is a linkable library with no distributable end-user application surface; downstream applications embed this library and carry their own disclosure.
