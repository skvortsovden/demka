import SwiftUI

struct CardView: View {
    let node: Node
    @EnvironmentObject var vm: DeckViewModel

    private var isActive: Bool {
        guard vm.activeIndex < vm.nodes.count else { return false }
        return vm.nodes[vm.activeIndex].id == node.id
    }
    private var isVisited: Bool { vm.visitedIds.contains(node.id) }
    private var nodeIndex: Int {
        vm.nodes.firstIndex(where: { $0.id == node.id }) ?? 0
    }
    private var isFollowing: Bool {
        vm.isPresenting && nodeIndex > vm.activeIndex
    }

    private var borderColor: Color {
        guard vm.cardsVisible else { return .clear }
        guard vm.isPresenting else { return vm.theme.line }
        if isActive  { return vm.theme.active }
        if isVisited { return vm.theme.visited }
        return vm.theme.line
    }
    private var bgColor: Color {
        guard vm.cardsVisible else { return .clear }
        guard vm.isPresenting else { return vm.theme.surface }
        if isActive  { return vm.theme.surface }
        if isVisited { return vm.theme.bg }
        return vm.theme.surface
    }
    private var borderWidth: CGFloat {
        vm.isPresenting && isActive ? 1.5 : 1.0
    }
    private var isLandscape: Bool {
        vm.viewportSize.width > vm.viewportSize.height
    }
    // True when the zoom-reveal highlight is active on this card.
    private var zoomDimActive: Bool {
        vm.zoomEnabled && vm.zoomRevealActive && vm.isPresenting && isActive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleText
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            if !node.lede.isEmpty || !node.bullets.isEmpty {
                bodyContent
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
        }
        // Measure natural content height before any frame constraint.
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: CardHeightKey.self,
                    value: [node.id: geo.size.height]
                )
            }
        )
        // In landscape: fixed height fills most of screen; clip overflow.
        // In portrait:  no height constraint; card grows to content.
        .frame(width: node.w,
               height: isLandscape ? node.h : nil,
               alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(bgColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .scaleEffect(vm.isPresenting && isActive ? 1.02 : 1.0, anchor: .center)
        .animation(.easeInOut(duration: 0.18), value: isActive)
        .onTapGesture { vm.activateNode(node) }
        .allowsHitTesting(!vm.isPresenting)
    }

    @ViewBuilder
    private var titleText: some View {
        let ink = (vm.isPresenting && isVisited) ? vm.theme.ink2 : vm.theme.ink
        switch node.level {
        case 1:
            Text(node.title)
                .font(.system(size: vm.fontSize.h1, weight: .black))
                .foregroundColor(ink)
                .fixedSize(horizontal: false, vertical: true)
        case 2:
            Text(node.title)
                .font(.system(size: vm.fontSize.h2, weight: .bold))
                .foregroundColor(ink)
                .fixedSize(horizontal: false, vertical: true)
        default:
            Text(node.title)
                .font(.system(size: vm.fontSize.h3, weight: .semibold))
                .foregroundColor(ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !node.lede.isEmpty {
                let ledeVisible: Bool = {
                    if !vm.isPresenting { return true }
                    if isFollowing      { return false }
                    return !isActive || bulletsShownCount > 0
                }()
                // Dim when zoom-reveal is active and lede is not the current focus.
                let ledeIsCurrent = bulletsShownCount == 1
                let ledeOpacity: Double = {
                    if !ledeVisible           { return 0 }
                    if zoomDimActive && !ledeIsCurrent { return 0.35 }
                    return 1
                }()
                Text(node.lede)
                    .font(.system(size: vm.fontSize.lede))
                    .foregroundColor(vm.theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(ledeOpacity)
                    .animation(.easeOut(duration: 0.18), value: bulletsShownCount)
                    .animation(.easeOut(duration: 0.18), value: vm.zoomRevealActive)
            }

            ForEach(Array(node.bullets.prefix(LayoutEngine.maxBullets).enumerated()), id: \.element.id) { idx, bullet in
                let bulletOffset = node.lede.isEmpty ? 0 : 1
                let bulletVisible: Bool = {
                    if !vm.isPresenting { return true }
                    if isFollowing      { return false }
                    return !isActive || bulletsShownCount > idx + bulletOffset
                }()
                // Current element = the one whose reveal step equals bulletsShownCount.
                let isCurrent = bulletsShownCount == idx + bulletOffset + 1
                let rowOpacity: Double = {
                    if !bulletVisible { return (isActive || isFollowing) ? 0 : 1 }
                    if zoomDimActive && !isCurrent { return 0.35 }
                    return 1
                }()
                HStack(alignment: .top, spacing: 8) {
                    if let num = bullet.num {
                        Text("\(num).")
                            .font(.system(size: vm.fontSize.bulletNum, weight: .semibold, design: .monospaced))
                            .foregroundColor(vm.theme.ink2)
                            .frame(minWidth: 18, alignment: .leading)
                    } else {
                        Rectangle()
                            .fill(vm.theme.ink2)
                            .frame(width: 8, height: 1.5)
                            .padding(.top, 8)
                    }
                    Text(bullet.text)
                        .font(.system(size: vm.fontSize.bullet))
                        .foregroundColor(bulletVisible ? vm.theme.ink : vm.theme.mute)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(rowOpacity)
                .animation(.easeOut(duration: 0.18), value: bulletsShownCount)
                .animation(.easeOut(duration: 0.18), value: vm.zoomRevealActive)
            }
        }
    }

    private var bulletsShownCount: Int {
        if !vm.isPresenting    { return Int.max }
        if isFollowing         { return 0 }
        if !vm.revealEnabled   { return Int.max }
        if isActive            { return vm.bulletsShown }
        return Int.max
    }
}

// MARK: - Export card (used by PDF renderer — no environment, all state passed in)

struct CardExportView: View {
    let node: Node
    let theme: Theme

    var body: some View {
        ZStack(alignment: .topLeading) {
            theme.bg
            VStack(alignment: .leading, spacing: 0) {
                titleText
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 60)
                    .padding(.top, 56)
                    .padding(.bottom, 24)

                if !node.lede.isEmpty || !node.bullets.isEmpty {
                    bodyContent
                        .padding(.horizontal, 60)
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var titleText: some View {
        switch node.level {
        case 1:
            Text(node.title)
                .font(.system(size: 52, weight: .black))
                .foregroundColor(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        case 2:
            Text(node.title)
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        default:
            Text(node.title)
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !node.lede.isEmpty {
                Text(node.lede)
                    .font(.system(size: 24))
                    .foregroundColor(theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(node.bullets) { bullet in
                HStack(alignment: .top, spacing: 16) {
                    if let num = bullet.num {
                        Text("\(num).")
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundColor(theme.ink2)
                            .frame(minWidth: 28, alignment: .leading)
                    } else {
                        Rectangle()
                            .fill(theme.ink2)
                            .frame(width: 12, height: 2.5)
                            .padding(.top, 16)
                    }
                    Text(bullet.text)
                        .font(.system(size: 22))
                        .foregroundColor(theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
