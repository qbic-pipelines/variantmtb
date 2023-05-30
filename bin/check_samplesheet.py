#!/usr/bin/env python


"""Provide a command line tool to validate and transform tabular samplesheets."""


import argparse
import csv
import logging
import sys
from collections import Counter
from pathlib import Path


logger = logging.getLogger()


class RowChecker:
    """
    Define a service that can validate and transform each given row.

    Attributes:
        modified (list): A list of dicts, where each dict corresponds to a previously
            validated and transformed row. The order of rows is maintained.

    """

    VALID_FORMATS = (
        ".vcf",
        ".vcf.gz",
        ".tsv",
        ".ext"
    )

    VALID_GENOMES = (
        "hg19",
        "GRCh37",
        "hg38",
        "GRCh38"
    )

    VALID_FILETYPES = (
        "mutations",
        "cnas",
        "translocations"
    )

    def __init__(
        self,
        sample_col="sample",
        filename_col="filename",
        genome_col="genome",
        filetype_col="filetype",

        **kwargs,
    ):
        """
        Initialize the row checker with the expected column names.

        Args:
            sample_col (str): The name of the column that contains the sample name
                (default "sample").
            filename_col (str): The name of the column that contains the input file path.
            genome_col (str): The name of the column that contains the reference genome.
                (default "GRCh37")
            filetype_col (str): The name of the column that contains the type of the input file
                (default "mutations")
            
            

        """
        super().__init__(**kwargs)
        self._sample_col = sample_col
        self._filename_col = filename_col
        self._genome_col = genome_col
        self._filetype_col = filetype_col
        self._seen = set()
        self.modified = []

    def validate_and_transform(self, row):
        """
        Perform all validations on the given row and insert the read pairing status.

        Args:
            row (dict): A mapping from column headers (keys) to elements of that row
                (values).

        """
        self._validate_sample(row)
        self._validate_entries(row)
        self._seen.add((row[self._sample_col], row[self._filename_col]))
        self.modified.append(row)

    def _validate_sample(self, row):
        """Assert that the sample name exists and convert spaces to underscores."""
        assert len(row[self._sample_col]) > 0, "Sample input is required."
        # Sanitize samples slightly.
        row[self._sample_col] = row[self._sample_col].replace(" ", "_")

    def _validate_entries(self, row):
        """
        Assert that the first VCF entry is non-empty and has the right format.
        Assert that supported reference genome is given
        Assert that supported filetype is provided
        """
        assert len(row[self._filename_col]) > 0, "At least the first VCF file is required."
        self._validate_file_format(row[self._filename_col])
        self._validate_genome(row[self._genome_col])
        self._validate_filetype(row[self._filetype_col])

    def _validate_file_format(self, filename):
        """Assert that a given filename has one of the expected VCF extensions."""
        assert any(filename.endswith(extension) for extension in self.VALID_FORMATS), (
            f"The VCF file has an unrecognized extension: {filename}\n"
            f"It should be one of: {', '.join(self.VALID_FORMATS)}"
        )

    def _validate_genome(self, genome_name):
        """Assert that the given reference genome is compatible with the pipeline."""
        assert any(genome_name == genome for genome in self.VALID_GENOMES), (
            f"The provided reference genome is not supported: {genome_name}\n"
            f"It should be one of: {', '.join(self.VALID_GENOMES)}"
        )

    def _validate_filetype(self, file_type):
        """Assert that the given reference genome is compatible with the pipeline."""
        assert any(file_type == f_t for f_t in self.VALID_FILETYPES), (
            f"The provided filetype is not supported: {file_type}\n"
            f"It should be one of: {', '.join(self.VALID_FILETYPES)}"
        )

    def validate_unique_samples(self):
        """
        Assert that the combination of sample name and VCF filename is unique.

        In addition to the validation, also rename the sample if more than one sample,
        VCF file combination exists.

        """
        assert len(self._seen) == len(self.modified), "The pair of sample name and VCF must be unique."
        if len({pair[0] for pair in self._seen}) < len(self._seen):
            counts = Counter(pair[0] for pair in self._seen)
            seen = Counter()
            for row in self.modified:
                sample = row[self._sample_col]
                seen[sample] += 1
                if counts[sample] > 1:
                    row[self._sample_col] = f"{sample}_T{seen[sample]}"


def read_head(handle, num_lines=10):
    """Read the specified number of lines from the current position in the file."""
    lines = []
    for idx, line in enumerate(handle):
        if idx == num_lines:
            break
        lines.append(line)
    return "".join(lines)


def sniff_format(handle):
    """
    Detect the tabular format.

    Args:
        handle (text file): A handle to a `text file`_ object. The read position is
        expected to be at the beginning (index 0).

    Returns:
        csv.Dialect: The detected tabular format.

    .. _text file:
        https://docs.python.org/3/glossary.html#term-text-file

    """
    peek = read_head(handle)
    handle.seek(0)
    sniffer = csv.Sniffer()
    if not sniffer.has_header(peek):
        logger.critical(f"The given sample sheet does not appear to contain a header.")
        sys.exit(1)
    dialect = sniffer.sniff(peek)
    return dialect


def check_samplesheet(file_in, file_out):
    """
    Check that the tabular samplesheet has the structure expected by nf-core pipelines.

    Validate the general shape of the table, expected columns, and each row. Also add
    an additional column which records whether one or two VCF reads were found.

    Args:
        file_in (pathlib.Path): The given tabular samplesheet. The format can be either
            CSV, TSV, or any other format automatically recognized by ``csv.Sniffer``.
        file_out (pathlib.Path): Where the validated and transformed samplesheet should
            be created; always in CSV format.

    Example:
        This function checks that the samplesheet follows the following structure,
        see also the `viral recon samplesheet`_::

            sample,filename,genome,filetype
            SAMPLE1,SAMPLE1.vcf.gz,hg19,mutations
            SAMPLE2,SAMPLE2.tsv,GRCh37,translocations
            SAMPLE3,SAMPLE3.vcf,hg19,mutations

    .. _viral recon samplesheet:
        https://raw.githubusercontent.com/nf-core/test-datasets/viralrecon/samplesheet/samplesheet_test_illumina_amplicon.csv

    """
    required_columns = {"sample", "filename", "genome", "filetype"}
    # See https://docs.python.org/3.9/library/csv.html#id3 to read up on `newline=""`.
    with file_in.open(newline="") as in_handle:
        reader = csv.DictReader(in_handle, dialect=sniff_format(in_handle))
        # Validate the existence of the expected header columns.
        if not required_columns.issubset(reader.fieldnames):
            logger.critical(f"The sample sheet **must** contain the column headers: {', '.join(required_columns)}.")
            sys.exit(1)
        # Validate each row.
        checker = RowChecker()
        for i, row in enumerate(reader):
            try:
                checker.validate_and_transform(row)
            except AssertionError as error:
                logger.critical(f"{str(error)} On line {i + 2}.")
                sys.exit(1)
        checker.validate_unique_samples()
    header = list(reader.fieldnames)
    # See https://docs.python.org/3.9/library/csv.html#id3 to read up on `newline=""`.
    with file_out.open(mode="w", newline="") as out_handle:
        writer = csv.DictWriter(out_handle, header, delimiter=",")
        writer.writeheader()
        for row in checker.modified:
            writer.writerow(row)


def parse_args(argv=None):
    """Define and immediately parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Validate and transform a tabular samplesheet.",
        epilog="Example: python check_samplesheet.py samplesheet.csv samplesheet.valid.csv",
    )
    parser.add_argument(
        "file_in",
        metavar="FILE_IN",
        type=Path,
        help="Tabular input samplesheet in CSV or TSV format.",
    )
    parser.add_argument(
        "file_out",
        metavar="FILE_OUT",
        type=Path,
        help="Transformed output samplesheet in CSV format.",
    )
    parser.add_argument(
        "-l",
        "--log-level",
        help="The desired log level (default WARNING).",
        choices=("CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG"),
        default="WARNING",
    )
    return parser.parse_args(argv)


def main(argv=None):
    """Coordinate argument parsing and program execution."""
    args = parse_args(argv)
    logging.basicConfig(level=args.log_level, format="[%(levelname)s] %(message)s")
    if not args.file_in.is_file():
        logger.error(f"The given input file {args.file_in} was not found!")
        sys.exit(2)
    args.file_out.parent.mkdir(parents=True, exist_ok=True)
    check_samplesheet(args.file_in, args.file_out)


if __name__ == "__main__":
    sys.exit(main())
