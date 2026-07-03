import XCTest
@testable import AppleConnectApp

final class MetadataValidatorTests: XCTestCase {
    func testValidatesAppStoreFieldLimits() {
        let document = MetadataDocument(
            localizations: [
                LocaleMetadata(
                    locale: "en-US",
                    appInfo: AppInfoMetadata(
                        name: "A",
                        subtitle: String(repeating: "x", count: 31),
                        privacyPolicyURL: "example.com",
                        privacyChoicesURL: "",
                        privacyPolicyText: ""
                    ),
                    version: VersionMetadata(
                        description: String(repeating: "x", count: 4_001),
                        keywords: String(repeating: "k", count: 101),
                        marketingURL: "",
                        promotionalText: String(repeating: "x", count: 171),
                        supportURL: "example.com",
                        whatsNew: ""
                    )
                )
            ],
            pulledAt: .now
        )

        let issues = MetadataValidator.validate(document: document)
        XCTAssertEqual(issues.filter { $0.severity == .error }.count, 7)
    }

    func testKeywordNormalizerTrimsSeparatorsAndDeduplicates() {
        let normalized = MetadataKeywordNormalizer.normalized(" release; metadata\nrelease, App Store,app store ,, review ")

        XCTAssertEqual(normalized, "release,metadata,App Store,review")
    }

    func testReviewFixPlannerSuggestsSafeDeterministicFixes() {
        var document = sampleDocument(name: "Example")
        document.localizations[0].appInfo.privacyPolicyURL = " http://example.com/privacy "
        document.localizations[0].version.marketingURL = "http://example.com"
        document.localizations[0].version.keywords = " release; metadata\nrelease "

        let proposals = MetadataReviewFixPlanner.proposals(document: document)

        XCTAssertEqual(proposals.count, 3)
        XCTAssertTrue(proposals.contains {
            $0.kind == .upgradeHTTPS
                && $0.field == "appInfo.privacyPolicyUrl"
                && $0.after == "https://example.com/privacy"
        })
        XCTAssertTrue(proposals.contains {
            $0.kind == .upgradeHTTPS
                && $0.field == "version.marketingUrl"
                && $0.after == "https://example.com"
        })
        XCTAssertTrue(proposals.contains {
            $0.kind == .normalizeKeywords
                && $0.field == "version.keywords"
                && $0.after == "release,metadata"
        })
    }

    func testStoreMediaRequirementValidatorFlagsMissingAndMismatchedAssets() {
        var catalog = StoreMediaCatalog.empty(locales: ["en-US", "ja"], platform: "IOS")
        catalog.add(
            StoreMediaAsset(
                kind: .screenshot,
                fileName: "bad-size.png",
                filePath: "/tmp/bad-size.png",
                width: 1200,
                height: 2400,
                fileSizeBytes: 1_000_000,
                durationSeconds: nil,
                importedAt: .now
            ),
            locale: "en-US",
            deviceID: StoreMediaDeviceSpec.iphone69.id
        )

        let issues = StoreMediaRequirementValidator.issues(for: catalog)
        let summary = StoreMediaRequirementValidator.summary(for: catalog)

        XCTAssertTrue(issues.contains {
            $0.locale == "en-US"
                && $0.deviceID == StoreMediaDeviceSpec.iphone69.id
                && $0.title == "Screenshot size mismatch"
        })
        XCTAssertTrue(issues.contains {
            $0.locale == "ja"
                && $0.kind == .screenshot
                && $0.title == "Missing required screenshots"
        })
        XCTAssertEqual(summary.requiredSetCount, 4)
        XCTAssertEqual(summary.completeRequiredSetCount, 1)
        XCTAssertEqual(summary.screenshotCount, 1)
        XCTAssertGreaterThanOrEqual(summary.blockingCount, 4)
    }

    func testReviewPrepAdvisorPrioritizesProposedFixes() {
        let summary = MetadataReviewPrepAdvisor.summary(
            metadataLoaded: true,
            readinessItems: [
                ReleaseReadinessItem(
                    level: .warning,
                    title: "Validation warnings",
                    detail: "Review warnings.",
                    systemImage: "exclamationmark.triangle"
                )
            ],
            checklistItems: [],
            fixProposals: [
                ReviewFixProposal(
                    kind: .upgradeHTTPS,
                    locale: "en-US",
                    field: "version.marketingUrl",
                    title: "Upgrade Marketing URL",
                    detail: "Use HTTPS.",
                    before: "http://example.com",
                    after: "https://example.com"
                )
            ],
            validationIssues: [],
            plan: .empty
        )

        XCTAssertEqual(summary.proposedFixCount, 1)
        XCTAssertEqual(summary.warningCount, 1)
        XCTAssertEqual(summary.nextAction.kind, .reviewFixes)
    }

    func testReviewPrepAdvisorReportsReadyForCleanSavedMetadata() {
        let summary = MetadataReviewPrepAdvisor.summary(
            metadataLoaded: true,
            readinessItems: [
                ReleaseReadinessItem(
                    level: .ready,
                    title: "Ready",
                    detail: "Ready for metadata save.",
                    systemImage: "checkmark.circle"
                )
            ],
            checklistItems: [],
            fixProposals: [],
            validationIssues: [],
            plan: .empty
        )

        XCTAssertEqual(summary.blockerCount, 0)
        XCTAssertEqual(summary.warningCount, 0)
        XCTAssertEqual(summary.nextAction.kind, .exportHandoff)
        XCTAssertEqual(summary.nextAction.level, .ready)
    }

    func testAddsPolicyGuidanceWarningsWithoutBlockingPlan() {
        let baseline = sampleDocument(name: "Example")
        var document = baseline
        document.localizations[0].appInfo.subtitle = "#1 guaranteed helper"
        document.localizations[0].version.description = "Lorem ipsum beta copy for internal test."
        document.localizations[0].version.marketingURL = "http://example.com"

        let issues = MetadataValidator.validate(document: document)
        let warningMessages = Set(issues.filter { $0.severity == .warning }.map(\.message))

        XCTAssertTrue(warningMessages.contains("Replace placeholder copy before App Review."))
        XCTAssertTrue(warningMessages.contains("Remove beta, TestFlight, or internal-testing language from App Store metadata."))
        XCTAssertTrue(warningMessages.contains("Substantiate ranking or guarantee claims before submission."))
        XCTAssertTrue(warningMessages.contains("Use HTTPS for customer-facing App Store URLs."))

        let plan = MetadataValidator.plan(
            document: document,
            baseline: baseline,
            validationIssues: issues
        )

        XCTAssertFalse(plan.hasBlockingIssues)
    }

    func testValidationIssueProvidesRemediationText() {
        let issue = ValidationIssue(
            severity: .warning,
            locale: "en-US",
            field: "version.promotionalText",
            message: "Remove beta, TestFlight, or internal-testing language from App Store metadata."
        )

        XCTAssertEqual(
            issue.remediation,
            "Use customer-facing release language instead of internal test terms."
        )
    }

    func testPlansOnlyChangedFields() {
        let baseline = sampleDocument(name: "Example")
        let edited = sampleDocument(name: "Example Pro")

        let plan = MetadataValidator.plan(
            document: edited,
            baseline: baseline,
            validationIssues: []
        )

        XCTAssertEqual(plan.visibleActions.count, 1)
        XCTAssertEqual(plan.visibleActions.first?.fields, ["name"])
    }

    func testFormatsMetadataChangeSummaryMarkdown() {
        let baseline = sampleDocument(name: "Example")
        var edited = baseline
        edited.localizations[0].appInfo.name = "Example Pro"
        edited.localizations[0].version.keywords = "release,metadata"
        let issues = MetadataValidator.validate(document: edited)
        let plan = MetadataValidator.plan(
            document: edited,
            baseline: baseline,
            validationIssues: issues
        )

        let summary = MetadataChangeSummaryFormatter.markdown(
            appName: "Example",
            versionString: "1.0",
            plan: plan,
            issues: issues,
            document: edited,
            baseline: baseline
        )

        XCTAssertTrue(summary.contains("# Metadata Change Summary"))
        XCTAssertTrue(summary.contains("App: Example"))
        XCTAssertTrue(summary.contains("Version: 1.0"))
        XCTAssertTrue(summary.contains("### en-US · App Info · Update"))
        XCTAssertTrue(summary.contains("- Name: Example -> Example Pro"))
        XCTAssertTrue(summary.contains("### en-US · Version · Update"))
        XCTAssertTrue(summary.contains("- Keywords: utility,productivity -> release,metadata"))
    }

    func testFormatsMetadataReviewReportMarkdown() {
        let baseline = sampleDocument(name: "Example")
        var edited = baseline
        edited.localizations[0].version.promotionalText = "The #1 guaranteed beta helper."
        edited.localizations[0].version.marketingURL = "http://example.com"
        let issues = MetadataValidator.validate(document: edited)
        let plan = MetadataValidator.plan(
            document: edited,
            baseline: baseline,
            validationIssues: issues
        )
        let checklist = MetadataReviewChecklist.evaluate(
            document: edited,
            validationIssues: issues,
            hasUnsavedChanges: true
        )
        let fixProposals = MetadataReviewFixPlanner.proposals(document: edited)
        let mediaIssues = [
            StoreMediaValidationIssue(
                severity: .blocking,
                locale: "en-US",
                deviceID: "iphone-6-9",
                kind: .screenshot,
                title: "Screenshot size mismatch",
                detail: "hero.png is 1200 x 2400; expected 1260 x 2736."
            )
        ]
        let pricingIssues = [
            PricingAvailabilityIssue(
                severity: .blocking,
                title: "Price not set",
                detail: "Set an app price before preparing the version for submission.",
                affectedTerritories: []
            )
        ]
        let appPrivacyIssues = [
            AppPrivacyIssue(
                severity: .blocking,
                title: "Data type purposes missing",
                detail: "Each selected data type needs at least one collection purpose.",
                affectedDataTypes: [.identifiers]
            )
        ]
        let submissionIssues = [
            SubmissionSetupIssue(
                severity: .blocking,
                area: .build,
                title: "Build not selected",
                detail: "Choose the build that should be associated with this App Store version."
            )
        ]
        let ratingsIssues = [
            RatingsComplianceIssue(
                severity: .blocking,
                area: .ageRating,
                title: "Age rating questionnaire incomplete",
                detail: "Complete the App Store Connect age rating questionnaire before submission."
            )
        ]

        let report = MetadataReviewReportFormatter.markdown(
            appName: "Example",
            versionString: "1.0",
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            readinessItems: [
                ReleaseReadinessItem(
                    level: .warning,
                    title: "Validation warnings",
                    detail: "2 warnings should be reviewed before submission.",
                    systemImage: "exclamationmark.triangle"
                )
            ],
            checklistItems: checklist,
            fixProposals: fixProposals,
            validationIssues: issues,
            mediaValidationIssues: mediaIssues,
            pricingAvailabilityIssues: pricingIssues,
            appPrivacyIssues: appPrivacyIssues,
            submissionSetupIssues: submissionIssues,
            ratingsComplianceIssues: ratingsIssues,
            plan: plan
        )

        XCTAssertTrue(report.contains("# App Store Review Prep Report"))
        XCTAssertTrue(report.contains("Generated: 2023-11-14T22:13:20Z"))
        XCTAssertTrue(report.contains("## Review Checklist"))
        XCTAssertTrue(report.contains("- [warning] Review-Sensitive Language"))
        XCTAssertTrue(report.contains("  - Action: Remove internal test wording"))
        XCTAssertTrue(report.contains("  - Locales: en-US"))
        XCTAssertTrue(report.contains("## Proposed Fixes"))
        XCTAssertTrue(report.contains("- en-US Marketing URL: Use HTTPS for this customer-facing App Store URL."))
        XCTAssertTrue(report.contains("  - After: https://example.com"))
        XCTAssertTrue(report.contains("## Validation"))
        XCTAssertTrue(report.contains("  - Fix:"))
        XCTAssertTrue(report.contains("## Media Validation"))
        XCTAssertTrue(report.contains("- [blocking] en-US Iphone 6 9 Screenshot: Screenshot size mismatch"))
        XCTAssertTrue(report.contains("## Pricing and Availability"))
        XCTAssertTrue(report.contains("- [blocking] Price not set"))
        XCTAssertTrue(report.contains("## App Privacy"))
        XCTAssertTrue(report.contains("- [blocking] Data type purposes missing"))
        XCTAssertTrue(report.contains("## Submission Setup"))
        XCTAssertTrue(report.contains("- [blocking] Build"))
        XCTAssertTrue(report.contains("## Ratings and Compliance"))
        XCTAssertTrue(report.contains("- [blocking] Age Rating"))
        XCTAssertTrue(report.contains("## Draft Changes"))
        XCTAssertTrue(report.contains("- en-US Version update: Marketing URL, Promotional Text"))
    }

    func testReviewHandoffPackageWritesExpectedFiles() throws {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppleConnectHandoffTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folderURL) }

        var baseline = sampleDocument(name: "Example")
        baseline.pulledAt = Date(timeIntervalSince1970: 1_700_000_000)
        var edited = baseline
        edited.localizations[0].version.marketingURL = "http://example.com"
        let issues = MetadataValidator.validate(document: edited)
        let plan = MetadataValidator.plan(
            document: edited,
            baseline: baseline,
            validationIssues: issues
        )
        let mediaIssues = [
            StoreMediaValidationIssue(
                severity: .blocking,
                locale: "en-US",
                deviceID: "iphone-6-9",
                kind: .screenshot,
                title: "Missing required screenshots",
                detail: "Add 1-10 screenshots for this required display size."
            )
        ]
        let pricingIssues = [
            PricingAvailabilityIssue(
                severity: .warning,
                title: "Limited storefront coverage",
                detail: "1 of 6 configured storefronts are customer-visible.",
                affectedTerritories: ["US"]
            )
        ]
        let appPrivacyIssues = [
            AppPrivacyIssue(
                severity: .blocking,
                title: "Privacy policy URL missing",
                detail: "A public privacy policy URL is required before publishing privacy responses.",
                affectedDataTypes: []
            )
        ]
        let submissionIssues = [
            SubmissionSetupIssue(
                severity: .blocking,
                area: .build,
                title: "Build not selected",
                detail: "Choose the build that should be associated with this App Store version."
            )
        ]
        let ratingsIssues = [
            RatingsComplianceIssue(
                severity: .blocking,
                area: .ageRating,
                title: "Age rating questionnaire incomplete",
                detail: "Complete the App Store Connect age rating questionnaire before submission."
            )
        ]
        let context = MetadataReviewHandoffContext(
            appName: "Example App",
            versionString: "1.0",
            sourceMode: "demo",
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            document: edited,
            baseline: baseline,
            readinessItems: [
                ReleaseReadinessItem(
                    level: .warning,
                    title: "Validation warnings",
                    detail: "1 warning should be reviewed before submission.",
                    systemImage: "exclamationmark.triangle"
                )
            ],
            checklistItems: MetadataReviewChecklist.evaluate(
                document: edited,
                validationIssues: issues,
                hasUnsavedChanges: true
            ),
            fixProposals: MetadataReviewFixPlanner.proposals(document: edited),
            validationIssues: issues,
            mediaValidationIssues: mediaIssues,
            pricingAvailabilityIssues: pricingIssues,
            appPrivacyIssues: appPrivacyIssues,
            submissionSetupIssues: submissionIssues,
            ratingsComplianceIssues: ratingsIssues,
            plan: plan
        )

        let packageURL = try MetadataReviewHandoffPackage.write(context: context, to: folderURL)
        let importedDocument = try MetadataDocumentFileTransfer.read(from: packageURL.appendingPathComponent("metadata.json"))
        let manifestData = try Data(contentsOf: packageURL.appendingPathComponent("manifest.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(MetadataReviewHandoffManifest.self, from: manifestData)
        let report = try String(contentsOf: packageURL.appendingPathComponent("review-report.md"), encoding: .utf8)
        let summary = try String(contentsOf: packageURL.appendingPathComponent("change-summary.md"), encoding: .utf8)

        XCTAssertEqual(packageURL.lastPathComponent, "Example-App-1-0-review-handoff")
        XCTAssertEqual(importedDocument, edited)
        XCTAssertEqual(manifest.schemaVersion, 6)
        XCTAssertEqual(manifest.sourceMode, "demo")
        XCTAssertEqual(manifest.localeCount, 1)
        XCTAssertEqual(manifest.mediaValidationIssueCount, 1)
        XCTAssertEqual(manifest.pricingAvailabilityIssueCount, 1)
        XCTAssertEqual(manifest.appPrivacyIssueCount, 1)
        XCTAssertEqual(manifest.submissionSetupIssueCount, 1)
        XCTAssertEqual(manifest.ratingsComplianceIssueCount, 1)
        XCTAssertEqual(manifest.proposedFixCount, 1)
        XCTAssertEqual(manifest.reviewStatus, "blocked")
        XCTAssertTrue(report.contains("# App Store Review Prep Report"))
        XCTAssertTrue(report.contains("## Media Validation"))
        XCTAssertTrue(report.contains("## Pricing and Availability"))
        XCTAssertTrue(report.contains("## App Privacy"))
        XCTAssertTrue(report.contains("## Submission Setup"))
        XCTAssertTrue(report.contains("## Ratings and Compliance"))
        XCTAssertTrue(report.contains("## Proposed Fixes"))
        XCTAssertTrue(summary.contains("# Metadata Change Summary"))
    }

    func testFormatsMetadataDocumentJSONExport() throws {
        let document = sampleDocument(name: "Example")

        let json = try MetadataDocumentExportFormatter.json(document: document)

        XCTAssertTrue(json.contains("\"localizations\""))
        XCTAssertTrue(json.contains("\"locale\" : \"en-US\""))
        XCTAssertTrue(json.contains("\"name\" : \"Example\""))
        XCTAssertTrue(json.contains("\"pulledAt\""))
    }

    func testImportsMetadataDocumentJSONExport() throws {
        var document = sampleDocument(name: "Example")
        document.localizations[0].version.description = "Imported description."
        document.pulledAt = Date(timeIntervalSince1970: 1_700_000_000)
        let json = try MetadataDocumentExportFormatter.json(document: document)

        let imported = try MetadataDocumentImportFormatter.document(from: json)

        XCTAssertEqual(imported, document)
    }

    func testMetadataDocumentFileTransferRoundTripsJSON() throws {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppleConnectFileTransferTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folderURL) }

        var document = sampleDocument(name: "Example")
        document.localizations[0].version.description = "File export description."
        document.pulledAt = Date(timeIntervalSince1970: 1_700_000_000)
        let fileURL = folderURL.appendingPathComponent("metadata.json")

        try MetadataDocumentFileTransfer.write(document: document, to: fileURL)
        let imported = try MetadataDocumentFileTransfer.read(from: fileURL)

        XCTAssertEqual(imported, document)
    }

    @MainActor
    func testSaveMetadataChangesUpdatesBaselineAndClearsPlan() async {
        let service = SavingServiceSpy(document: sampleDocument(name: "Example"))
        let model = AppModel(
            service: service,
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            userDefaults: testDefaults()
        )

        await model.selectApp(service.app)
        model.metadataDocument?.localizations[0].appInfo.name = "Example Pro"
        model.updateValidation()

        XCTAssertTrue(model.hasMetadataChanges)

        await model.saveMetadataChanges()

        XCTAssertEqual(service.saveCallCount, 1)
        XCTAssertFalse(model.hasMetadataChanges)
        XCTAssertEqual(model.baselineDocument?.localizations[0].appInfo.name, "Example Pro")
        XCTAssertEqual(service.lastSavedPlan?.visibleActions.first?.fields, ["name"])
        XCTAssertNotNil(model.metadataSaveStatusMessage)
    }

    @MainActor
    func testImportMetadataDocumentReplacesDraftButPreservesBaseline() async {
        let service = SavingServiceSpy(document: sampleDocument(name: "Example"))
        let model = AppModel(
            service: service,
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            userDefaults: testDefaults()
        )
        var imported = sampleDocument(name: "Imported")
        imported.localizations[0].version.description = "Imported description."

        await model.selectApp(service.app)
        model.importMetadataDocument(imported)

        XCTAssertEqual(model.baselineDocument?.localizations[0].appInfo.name, "Example")
        XCTAssertEqual(model.metadataDocument?.localizations[0].appInfo.name, "Imported")
        XCTAssertEqual(model.selectedLocaleID, "en-US")
        XCTAssertEqual(model.workspaceNoticeMessage, "Imported metadata JSON with 1 locales.")
        XCTAssertTrue(model.hasMetadataChanges)
        XCTAssertTrue(model.publishPlan.visibleActions.contains {
            $0.locale == "en-US" && $0.fields.contains("name")
        })
    }

    @MainActor
    func testSaveMetadataChangesStopsWhenValidationBlocks() async {
        let service = SavingServiceSpy(document: sampleDocument(name: "Example"))
        let model = AppModel(
            service: service,
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            userDefaults: testDefaults()
        )

        await model.selectApp(service.app)
        model.metadataDocument?.localizations[0].appInfo.name = "A"
        model.updateValidation()

        await model.saveMetadataChanges()

        XCTAssertEqual(service.saveCallCount, 0)
        XCTAssertTrue(model.hasMetadataChanges)
        XCTAssertNotNil(model.errorMessage)
    }

    @MainActor
    func testDemoSessionLoadsSampleAppsWithoutPersistingConnection() async {
        let store = ConnectionStoreSpy()
        let model = AppModel(
            llmService: NoopLLMService(),
            connectionStore: store,
            userDefaults: testDefaults()
        )

        await model.startDemoSession()

        XCTAssertEqual(model.dataSourceMode, .demo)
        XCTAssertEqual(model.userSession?.displayName, "Demo Developer")
        XCTAssertTrue(model.isConnectionVerified)
        XCTAssertEqual(model.apps.count, 2)
        XCTAssertEqual(model.selectedAppID, "2234567890")
        XCTAssertEqual(model.sidebarSelection, .reviewPrep)
        XCTAssertNotNil(model.metadataDocument)
        XCTAssertEqual(model.workspaceNoticeMessage, "Loaded the Demo Review Prep workspace.")
        XCTAssertEqual(store.saveCallCount, 0)
    }

    @MainActor
    func testDemoModeUsesFixtureAIWithoutProviderConfiguration() async {
        let model = AppModel(
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: testDefaults()
        )

        await model.startDemoSession()
        model.selectedLocaleID = "en-US"

        XCTAssertFalse(model.providerConfiguration.isEnabled)

        await model.generateMetadataCopy(.draftWhatsNew)

        XCTAssertEqual(
            model.metadataDocument?.localizations[0].version.whatsNew,
            "Improved review prep, validation guidance, and shareable metadata handoff reports."
        )
        XCTAssertEqual(model.llmStatusMessage, "Demo AI generated What's New for en-US.")
        XCTAssertNil(model.errorMessage)
    }

    @MainActor
    func testDemoSessionLoadsMediaAssetCatalogWithReviewGaps() async {
        let model = AppModel(
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: testDefaults()
        )

        await model.startDemoSession()

        XCTAssertNotNil(model.mediaAssetCatalog)
        XCTAssertEqual(model.selectedMediaLocaleID, "en-US")
        XCTAssertGreaterThan(model.mediaValidationSummary.requiredSetCount, 0)
        XCTAssertGreaterThan(model.mediaValidationSummary.screenshotCount, 0)
        XCTAssertGreaterThan(model.mediaValidationSummary.blockingCount, 0)
        XCTAssertTrue(model.mediaValidationIssues.contains { $0.title == "Screenshot size mismatch" })
    }

    @MainActor
    func testMockDemoAppIncludesReviewWorkflowSignals() async throws {
        let service = MockAppStoreConnectService()
        let document = try await service.pullMetadata(
            connection: .demo,
            appID: "2234567890",
            versionID: "version-2234567890-1"
        )
        let issues = MetadataValidator.validate(document: document)
        let proposals = MetadataReviewFixPlanner.proposals(document: document)

        XCTAssertGreaterThanOrEqual(document.localizations.count, 4)
        XCTAssertTrue(document.localizations.contains { $0.locale == "ja" && $0.appInfo.name.isEmpty })
        XCTAssertTrue(issues.contains { $0.message == "Replace placeholder copy before App Review." })
        XCTAssertTrue(issues.contains { $0.message == "Use HTTPS for customer-facing App Store URLs." })
        XCTAssertTrue(issues.contains { $0.message == "Remove beta, TestFlight, or internal-testing language from App Store metadata." })
        XCTAssertTrue(proposals.contains { $0.kind == .upgradeHTTPS && $0.field == "version.marketingUrl" })
        XCTAssertTrue(proposals.contains { $0.kind == .normalizeKeywords && $0.field == "version.keywords" })
    }

    @MainActor
    func testForgetStoredConnectionClearsActiveLiveConnection() {
        let store = ConnectionStoreSpy()
        let model = AppModel(
            llmService: NoopLLMService(),
            connectionStore: store,
            userDefaults: testDefaults()
        )
        model.activeConnection = DeveloperConnection(
            name: "Team",
            keyID: "KEY",
            issuerID: "ISSUER",
            privateKeyPath: "/tmp/AuthKey_KEY.p8",
            privateKeyPEM: "PRIVATE",
            status: .verified(visibleAppCount: 3),
            lastCheckedAt: .now
        )

        model.forgetStoredConnection()

        XCTAssertEqual(store.deleteCallCount, 1)
        XCTAssertEqual(model.activeConnection, .placeholder)
    }

    @MainActor
    func testMetadataDraftRestoresForSelectedVersion() async throws {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppleConnectAppTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folderURL) }

        let service = SavingServiceSpy(document: sampleDocument(name: "Example"))
        let draftStore = FileMetadataDraftStore(folderURL: folderURL)
        let model = AppModel(
            service: service,
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: draftStore,
            userDefaults: testDefaults()
        )

        await model.selectApp(service.app)
        model.metadataDocument?.localizations[0].appInfo.name = "Example Pro"
        model.updateValidation()

        XCTAssertTrue(model.hasMetadataChanges)
        XCTAssertNotNil(model.metadataDraftSavedAt)

        let restoredModel = AppModel(
            service: service,
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: draftStore,
            userDefaults: testDefaults()
        )

        await restoredModel.selectApp(service.app)

        XCTAssertEqual(restoredModel.baselineDocument?.localizations[0].appInfo.name, "Example")
        XCTAssertEqual(restoredModel.metadataDocument?.localizations[0].appInfo.name, "Example Pro")
        XCTAssertTrue(restoredModel.hasMetadataChanges)
        XCTAssertNotNil(restoredModel.metadataDraftSavedAt)
    }

    @MainActor
    func testSwitchingVersionsSecuresDraftAndRestoresItWhenReturning() async throws {
        let firstVersion = AppStoreVersion(
            id: "version-1",
            platform: "IOS",
            versionString: "1.0",
            appVersionState: "PREPARE_FOR_SUBMISSION",
            appStoreState: "DEVELOPER_REMOVED_FROM_SALE",
            createdDate: Date(timeIntervalSinceReferenceDate: 100)
        )
        let secondVersion = AppStoreVersion(
            id: "version-2",
            platform: "IOS",
            versionString: "2.0",
            appVersionState: "PREPARE_FOR_SUBMISSION",
            appStoreState: "DEVELOPER_REMOVED_FROM_SALE",
            createdDate: Date(timeIntervalSinceReferenceDate: 200)
        )
        let service = SavingServiceSpy(
            documentsByVersionID: [
                firstVersion.id: sampleDocument(name: "Version One"),
                secondVersion.id: sampleDocument(name: "Version Two")
            ],
            versions: [firstVersion, secondVersion]
        )
        let draftStore = MemoryDraftStore()
        let model = AppModel(
            service: service,
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: draftStore,
            userDefaults: testDefaults()
        )

        await model.selectApp(service.app)
        XCTAssertEqual(model.selectedVersionID, secondVersion.id)

        model.metadataDocument?.localizations[0].appInfo.name = "Version Two Draft"
        model.updateValidation()

        await model.selectVersion(firstVersion)

        let savedDraft = try draftStore.loadDraft(appID: service.app.id, versionID: secondVersion.id)
        XCTAssertEqual(savedDraft?.document.localizations[0].appInfo.name, "Version Two Draft")
        XCTAssertEqual(model.metadataDocument?.localizations[0].appInfo.name, "Version One")
        XCTAssertEqual(model.workspaceNoticeMessage, "1 draft fields for 2.0 were saved locally before switching versions.")

        await model.selectVersion(secondVersion)

        XCTAssertEqual(model.metadataDocument?.localizations[0].appInfo.name, "Version Two Draft")
        XCTAssertTrue(model.hasMetadataChanges)
    }

    @MainActor
    func testAddLocaleCreatesMetadataPlanActions() async {
        let service = SavingServiceSpy(document: sampleDocument(name: "Example"))
        let model = AppModel(
            service: service,
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            userDefaults: testDefaults()
        )

        await model.selectApp(service.app)

        XCTAssertTrue(model.addLocale(localeID: "ja", copyFrom: "en-US"))

        XCTAssertEqual(model.selectedLocaleID, "ja")
        XCTAssertTrue(model.hasMetadataChanges)
        XCTAssertTrue(model.publishPlan.visibleActions.contains {
            $0.locale == "ja" && $0.kind == .create && $0.resource == .appInfoLocalization
        })
        XCTAssertTrue(model.publishPlan.visibleActions.contains {
            $0.locale == "ja" && $0.kind == .create && $0.resource == .appStoreVersionLocalization
        })
    }

    @MainActor
    func testFillMissingURLsFromSelectedLocaleOnlyCopiesBlankURLFields() async {
        var document = sampleDocument(name: "Example")
        document.localizations[0].appInfo.privacyChoicesURL = "https://example.com/privacy/choices"
        let service = SavingServiceSpy(document: document)
        let model = AppModel(
            service: service,
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            userDefaults: testDefaults()
        )

        await model.selectApp(service.app)
        XCTAssertTrue(model.addLocale(localeID: "ja", copyFrom: nil))
        model.metadataDocument?.localizations[1].version.marketingURL = "https://example.jp"
        model.selectedLocaleID = "en-US"

        let changedLocaleCount = model.fillMissingURLsFromSelectedLocale()

        let localization = model.metadataDocument?.localizations.first { $0.locale == "ja" }
        XCTAssertEqual(changedLocaleCount, 1)
        XCTAssertEqual(localization?.appInfo.privacyPolicyURL, "https://example.com/privacy")
        XCTAssertEqual(localization?.appInfo.privacyChoicesURL, "https://example.com/privacy/choices")
        XCTAssertEqual(localization?.version.marketingURL, "https://example.jp")
        XCTAssertEqual(localization?.version.supportURL, "https://example.com/support")
        XCTAssertEqual(localization?.appInfo.name, "")
        XCTAssertEqual(model.workspaceNoticeMessage, "Filled missing URLs in 1 locales from en-US.")
        XCTAssertTrue(model.hasMetadataChanges)
    }

    @MainActor
    func testUpgradeHTTPURLsToHTTPSUpdatesCustomerFacingURLFields() async {
        var document = sampleDocument(name: "Example")
        document.localizations[0].appInfo.privacyPolicyURL = " http://example.com/privacy "
        document.localizations[0].appInfo.privacyChoicesURL = "https://example.com/privacy/choices"
        document.localizations[0].version.marketingURL = "HTTP://example.com"
        document.localizations[0].version.supportURL = "http://example.com/support"
        let service = SavingServiceSpy(document: document)
        let model = AppModel(
            service: service,
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            userDefaults: testDefaults()
        )

        await model.selectApp(service.app)
        XCTAssertTrue(model.validationIssues.contains {
            $0.message == "Use HTTPS for customer-facing App Store URLs."
        })

        let changedCount = model.upgradeHTTPURLsToHTTPS()

        let localization = model.metadataDocument?.localizations[0]
        XCTAssertEqual(changedCount, 3)
        XCTAssertEqual(localization?.appInfo.privacyPolicyURL, "https://example.com/privacy")
        XCTAssertEqual(localization?.appInfo.privacyChoicesURL, "https://example.com/privacy/choices")
        XCTAssertEqual(localization?.version.marketingURL, "https://example.com")
        XCTAssertEqual(localization?.version.supportURL, "https://example.com/support")
        XCTAssertFalse(model.validationIssues.contains {
            $0.message == "Use HTTPS for customer-facing App Store URLs."
        })
        XCTAssertEqual(model.workspaceNoticeMessage, "Upgraded 3 URLs across 1 locales to HTTPS.")
        XCTAssertTrue(model.hasMetadataChanges)
    }

    @MainActor
    func testApplyReviewFixProposalsUpdatesDraftSafely() async {
        var document = sampleDocument(name: "Example")
        document.localizations[0].version.marketingURL = "http://example.com"
        document.localizations[0].version.keywords = " release; metadata\nrelease "
        let service = SavingServiceSpy(document: document)
        let model = AppModel(
            service: service,
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            userDefaults: testDefaults()
        )

        await model.selectApp(service.app)

        let proposals = model.reviewFixProposals
        let appliedCount = model.applyReviewFixProposals(proposals)

        XCTAssertEqual(appliedCount, 2)
        XCTAssertEqual(model.metadataDocument?.localizations[0].version.marketingURL, "https://example.com")
        XCTAssertEqual(model.metadataDocument?.localizations[0].version.keywords, "release,metadata")
        XCTAssertTrue(model.reviewFixProposals.isEmpty)
        XCTAssertEqual(model.workspaceNoticeMessage, "Applied 2 review fixes across 1 locales.")
        XCTAssertTrue(model.hasMetadataChanges)
    }

    @MainActor
    func testFillMissingCopyFromSelectedLocaleOnlyCopiesBlankNonURLFields() async {
        var document = sampleDocument(name: "Example")
        document.localizations[0].appInfo.privacyPolicyText = "Privacy policy text."
        let service = SavingServiceSpy(document: document)
        let model = AppModel(
            service: service,
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            userDefaults: testDefaults()
        )

        await model.selectApp(service.app)
        XCTAssertTrue(model.addLocale(localeID: "ja", copyFrom: nil))
        model.metadataDocument?.localizations[1].version.description = "既存の説明"
        model.selectedLocaleID = "en-US"

        let changedLocaleCount = model.fillMissingCopyFromSelectedLocale()

        let localization = model.metadataDocument?.localizations.first { $0.locale == "ja" }
        XCTAssertEqual(changedLocaleCount, 1)
        XCTAssertEqual(localization?.appInfo.name, "Example")
        XCTAssertEqual(localization?.appInfo.subtitle, "Calm productivity")
        XCTAssertEqual(localization?.appInfo.privacyPolicyText, "Privacy policy text.")
        XCTAssertEqual(localization?.version.description, "既存の説明")
        XCTAssertEqual(localization?.version.keywords, "utility,productivity")
        XCTAssertEqual(localization?.version.promotionalText, "A useful app.")
        XCTAssertEqual(localization?.version.whatsNew, "Initial release.")
        XCTAssertEqual(localization?.appInfo.privacyPolicyURL, "")
        XCTAssertEqual(localization?.version.supportURL, "")
        XCTAssertEqual(model.workspaceNoticeMessage, "Filled missing copy in 1 locales from en-US.")
        XCTAssertTrue(model.hasMetadataChanges)
    }

    @MainActor
    func testFocusValidationIssueSelectsLocaleAndLocalizedCopy() async {
        let service = SavingServiceSpy(document: sampleDocument(name: "Example"))
        let model = AppModel(
            service: service,
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            userDefaults: testDefaults()
        )

        await model.selectApp(service.app)
        model.detailSelection = .overview
        model.focusValidationIssue(
            ValidationIssue(
                severity: .warning,
                locale: "en-US",
                field: "version.keywords",
                message: "Review keywords."
            )
        )

        XCTAssertEqual(model.selectedLocaleID, "en-US")
        XCTAssertEqual(model.detailSelection, .localizedCopy)
        XCTAssertEqual(model.workspaceNoticeMessage, "Focused en-US version.keywords.")

        model.focusValidationIssue(
            ValidationIssue(
                severity: .warning,
                locale: "missing",
                field: "version.keywords",
                message: "Review keywords."
            )
        )

        XCTAssertEqual(model.selectedLocaleID, "en-US")
    }

    @MainActor
    func testGenerateWhatsNewUpdatesSelectedLocale() async {
        let service = SavingServiceSpy(document: sampleDocument(name: "Example"))
        let model = AppModel(
            service: service,
            llmService: GeneratingLLMService(response: "Better editing, faster review, and cleaner release notes."),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: testDefaults()
        )
        model.providerConfiguration = LLMProviderConfiguration(
            kind: .openAICompatible,
            apiKey: "test-key",
            baseURL: "https://example.com/v1",
            model: "test-model",
            temperature: 0.2,
            isEnabled: true
        )

        await model.selectApp(service.app)
        await model.generateWhatsNewForSelectedLocale()

        XCTAssertEqual(
            model.metadataDocument?.localizations[0].version.whatsNew,
            "Better editing, faster review, and cleaner release notes."
        )
        XCTAssertTrue(model.hasMetadataChanges)
        XCTAssertEqual(model.llmStatusMessage, "Generated What's New for en-US.")
    }

    @MainActor
    func testGenerateMetadataCopyUpdatesDescriptionKeywordsAndPromotionalText() async {
        let service = SavingServiceSpy(document: sampleDocument(name: "Example"))
        let llmService = SequenceLLMService(responses: [
            "A clearer App Store description.",
            "focus; release\nmetadata, app store",
            "Ship cleaner releases with less copywork."
        ])
        let model = AppModel(
            service: service,
            llmService: llmService,
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: testDefaults()
        )
        model.providerConfiguration = LLMProviderConfiguration(
            kind: .openAICompatible,
            apiKey: "test-key",
            baseURL: "https://example.com/v1",
            model: "test-model",
            temperature: 0.2,
            isEnabled: true
        )

        await model.selectApp(service.app)
        await model.generateMetadataCopy(.rewriteDescription)
        await model.generateMetadataCopy(.suggestKeywords)
        await model.generateMetadataCopy(.draftPromotionalText)

        let version = model.metadataDocument?.localizations[0].version
        XCTAssertEqual(version?.description, "A clearer App Store description.")
        XCTAssertEqual(version?.keywords, "focus,release,metadata,app store")
        XCTAssertEqual(version?.promotionalText, "Ship cleaner releases with less copywork.")
        XCTAssertTrue(model.hasMetadataChanges)
        XCTAssertEqual(model.llmStatusMessage, "Generated promotional text for en-US.")
        XCTAssertEqual(llmService.callCount, 3)
    }

    @MainActor
    func testReviewPolishAppliesStructuredMetadata() async {
        let service = SavingServiceSpy(document: sampleDocument(name: "Example"))
        let llmService = GeneratingLLMService(response: """
        {
          "appInfo": {
            "name": "Example",
            "subtitle": "Calm release workflow",
            "privacyPolicyURL": "https://example.com/privacy",
            "privacyChoicesURL": "",
            "privacyPolicyText": ""
          },
          "version": {
            "description": "Plan, review, and update App Store metadata with a focused release workspace.",
            "keywords": "release; metadata\\nreview",
            "marketingURL": "https://example.com",
            "promotionalText": "Review release metadata with calm, focused tools.",
            "supportURL": "https://example.com/support",
            "whatsNew": "Improved review guidance for release metadata."
          }
        }
        """)
        let model = AppModel(
            service: service,
            llmService: llmService,
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: testDefaults()
        )
        model.providerConfiguration = LLMProviderConfiguration(
            kind: .openAICompatible,
            apiKey: "test-key",
            baseURL: "https://example.com/v1",
            model: "test-model",
            temperature: 0.2,
            isEnabled: true
        )

        await model.selectApp(service.app)
        model.metadataDocument?.localizations[0].version.promotionalText = "The #1 guaranteed beta helper."
        model.updateValidation()

        await model.generateMetadataCopy(.reviewPolish)

        let localization = model.metadataDocument?.localizations[0]
        XCTAssertEqual(localization?.appInfo.subtitle, "Calm release workflow")
        XCTAssertEqual(localization?.version.keywords, "release,metadata,review")
        XCTAssertEqual(localization?.version.promotionalText, "Review release metadata with calm, focused tools.")
        XCTAssertEqual(model.llmStatusMessage, "Polished review-ready metadata for en-US.")
        XCTAssertTrue(model.hasMetadataChanges)
    }

    @MainActor
    func testTranslateSelectedLocaleAppliesStructuredMetadata() async {
        let service = SavingServiceSpy(document: sampleDocument(name: "Example"))
        let llmService = GeneratingLLMService(response: """
        {
          "appInfo": {
            "name": "Example JP",
            "subtitle": "静かなリリース管理",
            "privacyPolicyURL": "https://example.com/privacy",
            "privacyChoicesURL": "",
            "privacyPolicyText": ""
          },
          "version": {
            "description": "App Store のメタデータを落ち着いて管理できます。",
            "keywords": "release; metadata\\napp store",
            "marketingURL": "https://example.com",
            "promotionalText": "より整ったリリース作業を。",
            "supportURL": "https://example.com/support",
            "whatsNew": "翻訳ワークフローを追加しました。"
          }
        }
        """)
        let model = AppModel(
            service: service,
            llmService: llmService,
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: testDefaults()
        )
        model.providerConfiguration = LLMProviderConfiguration(
            kind: .openAICompatible,
            apiKey: "test-key",
            baseURL: "https://example.com/v1",
            model: "test-model",
            temperature: 0.2,
            isEnabled: true
        )

        await model.selectApp(service.app)
        XCTAssertTrue(model.addLocale(localeID: "ja", copyFrom: nil))
        await model.translateSelectedLocale(from: "en-US")

        let localization = model.metadataDocument?.localizations.first { $0.locale == "ja" }
        XCTAssertEqual(localization?.appInfo.name, "Example JP")
        XCTAssertEqual(localization?.appInfo.subtitle, "静かなリリース管理")
        XCTAssertEqual(localization?.version.description, "App Store のメタデータを落ち着いて管理できます。")
        XCTAssertEqual(localization?.version.keywords, "release,metadata,app store")
        XCTAssertEqual(localization?.version.promotionalText, "より整ったリリース作業を。")
        XCTAssertEqual(model.llmStatusMessage, "Translated en-US to ja.")
        XCTAssertTrue(model.hasMetadataChanges)
    }

    @MainActor
    func testReleaseReadinessIsReadyForCompleteSavedMetadata() async {
        let service = SavingServiceSpy(document: sampleDocument(name: "Example"))
        let model = AppModel(
            service: service,
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: testDefaults()
        )

        await model.selectApp(service.app)
        completeRequiredMedia(in: model)

        XCTAssertEqual(model.releaseReadinessItems.count, 1)
        XCTAssertEqual(model.releaseReadinessItems.first?.level, .ready)
    }

    @MainActor
    func testReviewChecklistIsReadyForCompleteSavedMetadata() async {
        let service = SavingServiceSpy(document: sampleDocument(name: "Example"))
        let model = AppModel(
            service: service,
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: testDefaults()
        )

        await model.selectApp(service.app)
        completeRequiredMedia(in: model)

        XCTAssertEqual(model.reviewChecklistItems.count, 11)
        XCTAssertTrue(model.reviewChecklistItems.allSatisfy { $0.level == .ready })
        XCTAssertTrue(model.reviewChecklistItems.contains { $0.title == "Review-Sensitive Language" })
        XCTAssertTrue(model.reviewChecklistItems.contains { $0.title == "Localized Media" })
        XCTAssertTrue(model.reviewChecklistItems.contains { $0.title == "Pricing And Availability" })
        XCTAssertTrue(model.reviewChecklistItems.contains { $0.title == "App Privacy" })
        XCTAssertTrue(model.reviewChecklistItems.contains { $0.title == "Submission Setup" })
        XCTAssertTrue(model.reviewChecklistItems.contains { $0.title == "Ratings And Compliance" })
    }

    @MainActor
    func testPricingAvailabilityBlockersFeedReleaseReadinessAndReviewPrep() async {
        let service = SavingServiceSpy(document: sampleDocument(name: "Example"))
        let model = AppModel(
            service: service,
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: testDefaults()
        )

        await model.selectApp(service.app)
        completeRequiredMedia(in: model)
        model.updatePricingTier(priceTier: "", customerPrice: "0.00", proceeds: "0.00")
        model.updateTaxCategory("")

        let pricingChecklistItem = model.reviewChecklistItems.first { $0.title == "Pricing And Availability" }

        XCTAssertTrue(model.releaseReadinessItems.contains {
            $0.level == .blocking && $0.title == "Pricing and availability blockers"
        })
        XCTAssertEqual(pricingChecklistItem?.level, .blocking)
        XCTAssertGreaterThan(model.pricingAvailabilitySummary.blockingCount, 0)
        XCTAssertGreaterThan(model.reviewPrepSummary.blockerCount, 0)
        XCTAssertEqual(model.reviewPrepSummary.nextAction.kind, .resolveBlockers)
    }

    @MainActor
    func testAppPrivacyBlockersFeedReleaseReadinessAndReviewPrep() async {
        let service = SavingServiceSpy(document: sampleDocument(name: "Example"))
        let model = AppModel(
            service: service,
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: testDefaults()
        )

        await model.selectApp(service.app)
        completeRequiredMedia(in: model)
        model.updateAppPrivacyPolicyURL("")
        model.setAppPrivacyDataType(.identifiers, isEnabled: true)
        model.setAppPrivacyPurpose(dataType: .identifiers, purpose: .analytics, isEnabled: false)

        let privacyChecklistItem = model.reviewChecklistItems.first { $0.title == "App Privacy" }

        XCTAssertTrue(model.releaseReadinessItems.contains {
            $0.level == .blocking && $0.title == "App privacy blockers"
        })
        XCTAssertEqual(privacyChecklistItem?.level, .blocking)
        XCTAssertGreaterThan(model.appPrivacySummary.blockingCount, 0)
        XCTAssertGreaterThan(model.reviewPrepSummary.blockerCount, 0)
        XCTAssertEqual(model.reviewPrepSummary.nextAction.kind, .resolveBlockers)
    }

    @MainActor
    func testSubmissionSetupBlockersFeedReleaseReadinessAndReviewPrep() async {
        let service = SavingServiceSpy(document: sampleDocument(name: "Example"))
        let model = AppModel(
            service: service,
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: testDefaults()
        )

        await model.selectApp(service.app)
        completeRequiredMedia(in: model)
        model.updateSubmissionSetupField(\.selectedBuildID, value: Optional<SubmissionBuildCandidate.ID>.none)
        model.updateSubmissionSetupField(\.reviewContact.phone, value: "")

        let submissionChecklistItem = model.reviewChecklistItems.first { $0.title == "Submission Setup" }

        XCTAssertTrue(model.releaseReadinessItems.contains {
            $0.level == .blocking && $0.title == "Submission setup blockers"
        })
        XCTAssertEqual(submissionChecklistItem?.level, .blocking)
        XCTAssertGreaterThan(model.submissionSetupSummary.blockingCount, 0)
        XCTAssertGreaterThan(model.reviewPrepSummary.blockerCount, 0)
        XCTAssertEqual(model.reviewPrepSummary.nextAction.kind, .resolveBlockers)
    }

    @MainActor
    func testRatingsComplianceBlockersFeedReleaseReadinessAndReviewPrep() async {
        let service = SavingServiceSpy(document: sampleDocument(name: "Example"))
        let model = AppModel(
            service: service,
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: testDefaults()
        )

        await model.selectApp(service.app)
        completeRequiredMedia(in: model)
        model.updateRatingsComplianceField(\.isAgeQuestionnaireComplete, value: false)
        model.updateRatingsComplianceField(\.primaryCategory, value: AppStoreCategory?.none)

        let ratingsChecklistItem = model.reviewChecklistItems.first { $0.title == "Ratings And Compliance" }

        XCTAssertTrue(model.releaseReadinessItems.contains {
            $0.level == .blocking && $0.title == "Ratings and compliance blockers"
        })
        XCTAssertEqual(ratingsChecklistItem?.level, .blocking)
        XCTAssertGreaterThan(model.ratingsComplianceSummary.blockingCount, 0)
        XCTAssertGreaterThan(model.reviewPrepSummary.blockerCount, 0)
        XCTAssertEqual(model.reviewPrepSummary.nextAction.kind, .resolveBlockers)
    }

    @MainActor
    func testMediaAssetBlockersFeedReleaseReadinessAndReviewPrep() async {
        let service = SavingServiceSpy(document: sampleDocument(name: "Example"))
        let model = AppModel(
            service: service,
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: testDefaults()
        )

        await model.selectApp(service.app)
        model.mediaAssetCatalog = StoreMediaCatalog.empty(locales: ["en-US"], platform: "IOS")

        let mediaChecklistItem = model.reviewChecklistItems.first { $0.title == "Localized Media" }

        XCTAssertTrue(model.releaseReadinessItems.contains {
            $0.level == .blocking && $0.title == "Media asset blockers"
        })
        XCTAssertEqual(mediaChecklistItem?.level, .blocking)
        XCTAssertEqual(mediaChecklistItem?.affectedLocales, ["en-US"])
        XCTAssertGreaterThan(model.reviewPrepSummary.blockerCount, 0)
        XCTAssertEqual(model.reviewPrepSummary.nextAction.kind, .resolveBlockers)
    }

    @MainActor
    func testReleaseReadinessFlagsMissingFieldsAndLocalDrafts() async {
        let service = SavingServiceSpy(document: sampleDocument(name: "Example"))
        let model = AppModel(
            service: service,
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: testDefaults()
        )

        await model.selectApp(service.app)
        model.metadataDocument?.localizations[0].appInfo.name = ""
        model.metadataDocument?.localizations[0].version.description = ""
        model.metadataDocument?.localizations[0].version.keywords = ""
        model.updateValidation()

        XCTAssertTrue(model.releaseReadinessItems.contains {
            $0.level == .blocking && $0.title == "Missing app names"
        })
        XCTAssertTrue(model.releaseReadinessItems.contains {
            $0.level == .blocking && $0.title == "Missing descriptions"
        })
        XCTAssertTrue(model.releaseReadinessItems.contains {
            $0.level == .warning && $0.title == "Missing keywords"
        })
        XCTAssertTrue(model.releaseReadinessItems.contains {
            $0.level == .warning && $0.title == "Unsaved draft changes"
        })
    }

    @MainActor
    func testReviewChecklistFlagsSubmissionRisksAndDraftState() async {
        let service = SavingServiceSpy(document: sampleDocument(name: "Example"))
        let model = AppModel(
            service: service,
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: testDefaults()
        )

        await model.selectApp(service.app)
        model.metadataDocument?.localizations[0].appInfo.name = ""
        model.metadataDocument?.localizations[0].appInfo.privacyPolicyURL = ""
        model.metadataDocument?.localizations[0].version.description = ""
        model.metadataDocument?.localizations[0].version.keywords = ""
        model.metadataDocument?.localizations[0].version.promotionalText = "The #1 guaranteed beta helper."
        model.metadataDocument?.localizations[0].version.marketingURL = "http://example.com"
        model.metadataDocument?.localizations[0].version.supportURL = ""
        model.metadataDocument?.localizations[0].version.whatsNew = ""
        model.updateValidation()

        let checklistByTitle = Dictionary(uniqueKeysWithValues: model.reviewChecklistItems.map { ($0.title, $0) })

        XCTAssertEqual(checklistByTitle["Required Storefront Copy"]?.level, .blocking)
        XCTAssertEqual(checklistByTitle["Required Storefront Copy"]?.affectedLocales, ["en-US"])
        XCTAssertEqual(checklistByTitle["Privacy And URLs"]?.level, .warning)
        XCTAssertEqual(checklistByTitle["Review-Sensitive Language"]?.level, .warning)
        XCTAssertEqual(checklistByTitle["Release Notes"]?.level, .warning)
        XCTAssertEqual(checklistByTitle["Draft State"]?.level, .warning)
    }

    @MainActor
    func testProviderConfigurationPersistsAndReloads() {
        let providerStore = MemoryProviderStore()
        let firstModel = AppModel(
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: providerStore,
            userDefaults: testDefaults()
        )

        firstModel.providerConfiguration = LLMProviderConfiguration(
            kind: .openAICompatible,
            apiKey: "secret-key",
            baseURL: "https://models.example.com/v1",
            model: "release-copy",
            temperature: 0.1,
            isEnabled: true
        )

        let secondModel = AppModel(
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: providerStore,
            userDefaults: testDefaults()
        )

        XCTAssertEqual(secondModel.providerConfiguration.kind, .openAICompatible)
        XCTAssertEqual(secondModel.providerConfiguration.apiKey, "secret-key")
        XCTAssertEqual(secondModel.providerConfiguration.baseURL, "https://models.example.com/v1")
        XCTAssertEqual(secondModel.providerConfiguration.model, "release-copy")
        XCTAssertEqual(secondModel.providerConfiguration.temperature, 0.1)
        XCTAssertTrue(secondModel.providerConfiguration.isEnabled)
    }

    @MainActor
    func testAppLanguagePersistsAndReloads() {
        let defaults = testDefaults()
        let firstModel = AppModel(
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: defaults
        )

        firstModel.appLanguage = .simplifiedChinese

        let secondModel = AppModel(
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: defaults
        )

        XCTAssertEqual(secondModel.appLanguage, .simplifiedChinese)
        XCTAssertEqual(defaults.string(forKey: AppConstants.languageDefaultsKey), AppLanguage.simplifiedChinese.rawValue)
    }

    @MainActor
    func testUserSessionPersistsAndReloads() {
        let defaults = testDefaults()
        let firstModel = AppModel(
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: defaults
        )

        firstModel.completeAppleSignIn(displayName: "Changxin", email: "changxin@example.com")

        let secondModel = AppModel(
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: defaults
        )

        XCTAssertEqual(secondModel.userSession?.displayName, "Changxin")
        XCTAssertEqual(secondModel.userSession?.email, "changxin@example.com")
    }

    @MainActor
    func testSignOutClearsPersistedUserSession() {
        let defaults = testDefaults()
        let model = AppModel(
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: defaults
        )

        model.completeAppleSignIn(displayName: "Changxin", email: "changxin@example.com")
        model.signOut()

        let restoredModel = AppModel(
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: defaults
        )

        XCTAssertNil(restoredModel.userSession)
        XCTAssertNil(defaults.data(forKey: AppConstants.userSessionDefaultsKey))
    }

    func testVerifiedConnectionRestoresAsAuthorized() throws {
        let defaults = testDefaults()
        let secretStore = MemorySecretStore()
        let store = KeychainConnectionStore(secretStore: secretStore, userDefaults: defaults)
        let connection = DeveloperConnection(
            name: "Primary Team",
            keyID: "ABC123DEFG",
            issuerID: "issuer-id",
            privateKeyPath: "/tmp/AuthKey_ABC123DEFG.p8",
            privateKeyPEM: "PRIVATE KEY",
            status: .verified(visibleAppCount: 7),
            lastCheckedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        try store.saveConnection(connection)
        let restored = try XCTUnwrap(store.loadConnection())

        XCTAssertEqual(restored.name, "Primary Team")
        XCTAssertEqual(restored.privateKeyPEM, "PRIVATE KEY")
        XCTAssertEqual(restored.status, .verified(visibleAppCount: 7))
    }

    @MainActor
    func testPersistedDemoSessionRestoresVerifiedDemoConnection() async {
        let defaults = testDefaults()
        let firstModel = AppModel(
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: defaults
        )

        await firstModel.startDemoSession()

        let secondModel = AppModel(
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: MemoryProviderStore(),
            userDefaults: defaults
        )

        XCTAssertEqual(secondModel.userSession?.displayName, "Demo Developer")
        XCTAssertEqual(secondModel.dataSourceMode, .demo)
        XCTAssertTrue(secondModel.isConnectionVerified)
    }

    @MainActor
    func testResetProviderConfigurationClearsStoredSecret() {
        let providerStore = MemoryProviderStore()
        let model = AppModel(
            llmService: NoopLLMService(),
            connectionStore: MemoryConnectionStore(),
            draftStore: MemoryDraftStore(),
            providerStore: providerStore,
            userDefaults: testDefaults()
        )
        model.providerConfiguration = LLMProviderConfiguration(
            kind: .openAICompatible,
            apiKey: "secret-key",
            baseURL: "https://models.example.com/v1",
            model: "release-copy",
            temperature: 0.1,
            isEnabled: true
        )

        model.resetProviderConfiguration()

        XCTAssertEqual(model.providerConfiguration, .aliyunBailianDefault)
        XCTAssertEqual(providerStore.savedConfiguration?.apiKey, "")
        XCTAssertEqual(providerStore.deleteCallCount, 1)
    }

    private func sampleDocument(name: String) -> MetadataDocument {
        MetadataDocument(
            localizations: [
                LocaleMetadata(
                    locale: "en-US",
                    appInfo: AppInfoMetadata(
                        name: name,
                        subtitle: "Calm productivity",
                        privacyPolicyURL: "https://example.com/privacy",
                        privacyChoicesURL: "",
                        privacyPolicyText: ""
                    ),
                    version: VersionMetadata(
                        description: "Useful app.",
                        keywords: "utility,productivity",
                        marketingURL: "https://example.com",
                        promotionalText: "A useful app.",
                        supportURL: "https://example.com/support",
                        whatsNew: "Initial release."
                    )
                )
            ],
            pulledAt: .now
        )
    }

    private func testDefaults() -> UserDefaults {
        UserDefaults(suiteName: "AppleConnectAppTests.\(UUID().uuidString)")!
    }

    @MainActor
    private func completeRequiredMedia(in model: AppModel) {
        guard var catalog = model.mediaAssetCatalog else {
            return
        }

        for locale in catalog.locales {
            for spec in catalog.deviceSpecs where spec.isRequired {
                guard let size = spec.screenshotSizes.first else {
                    continue
                }

                catalog.add(
                    StoreMediaAsset(
                        kind: .screenshot,
                        fileName: "\(locale)-\(spec.id).png",
                        filePath: "/tmp/\(locale)-\(spec.id).png",
                        width: size.width,
                        height: size.height,
                        fileSizeBytes: 1_000_000,
                        durationSeconds: nil,
                        importedAt: Date(timeIntervalSince1970: 1_700_000_000)
                    ),
                    locale: locale,
                    deviceID: spec.id
                )
            }
        }

        model.mediaAssetCatalog = catalog
    }
}

@MainActor
private final class SavingServiceSpy: AppStoreConnectServicing {
    let app = ConnectApp(
        id: "app-1",
        name: "Example",
        bundleID: "com.example.app",
        sku: "EXAMPLE",
        primaryLocale: "en-US"
    )
    private let documentsByVersionID: [String: MetadataDocument]
    private let fallbackDocument: MetadataDocument
    private let versions: [AppStoreVersion]
    var saveCallCount = 0
    var lastSavedPlan: MetadataPlan?

    init(document: MetadataDocument) {
        let version = AppStoreVersion(
            id: "version-1",
            platform: "IOS",
            versionString: "1.0",
            appVersionState: "PREPARE_FOR_SUBMISSION",
            appStoreState: "DEVELOPER_REMOVED_FROM_SALE",
            createdDate: .now
        )
        self.documentsByVersionID = [version.id: document]
        self.fallbackDocument = document
        self.versions = [version]
    }

    init(documentsByVersionID: [String: MetadataDocument], versions: [AppStoreVersion]) {
        self.documentsByVersionID = documentsByVersionID
        self.fallbackDocument = documentsByVersionID[versions.first?.id ?? ""] ?? documentsByVersionID.values.first ?? MetadataDocument(localizations: [], pulledAt: .now)
        self.versions = versions
    }

    func validateConnection(_ connection: DeveloperConnection) async throws -> ConnectionCheckResult {
        ConnectionCheckResult(visibleAppCount: 1)
    }

    func listApps(connection: DeveloperConnection) async throws -> [ConnectApp] {
        [app]
    }

    func listAppInfos(connection: DeveloperConnection, appID: String) async throws -> [AppInfoSummary] {
        [
            AppInfoSummary(
                id: "app-info-1",
                state: "PREPARE_FOR_SUBMISSION",
                appStoreState: "DEVELOPER_REMOVED_FROM_SALE"
            )
        ]
    }

    func listVersions(connection: DeveloperConnection, appID: String) async throws -> [AppStoreVersion] {
        versions
    }

    func pullMetadata(
        connection: DeveloperConnection,
        appID: String,
        versionID: String
    ) async throws -> MetadataDocument {
        documentsByVersionID[versionID] ?? fallbackDocument
    }

    func saveMetadata(
        connection: DeveloperConnection,
        appID: String,
        versionID: String,
        document: MetadataDocument,
        plan: MetadataPlan
    ) async throws -> MetadataSaveResult {
        saveCallCount += 1
        lastSavedPlan = plan
        return MetadataSaveResult(appliedActionCount: plan.visibleActions.count)
    }
}

private struct NoopLLMService: LLMServicing {
    func testConnection(configuration: LLMProviderConfiguration) async throws -> String {
        "OK"
    }

    func generateText(configuration: LLMProviderConfiguration, messages: [LLMMessage]) async throws -> String {
        ""
    }
}

private struct GeneratingLLMService: LLMServicing {
    var response: String

    func testConnection(configuration: LLMProviderConfiguration) async throws -> String {
        "OK"
    }

    func generateText(configuration: LLMProviderConfiguration, messages: [LLMMessage]) async throws -> String {
        response
    }
}

@MainActor
private final class SequenceLLMService: LLMServicing {
    private var responses: [String]
    private(set) var callCount = 0

    init(responses: [String]) {
        self.responses = responses
    }

    func testConnection(configuration: LLMProviderConfiguration) async throws -> String {
        "OK"
    }

    func generateText(configuration: LLMProviderConfiguration, messages: [LLMMessage]) async throws -> String {
        callCount += 1
        guard !responses.isEmpty else {
            return ""
        }

        return responses.removeFirst()
    }
}

private struct MemoryConnectionStore: ConnectionPersisting {
    func loadConnection() throws -> DeveloperConnection? {
        nil
    }

    func saveConnection(_ connection: DeveloperConnection) throws {}

    func deleteConnection(_ connection: DeveloperConnection) throws {}
}

private final class MemoryDraftStore: MetadataDraftPersisting {
    private var drafts: [String: MetadataDraft] = [:]

    func loadDraft(appID: String, versionID: String) throws -> MetadataDraft? {
        drafts[key(appID, versionID)]
    }

    func saveDraft(_ draft: MetadataDraft, appID: String, versionID: String) throws {
        drafts[key(appID, versionID)] = draft
    }

    func deleteDraft(appID: String, versionID: String) throws {
        drafts.removeValue(forKey: key(appID, versionID))
    }

    private func key(_ appID: String, _ versionID: String) -> String {
        "\(appID)|\(versionID)"
    }
}

private final class MemoryProviderStore: LLMProviderPersisting {
    var savedConfiguration: LLMProviderConfiguration?
    var deleteCallCount = 0

    func loadConfiguration() throws -> LLMProviderConfiguration? {
        savedConfiguration
    }

    func saveConfiguration(_ configuration: LLMProviderConfiguration) throws {
        savedConfiguration = configuration
    }

    func deleteConfiguration() throws {
        deleteCallCount += 1
        savedConfiguration = nil
    }
}

private final class MemorySecretStore: SecretStoring {
    private var values: [String: String] = [:]

    func save(_ value: String, account: String, service: String) throws {
        values[key(account: account, service: service)] = value
    }

    func read(account: String, service: String) throws -> String? {
        values[key(account: account, service: service)]
    }

    func delete(account: String, service: String) throws {
        values.removeValue(forKey: key(account: account, service: service))
    }

    private func key(account: String, service: String) -> String {
        "\(service)|\(account)"
    }
}

private final class ConnectionStoreSpy: ConnectionPersisting {
    var saveCallCount = 0
    var deleteCallCount = 0

    func loadConnection() throws -> DeveloperConnection? {
        nil
    }

    func saveConnection(_ connection: DeveloperConnection) throws {
        saveCallCount += 1
    }

    func deleteConnection(_ connection: DeveloperConnection) throws {
        deleteCallCount += 1
    }
}
