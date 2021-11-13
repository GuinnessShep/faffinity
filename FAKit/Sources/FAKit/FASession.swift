//
//  FASession.swift
//
//
//  Created by Ceylo on 24/10/2021.
//

import Foundation
import FAPages

public struct FASession: Equatable {
    public let username: String
    public let displayUsername: String
    private let cookies: [HTTPCookie]
    
    /// Initialize a FASession from the given session cookies.
    /// - Parameter cookies: The cookies for furaffinity.net after the user is logged
    /// in through a usual web browser.
    public init?(cookies: [HTTPCookie], dataSource: HTTPDataSource = URLSession.shared) async {
        guard cookies.map(\.name).contains("a"),
              let data = await dataSource.httpData(from: FAHomePage.url, cookies: cookies),
              let page = FAHomePage(data: data)
        else { return nil }
        
        guard let username = page.username,
              let displayUsername = page.displayUsername
        else { return nil }
        
        self.username = username
        self.displayUsername = displayUsername
        self.cookies = cookies
    }
}
