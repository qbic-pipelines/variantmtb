# nf-core/variantmtb: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0](https://github.com/qbic-pipelines/variantmtb/releases/tag/1.0.0) - Piz Bernina

### Added

- filter civic evidences according to patient cancer type

### Fixed

- [#10](https://github.com/qbic-pipelines/variantmtb/issues/10) CGI used to fail when querying files in parallel. Disabled parallelization for CGI.
- important querynator fixes, see [querynator:0.5.5 release notes](https://github.com/qbic-pipelines/querynator/releases/tag/0.5.5)

### Dependencies

- updated querynator to 0.5.5

### Deprecated

### Removed

- `--cgi_cancer_type` is no longer supported. specify cancer type in sample sheet instead using fields `cgi_cancer` and `civic_cancer`

## [0.2.0](https://github.com/qbic-pipelines/variantmtb/releases/tag/0.2.0) - Wendelstein

### Added

- nextflow secrets for CGI credentials.

### Fixed

### Dependencies

- bcftools version 1.18.

### Deprecated

## [0.1.0](https://github.com/qbic-pipelines/variantmtb/releases/tag/0.1.0) - Paris-Roubaix

### Added

- [#1](https://github.com/qbic-pipelines/variantmtb/pull/1) - Query to CGI & CIViC. Creation of a comprehensive HTML report.

### Fixed

### Dependencies

### Deprecated

## v1.0dev - [date]

Initial release of nf-core/variantmtb, created with the [nf-core](https://nf-co.re/) template.

### Added

### Fixed

### Dependencies

### Deprecated
