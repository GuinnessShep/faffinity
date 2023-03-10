//
//  FASession.swift
//
//
//  Created by Ceylo on 24/10/2021.
//

import Foundation
import FAPages
import Cache

private extension Expiry {
    static func days(_ days: Int) -> Expiry {
        .seconds(TimeInterval(60 * 60 * 24 * days))
    }
}

open class FASession: Equatable {
    enum Error: String, Swift.Error {
        case requestFailure
    }
    
    public let username: String
    public let displayUsername: String
    let cookies: [HTTPCookie]
    let dataSource: HTTPDataSource
    
    public init(username: String, displayUsername: String, cookies: [HTTPCookie], dataSource: HTTPDataSource) {
        self.username = username
        self.displayUsername = displayUsername
        self.cookies = cookies
        self.dataSource = dataSource
        self.avatarUrlsCache = try! Storage(
            diskConfig: DiskConfig(name: "AvatarURLs"),
            memoryConfig: MemoryConfig(),
            transformer: TransformerFactory.forCodable(ofType: URL.self)
        )
    }
    
    public static func == (lhs: FASession, rhs: FASession) -> Bool {
        lhs.username == rhs.username
    }
    
    open func submissionPreviews() async -> [FASubmissionPreview] {
        guard let data = await dataSource.httpData(from: FASubmissionsPage.url, cookies: cookies),
              let page = await FASubmissionsPage(data: data)
        else { return [] }
        
        let previews = page.submissions
            .compactMap { $0 }
            .map { FASubmissionPreview($0) }
        logger.info("Got \(page.submissions.count) submission previews (\(previews.count) after filter)")
        return previews
    }
    
    open func submission(for preview: FASubmissionPreview) async -> FASubmission? {
        guard let data = await dataSource.httpData(from: preview.url, cookies: cookies),
              let page = FASubmissionPage(data: data)
        else { return nil }
        
        return FASubmission(page, url: preview.url)
    }
    
    open func nukeSubmissions() async throws {
        let url = URL(string: "https://www.furaffinity.net/msg/submissions/new@72/")!
        let params: [URLQueryItem] = [
            .init(name: "messagecenter-action", value: "nuke_notifications"),
        ]
        
        guard let data = await dataSource.httpData(from: url, cookies: cookies, method: .POST, parameters: params),
              await FASubmissionsPage(data: data) != nil else {
            throw Error.requestFailure
        }
    }
    
    open func toggleFavorite(for submission: FASubmission) async -> FASubmission? {
        guard let data = await dataSource.httpData(from: submission.favoriteUrl, cookies: cookies),
              let page = FASubmissionPage(data: data)
        else { return nil }
        
        return FASubmission(page, url: submission.url)
    }
    
    open func notePreviews() async -> [FANotePreview] {
        guard let data = await dataSource.httpData(from: FANotesPage.url, cookies: cookies),
              let page = await FANotesPage(data: data)
        else { return [] }
        
        let headers = page.noteHeaders
            .compactMap { $0 }
            .map { FANotePreview($0) }
        
        logger.info("Got \(page.noteHeaders.count) note previews (\(headers.count) after filter)")
        return headers
    }
    
    open func note(for preview: FANotePreview) async -> FANote? {
        guard let data = await dataSource.httpData(from: preview.noteUrl, cookies: cookies),
              let page = FANotePage(data: data)
        else { return nil }
        
        return FANote(page)
    }
    
    private let avatarUrlRequestsQueue = DispatchQueue(label: "FASession.AvatarRequests")
    private var avatarUrlTasks = [String: Task<URL?, Swift.Error>]()
    private let avatarUrlsCache: Storage<String, URL>
    open func avatarUrl(for user: String) async -> URL? {
        let task = avatarUrlRequestsQueue.sync { () -> Task<URL?, Swift.Error> in
            let previousTask = avatarUrlTasks[user]
            let newTask = Task { () -> URL? in
                _ = await previousTask?.result
                try avatarUrlsCache.removeExpiredObjects()
                
                if let url = try? avatarUrlsCache.object(forKey: user) {
                    return url
                }
                
                guard let userpageUrl = FAUserPage.url(for: user),
                      let data = await dataSource.httpData(from: userpageUrl, cookies: cookies),
                      let page = FAUserPage(data: data),
                      let avatarUrl = page.avatarUrl
                else { return nil }
                
                let validDays = (7..<14).randomElement()!
                let expiry = Expiry.days(validDays)
                try avatarUrlsCache.setObject(avatarUrl, forKey: user, expiry: expiry)
                logger.info("Cached url \(avatarUrl, privacy: .public) for user \(user, privacy: .public) for \(validDays) days")
                return avatarUrl
            }
            
            avatarUrlTasks[user] = newTask
            return newTask
            
        }
        
        return try? await task.result.get()
    }
}

extension FASession {
    /// Initialize a FASession from the given session cookies.
    /// - Parameter cookies: The cookies for furaffinity.net after the user is logged
    /// in through a usual web browser.
    public convenience init?(cookies: [HTTPCookie], dataSource: HTTPDataSource = URLSession.sharedForFARequests) async {
        guard cookies.map(\.name).contains("a"),
              let data = await dataSource.httpData(from: FAHomePage.url, cookies: cookies),
              let page = FAHomePage(data: data)
        else { return nil }
        
        guard let username = page.username,
              let displayUsername = page.displayUsername
        else {
            logger.error("\(#file, privacy: .public) - missing user")
            return nil
        }
        
        self.init(username: username,
                  displayUsername: displayUsername,
                  cookies: cookies,
                  dataSource: dataSource)
    }
}

