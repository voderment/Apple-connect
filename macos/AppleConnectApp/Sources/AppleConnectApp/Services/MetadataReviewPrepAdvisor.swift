import Foundation

enum MetadataReviewPrepAdvisor {
    static func summary(
        metadataLoaded: Bool,
        readinessItems: [ReleaseReadinessItem],
        checklistItems: [ReviewChecklistItem],
        fixProposals: [ReviewFixProposal],
        validationIssues: [ValidationIssue],
        plan: MetadataPlan
    ) -> ReviewPrepSummary {
        let blockerCount = readinessItems.filter { $0.level == .blocking }.count
            + checklistItems.filter { $0.level == .blocking }.count
            + validationIssues.filter { $0.severity == .error }.count
        let warningCount = readinessItems.filter { $0.level == .warning }.count
            + checklistItems.filter { $0.level == .warning }.count
            + validationIssues.filter { $0.severity == .warning }.count

        return ReviewPrepSummary(
            blockerCount: blockerCount,
            warningCount: warningCount,
            proposedFixCount: fixProposals.count,
            draftActionCount: plan.visibleActions.count,
            nextAction: nextAction(
                metadataLoaded: metadataLoaded,
                blockerCount: blockerCount,
                warningCount: warningCount,
                proposedFixCount: fixProposals.count,
                draftActionCount: plan.visibleActions.count
            )
        )
    }

    private static func nextAction(
        metadataLoaded: Bool,
        blockerCount: Int,
        warningCount: Int,
        proposedFixCount: Int,
        draftActionCount: Int
    ) -> ReviewPrepNextAction {
        guard metadataLoaded else {
            return ReviewPrepNextAction(
                kind: .selectVersion,
                title: "Select a version",
                detail: "Choose an app and App Store version before preparing a review handoff.",
                systemImage: "doc.text.magnifyingglass",
                level: .blocking
            )
        }

        if proposedFixCount > 0 {
            return ReviewPrepNextAction(
                kind: .reviewFixes,
                title: "Review proposed fixes",
                detail: "\(proposedFixCount) deterministic fixes can be applied after review.",
                systemImage: "checkmark.circle",
                level: .warning
            )
        }

        if blockerCount > 0 {
            return ReviewPrepNextAction(
                kind: .resolveBlockers,
                title: "Resolve blockers",
                detail: "\(blockerCount) blocking readiness signals need attention before save or handoff.",
                systemImage: "xmark.octagon",
                level: .blocking
            )
        }

        if warningCount > 0 {
            return ReviewPrepNextAction(
                kind: .reviewWarnings,
                title: "Review warnings",
                detail: "\(warningCount) warning signals should be checked before handoff.",
                systemImage: "exclamationmark.triangle",
                level: .warning
            )
        }

        if draftActionCount > 0 {
            return ReviewPrepNextAction(
                kind: .saveDraft,
                title: "Save or package draft",
                detail: "\(draftActionCount) draft actions are ready for save, report, or handoff.",
                systemImage: "tray.and.arrow.up",
                level: .warning
            )
        }

        return ReviewPrepNextAction(
            kind: .exportHandoff,
            title: "Ready for handoff",
            detail: "No blocking or warning signals are currently active.",
            systemImage: "checkmark.seal",
            level: .ready
        )
    }
}
