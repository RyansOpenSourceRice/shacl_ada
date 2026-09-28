# THIRD_PARTY_NOTICES.md

> SPDX-License-Identifier: Apache-2.0
>
> Open-source license disclosure per preferences.md §29: this file records the licenses of third-party code and data that ships with, links against, or is embedded in this project.

## Current state

- **This project's code and files:** Apache License 2.0 (see `LICENSE`).
- **Vendored corpus:** the W3C SHACL test-suite data under `corpora/data-shapes-test-suite/tests/`, from the [w3c/data-shapes](https://github.com/w3c/data-shapes) repository at the commit recorded in `corpora/PIN.md`. All documents in that repository are licensed by contributors under the [W3C Software and Document License](http://www.w3.org/Consortium/Legal/copyright-software). The data is vendored verbatim (integrity manifest: `corpora/SHA256SUMS`); this project's additions around it are Apache-2.0.

## Runtime dependencies

- **flyology_rdf 0.1.0-dev** — RDF syntax layer (Turtle parsing, datasets, terms) from the [flyology-ada/flyology-rdf](https://github.com/flyology-ada/flyology-rdf) project, dual-licensed [MIT OR Apache-2.0](https://github.com/flyology-ada/flyology-rdf/blob/main/LICENSE). Deployed through Alire from the flyology-ada index; consumed only by the `boundary/` adapter, never by the proved core.
- **flyology_iri 0.1.1-dev** — transitive dependency of flyology_rdf (IRI handling) from [flyology-ada/flyology-iri](https://github.com/flyology-ada/flyology-iri), dual-licensed MIT OR Apache-2.0.

## In-app disclosure

Not applicable: shacl_ada is a linkable library with no distributable end-user application surface; downstream applications embed this library and carry their own disclosure.
