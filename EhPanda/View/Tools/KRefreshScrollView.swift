//
//  KRefreshScrollView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/14.
//  Copied from https://kavsoft.dev/SwiftUI_2.0/Pull_To_Refresh/
//

import SwiftUI

struct KRefreshScrollView<Content: View>: View {
    @State private var refresh = Refresh(
        started: false, released: false
    )

    private var content: Content
    private var onUpdate : () -> Void
    private var progressTint: Color
    private var arrowTint: Color

    init(
        progressTint: Color,
        arrowTint: Color,
        onUpdate: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.onUpdate = onUpdate
        self.progressTint = progressTint
        self.arrowTint = arrowTint
    }

    var body: some View{
        ScrollView(.vertical, showsIndicators: true) {

            // geometry reader for calculating postion....

            GeometryReader { reader -> AnyView in

                DispatchQueue.main.async {

                    if refresh.startOffset == 0 {
                        refresh.startOffset = reader.frame(in: .global).minY
                    }

                    refresh.offset = reader.frame(in: .global).minY

                    if refresh.offset - refresh.startOffset > 140 && !refresh.started {
                        refresh.started = true
                    }

                    // checking if refresh is started and drag is released....

                    if refresh.startOffset == refresh.offset
                        && refresh.started
                        && !refresh.released
                    {
                        withAnimation(Animation.linear) { refresh.released = true }
                        fireUpdate()
                    }

                    // checking if invalid becomes valid....

                    if refresh.startOffset == refresh.offset
                        && refresh.started
                        && refresh.released
                        && refresh.invalid
                    {
                        refresh.invalid = false
                        fireUpdate()
                    }
                }

                return AnyView(Color.black.frame(width: 0, height: 0))
            }
            .frame(width: 0, height: 0)

            ZStack(alignment: Alignment(horizontal: .center, vertical: .top)) {

                // Arrow And Indicator....

                Image(systemName: "arrow.down")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(arrowTint)
                    .rotationEffect(.init(degrees: refresh.degree))
                    .offset(y: -110)
                    .animation(.easeIn, value: 0.2)
                    .opacity(refresh.degree > 0 ? 1 : 0)

                LazyVStack {
                    content
                }
                .padding(.top, 15)
                .frame(maxWidth: .infinity)
            }
            .offset(y: -10)
            .onChange(of: refresh.degree) { (value) in
                if value == 180 {
                    impactFeedback(style: .medium)
                }
            }
        }
    }

    private func fireUpdate() {
        DispatchQueue.main.async {
            withAnimation(Animation.linear) {
                if refresh.startOffset == refresh.offset {
                    onUpdate()
                    refresh.released = false
                    refresh.started = false
                } else {
                    refresh.invalid = true
                }
            }
        }
    }
}

private struct Refresh {
    var startOffset: CGFloat = 0
    var offset: CGFloat = 0
    var degree: Double {
        rotationDegree()
    }
    var started: Bool
    var released: Bool
    var invalid: Bool = false
}

private extension Refresh {
    func rotationDegree() -> Double {
        let degree = offset - startOffset - 100
        if degree >= 0 && degree <= 40 {
            return Double(degree * 180 / 40)
        } else if degree > 40 {
            return 180
        } else {
            return 0
        }
    }
}
