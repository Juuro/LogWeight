"""Store locale ids, text-document aliases, device folders and the required screenshot set."""
from __future__ import annotations

STORE_LOCALES = (
    "de-DE", "en-AU", "en-CA", "en-GB", "en-US", "es-ES", "es-MX", "fr-CA", "fr-FR", "it", "ja", "ko",
    "nl-NL", "pt-BR", "pt-PT", "zh-Hans", "zh-Hant",
)
ENGLISH_LOCALES = ("en-AU", "en-CA", "en-GB", "en-US")
# Store locales without their own text section reuse another locale's text (maintainer decision).
TEXT_COPIES = {"es-MX": "es-ES", "fr-CA": "fr-FR", "pt-PT": "pt-BR"}

# Heading in docs/AppStoreMetadata.localized.md -> store locale (identity when absent)
DOC_ALIASES = {"it-IT": "it", "ja-JP": "ja", "ko-KR": "ko"}

# Device folder -> App Store Connect screenshotDisplayType.
# APP_IPHONE_DUO is not in Apple's public spec; verified accepted by the live store (research R5).
DISPLAY_TYPES = {
    "iphone-6.5": "APP_IPHONE_65",
    "ipad-13": "APP_IPAD_PRO_3GEN_129",
    "watch-series-11": "APP_WATCH_SERIES_10",
    "iphone-duo-outer": "APP_IPHONE_DUO",
    "iphone-duo-inner": "APP_IPHONE_DUO",
}
UNVERIFIED_DISPLAY_TYPES: set[str] = set()  # APP_IPHONE_DUO verified accepted on 2026-10-08

_PORTRAIT_THREE = ("01-entry.png", "02-history.png", "03-settings.png")

# Required set per device: ordered file names with exact pixel sizes (spec User Story 7).
REQUIRED_SET: dict[str, dict[str, tuple[int, int]]] = {
    "iphone-6.5": {n: (1284, 2778) for n in _PORTRAIT_THREE},
    "ipad-13": {n: (2064, 2752) for n in _PORTRAIT_THREE},
    "iphone-duo-outer": {n: (1398, 2034) for n in _PORTRAIT_THREE},
    "iphone-duo-inner": {
        **{n: (2007, 2853) for n in _PORTRAIT_THREE},
        "04-entry-landscape.png": (2853, 2007),
        "05-history-landscape.png": (2853, 2007),
    },
    "watch-series-11": {"01-entry.png": (416, 496), "02-history.png": (416, 496)},
}
DEVICE_FOLDERS = tuple(REQUIRED_SET)

# The store keeps one screenshot set per display type (max 10). iPhone Duo has a single type
# for both displays (verified live on de-DE), so outer and inner form ONE merged set: outer
# first, then inner, with unique store file names (prefix + local name).
STORE_SETS: dict[str, list[tuple[str, str]]] = {
    "iphone-6.5": [("iphone-6.5", "")],
    "ipad-13": [("ipad-13", "")],
    "iphone-duo": [("iphone-duo-outer", "1-outer-"), ("iphone-duo-inner", "2-inner-")],
    "watch-series-11": [("watch-series-11", "")],
}
DEVICE_ALIASES = {"iphone-duo-outer": "iphone-duo", "iphone-duo-inner": "iphone-duo"}
MAX_SCREENSHOTS_PER_SET = 10


def doc_locale_to_store(heading: str) -> str:
    return DOC_ALIASES.get(heading, heading)
