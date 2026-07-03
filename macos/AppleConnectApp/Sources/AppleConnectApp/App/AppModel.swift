import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var userSession: UserSession?
    var activeConnection = DeveloperConnection.placeholder
    var apps: [ConnectApp] = []
    var appInfosByAppID: [String: [AppInfoSummary]] = [:]
    var versionsByAppID: [String: [AppStoreVersion]] = [:]
    var selectedAppID: String?
    var selectedVersionID: String?
    var rootScreen: RootScreen = .home
    var appListViewMode: AppListViewMode = .grid
    var detailSelection: AppDetailSelection? = .overview
    var sidebarSelection: SidebarSelection? = .dashboard
    var metadataDocument: MetadataDocument?
    var baselineDocument: MetadataDocument?
    var selectedLocaleID: String?
    var mediaAssetCatalog: StoreMediaCatalog?
    var selectedMediaLocaleID: String?
    var pricingAvailability: AppPricingAvailability?
    var appPrivacyDisclosure: AppPrivacyDisclosure?
    var submissionSetup: AppSubmissionSetup?
    var ratingsCompliance: AppRatingsCompliance?
    var validationIssues: [ValidationIssue] = []
    var publishPlan = MetadataPlan.empty
    var providerConfiguration = LLMProviderConfiguration.aliyunBailianDefault {
        didSet {
            persistProviderConfiguration()
        }
    }
    var llmStatusMessage: String?
    var metadataSaveStatusMessage: String?
    var metadataDraftStatusMessage: String?
    var metadataDraftSavedAt: Date?
    var workspaceNoticeMessage: String?
    var dataSourceMode: AppDataSourceMode {
        didSet {
            userDefaults.set(dataSourceMode.rawValue, forKey: AppConstants.dataSourceDefaultsKey)
        }
    }
    var isBusy = false
    var errorMessage: String?
    var theme: AppTheme {
        didSet {
            userDefaults.set(theme.rawValue, forKey: AppConstants.themeDefaultsKey)
        }
    }
    var appLanguage: AppLanguage {
        didSet {
            userDefaults.set(appLanguage.rawValue, forKey: AppConstants.languageDefaultsKey)
        }
    }

    private var service: any AppStoreConnectServicing
    private let serviceFactory: (AppDataSourceMode) -> any AppStoreConnectServicing
    private let llmService: any LLMServicing
    private let connectionStore: any ConnectionPersisting
    private let draftStore: any MetadataDraftPersisting
    private let providerStore: any LLMProviderPersisting
    private let userDefaults: UserDefaults

    init(
        service: (any AppStoreConnectServicing)? = nil,
        llmService: any LLMServicing = OpenAICompatibleLLMService(),
        connectionStore: any ConnectionPersisting = KeychainConnectionStore(),
        draftStore: any MetadataDraftPersisting = FileMetadataDraftStore(),
        providerStore: (any LLMProviderPersisting)? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.userDefaults = userDefaults
        self.llmService = llmService
        self.connectionStore = connectionStore
        self.draftStore = draftStore
        self.providerStore = providerStore ?? KeychainLLMProviderStore(userDefaults: userDefaults)
        let storedDataSourceMode = userDefaults.string(forKey: AppConstants.dataSourceDefaultsKey)
        let selectedDataSourceMode = storedDataSourceMode.flatMap(AppDataSourceMode.init(rawValue:)) ?? .live
        self.dataSourceMode = selectedDataSourceMode
        if let service {
            self.service = service
            self.serviceFactory = { _ in service }
        } else {
            self.service = Self.makeService(for: selectedDataSourceMode)
            self.serviceFactory = Self.makeService(for:)
        }
        let storedTheme = userDefaults.string(forKey: AppConstants.themeDefaultsKey)
        self.theme = storedTheme.flatMap(AppTheme.init(rawValue:)) ?? .system
        let storedLanguage = userDefaults.string(forKey: AppConstants.languageDefaultsKey)
        self.appLanguage = storedLanguage.flatMap(AppLanguage.init(rawValue:)) ?? .system
        self.userSession = Self.loadPersistedUserSession(from: userDefaults)
        if selectedDataSourceMode == .demo {
            activeConnection = .demo
            if userSession != nil {
                activeConnection.status = .verified(visibleAppCount: 0)
            }
        } else {
            loadPersistedConnection()
        }
        loadPersistedProviderConfiguration()
    }

    var selectedApp: ConnectApp? {
        apps.first { $0.id == selectedAppID }
    }

    var selectedVersion: AppStoreVersion? {
        guard let selectedAppID, let selectedVersionID else {
            return nil
        }

        return versionsByAppID[selectedAppID]?.first { $0.id == selectedVersionID }
    }

    var versionsForSelectedApp: [AppStoreVersion] {
        guard let selectedAppID else {
            return []
        }

        return versionsByAppID[selectedAppID] ?? []
    }

    var appInfosForSelectedApp: [AppInfoSummary] {
        guard let selectedAppID else {
            return []
        }

        return appInfosByAppID[selectedAppID] ?? []
    }

    var hasMetadataChanges: Bool {
        !publishPlan.visibleActions.isEmpty
    }

    var changedFieldCount: Int {
        publishPlan.visibleActions.reduce(0) { $0 + $1.fields.count }
    }

    var changedLocaleIDs: Set<String> {
        Set(publishPlan.visibleActions.map(\.locale))
    }

    var reviewChecklistItems: [ReviewChecklistItem] {
        let copyItems = MetadataReviewChecklist.evaluate(
            document: metadataDocument,
            validationIssues: validationIssues,
            hasUnsavedChanges: hasMetadataChanges
        )

        return copyItems + [
            StoreMediaReviewReadiness.checklistItem(
                catalog: mediaAssetCatalog,
                issues: mediaValidationIssues
            ),
            PricingAvailabilityReviewReadiness.checklistItem(
                configuration: pricingAvailability,
                issues: pricingAvailabilityIssues
            ),
            AppPrivacyReviewReadiness.checklistItem(
                disclosure: appPrivacyDisclosure,
                issues: appPrivacyIssues
            ),
            SubmissionSetupReviewReadiness.checklistItem(
                setup: submissionSetup,
                issues: submissionSetupIssues
            ),
            RatingsComplianceReviewReadiness.checklistItem(
                configuration: ratingsCompliance,
                issues: ratingsComplianceIssues
            )
        ]
    }

    var reviewFixProposals: [ReviewFixProposal] {
        MetadataReviewFixPlanner.proposals(document: metadataDocument)
    }

    var mediaValidationIssues: [StoreMediaValidationIssue] {
        guard let mediaAssetCatalog else {
            return []
        }

        return StoreMediaRequirementValidator.issues(for: mediaAssetCatalog)
    }

    var mediaValidationSummary: StoreMediaValidationSummary {
        guard let mediaAssetCatalog else {
            return StoreMediaValidationSummary(
                requiredSetCount: 0,
                completeRequiredSetCount: 0,
                screenshotCount: 0,
                previewCount: 0,
                blockingCount: 0,
                warningCount: 0
            )
        }

        return StoreMediaRequirementValidator.summary(for: mediaAssetCatalog)
    }

    var pricingAvailabilityIssues: [PricingAvailabilityIssue] {
        PricingAvailabilityValidator.issues(for: pricingAvailability)
    }

    var pricingAvailabilitySummary: PricingAvailabilitySummary {
        PricingAvailabilityValidator.summary(for: pricingAvailability)
    }

    var appPrivacyIssues: [AppPrivacyIssue] {
        AppPrivacyValidator.issues(for: appPrivacyDisclosure)
    }

    var appPrivacySummary: AppPrivacySummary {
        AppPrivacyValidator.summary(for: appPrivacyDisclosure)
    }

    var submissionSetupIssues: [SubmissionSetupIssue] {
        SubmissionSetupValidator.issues(for: submissionSetup)
    }

    var submissionSetupSummary: SubmissionSetupSummary {
        SubmissionSetupValidator.summary(for: submissionSetup)
    }

    var ratingsComplianceIssues: [RatingsComplianceIssue] {
        RatingsComplianceValidator.issues(for: ratingsCompliance)
    }

    var ratingsComplianceSummary: RatingsComplianceSummary {
        RatingsComplianceValidator.summary(for: ratingsCompliance)
    }

    var reviewPrepSummary: ReviewPrepSummary {
        MetadataReviewPrepAdvisor.summary(
            metadataLoaded: metadataDocument != nil,
            readinessItems: releaseReadinessItems,
            checklistItems: reviewChecklistItems,
            fixProposals: reviewFixProposals,
            validationIssues: validationIssues,
            plan: publishPlan
        )
    }

    var releaseReadinessItems: [ReleaseReadinessItem] {
        var items: [ReleaseReadinessItem] = []

        guard let metadataDocument else {
            return [
                ReleaseReadinessItem(
                    level: .blocking,
                    title: "Metadata not loaded",
                    detail: "Select an app and version before preparing release copy.",
                    systemImage: "doc.text.magnifyingglass"
                )
            ]
        }

        if metadataDocument.localizations.isEmpty {
            items.append(
                ReleaseReadinessItem(
                    level: .blocking,
                    title: "No localizations",
                    detail: "Add at least one locale before preparing App Store metadata.",
                    systemImage: "globe.badge.chevron.backward"
                )
            )
        }

        let errorCount = validationIssues.filter { $0.severity == .error }.count
        let warningCount = validationIssues.filter { $0.severity == .warning }.count
        if errorCount > 0 {
            items.append(
                ReleaseReadinessItem(
                    level: .blocking,
                    title: "Validation errors",
                    detail: "\(errorCount) field issues must be resolved before saving.",
                    systemImage: "xmark.octagon"
                )
            )
        }

        if warningCount > 0 {
            items.append(
                ReleaseReadinessItem(
                    level: .warning,
                    title: "Validation warnings",
                    detail: "\(warningCount) warnings should be reviewed before submission.",
                    systemImage: "exclamationmark.triangle"
                )
            )
        }

        let missingNames = metadataDocument.localizations.filter {
            $0.appInfo.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if !missingNames.isEmpty {
            items.append(
                ReleaseReadinessItem(
                    level: .blocking,
                    title: "Missing app names",
                    detail: localeListDetail(missingNames.map(\.locale)),
                    systemImage: "app.badge"
                )
            )
        }

        let missingDescriptions = metadataDocument.localizations.filter {
            $0.version.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if !missingDescriptions.isEmpty {
            items.append(
                ReleaseReadinessItem(
                    level: .blocking,
                    title: "Missing descriptions",
                    detail: localeListDetail(missingDescriptions.map(\.locale)),
                    systemImage: "text.alignleft"
                )
            )
        }

        let missingKeywords = metadataDocument.localizations.filter {
            $0.version.keywords.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if !missingKeywords.isEmpty {
            items.append(
                ReleaseReadinessItem(
                    level: .warning,
                    title: "Missing keywords",
                    detail: localeListDetail(missingKeywords.map(\.locale)),
                    systemImage: "tag"
                )
            )
        }

        let missingSupportURLs = metadataDocument.localizations.filter {
            $0.version.supportURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if !missingSupportURLs.isEmpty {
            items.append(
                ReleaseReadinessItem(
                    level: .warning,
                    title: "Missing support URLs",
                    detail: localeListDetail(missingSupportURLs.map(\.locale)),
                    systemImage: "lifepreserver"
                )
            )
        }

        if hasMetadataChanges {
            items.append(
                ReleaseReadinessItem(
                    level: .warning,
                    title: "Unsaved draft changes",
                    detail: "\(changedFieldCount) fields across \(changedLocaleIDs.count) locales are still local.",
                    systemImage: "tray.and.arrow.down"
                )
            )
        }

        items.append(
            contentsOf: StoreMediaReviewReadiness.releaseItems(
                catalog: mediaAssetCatalog,
                issues: mediaValidationIssues
            )
        )

        items.append(
            contentsOf: PricingAvailabilityReviewReadiness.releaseItems(
                configuration: pricingAvailability,
                issues: pricingAvailabilityIssues
            )
        )

        items.append(
            contentsOf: AppPrivacyReviewReadiness.releaseItems(
                disclosure: appPrivacyDisclosure,
                issues: appPrivacyIssues
            )
        )

        items.append(
            contentsOf: SubmissionSetupReviewReadiness.releaseItems(
                setup: submissionSetup,
                issues: submissionSetupIssues
            )
        )

        items.append(
            contentsOf: RatingsComplianceReviewReadiness.releaseItems(
                configuration: ratingsCompliance,
                issues: ratingsComplianceIssues
            )
        )

        if isDemoMode {
            items.append(
                ReleaseReadinessItem(
                    level: .warning,
                    title: "Demo workspace",
                    detail: "Saves update the local demo baseline and will not write to App Store Connect.",
                    systemImage: "play.circle"
                )
            )
        }

        if items.isEmpty {
            items.append(
                ReleaseReadinessItem(
                    level: .ready,
                    title: "Ready for metadata save",
                    detail: "No blocking metadata issues were found for the selected version.",
                    systemImage: "checkmark.circle"
                )
            )
        }

        return items
    }

    func issueCount(for locale: String) -> Int {
        validationIssues.filter { $0.locale == locale }.count
    }

    func issues(for locale: String) -> [ValidationIssue] {
        validationIssues.filter { $0.locale == locale }
    }

    func focusValidationIssue(_ issue: ValidationIssue) {
        guard metadataDocument?.localizations.contains(where: { $0.locale == issue.locale }) == true else {
            return
        }

        selectedLocaleID = issue.locale
        detailSelection = .localizedCopy
        workspaceNoticeMessage = String(localized: "Focused \(issue.locale) \(issue.field).")
    }

    func localeListDetail(_ locales: [String]) -> String {
        let sortedLocales = locales.sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
        let visibleLocales = sortedLocales.prefix(4).joined(separator: ", ")
        let remainingCount = max(0, sortedLocales.count - 4)
        if remainingCount == 0 {
            return visibleLocales
        }

        return "\(visibleLocales) and \(remainingCount) more"
    }

    func changedFields(for locale: String, resource: MetadataResource) -> Set<String> {
        let fields = publishPlan.visibleActions
            .filter { $0.locale == locale && $0.resource == resource }
            .flatMap(\.fields)
        return Set(fields)
    }

    var isConnectionVerified: Bool {
        if case .verified = activeConnection.status {
            return true
        }

        return false
    }

    var isDemoMode: Bool {
        dataSourceMode == .demo
    }

    func completeAppleSignIn(displayName: String?, email: String?) {
        userSession = UserSession(
            id: UUID().uuidString,
            displayName: displayName?.isEmpty == false ? displayName : "Apple Developer",
            email: email
        )
        persistUserSession()
        rootScreen = .home
        selectedAppID = nil
        selectedVersionID = nil
        detailSelection = .overview
    }

    func startDemoSession() async {
        switchDataSourceMode(.demo)
        userSession = UserSession(
            id: "demo-user",
            displayName: "Demo Developer",
            email: nil
        )
        persistUserSession()
        await validateConnection()
        await selectInitialDemoReviewApp()
    }

    func switchDataSourceMode(_ mode: AppDataSourceMode) {
        guard dataSourceMode != mode else {
            return
        }

        guard saveCurrentDraftBeforeContextChange("switching data sources") else {
            return
        }

        dataSourceMode = mode
        service = serviceFactory(mode)
        clearWorkspaceState()

        switch mode {
        case .live:
            activeConnection = .placeholder
            loadPersistedConnection()
        case .demo:
            activeConnection = .demo
        }
    }

    func signOut() {
        guard saveCurrentDraftBeforeContextChange("signing out") else {
            return
        }

        userSession = nil
        userDefaults.removeObject(forKey: AppConstants.userSessionDefaultsKey)
        activeConnection.status = .notVerified
        clearWorkspaceState()
    }

    func forgetStoredConnection() {
        do {
            try connectionStore.deleteConnection(activeConnection)
            activeConnection = dataSourceMode == .demo ? .demo : .placeholder
            metadataSaveStatusMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetProviderConfiguration() {
        do {
            try providerStore.deleteConfiguration()
            providerConfiguration = .aliyunBailianDefault
            llmStatusMessage = String(localized: "Model provider settings were reset.")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func validateConnection() async {
        guard !isBusy else {
            return
        }

        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            let result = try await service.validateConnection(activeConnection)
            activeConnection.status = .verified(visibleAppCount: result.visibleAppCount)
            activeConnection.lastCheckedAt = .now
            if dataSourceMode == .live {
                try connectionStore.saveConnection(activeConnection)
            }
            try await loadAppsAfterConnection()
            rootScreen = .home
        } catch {
            let message = error.localizedDescription
            activeConnection.status = .failed(message: message)
            errorMessage = message
        }
    }

    func loadApps() async {
        await runBusyTask {
            try await loadAppsAfterConnection()
        }
    }

    func selectApp(_ app: ConnectApp) async {
        if selectedAppID == app.id {
            rootScreen = .appDetail
            sidebarSelection = .app(app.id)
            return
        }

        guard saveCurrentDraftBeforeContextChange("switching apps") else {
            return
        }

        selectedAppID = app.id
        rootScreen = .appDetail
        sidebarSelection = .app(app.id)
        selectedVersionID = nil
        metadataDocument = nil
        baselineDocument = nil
        selectedLocaleID = nil
        mediaAssetCatalog = nil
        selectedMediaLocaleID = nil
        pricingAvailability = nil
        appPrivacyDisclosure = nil
        submissionSetup = nil
        ratingsCompliance = nil
        metadataSaveStatusMessage = nil
        detailSelection = .overview

        await runBusyTask {
            let appInfos = try await service.listAppInfos(connection: activeConnection, appID: app.id)
            let versions = try await service.listVersions(connection: activeConnection, appID: app.id)
            let sortedVersions = versions.sorted { $0.createdDate > $1.createdDate }
            appInfosByAppID[app.id] = appInfos
            versionsByAppID[app.id] = sortedVersions
            selectedVersionID = sortedVersions.first?.id
            if let firstVersion = sortedVersions.first {
                try await loadMetadata(appID: app.id, versionID: firstVersion.id)
            }
        }
    }

    func selectVersion(_ version: AppStoreVersion) async {
        if selectedVersionID == version.id, metadataDocument != nil {
            detailSelection = .version(version.id)
            return
        }

        guard saveCurrentDraftBeforeContextChange("switching versions") else {
            return
        }

        selectedVersionID = version.id
        detailSelection = .version(version.id)
        metadataDocument = nil
        baselineDocument = nil
        selectedLocaleID = nil
        mediaAssetCatalog = nil
        selectedMediaLocaleID = nil
        pricingAvailability = nil
        appPrivacyDisclosure = nil
        submissionSetup = nil
        ratingsCompliance = nil
        metadataSaveStatusMessage = nil
        guard let selectedAppID else {
            return
        }

        await runBusyTask {
            try await loadMetadata(appID: selectedAppID, versionID: version.id)
        }
    }

    func refreshCurrentSelection() async {
        if let selectedAppID, let selectedVersionID {
            guard saveCurrentDraftBeforeContextChange("refreshing metadata") else {
                return
            }

            await runBusyTask {
                try await loadMetadata(appID: selectedAppID, versionID: selectedVersionID)
            }
            return
        }

        if !apps.isEmpty {
            await loadApps()
        }
    }

    func returnToHome() {
        guard saveCurrentDraftBeforeContextChange("leaving the app workspace") else {
            return
        }

        rootScreen = .home
        selectedAppID = nil
        selectedVersionID = nil
        metadataDocument = nil
        baselineDocument = nil
        selectedLocaleID = nil
        mediaAssetCatalog = nil
        selectedMediaLocaleID = nil
        pricingAvailability = nil
        appPrivacyDisclosure = nil
        submissionSetup = nil
        ratingsCompliance = nil
        metadataSaveStatusMessage = nil
        metadataDraftStatusMessage = nil
        metadataDraftSavedAt = nil
        detailSelection = .overview
    }

    func showCreateAppPlaceholder() {
        errorMessage = String(localized: "Creating a new app will be connected after the App Store Connect account flow is ready.")
    }

    func updateValidation() {
        guard let metadataDocument else {
            validationIssues = []
            publishPlan = .empty
            mediaAssetCatalog = nil
            selectedMediaLocaleID = nil
            pricingAvailability = nil
            appPrivacyDisclosure = nil
            submissionSetup = nil
            ratingsCompliance = nil
            return
        }

        validationIssues = MetadataValidator.validate(document: metadataDocument)
        publishPlan = MetadataValidator.plan(
            document: metadataDocument,
            baseline: baselineDocument,
            validationIssues: validationIssues
        )
        syncDraftAfterValidation()
        syncMediaCatalogLocales(with: metadataDocument)
    }

    func importMediaAsset(url: URL, kind: StoreMediaAssetKind, locale: String, deviceID: String) async {
        guard mediaAssetCatalog != nil else {
            errorMessage = String(localized: "Load a version before importing media assets.")
            return
        }

        do {
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let asset = try await StoreMediaAssetInspector.inspect(url: url, kind: kind)
            mediaAssetCatalog?.add(asset, locale: locale, deviceID: deviceID)
            selectedMediaLocaleID = locale
            workspaceNoticeMessage = String(localized: "Imported \(asset.fileName) for \(locale).")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeMediaAsset(assetID: StoreMediaAsset.ID, locale: String, deviceID: String, kind: StoreMediaAssetKind) {
        mediaAssetCatalog?.remove(assetID: assetID, locale: locale, deviceID: deviceID, kind: kind)
        workspaceNoticeMessage = String(localized: "Removed media asset from \(locale).")
    }

    func updatePricingDistributionMethod(_ method: AppDistributionMethod) {
        updatePricingAvailability { configuration in
            configuration.distributionMethod = method
        }
    }

    func updatePricingTier(priceTier: String, customerPrice: String, proceeds: String) {
        updatePricingAvailability { configuration in
            configuration.priceTier = priceTier
            configuration.customerPrice = customerPrice
            configuration.proceeds = proceeds
        }
    }

    func updateTaxCategory(_ taxCategory: String) {
        updatePricingAvailability { configuration in
            configuration.taxCategory = taxCategory
        }
    }

    func setPreOrderEnabled(_ isEnabled: Bool) {
        updatePricingAvailability { configuration in
            configuration.isPreOrderEnabled = isEnabled
            if !isEnabled {
                configuration.preOrderReleaseDate = nil
                for index in configuration.territories.indices where configuration.territories[index].status == .preOrder {
                    configuration.territories[index].status = .available
                }
            }
        }
    }

    func updatePreOrderReleaseDate(_ date: Date?) {
        updatePricingAvailability { configuration in
            configuration.preOrderReleaseDate = date
            configuration.isPreOrderEnabled = date != nil || configuration.isPreOrderEnabled
        }
    }

    func setPhasedReleaseEnabled(_ isEnabled: Bool) {
        updatePricingAvailability { configuration in
            configuration.isPhasedReleaseEnabled = isEnabled
        }
    }

    func setEducationDiscountEnabled(_ isEnabled: Bool) {
        updatePricingAvailability { configuration in
            configuration.isEducationDiscountEnabled = isEnabled
        }
    }

    func setAppleSiliconMacAvailable(_ isAvailable: Bool) {
        updatePricingAvailability { configuration in
            configuration.isAppleSiliconMacAvailable = isAvailable
        }
    }

    func updateTerritoryAvailability(code: String, status: StorefrontAvailabilityStatus) {
        updatePricingAvailability { configuration in
            guard let index = configuration.territories.firstIndex(where: { $0.code == code }) else {
                return
            }

            configuration.territories[index].status = status
            if status == .preOrder {
                configuration.isPreOrderEnabled = true
            }
        }
    }

    private func updatePricingAvailability(_ update: (inout AppPricingAvailability) -> Void) {
        guard var configuration = pricingAvailability else {
            errorMessage = String(localized: "Load a version before editing pricing and availability.")
            return
        }

        update(&configuration)
        pricingAvailability = configuration
        workspaceNoticeMessage = String(localized: "Updated pricing and availability draft.")
    }

    func setAppPrivacyCollectsData(_ doesCollectData: Bool) {
        updateAppPrivacyDisclosure { disclosure in
            disclosure.doesCollectData = doesCollectData
            if !doesCollectData {
                disclosure.dataDisclosures = []
            }
        }
    }

    func updateAppPrivacyPolicyURL(_ url: String) {
        updateAppPrivacyDisclosure { disclosure in
            disclosure.privacyPolicyURL = url
        }
    }

    func updateAppPrivacyChoicesURL(_ url: String) {
        updateAppPrivacyDisclosure { disclosure in
            disclosure.privacyChoicesURL = url
        }
    }

    func setAppPrivacyDataType(_ dataType: AppPrivacyDataType, isEnabled: Bool) {
        updateAppPrivacyDisclosure { disclosure in
            if isEnabled {
                disclosure.doesCollectData = true
                guard !disclosure.dataDisclosures.contains(where: { $0.dataType == dataType }) else {
                    return
                }
                disclosure.dataDisclosures.append(
                    AppPrivacyDataDisclosure(
                        dataType: dataType,
                        purposes: [],
                        isLinkedToUser: false,
                        isUsedForTracking: false,
                        note: ""
                    )
                )
                disclosure.dataDisclosures.sort { $0.dataType.title.localizedStandardCompare($1.dataType.title) == .orderedAscending }
            } else {
                disclosure.dataDisclosures.removeAll { $0.dataType == dataType }
            }
        }
    }

    func setAppPrivacyPurpose(dataType: AppPrivacyDataType, purpose: AppPrivacyPurpose, isEnabled: Bool) {
        updateAppPrivacyDisclosure { disclosure in
            guard let index = disclosure.dataDisclosures.firstIndex(where: { $0.dataType == dataType }) else {
                return
            }

            if isEnabled {
                disclosure.dataDisclosures[index].purposes.insert(purpose)
            } else {
                disclosure.dataDisclosures[index].purposes.remove(purpose)
            }
        }
    }

    func setAppPrivacyLinked(dataType: AppPrivacyDataType, isLinked: Bool) {
        updateAppPrivacyDisclosure { disclosure in
            guard let index = disclosure.dataDisclosures.firstIndex(where: { $0.dataType == dataType }) else {
                return
            }

            disclosure.dataDisclosures[index].isLinkedToUser = isLinked
        }
    }

    func setAppPrivacyTracking(dataType: AppPrivacyDataType, isTracking: Bool) {
        updateAppPrivacyDisclosure { disclosure in
            guard let index = disclosure.dataDisclosures.firstIndex(where: { $0.dataType == dataType }) else {
                return
            }

            disclosure.dataDisclosures[index].isUsedForTracking = isTracking
        }
    }

    private func updateAppPrivacyDisclosure(_ update: (inout AppPrivacyDisclosure) -> Void) {
        guard var disclosure = appPrivacyDisclosure else {
            errorMessage = String(localized: "Load a version before editing App Privacy responses.")
            return
        }

        update(&disclosure)
        appPrivacyDisclosure = disclosure
        workspaceNoticeMessage = String(localized: "Updated App Privacy draft.")
    }

    func selectSubmissionBuild(_ buildID: SubmissionBuildCandidate.ID) {
        updateSubmissionSetup { setup in
            setup.selectedBuildID = buildID
            if let build = setup.selectedBuild, build.usesNonExemptEncryption == true {
                setup.exportCompliance.usesEncryption = true
            }
        }
    }

    func updateSubmissionReleaseOption(_ option: SubmissionReleaseOption) {
        updateSubmissionSetup { setup in
            setup.releaseOption = option
            if option == .scheduledRelease, setup.scheduledReleaseDate == nil {
                setup.scheduledReleaseDate = Calendar.current.date(byAdding: .day, value: 7, to: .now)
            } else if option != .scheduledRelease {
                setup.scheduledReleaseDate = nil
            }
        }
    }

    func updateSubmissionScheduledReleaseDate(_ date: Date?) {
        updateSubmissionSetup { setup in
            setup.scheduledReleaseDate = date
            if date != nil {
                setup.releaseOption = .scheduledRelease
            }
        }
    }

    func updateSubmissionDraftItemCount(_ count: Int) {
        updateSubmissionSetup { setup in
            setup.draftSubmissionItemCount = max(0, count)
        }
    }

    func updateSubmissionSetupField<Value>(_ keyPath: WritableKeyPath<AppSubmissionSetup, Value>, value: Value) {
        updateSubmissionSetup { setup in
            setup[keyPath: keyPath] = value
        }
    }

    private func updateSubmissionSetup(_ update: (inout AppSubmissionSetup) -> Void) {
        guard var setup = submissionSetup else {
            errorMessage = String(localized: "Load a version before editing submission setup.")
            return
        }

        update(&setup)
        setup.updatedAt = .now
        submissionSetup = setup
        workspaceNoticeMessage = String(localized: "Updated submission setup draft.")
    }

    func updateRatingsComplianceField<Value>(_ keyPath: WritableKeyPath<AppRatingsCompliance, Value>, value: Value) {
        updateRatingsCompliance { configuration in
            configuration[keyPath: keyPath] = value
        }
    }

    func setAgeRatingFrequency(descriptor: AgeRatingDescriptor, frequency: AgeRatingFrequency) {
        updateRatingsCompliance { configuration in
            if let index = configuration.ageResponses.firstIndex(where: { $0.descriptor == descriptor }) {
                configuration.ageResponses[index].frequency = frequency
            } else {
                configuration.ageResponses.append(
                    AgeRatingResponse(descriptor: descriptor, frequency: frequency)
                )
                configuration.ageResponses.sort { $0.descriptor.title.localizedStandardCompare($1.descriptor.title) == .orderedAscending }
            }
        }
    }

    private func updateRatingsCompliance(_ update: (inout AppRatingsCompliance) -> Void) {
        guard var configuration = ratingsCompliance else {
            errorMessage = String(localized: "Load a version before editing ratings and compliance.")
            return
        }

        update(&configuration)
        configuration.updatedAt = .now
        ratingsCompliance = configuration
        workspaceNoticeMessage = String(localized: "Updated ratings and compliance draft.")
    }

    func reviewReportMarkdown(generatedAt: Date = .now) -> String {
        updateValidation()
        return MetadataReviewReportFormatter.markdown(
            appName: selectedApp?.name ?? "",
            versionString: selectedVersion?.versionString ?? "",
            generatedAt: generatedAt,
            readinessItems: releaseReadinessItems,
            checklistItems: reviewChecklistItems,
            fixProposals: reviewFixProposals,
            validationIssues: validationIssues,
            mediaValidationIssues: mediaValidationIssues,
            pricingAvailabilityIssues: pricingAvailabilityIssues,
            appPrivacyIssues: appPrivacyIssues,
            submissionSetupIssues: submissionSetupIssues,
            ratingsComplianceIssues: ratingsComplianceIssues,
            plan: publishPlan
        )
    }

    func resetMetadataChanges() {
        guard let baselineDocument else {
            return
        }

        let currentLocaleID = selectedLocaleID
        metadataDocument = baselineDocument
        if let currentLocaleID,
           baselineDocument.localizations.contains(where: { $0.locale == currentLocaleID }) {
            selectedLocaleID = currentLocaleID
        } else {
            selectedLocaleID = baselineDocument.localizations.first?.locale
        }
        updateValidation()
    }

    func importMetadataDocument(_ document: MetadataDocument) {
        guard metadataDocument != nil else {
            errorMessage = String(localized: "Load metadata before importing JSON.")
            return
        }

        let currentLocaleID = selectedLocaleID
        metadataDocument = document
        if let currentLocaleID,
           document.localizations.contains(where: { $0.locale == currentLocaleID }) {
            selectedLocaleID = currentLocaleID
        } else {
            selectedLocaleID = document.localizations.first?.locale
        }
        updateValidation()
        workspaceNoticeMessage = String(localized: "Imported metadata JSON with \(document.localizations.count) locales.")
    }

    @discardableResult
    func applyReviewFixProposal(_ proposal: ReviewFixProposal) -> Bool {
        guard var document = metadataDocument else {
            errorMessage = String(localized: "Load metadata before applying review fixes.")
            return false
        }

        guard applyReviewFixProposal(proposal, to: &document) else {
            errorMessage = String(localized: "This review fix is no longer current. Refresh Review Prep and try again.")
            return false
        }

        metadataDocument = document
        selectedLocaleID = proposal.locale
        updateValidation()
        workspaceNoticeMessage = String(localized: "Applied review fix for \(proposal.locale) \(proposal.title).")
        return true
    }

    @discardableResult
    func applyReviewFixProposals(_ proposals: [ReviewFixProposal]) -> Int {
        guard var document = metadataDocument else {
            errorMessage = String(localized: "Load metadata before applying review fixes.")
            return 0
        }

        guard !proposals.isEmpty else {
            workspaceNoticeMessage = String(localized: "No review fixes are available.")
            return 0
        }

        var appliedCount = 0
        var changedLocales = Set<String>()

        for proposal in proposals where applyReviewFixProposal(proposal, to: &document) {
            appliedCount += 1
            changedLocales.insert(proposal.locale)
        }

        guard appliedCount > 0 else {
            errorMessage = String(localized: "No review fixes could be applied. Refresh Review Prep and try again.")
            return 0
        }

        metadataDocument = document
        updateValidation()
        workspaceNoticeMessage = String(localized: "Applied \(appliedCount) review fixes across \(changedLocales.count) locales.")
        return appliedCount
    }

    @discardableResult
    func upgradeHTTPURLsToHTTPS() -> Int {
        guard var document = metadataDocument else {
            errorMessage = String(localized: "Load metadata before upgrading URLs.")
            return 0
        }

        var changedFieldCount = 0
        var changedLocales = Set<String>()

        for index in document.localizations.indices {
            var localization = document.localizations[index]
            var didChangeLocale = false

            if upgradeHTTPURL(&localization.appInfo.privacyPolicyURL) {
                changedFieldCount += 1
                didChangeLocale = true
            }
            if upgradeHTTPURL(&localization.appInfo.privacyChoicesURL) {
                changedFieldCount += 1
                didChangeLocale = true
            }
            if upgradeHTTPURL(&localization.version.marketingURL) {
                changedFieldCount += 1
                didChangeLocale = true
            }
            if upgradeHTTPURL(&localization.version.supportURL) {
                changedFieldCount += 1
                didChangeLocale = true
            }

            if didChangeLocale {
                changedLocales.insert(localization.locale)
                document.localizations[index] = localization
            }
        }

        guard changedFieldCount > 0 else {
            workspaceNoticeMessage = String(localized: "No http:// App Store URLs were found.")
            return 0
        }

        metadataDocument = document
        updateValidation()
        workspaceNoticeMessage = String(localized: "Upgraded \(changedFieldCount) URLs across \(changedLocales.count) locales to HTTPS.")
        return changedFieldCount
    }

    @discardableResult
    func addLocale(localeID: String, copyFrom sourceLocaleID: String?) -> Bool {
        let normalizedLocaleID = localeID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLocaleID.isEmpty else {
            errorMessage = String(localized: "Enter a locale identifier.")
            return false
        }

        guard var document = metadataDocument else {
            errorMessage = String(localized: "Load metadata before adding a locale.")
            return false
        }

        guard !document.localizations.contains(where: { $0.locale.caseInsensitiveCompare(normalizedLocaleID) == .orderedSame }) else {
            errorMessage = String(localized: "\(normalizedLocaleID) already exists.")
            return false
        }

        let sourceLocalization = sourceLocaleID.flatMap { localeID in
            document.localizations.first { $0.locale == localeID }
        }

        var newLocalization = sourceLocalization ?? LocaleMetadata(
            locale: normalizedLocaleID,
            appInfo: AppInfoMetadata(
                name: "",
                subtitle: "",
                privacyPolicyURL: "",
                privacyChoicesURL: "",
                privacyPolicyText: ""
            ),
            version: VersionMetadata(
                description: "",
                keywords: "",
                marketingURL: "",
                promotionalText: "",
                supportURL: "",
                whatsNew: ""
            )
        )
        newLocalization.locale = normalizedLocaleID
        document.localizations.append(newLocalization)
        document.localizations.sort { $0.locale.localizedStandardCompare($1.locale) == .orderedAscending }
        metadataDocument = document
        selectedLocaleID = normalizedLocaleID
        mediaAssetCatalog?.ensureLocale(normalizedLocaleID)
        selectedMediaLocaleID = normalizedLocaleID
        updateValidation()
        return true
    }

    @discardableResult
    func fillMissingURLsFromSelectedLocale() -> Int {
        guard let selectedLocaleID,
              var document = metadataDocument,
              let sourceLocalization = document.localizations.first(where: { $0.locale == selectedLocaleID }) else {
            errorMessage = String(localized: "Select a source locale before filling missing URLs.")
            return 0
        }

        var changedLocales = Set<String>()

        for index in document.localizations.indices {
            guard document.localizations[index].locale != selectedLocaleID else {
                continue
            }

            var localization = document.localizations[index]
            var didChange = false

            copyIfMissing(
                sourceLocalization.appInfo.privacyPolicyURL,
                into: &localization.appInfo.privacyPolicyURL,
                didChange: &didChange
            )
            copyIfMissing(
                sourceLocalization.appInfo.privacyChoicesURL,
                into: &localization.appInfo.privacyChoicesURL,
                didChange: &didChange
            )
            copyIfMissing(
                sourceLocalization.version.marketingURL,
                into: &localization.version.marketingURL,
                didChange: &didChange
            )
            copyIfMissing(
                sourceLocalization.version.supportURL,
                into: &localization.version.supportURL,
                didChange: &didChange
            )

            if didChange {
                changedLocales.insert(localization.locale)
                document.localizations[index] = localization
            }
        }

        if changedLocales.isEmpty {
            workspaceNoticeMessage = String(localized: "No missing URL fields were found outside \(selectedLocaleID).")
            return 0
        }

        metadataDocument = document
        updateValidation()
        workspaceNoticeMessage = String(localized: "Filled missing URLs in \(changedLocales.count) locales from \(selectedLocaleID).")
        return changedLocales.count
    }

    @discardableResult
    func fillMissingCopyFromSelectedLocale() -> Int {
        guard let selectedLocaleID,
              var document = metadataDocument,
              let sourceLocalization = document.localizations.first(where: { $0.locale == selectedLocaleID }) else {
            errorMessage = String(localized: "Select a source locale before filling missing copy.")
            return 0
        }

        var changedLocales = Set<String>()

        for index in document.localizations.indices {
            guard document.localizations[index].locale != selectedLocaleID else {
                continue
            }

            var localization = document.localizations[index]
            var didChange = false

            copyIfMissing(
                sourceLocalization.appInfo.name,
                into: &localization.appInfo.name,
                didChange: &didChange
            )
            copyIfMissing(
                sourceLocalization.appInfo.subtitle,
                into: &localization.appInfo.subtitle,
                didChange: &didChange
            )
            copyIfMissing(
                sourceLocalization.appInfo.privacyPolicyText,
                into: &localization.appInfo.privacyPolicyText,
                didChange: &didChange
            )
            copyIfMissing(
                sourceLocalization.version.description,
                into: &localization.version.description,
                didChange: &didChange
            )
            copyIfMissing(
                sourceLocalization.version.keywords,
                into: &localization.version.keywords,
                didChange: &didChange
            )
            copyIfMissing(
                sourceLocalization.version.promotionalText,
                into: &localization.version.promotionalText,
                didChange: &didChange
            )
            copyIfMissing(
                sourceLocalization.version.whatsNew,
                into: &localization.version.whatsNew,
                didChange: &didChange
            )

            if didChange {
                changedLocales.insert(localization.locale)
                document.localizations[index] = localization
            }
        }

        if changedLocales.isEmpty {
            workspaceNoticeMessage = String(localized: "No missing copy fields were found outside \(selectedLocaleID).")
            return 0
        }

        metadataDocument = document
        updateValidation()
        workspaceNoticeMessage = String(localized: "Filled missing copy in \(changedLocales.count) locales from \(selectedLocaleID).")
        return changedLocales.count
    }

    func saveMetadataChanges() async {
        guard let selectedAppID, let selectedVersionID, let metadataDocument else {
            return
        }

        updateValidation()
        guard !publishPlan.hasBlockingIssues else {
            errorMessage = String(localized: "Resolve validation errors before saving.")
            return
        }

        guard hasMetadataChanges else {
            metadataSaveStatusMessage = String(localized: "No draft changes to save.")
            return
        }

        let documentToSave = metadataDocument
        let planToSave = publishPlan

        await runBusyTask {
            let result = try await service.saveMetadata(
                connection: activeConnection,
                appID: selectedAppID,
                versionID: selectedVersionID,
                document: documentToSave,
                plan: planToSave
            )
            baselineDocument = documentToSave
            updateValidation()
            if self.metadataDocument == documentToSave {
                if isDemoMode {
                    metadataSaveStatusMessage = String(localized: "Saved \(result.appliedActionCount) demo metadata updates.")
                } else {
                    metadataSaveStatusMessage = String(localized: "Saved \(result.appliedActionCount) metadata updates to App Store Connect.")
                }
            } else {
                metadataSaveStatusMessage = String(localized: "Saved \(result.appliedActionCount) metadata updates. New local edits remain unsaved.")
            }
        }
    }

    func testLLMProvider() async {
        await runBusyTask {
            let response = try await llmService.testConnection(configuration: providerConfiguration)
            llmStatusMessage = String(localized: "Provider replied: \(response)")
        }
    }

    func generateWhatsNewForSelectedLocale() async {
        await generateMetadataCopy(.draftWhatsNew)
    }

    func generateMetadataCopy(_ action: MetadataAIAction) async {
        guard let llmContext = llmGenerationContext() else {
            return
        }

        guard let selectedLocaleID,
              let localization = metadataDocument?.localizations.first(where: { $0.locale == selectedLocaleID }) else {
            errorMessage = String(localized: "Select a locale before generating release copy.")
            return
        }
        let selectedAppName = selectedApp?.name ?? AppConstants.productName
        let selectedIssues = issues(for: selectedLocaleID)

        if action == .reviewPolish {
            await runBusyTask {
                let response = try await llmContext.service.generateText(
                    configuration: llmContext.configuration,
                    messages: reviewPolishPrompt(
                        appName: selectedAppName,
                        localization: localization,
                        issues: selectedIssues
                    )
                )
                let polished = try decodeTranslationResponse(response)
                applyTranslation(polished, targetLocaleID: selectedLocaleID)
                llmStatusMessage = String(localized: "\(llmContext.polishedVerb) review-ready metadata for \(selectedLocaleID).")
            }
            return
        }

        await runBusyTask {
            let generatedText = try await llmContext.service.generateText(
                configuration: llmContext.configuration,
                messages: metadataAIPrompt(
                    action: action,
                    appName: selectedAppName,
                    localization: localization
                )
            )
            applyGeneratedMetadataText(generatedText, localeID: selectedLocaleID, action: action)
            llmStatusMessage = String(localized: "\(llmContext.generatedVerb) \(action.resultName) for \(selectedLocaleID).")
        }
    }

    func translateSelectedLocale(from sourceLocaleID: String) async {
        guard let llmContext = llmGenerationContext() else {
            return
        }

        guard let targetLocaleID = selectedLocaleID,
              let sourceLocalization = metadataDocument?.localizations.first(where: { $0.locale == sourceLocaleID }),
              metadataDocument?.localizations.contains(where: { $0.locale == targetLocaleID }) == true else {
            errorMessage = String(localized: "Choose a source and target locale before translating.")
            return
        }

        guard sourceLocaleID != targetLocaleID else {
            errorMessage = String(localized: "Choose a different source locale.")
            return
        }

        await runBusyTask {
            let response = try await llmContext.service.generateText(
                configuration: llmContext.configuration,
                messages: translationPrompt(
                    sourceLocalization: sourceLocalization,
                    targetLocaleID: targetLocaleID
                )
            )
            let translated = try decodeTranslationResponse(response)
            applyTranslation(translated, targetLocaleID: targetLocaleID)
            llmStatusMessage = String(localized: "\(llmContext.translatedVerb) \(sourceLocaleID) to \(targetLocaleID).")
        }
    }

    private func loadAppsAfterConnection() async throws {
        apps = try await service.listApps(connection: activeConnection)
    }

    private func selectInitialDemoReviewApp() async {
        guard isDemoMode, selectedAppID == nil else {
            return
        }

        guard let app = apps.first(where: { $0.id == "2234567890" }) ?? apps.first else {
            return
        }

        await selectApp(app)
        sidebarSelection = .reviewPrep
        workspaceNoticeMessage = String(localized: "Loaded the Demo Review Prep workspace.")
    }

    private static func makeService(for mode: AppDataSourceMode) -> any AppStoreConnectServicing {
        switch mode {
        case .live:
            LiveAppStoreConnectService()
        case .demo:
            MockAppStoreConnectService()
        }
    }

    private func loadPersistedConnection() {
        do {
            if let connection = try connectionStore.loadConnection() {
                activeConnection = connection
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func loadPersistedUserSession(from userDefaults: UserDefaults) -> UserSession? {
        guard let data = userDefaults.data(forKey: AppConstants.userSessionDefaultsKey) else {
            return nil
        }

        return try? JSONDecoder().decode(UserSession.self, from: data)
    }

    private func persistUserSession() {
        guard let userSession else {
            userDefaults.removeObject(forKey: AppConstants.userSessionDefaultsKey)
            return
        }

        do {
            let data = try JSONEncoder().encode(userSession)
            userDefaults.set(data, forKey: AppConstants.userSessionDefaultsKey)
        } catch {
            errorMessage = String(localized: "Sign-in state could not be saved: \(error.localizedDescription)")
        }
    }

    private func loadPersistedProviderConfiguration() {
        do {
            if let configuration = try providerStore.loadConfiguration() {
                providerConfiguration = configuration
            }
        } catch {
            llmStatusMessage = String(localized: "Model provider settings could not be loaded: \(error.localizedDescription)")
        }
    }

    private func persistProviderConfiguration() {
        do {
            try providerStore.saveConfiguration(providerConfiguration)
        } catch {
            llmStatusMessage = String(localized: "Model provider settings could not be saved: \(error.localizedDescription)")
        }
    }

    private func llmGenerationContext() -> LLMGenerationContext? {
        if providerConfiguration.isEnabled && providerConfiguration.isConfigured {
            return LLMGenerationContext(
                service: llmService,
                configuration: providerConfiguration,
                isDemoFixture: false
            )
        }

        if isDemoMode {
            return LLMGenerationContext(
                service: DemoLLMService(),
                configuration: .demoFixture,
                isDemoFixture: true
            )
        }

        if !providerConfiguration.isEnabled {
            errorMessage = String(localized: "Enable AI assistance in Model Provider settings first.")
        } else {
            errorMessage = LLMError.missingConfiguration.localizedDescription
        }
        return nil
    }

    private func clearWorkspaceState() {
        apps = []
        appInfosByAppID = [:]
        versionsByAppID = [:]
        selectedAppID = nil
        selectedVersionID = nil
        metadataDocument = nil
        baselineDocument = nil
        selectedLocaleID = nil
        mediaAssetCatalog = nil
        selectedMediaLocaleID = nil
        pricingAvailability = nil
        appPrivacyDisclosure = nil
        submissionSetup = nil
        ratingsCompliance = nil
        validationIssues = []
        publishPlan = .empty
        metadataSaveStatusMessage = nil
        metadataDraftStatusMessage = nil
        metadataDraftSavedAt = nil
        workspaceNoticeMessage = nil
        rootScreen = .home
        detailSelection = .overview
        sidebarSelection = .dashboard
    }

    private func loadMetadata(appID: String, versionID: String) async throws {
        let document = try await service.pullMetadata(
            connection: activeConnection,
            appID: appID,
            versionID: versionID
        )
        baselineDocument = document
        if let draft = try draftStore.loadDraft(appID: appID, versionID: versionID) {
            metadataDocument = draft.document
            metadataDraftSavedAt = draft.savedAt
            metadataDraftStatusMessage = String(localized: "Restored local draft saved \(draft.savedAt.formatted(date: .abbreviated, time: .shortened)).")
        } else {
            metadataDocument = document
            metadataDraftSavedAt = nil
            metadataDraftStatusMessage = nil
        }
        selectedLocaleID = metadataDocument?.localizations.first?.locale
        mediaAssetCatalog = MockStoreMediaCatalogFactory.catalog(
            app: selectedApp,
            version: selectedVersion,
            locales: metadataDocument?.localizations.map(\.locale) ?? [],
            isDemoMode: isDemoMode
        )
        selectedMediaLocaleID = selectedLocaleID
        pricingAvailability = MockPricingAvailabilityFactory.configuration(
            app: selectedApp,
            version: selectedVersion,
            isDemoMode: isDemoMode
        )
        appPrivacyDisclosure = MockAppPrivacyFactory.disclosure(
            app: selectedApp,
            version: selectedVersion,
            document: metadataDocument,
            isDemoMode: isDemoMode
        )
        submissionSetup = MockSubmissionSetupFactory.setup(
            app: selectedApp,
            version: selectedVersion,
            isDemoMode: isDemoMode
        )
        ratingsCompliance = MockRatingsComplianceFactory.configuration(
            app: selectedApp,
            version: selectedVersion,
            isDemoMode: isDemoMode
        )
        metadataSaveStatusMessage = nil
        updateValidation()
    }

    private func syncMediaCatalogLocales(with document: MetadataDocument) {
        guard mediaAssetCatalog != nil else {
            return
        }

        for locale in document.localizations.map(\.locale) {
            mediaAssetCatalog?.ensureLocale(locale)
        }

        if let selectedMediaLocaleID,
           document.localizations.contains(where: { $0.locale == selectedMediaLocaleID }) {
            return
        }

        selectedMediaLocaleID = document.localizations.first?.locale
    }

    private func syncDraftAfterValidation() {
        guard let selectedAppID, let selectedVersionID, let metadataDocument else {
            return
        }

        do {
            if hasMetadataChanges {
                let savedAt = Date()
                try draftStore.saveDraft(
                    MetadataDraft(document: metadataDocument, savedAt: savedAt),
                    appID: selectedAppID,
                    versionID: selectedVersionID
                )
                metadataDraftSavedAt = savedAt
                metadataDraftStatusMessage = String(localized: "Draft saved locally \(savedAt.formatted(date: .omitted, time: .shortened)).")
            } else {
                try draftStore.deleteDraft(appID: selectedAppID, versionID: selectedVersionID)
                metadataDraftSavedAt = nil
                metadataDraftStatusMessage = nil
            }
        } catch {
            metadataDraftStatusMessage = String(localized: "Draft could not be saved: \(error.localizedDescription)")
        }
    }

    @discardableResult
    private func saveCurrentDraftBeforeContextChange(_ actionDescription: String) -> Bool {
        guard let selectedAppID, let selectedVersionID, let metadataDocument, hasMetadataChanges else {
            return true
        }

        do {
            let savedAt = Date()
            try draftStore.saveDraft(
                MetadataDraft(document: metadataDocument, savedAt: savedAt),
                appID: selectedAppID,
                versionID: selectedVersionID
            )
            metadataDraftSavedAt = savedAt
            metadataDraftStatusMessage = String(localized: "Draft saved locally \(savedAt.formatted(date: .omitted, time: .shortened)).")
            let versionLabel = selectedVersion?.versionString ?? selectedVersionID
            workspaceNoticeMessage = String(localized: "\(changedFieldCount) draft fields for \(versionLabel) were saved locally before \(actionDescription).")
            return true
        } catch {
            metadataDraftStatusMessage = String(localized: "Draft could not be saved: \(error.localizedDescription)")
            errorMessage = String(localized: "Draft could not be saved before \(actionDescription): \(error.localizedDescription)")
            return false
        }
    }

    private func metadataAIPrompt(
        action: MetadataAIAction,
        appName: String,
        localization: LocaleMetadata
    ) -> [LLMMessage] {
        [
            LLMMessage(
                role: "system",
                content: "You write polished App Store metadata. Return only the requested copy, with no markdown heading, explanation, or surrounding quotes."
            ),
            LLMMessage(
                role: "user",
                content: """
                App: \(appName)
                Locale: \(localization.locale)
                App subtitle: \(localization.appInfo.subtitle)
                Description: \(localization.version.description)
                Keywords: \(localization.version.keywords)
                Promotional text: \(localization.version.promotionalText)
                Current What's New: \(localization.version.whatsNew)

                \(instruction(for: action))
                """
            )
        ]
    }

    private func instruction(for action: MetadataAIAction) -> String {
        switch action {
        case .rewriteDescription:
            "Rewrite the description for clarity and App Store polish. Keep it accurate, natural, and under 4000 characters."
        case .suggestKeywords:
            "Suggest a comma-separated App Store keyword list. Keep the total UTF-8 length under 100 bytes."
        case .draftPromotionalText:
            "Draft promotional text under 170 characters. Make it clear, specific, and suitable for App Store Connect."
        case .draftWhatsNew:
            "Draft a clear What's New update under 700 characters. Keep it suitable for App Store Connect."
        case .reviewPolish:
            "Rewrite the selected localization as strict JSON that addresses validation and review guidance while preserving facts and URLs."
        }
    }

    private func applyGeneratedMetadataText(
        _ value: String,
        localeID: String,
        action: MetadataAIAction
    ) {
        guard let index = metadataDocument?.localizations.firstIndex(where: { $0.locale == localeID }) else {
            return
        }

        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch action {
        case .rewriteDescription:
            metadataDocument?.localizations[index].version.description = text
        case .suggestKeywords:
            metadataDocument?.localizations[index].version.keywords = normalizedKeywordList(text)
        case .draftPromotionalText:
            metadataDocument?.localizations[index].version.promotionalText = text
        case .draftWhatsNew:
            metadataDocument?.localizations[index].version.whatsNew = text
        case .reviewPolish:
            break
        }
        updateValidation()
    }

    private func normalizedKeywordList(_ value: String) -> String {
        MetadataKeywordNormalizer.normalized(value)
    }

    private func copyIfMissing(_ source: String, into target: inout String, didChange: inout Bool) {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        target = source
        didChange = true
    }

    private func upgradeHTTPURL(_ value: inout String) -> Bool {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.lowercased().hasPrefix("http://") else {
            return false
        }

        value = "https://\(trimmedValue.dropFirst(7))"
        return true
    }

    private func applyReviewFixProposal(_ proposal: ReviewFixProposal, to document: inout MetadataDocument) -> Bool {
        guard let index = document.localizations.firstIndex(where: { $0.locale == proposal.locale }) else {
            return false
        }

        switch proposal.field {
        case "appInfo.privacyPolicyUrl":
            guard document.localizations[index].appInfo.privacyPolicyURL == proposal.before else {
                return false
            }
            document.localizations[index].appInfo.privacyPolicyURL = proposal.after
        case "appInfo.privacyChoicesUrl":
            guard document.localizations[index].appInfo.privacyChoicesURL == proposal.before else {
                return false
            }
            document.localizations[index].appInfo.privacyChoicesURL = proposal.after
        case "version.marketingUrl":
            guard document.localizations[index].version.marketingURL == proposal.before else {
                return false
            }
            document.localizations[index].version.marketingURL = proposal.after
        case "version.supportUrl":
            guard document.localizations[index].version.supportURL == proposal.before else {
                return false
            }
            document.localizations[index].version.supportURL = proposal.after
        case "version.keywords":
            guard document.localizations[index].version.keywords == proposal.before else {
                return false
            }
            document.localizations[index].version.keywords = proposal.after
        default:
            return false
        }

        return true
    }

    private func translationPrompt(
        sourceLocalization: LocaleMetadata,
        targetLocaleID: String
    ) -> [LLMMessage] {
        [
            LLMMessage(
                role: "system",
                content: "You translate App Store metadata. Return strict JSON only, with no markdown, explanation, or surrounding prose."
            ),
            LLMMessage(
                role: "user",
                content: """
                Translate this App Store metadata from \(sourceLocalization.locale) to \(targetLocaleID).
                Preserve meaning, product facts, and URLs. Keep keyword output comma-separated and under 100 UTF-8 bytes.

                Return exactly this JSON shape:
                {
                  "appInfo": {
                    "name": "...",
                    "subtitle": "...",
                    "privacyPolicyURL": "...",
                    "privacyChoicesURL": "...",
                    "privacyPolicyText": "..."
                  },
                  "version": {
                    "description": "...",
                    "keywords": "...",
                    "marketingURL": "...",
                    "promotionalText": "...",
                    "supportURL": "...",
                    "whatsNew": "..."
                  }
                }

                Source metadata:
                \(encodedLocalization(sourceLocalization))
                """
            )
        ]
    }

    private func reviewPolishPrompt(
        appName: String,
        localization: LocaleMetadata,
        issues: [ValidationIssue]
    ) -> [LLMMessage] {
        [
            LLMMessage(
                role: "system",
                content: "You revise App Store metadata for review readiness. Return strict JSON only, with no markdown, explanation, or surrounding prose."
            ),
            LLMMessage(
                role: "user",
                content: """
                App: \(appName)
                Locale: \(localization.locale)

                Revise this localization to address the validation and App Review guidance below.
                Preserve product facts and all URLs unless a URL is invalid or insecure.
                Keep keyword output comma-separated and under 100 UTF-8 bytes.

                Return exactly this JSON shape:
                {
                  "appInfo": {
                    "name": "...",
                    "subtitle": "...",
                    "privacyPolicyURL": "...",
                    "privacyChoicesURL": "...",
                    "privacyPolicyText": "..."
                  },
                  "version": {
                    "description": "...",
                    "keywords": "...",
                    "marketingURL": "...",
                    "promotionalText": "...",
                    "supportURL": "...",
                    "whatsNew": "..."
                  }
                }

                Validation and review guidance:
                \(encodedValidationIssues(issues))

                Current metadata:
                \(encodedLocalization(localization))
                """
            )
        ]
    }

    private func encodedLocalization(_ localization: LocaleMetadata) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(localization),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return text
    }

    private func encodedValidationIssues(_ issues: [ValidationIssue]) -> String {
        guard !issues.isEmpty else {
            return "[]"
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(issues),
              let text = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return text
    }

    private func decodeTranslationResponse(_ response: String) throws -> MetadataTranslationResponse {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonText: String
        if let firstBrace = trimmed.firstIndex(of: "{"),
           let lastBrace = trimmed.lastIndex(of: "}"),
           firstBrace <= lastBrace {
            jsonText = String(trimmed[firstBrace...lastBrace])
        } else {
            jsonText = trimmed
        }

        guard let data = jsonText.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(MetadataTranslationResponse.self, from: data) else {
            throw LLMError.invalidStructuredResponse
        }

        return decoded
    }

    private func applyTranslation(_ response: MetadataTranslationResponse, targetLocaleID: String) {
        guard let index = metadataDocument?.localizations.firstIndex(where: { $0.locale == targetLocaleID }) else {
            return
        }

        metadataDocument?.localizations[index].appInfo = response.appInfo
        metadataDocument?.localizations[index].version = VersionMetadata(
            description: response.version.description,
            keywords: normalizedKeywordList(response.version.keywords),
            marketingURL: response.version.marketingURL,
            promotionalText: response.version.promotionalText,
            supportURL: response.version.supportURL,
            whatsNew: response.version.whatsNew
        )
        updateValidation()
    }

    private func runBusyTask(_ operation: () async throws -> Void) async {
        guard !isBusy else {
            return
        }

        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct LLMGenerationContext {
    var service: any LLMServicing
    var configuration: LLMProviderConfiguration
    var isDemoFixture: Bool

    var generatedVerb: String {
        isDemoFixture ? "Demo AI generated" : "Generated"
    }

    var polishedVerb: String {
        isDemoFixture ? "Demo AI polished" : "Polished"
    }

    var translatedVerb: String {
        isDemoFixture ? "Demo AI translated" : "Translated"
    }
}

private struct MetadataTranslationResponse: Decodable {
    var appInfo: AppInfoMetadata
    var version: VersionMetadata
}
