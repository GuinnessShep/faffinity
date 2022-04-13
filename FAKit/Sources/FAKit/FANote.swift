//
//  FANote.swift
//  
//
//  Created by Ceylo on 11/04/2022.
//

import Foundation
import FAPages

public struct FANote: Equatable {
    public let author: String
    public let displayAuthor: String
    public let title: String
    public let datetime: String
    public let htmlMessage: String
    
    public init(author: String, displayAuthor: String, title: String, datetime: String, htmlMessage: String) {
        self.author = author
        self.displayAuthor = displayAuthor
        self.title = title
        self.datetime = datetime
        self.htmlMessage = htmlMessage.selfContainedFAHtml
    }
}

public extension FANote {
    init(_ notePage: FANotePage) {
        self.init(author: notePage.author, displayAuthor: notePage.displayAuthor,
                  title: notePage.title, datetime: notePage.datetime, htmlMessage: notePage.htmlMessage)
    }
}
