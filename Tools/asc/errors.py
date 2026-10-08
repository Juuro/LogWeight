"""Exit-code carrying errors (contracts/cli.md)."""

EXIT_OK = 0
EXIT_USAGE = 1
EXIT_VALIDATION = 2
EXIT_STORE = 3
EXIT_NOT_EDITABLE = 4


class AscError(Exception):
    exit_code = EXIT_STORE


class ConfigError(AscError):
    exit_code = EXIT_USAGE


class ValidationError(AscError):
    exit_code = EXIT_VALIDATION


class StoreError(AscError):
    exit_code = EXIT_STORE


class NotEditableError(AscError):
    exit_code = EXIT_NOT_EDITABLE
