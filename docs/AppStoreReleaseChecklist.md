# App Store Release Checklist

This checklist answers two release questions directly:

1. **What is still missing before the first App Store submission?**
2. **What increases the chance of passing App Review on the first try?**

## What is still missing

- [x] **Pick the exact submission scope.** The current XcodeGen project (`project.yml`) ships:
  - iPhone + iPad app (`LogWeight`)
  - Apple Watch companion app (`LogWeightWatchApp`)
  - iOS/iPadOS Home Screen widget (`LogWeightWidget`)
  - watchOS widget/complication (`LogWeightWatchWidget`)

  Do **not** claim macOS support in App Store Connect metadata, screenshots, or review notes unless a real macOS target is added back to `project.yml`.

- [ ] **Host a public privacy policy URL.** App Store Connect needs a public HTTPS page. Publish the policy from [`docs/Privacy.md`](./Privacy.md) verbatim or near-verbatim.

- [ ] **Verify the public support URL is submission-ready.** The support page can stay simple, but confirm the hosted page resolves over HTTPS before submission and still includes:
  - contact email or contact form
  - short explanation that data lives in Apple Health
  - links to the privacy policy and support instructions

- [ ] **Generate final App Store screenshots.** Use [`docs/AIScreenshotWorkflow.md`](./AIScreenshotWorkflow.md) for per-scene capture (`Tools/CaptureScene.sh`) and `bash Tools/CaptureStoreScreenshots.sh` for the store batch, then manually confirm the screenshots match the shipped platforms and current UI.

- [ ] **Run the release validation pass on macOS/Xcode.**
  - `xcodegen generate`
  - `xcodebuild test -scheme LogWeight -destination 'platform=iOS Simulator,name=iPhone 15'`
  - `xcodebuild build -scheme LogWeightWatch -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO`

- [ ] **Smoke-test HealthKit on physical devices or TestFlight.** Confirm:
  - HealthKit authorization copy is clear
  - first save succeeds on iPhone and Apple Watch
  - history reads real Apple Health samples
  - widgets and complications refresh after saves

- [ ] **Fill App Store Connect metadata from the checked-in drafts.**
  - base listing: [`docs/AppStoreMetadata.md`](./AppStoreMetadata.md)
  - localized variants: [`docs/AppStoreMetadata.localized.md`](./AppStoreMetadata.localized.md)

## What improves first-pass approval chances

- **Keep the submission scope narrow and accurate.** Only claim platforms and features that are present in the shipping build.
- **Explain HealthKit usage clearly in Review Notes.** State that LogWeight requests read/write access only for Body Mass and keeps data on-device.
- **Keep privacy answers consistent everywhere.** Privacy manifests, App Privacy answers, the privacy policy URL, and in-app behavior should all say the same thing: no account, no analytics, no third-party SDKs, no off-device syncing by the app.
- **Avoid broken links.** Apple reviewers often check the support URL and privacy policy URL.
- **Verify accessibility before submit.** Use [`docs/AccessibilityAudit.md`](./AccessibilityAudit.md) as the final manual checklist.
- **Review screenshots for policy risk.** Avoid placeholder text, debug UI, clipped layouts, and claims about platforms or features not in the build.

## Suggested submission flow

1. Finish the final validation run.
2. Publish the support URL and privacy policy URL.
3. Generate final screenshots for iPhone, iPad, and Apple Watch.
4. Copy the metadata drafts into App Store Connect.
5. Paste concise HealthKit review notes.
6. Upload the archive to TestFlight/App Store Connect.
7. Do one final TestFlight pass on physical devices before pressing Submit for Review.
