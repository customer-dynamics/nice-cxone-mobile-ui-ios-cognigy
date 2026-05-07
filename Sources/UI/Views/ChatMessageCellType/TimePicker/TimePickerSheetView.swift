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

struct TimePickerSheetView: View, Themed {

    // MARK: - Constants
    
    private enum Constants {
        
        enum Padding {
            static let contentTop: CGFloat = 48
            static let contentHorizontal: CGFloat = 16
            static let gridBottom: CGFloat = 16
            static let controlButtonsTop: CGFloat = 10
            static let controlButtonsBottom: CGFloat = 26
        }
        
        enum Spacing {
            static let bodyVertical: CGFloat = 0
            static let contentVertical: CGFloat = 24
            static let headerVertical: CGFloat = 4
            static let gridItemSpacing: CGFloat = 8
            static let gridSectionVertical: CGFloat = 8
            static let gridContentVertical: CGFloat = 8
            static let controlButtonsHorizontal: CGFloat = 0
        }
    }
    
    // MARK: - Properties
    
    @EnvironmentObject private var localization: ChatLocalization
    @EnvironmentObject var style: ChatStyle
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var scheme
    
    @State private var selectedOption: RichMessageTimeSlot?
    
    let item: TimePickerItem
    let onFinished: (RichMessageTimeSlot) -> Void
    
    private let calendar = Calendar.current
    
    private static let gridConfig = [
        GridItem(
            .adaptive(minimum: TimePickerSlotView.Constants.Sizing.minWidth, maximum: TimePickerSlotView.Constants.Sizing.maxWidth),
            spacing: Constants.Spacing.gridItemSpacing
        )
    ]
    
    // MARK: - Init
    
    init(item: TimePickerItem, onFinished: @escaping (RichMessageTimeSlot) -> Void) {
        self.item = item
        self.onFinished = onFinished
    }
    
    // MARK: - Builder
    
    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.bodyVertical) {
            content
            
            Spacer()
            
            ColoredDivider(colors.border.default)
            
            controlButtons
        }
        .background(colors.background.default)
    }
}

// MARK: - Subviews

private extension TimePickerSheetView {
    
    var content: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.contentVertical) {
            header
            
            ColoredDivider(colors.border.default)
            
            listOptions
                .padding(.horizontal, Constants.Padding.contentHorizontal)
        }
        .padding(.top, Constants.Padding.contentTop)
    }
    
    var header: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.headerVertical) {
            Text(item.sheetTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(colors.content.primary)
            
            Text(localization.formTimePickerSubtitle)
                .font(.footnote)
                .foregroundStyle(colors.content.secondary)
        }
        .padding(.horizontal, Constants.Padding.contentHorizontal)
    }
    
    var listOptions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.Spacing.gridSectionVertical) {
                let grouped = Dictionary(grouping: item.timeSlots) { slot in
                    calendar.startOfDay(for: slot.startTime)
                }
                
                ForEach(grouped.keys.sorted(), id: \.self) { day in
                    let formattedDay = day.formatted(date: .long, time: .omitted)
                    
                    VStack(alignment: .leading, spacing: Constants.Spacing.gridContentVertical) {
                        Text(formattedDay)
                            .font(.callout.weight(.bold))
                            .foregroundStyle(colors.content.primary)
                        
                        LazyVGrid(columns: Self.gridConfig, alignment: .leading, spacing: Constants.Spacing.gridItemSpacing) {
                            let data = grouped[day]?.sorted {
                                ($0.startTime, $0.durationInMinutes) < ($1.startTime, $1.durationInMinutes)
                            }
                            
                            ForEach(data ?? [], id: \.self) { timeSlot in
                                TimePickerSlotView(selectedEntity: $selectedOption, entity: timeSlot)
                            }
                        }
                        .padding(.bottom, Constants.Padding.gridBottom)
                    }
                }
            }
        }
    }
    
    var controlButtons: some View {
        HStack(spacing: Constants.Spacing.controlButtonsHorizontal) {
            Button(localization.commonCancel, action: dismiss.callAsFunction)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(colors.brand.primary)
            
            Spacer()
            
            Button(localization.commonConfirm) {
                guard let selectedOption else {
                    LogManager.error(.failed("Unable to get selected option"))
                    return
                }
                
                onFinished(selectedOption)
            }
            .disabled(selectedOption == nil)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(selectedOption == nil ? colors.content.tertiary : colors.brand.primary)
        }
        .padding(.top, Constants.Padding.controlButtonsTop)
        .padding(.bottom, Constants.Padding.controlButtonsBottom)
        .padding(.horizontal, Constants.Padding.contentHorizontal)
        .background(colors.background.default)
    }
}

// MARK: - Previews

@available(iOS 17.0, *)
#Preview {
    @Previewable @State var selectedOption: RichMessageTimeSlot?
    @Previewable @State var isSheetVisible = true
    
    VStack {
        Text("Selected option:")
            .font(.headline)
        
        Button {
            isSheetVisible = true
        } label: {
            if let selectedOption {
                Text(String(format: "%@ %d min", selectedOption.startTime.formatted(), selectedOption.durationInMinutes))
            } else {
                Text("No option selected")
            }
        }
    }
    .sheet(isPresented: $isSheetVisible) {
        TimePickerSheetView(item: MockData.timePickerItem) { option in
            selectedOption = option
            isSheetVisible = false
        }
    }
    .environmentObject(ChatStyle())
    .environmentObject(ChatLocalization())
}
