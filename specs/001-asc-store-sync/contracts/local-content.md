# Contract: local content layout

## Screenshots
```text
docs/store-screenshots/<store-locale>/<device-folder>/NN-<name>.png
```
- `<store-locale>`: `de-DE en-AU en-CA en-GB en-US es-ES es-MX fr-CA fr-FR it ja ko nl-NL pt-BR pt-PT zh-Hans zh-Hant` (17). `en-AU`, `es-MX`, `fr-CA`, `pt-PT` are copies of `en-GB`, `es-ES`, `fr-FR`, `pt-BR`.
- `NN`: two digits, unique within the folder, defines order. Required set (spec User Story 7): iphone-6.5, ipad-13, iphone-duo-outer: `01-entry`, `02-history`, `03-settings`. iphone-duo-inner: those three plus `04-entry-landscape`, `05-history-landscape`. watch-series-11: `01-entry`, `02-history`. Any other file or a missing one fails validation (exit 2).
- Allowed content: PNG, RGB, no alpha, exact pixel size for the display type.

| Folder | Display type | Pixels |
|---|---|---|
| `iphone-6.5` | `APP_IPHONE_65` | 1284×2778 |
| `ipad-13` | `APP_IPAD_PRO_3GEN_129` | 2064×2752 |
| `watch-series-11` | `APP_WATCH_SERIES_10` | 416×496 |
| `iphone-duo-outer` | `APP_IPHONE_DUO` (one set shared with inner, see research R5) | 1398×2034 (portrait only) |
| `iphone-duo-inner` | `APP_IPHONE_DUO` | 2007×2853 (01-03), 2853×2007 (04-05) |

## Texts
- `docs/AppStoreMetadata.md`: English base. Sections `## Subtitle`, `## Promotional text`, `## Description`, `## Keywords`, text in backticks or the description block as today.
- `docs/AppStoreMetadata.localized.md`: one `## <locale>` section per locale with bullets `**Subtitle:**`, `**Promotional text:**`, `**Description:**`, `**Keywords:**` (current format). Heading aliases: `it-IT` to `it`, `es-ES`, `fr-FR`, `de-DE`, `nl-NL`, `ja-JP` to `ja`, `ko-KR` to `ko`.
- `docs/AppStoreWhatsNew.md`: `**Version:** x.y.z` line plus one `## <locale>` section per language (`en` covers en-AU/CA/GB/US). Rewritten every release; a version mismatch with the target fails validation (exit 2). `whatsNew` is written to the version localization.
- A text field missing for a locale is a validation error (exit 2), not an empty write.
