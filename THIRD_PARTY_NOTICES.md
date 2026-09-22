# THIRD_PARTY_NOTICES.md

> SPDX-License-Identifier: Apache-2.0
>
> Open-source license disclosure per preferences.md §29: this file records the licenses of third-party code and data that ships with, links against, or is embedded in this project.

## Current state

- **This project's code and files:** Apache License 2.0 (see `LICENSE`).
- **Third-party code embedded or vendored:** none yet. The project is in bootstrap; when a dependency or vendored corpus is added, its license text and attribution are recorded in this file as part of that change.

## Anticipated entries

- The W3C SHACL test-suite data vendored under `corpora/` will carry its upstream license terms here at vendoring time (see `corpora/README.md`).

## Runtime dependencies

None yet. The first runtime dependency (the planned RDF syntax layer) is documented in `DESIGN.md` and lands with its license entry in this file in the same change.

## In-app disclosure

Not applicable: shacl_ada is a linkable library with no distributable end-user application surface; downstream applications embed this library and carry their own disclosure.
