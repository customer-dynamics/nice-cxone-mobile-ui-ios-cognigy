//
// Copyright (c) 2021-2026. NICE Ltd. All rights reserved.
//
// Licensed under the NICE License;
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    https://github.com/nice-devone/nice-cxone-mobile-ui-ios/blob/main/LICENSE
//
// TO THE EXTENT PERMITTED BY APPLICABLE LAW, THE CXONE MOBILE SDK IS PROVIDED ON
// AN "AS IS" BASIS. NICE HEREBY DISCLAIMS ALL WARRANTIES AND CONDITIONS, EXPRESS
// OR IMPLIED, INCLUDING (WITHOUT LIMITATION) WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, AND TITLE.
//

import SwiftUI

struct AttachmentLoadingView: View, Themed {

    // MARK: - Properties

    let width: CGFloat
    let height: CGFloat
    
    @EnvironmentObject var style: ChatStyle
    
    @Environment(\.colorScheme) var scheme
    
    // MARK: Builder

    var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: colors.content.primary))
            .frame(width: width, height: height)
    }
}

// MARK: - Previews

#Preview("Small") {
    AttachmentLoadingView(
        width: StyleGuide.Sizing.Attachment.smallDimension,
        height: StyleGuide.Sizing.Attachment.smallDimension
    )
    .environmentObject(ChatStyle())
}

#Preview("Regular") {
    AttachmentLoadingView(
        width: StyleGuide.Sizing.Attachment.regularDimension,
        height: StyleGuide.Sizing.Attachment.regularDimension
    )
    .environmentObject(ChatStyle())
}

#Preview("Large") {
    AttachmentLoadingView(
        width: StyleGuide.Sizing.Attachment.largeWidth,
        height: StyleGuide.Sizing.Attachment.largeHeight
    )
    .environmentObject(ChatStyle())
}
