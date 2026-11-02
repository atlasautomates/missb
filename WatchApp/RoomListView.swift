import SwiftUI
import AuditModel

struct RoomListView: View {
    @Environment(FloorSession.self) private var session
    @Environment(GlanceFocus.self) private var glance
    @Environment(LookTryOn.self) private var looks
    let side: Side
    /// Set by the path owner when a room's flow pops back here; consumed to
    /// snap the list onto the next incomplete room.
    @Binding var closedRoom: String?
    let onSelect: (String) -> Void

    /// Where the magnetized list currently sits. Written by the snap-to-next
    /// logic; also tracks the nurse's own scrolling via the binding.
    @State private var scrolledRoom: String?
    @State private var confirmSend = false
    @State private var confirmRest = false
    @State private var confirmClear = false
    @State private var editingCensus = false
    @State private var sending = false
    @State private var sendNote: String?
    /// Warm look only. The room number holds for a beat when that room finishes.
    @State private var celebrate: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: looks.current == .warm ? 6 : 0) {
                censusButton
                ForEach(side.rooms, id: \.self) { room in
                    Button {
                        LightHaptic.play()
                        glance.side = side
                        glance.room = room
                        onSelect(room)
                    } label: {
                        roomRow(room)
                    }
                    .buttonStyle(.plain)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: looks.current == .warm ? 58 : 52,
                        maxHeight: looks.current == .warm ? 64 : 52
                    )
                    .accessibilityIdentifier("room.\(room)")
                }
                restUnoccupiedButton
                sendButton
                clearButton
            }
            .scrollTargetLayout()
        }
        .modifier(RoomSnapModifier())
        .scrollPosition(id: $scrolledRoom, anchor: .top)
        .onChange(of: closedRoom) { _, _ in snapPastCompletedRoom() }
        .onAppear { noteGlance() }
        .onChange(of: scrolledRoom) { _, _ in noteGlance() }
        .confirmationDialog(
            "Mark the remaining rooms unoccupied?",
            isPresented: $confirmRest,
            titleVisibility: .visible
        ) {
            Button("Mark unoccupied") {
                LightHaptic.play()
                session.markRemainingUnoccupied(side: side)
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Clear every room on \(side.title)?",
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button("Clear everything", role: .destructive) {
                LightHaptic.play()
                session.clearCharting(side: side)
                sendNote = nil
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Send \(side.title) to the sheet?",
            isPresented: $confirmSend,
            titleVisibility: .visible
        ) {
            Button("Send") {
                LightHaptic.play()
                Task { await sendSheet() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .navigationTitle(side.title)
        .navigationBarTitleDisplayMode(.inline)
        .lookCanvas()
        .overlay {
            if let celebrate {
                RoomDoneFlash(room: celebrate)
            }
        }
        .navigationDestination(isPresented: $editingCensus) {
            CensusEditView(side: side, starting: session.sheet(for: side)?.startingCensus ?? 0)
        }
        .toolbar {
            // Ticket 014: compact strip between the back button and the
            // system top-right (time above, side title below). Profile icon
            // plus census countdown — no date here, the clock owns that corner.
            // Trailing, not leading: a leading toolbar item displaces the
            // system back button on watchOS. Trailing keeps the back button
            // and the system shifts the clock + side title left, so the strip
            // sits in the top bar without colliding with either.
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    LightHaptic.play()
                    editingCensus = true
                } label: {
                    CensusCountdownBar(
                        profileIcon: session.nurse?.icon,
                        countdown: session.sheet(for: side)?.censusCountdown
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("census.edit")
            }
        }
    }

    /// Depth-first reinforcement: when the room the nurse just left is now
    /// complete, magnetize the list onto the next incomplete room (wrapping
    /// past the end). A room left incomplete (backed out early) stays put.
    private func noteGlance() {
        glance.side = side
        glance.room = scrolledRoom ?? side.rooms.first
    }

    private func snapPastCompletedRoom() {
        guard let room = closedRoom else { return }
        closedRoom = nil
        guard let sheet = session.sheet(for: side), sheet.isRoomComplete(room) else { return }
        let next = sheet.nextIncompleteRoom(after: room)
        if looks.current == .warm {
            celebrate = room
            LightHaptic.success()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(.spring(duration: 0.35)) {
                    celebrate = nil
                    if let next { scrolledRoom = next }
                }
            }
        } else if let next {
            withAnimation { scrolledRoom = next }
        }
    }

    /// First room that still needs charting. Clinical marks that row and no other.
    private var nextRoom: String? {
        guard let sheet = session.sheet(for: side) else { return side.rooms.first }
        return side.rooms.first { !sheet.isRoomComplete($0) }
    }

    /// Stated census for this side. The corner digit is what remains of it.
    private var censusButton: some View {
        let stated = session.sheet(for: side)?.startingCensus
        return Button {
            LightHaptic.play()
            editingCensus = true
        } label: {
            HStack {
                Text("Census")
                    .font(.body)
                Spacer(minLength: 4)
                Text(stated.map(String.init) ?? "—")
                    .font(.title3)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(stated == nil)
        .accessibilityIdentifier("census.row")
    }

    /// Rooms whose occupancy is still unanswered. Occupied rooms stay, even
    /// when the rest of that room is unfinished.
    private var restUnoccupiedButton: some View {
        let waiting = session.sheet(for: side)?.roomsAwaitingOccupancy.count ?? 0
        return Button {
            LightHaptic.play()
            confirmRest = true
        } label: {
            Text("The rest are unoccupied")
                .multilineTextAlignment(.center)
                .foregroundStyle(looks.current == .clinical ? LookPalette.teal : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    if looks.current == .warm {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(LookPalette.coral, lineWidth: 1.5)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(waiting == 0)
        .accessibilityIdentifier("rooms.restUnoccupied")
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    /// Scrolls with the rooms so it stays reachable on the watch. Partial
    /// sheets send too: gaps land red in the tab, the app does not fill them.
    private var sendButton: some View {
        VStack(spacing: 2) {
            Button {
                LightHaptic.play()
                confirmSend = true
            } label: {
                Text(sending ? "Sending…" : "Send sheet")
                    .foregroundStyle(looks.current == .clinical ? LookPalette.teal : Color.white)
                    .frame(maxWidth: .infinity, minHeight: looks.current == .warm ? 48 : 40)
                    .background {
                        if looks.current == .warm {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(LookPalette.coral)
                        }
                    }
            }
            .buttonStyle(.plain)
            .disabled(sending || session.sheet(for: side) == nil)
            .accessibilityIdentifier("sheet.send")
            if let sendNote {
                Text(sendNote)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("sheet.send.note")
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    /// Last control on the list. Drops every room to incomplete. The header
    /// stays, so the nurse does not re-enter census to chart again.
    private var clearButton: some View {
        Button {
            LightHaptic.play()
            confirmClear = true
        } label: {
            Text("Clear everything")
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .disabled(!(session.sheet(for: side)?.hasCharting ?? false))
        .accessibilityIdentifier("rooms.clear")
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }

    private func sendSheet() async {
        guard let sheet = session.sheet(for: side) else { return }
        sending = true
        defer { sending = false }
        switch await SheetSender.send(sheet) {
        case .sent:
            sendNote = "Sent"
        case .unauthorized:
            sendNote = "Sheet rejected the send"
        case .unconfigured:
            sendNote = "Send is not set up on this watch"
        case .failed:
            sendNote = "Could not reach the sheet"
        }
    }

    @ViewBuilder
    private func roomRow(_ room: String) -> some View {
        let complete = session.sheet(for: side)?.isRoomComplete(room) ?? false
        if looks.current == .warm {
            warmRow(room, complete: complete)
        } else {
            clinicalRow(room, complete: complete, isNext: room == nextRoom)
        }
    }

    private func clinicalRow(_ room: String, complete: Bool, isNext: Bool) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(isNext ? LookPalette.teal : Color.clear)
                .frame(width: 3, height: 28)
            Text(room)
                .font(.system(.title2, design: .rounded).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(complete ? Color.secondary : Color.primary)
            Spacer(minLength: 4)
            Text(isNext ? "next" : (complete ? "done" : ""))
                .font(.caption2)
                .foregroundStyle(isNext ? LookPalette.teal : Color.secondary)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(isNext ? LookPalette.teal.opacity(0.14) : Color.white.opacity(0.04))
    }

    private func warmRow(_ room: String, complete: Bool) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(complete ? LookPalette.leaf.opacity(0.35) : LookPalette.honey.opacity(0.28))
                    .frame(width: 34, height: 34)
                Image(systemName: complete ? "checkmark" : "bed.double.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(complete ? LookPalette.leaf : LookPalette.honey)
            }
            Text(room)
                .font(.headline.weight(.semibold))
                .monospacedDigit()
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .padding(.horizontal, 4)
    }
}

/// Warm look. Holds the finished room number, then the list moves on.
private struct RoomDoneFlash: View {
    let room: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.82)
            VStack(spacing: 2) {
                Text(room)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(LookPalette.cream)
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(LookPalette.honey)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// Active profile icon + patients left to chart. Starts at the stated census,
/// drops per completed occupied room (AuditSheet.censusCountdown), glows green
/// at zero. Overshoot keeps counting signed — a negative amber number — so a
/// census mismatch stays visible instead of clamping at zero.
private struct CensusCountdownBar: View {
    @Environment(LookTryOn.self) private var looks
    let profileIcon: String?
    let countdown: Int?

    var body: some View {
        HStack(spacing: 4) {
            if let profileIcon {
                Text(profileIcon)
                    .font(.caption2)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.gray.opacity(0.35)))
            }
            if let countdown {
                Text("\(countdown)")
                    .font(.system(.footnote, design: .rounded).bold())
                    .monospacedDigit()
                    .foregroundStyle(color(for: countdown))
                    // The celebratory glow is a blurred halo *behind* the
                    // digit: a .shadow on a toolbar item made watchOS drop
                    // the glyph entirely (observed on the 26.x simulator).
                    .background {
                        if countdown == 0 {
                            Circle()
                                .fill(Color.green.opacity(0.55))
                                .blur(radius: 5)
                                .padding(-5)
                        }
                    }
                    .accessibilityIdentifier("census.countdown")
            }
        }
    }

    private func color(for countdown: Int) -> Color {
        if countdown == 0 { return looks.current == .warm ? LookPalette.leaf : LookPalette.teal }
        if countdown < 0 { return looks.current == .warm ? LookPalette.honey : .orange }
        return .primary
    }
}

/// Room-by-room detent. A free flick would coast between rows; alwaysByOne
/// lands on the next room, which is the scroll-wheel snap the brief asked for.
private struct RoomSnapModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(watchOS 26.0, *) {
            content.scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne, anchor: .top))
        } else if #available(watchOS 11.0, *) {
            content.scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
        } else {
            content.scrollTargetBehavior(.viewAligned)
        }
    }
}
