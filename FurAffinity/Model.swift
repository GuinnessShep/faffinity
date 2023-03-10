//
//  Model.swift
//  FurAffinity
//
//  Created by Ceylo on 21/11/2021.
//

import SwiftUI
import FAKit
import Combine

enum ModelError: Error {
    case disconnected
}

@MainActor
class Model: ObservableObject {
    static let autorefreshDelay: TimeInterval = 15 * 60
    
    @Published var session: FASession? {
        didSet {
            guard oldValue !== session else { return }
            if session != nil {
                assert(oldValue == nil, "Session set twice")
            }
            processNewSession()
        }
    }
    
    @Published
    /// nil until a fetch actually happened
    /// After a fetch it contains all found submissions, or an empty array if none was found
    private (set) var submissionPreviews: [FASubmissionPreview]?
    private (set) var lastSubmissionPreviewsFetchDate: Date?
    
    @Published
    /// nil until a fetch actually happened
    /// After a fetch it contains all found notes, or an empty array if none was found
    private (set) var notePreviews: [FANotePreview]?
    @Published
    private (set) var unreadNoteCount = 0
    private (set) var lastNotePreviewsFetchDate: Date?
    
    @Published
    private (set) var appInfo = AppInformation()
    private var lastAppInfoUpdate: Date?

    private var subscriptions = Set<AnyCancellable>()
    init(session: FASession? = nil) {
        self.session = session
        appInfo.objectWillChange.sink {
            self.objectWillChange.send()
        }
        .store(in: &subscriptions)
    }
    
    func fetchNewSubmissionPreviews() async -> Int {
        guard let session else {
            logger.error("Tried to fetch submissions with no active session, skipping")
            return 0
        }
        
        let latestSubmissions = await session.submissionPreviews()
        lastSubmissionPreviewsFetchDate = Date()
        let lastKnownSid = submissionPreviews?.first?.sid ?? 0
        // We take advantage of the fact that submission IDs are always increasing
        // to know which one are new.
        let newSubmissions = latestSubmissions.filter { $0.sid > lastKnownSid }
        
        if !newSubmissions.isEmpty {
            submissionPreviews = newSubmissions + (submissionPreviews ?? [])
        } else if submissionPreviews == nil {
            submissionPreviews = []
        }
        return newSubmissions.count
    }
    
    func nukeAllSubmissions() async {
        guard let session else {
            logger.error("Tried to nuke submissions with no active session, skipping")
            return
        }
        
        do {
            try await session.nukeSubmissions()
            lastSubmissionPreviewsFetchDate = Date()
            submissionPreviews = []
        } catch {
            logger.error("Failed nuking submissions: \(error, privacy: .public)")
        }
    }
    
    func fetchNewNotePreviews() async {
        guard let session else {
            logger.error("Tried to fetch notes with no active session, skipping")
            return
        }
        
        let fetchedNotes = await session.notePreviews()
        notePreviews = fetchedNotes
        unreadNoteCount = fetchedNotes.filter { $0.unread }.count
        lastNotePreviewsFetchDate = Date()
    }
    
    func toggleFavorite(for submission: FASubmission) async throws -> FASubmission? {
        guard let session else {
            throw ModelError.disconnected
        }
        
        let updated = await session.toggleFavorite(for: submission)
        if let updated {
            assert(updated.isFavorite != submission.isFavorite)
        }
        return updated
    }
    
    func updateAppInfoIfNeeded() {
        if let lastAppInfoUpdate {
            let secondsSinceLastRefresh = -lastAppInfoUpdate.timeIntervalSinceNow
            guard secondsSinceLastRefresh > Self.autorefreshDelay else { return }
        }
        
        appInfo.fetch()
        lastAppInfoUpdate = Date()
    }
    
    private func processNewSession() {
        guard session != nil else {
            lastSubmissionPreviewsFetchDate = nil
            submissionPreviews = nil
            lastNotePreviewsFetchDate = nil
            notePreviews = nil
            unreadNoteCount = 0
            return
        }
        
        Task {
            _ = await fetchNewSubmissionPreviews()
            await fetchNewNotePreviews()
            updateAppInfoIfNeeded()
        }
    }
}
