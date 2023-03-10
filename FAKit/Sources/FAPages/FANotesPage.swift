//
//  FANotesPage.swift
//  
//
//  Created by Ceylo on 07/04/2022.
//

import Foundation
import SwiftSoup

public struct FANotesPage: Equatable {
    public struct NoteHeader: Equatable {
        public let id: Int
        public let author: String
        public let displayAuthor: String
        public let title: String
        public let datetime: String
        public let naturalDatetime: String
        public let unread: Bool
        public let noteUrl: URL
    }
    
    public static let url = URL(string: "https://www.furaffinity.net/controls/switchbox/inbox/")!
    public let noteHeaders: [NoteHeader?]
}

extension FANotesPage {
    public init?(data: Data) async {
        let state = signposter.beginInterval("All Notes Preview Parsing")
        defer { signposter.endInterval("All Notes Preview Parsing", state) }
        
        do {
            let doc = try SwiftSoup.parse(String(decoding: data, as: UTF8.self))
            
            let notesContainerQuery = "body div#main-window div#site-content div.messagecenter-mail-container div.messagecenter-mail-content-pane div.messagecenter-mail-list form#pms-form div.messagecenter-mail-list-pane div#notes-list div.message-center-pms-note-list-view"
            
            let notesQuery = notesContainerQuery + " div.note-list-container"
            let noteNodes = try doc.select(notesQuery)
            
            self.noteHeaders = try await withThrowingTaskGroup(of: (Int, NoteHeader).self) { group in
                for (offset, node) in noteNodes.enumerated() {
                    group.addTask {
                        (offset, try NoteHeader(node))
                    }
                }
                
                return try await group
                    .reduce(into: [NoteHeader?](repeating: nil, count: noteNodes.count),
                            { $0[$1.0] = $1.1})
                as! [NoteHeader]
            }
        } catch {
            logger.error("Decoding failure in \(#file, privacy: .public): \(error, privacy: .public)")
            return nil
        }
            
    }
}

extension FANotesPage.NoteHeader {
    init(_ node: SwiftSoup.Element) throws {
        let state = signposter.beginInterval("Note Preview Parsing")
        defer { signposter.endInterval("Note Preview Parsing", state) }
        
        let baseQuery = "div.note-list-subjectgroup div.note-list-subject-container a.notelink"
        let baseNode = try node.select(baseQuery)
        let unread = baseNode.hasClass("note-unread")
        let noteUrlStr = try baseNode.attr("href")
        guard let noteUrl = URL(string: FAHomePage.url.absoluteString + noteUrlStr) else { throw FAPagesError.parserFailureError() }
        
        let idStr = try node.select("div.note-list-selectgroup div.note-list-checkbox-desktop input").attr("value")
        guard let id = Int(idStr) else { throw FAPagesError.parserFailureError() }
        let noteTitle = try baseNode.select("div.note-list-subject").text()
        
        let authorQuery = "div.note-list-sendgroup div.note-list-sender-container div.note-list-sender div a"
        let authorNode = try node.select(authorQuery)
        guard let author = try authorNode.attr("href")
            .substring(matching: "/user/(.+)/")
        else { throw FAPagesError.parserFailureError() }
        let displayAuthor = try authorNode.text()
        
        let datetimeNode = try node.select("div.note-list-sendgroup div.note-list-senddate span.popup_date")
        let datetime = try datetimeNode.attr("title")
        let naturalDatetime = try datetimeNode.text()
        
        self.init(id: id, author: author, displayAuthor: displayAuthor, title: noteTitle, datetime: datetime, naturalDatetime: naturalDatetime, unread: unread, noteUrl: noteUrl)
    }
}
