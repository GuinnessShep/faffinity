//
//  SubmissionCommentsView.swift
//  FurAffinity
//
//  Created by Ceylo on 23/10/2022.
//

import SwiftUI
import FAKit

extension FASubmission.Comment: Identifiable {
    public var id: Int { cid }
}

struct SubmissionCommentsView: View {
    var comments: [FASubmission.Comment]
    
    func commentViews(for comments: [FASubmission.Comment], indent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(comments) { comment in
                SubmissionCommentView(comment: comment)
                AnyView(commentViews(for: comment.answers, indent: true))
            }
        }
        .padding(.leading, indent ? 10 : 0)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            if !comments.isEmpty {
                Text("Comments:")
                    .font(.headline)
                commentViews(for: comments, indent: false)
            }
        }
    }
}

struct SubmissionCommentsView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            SubmissionCommentsView(comments: FASubmission.demo.comments)
                .padding()
        }
    }
}
