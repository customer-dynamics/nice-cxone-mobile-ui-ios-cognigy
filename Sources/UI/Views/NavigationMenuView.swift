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

struct NavigationMenuView: View {
    
    // MARK: - Properties

    let items: [MenuBuilder.Item]
    let colors: StyleColors
    
    // MARK: - Builder
    
    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            Menu {
                ForEach(items, id: \.name) { item in
                    Button(role: item.role, action: item.action) {
                        Text(item.name)
                        
                        item.icon
                    }
                    // Applies color on the icon, not on the text. The text color is done via NavigationBar appearance update
                    .tint(item.role == .destructive ? colors.status.error : colors.content.primary)
                }
            } label: {
                Asset.menu
            }
        }
    }
}

// MARK: - Methods

extension MenuBuilder {

    func build(colors: StyleColors) -> some View {
        NavigationMenuView(items: items, colors: colors)
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    @Previewable @Environment(\.colorScheme) var scheme
    let style = ChatStyle()
    let localization = ChatLocalization()

    let items = [
        MenuBuilder.Item(
            name: localization.chatMenuOptionUpdateName,
            icon: Asset.ChatThread.editThreadName
        ) {},
        MenuBuilder.Item(
            name: localization.alertEditPrechatCustomFieldsTitle,
            icon: Asset.ChatThread.editPrechatCustomFields
        ) {},
        MenuBuilder.Item(
            name: localization.chatMenuOptionSendTranscript,
            icon: Asset.sendTranscript
        ) {},
        MenuBuilder.Item(
            name: localization.chatMenuOptionEndConversation,
            icon: Asset.close,
            role: .destructive
        ) {}
    ]

    return NavigationView {
        VStack {
            Text("Background")
        }
        .onAppear {
            UINavigationBar.appearance(for: .light).chatAppearance(with: style.colors.light)
            UINavigationBar.appearance(for: .dark).chatAppearance(with: style.colors.dark)
        }
        .navigationTitle("Page")
        .navigationBarItems(trailing: NavigationMenuView(items: items, colors: style.colors(for: scheme)))
    }
}
