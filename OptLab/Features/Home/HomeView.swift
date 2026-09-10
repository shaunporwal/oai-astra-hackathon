import SwiftUI

struct HomeView: View {
    @Environment(SessionStore.self) private var store
    @Binding var path: [Route]

    var body: some View {
        ZStack {
            AmbientBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    hero
                    if let next = store.nextSession {
                        NextSessionCard(session: next) {
                            path.append(.session(next.id))
                        }
                    } else {
                        allDoneCard
                    }
                    upcoming
                    completed
                    ConceptFooter()
                }
                .screenPadding()
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            Text("Eye imaging")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Colors.ink)
            Spacer()
            Menu {
                Button("Reset demo data", role: .destructive) { store.resetForDemo() }
            } label: {
                Image(systemName: "person.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.Colors.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.7)))
            }
            .accessibilityLabel("Account")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ready for your\nnext capture.")
                .font(Theme.Typography.display(42))
                .foregroundStyle(Theme.Colors.ink)
                .lineSpacing(-2)
            Text("Guided anterior segment imaging.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.inkSecondary)
        }
        .padding(.top, 48)
        .padding(.bottom, 24)
    }

    private var allDoneCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ALL SESSIONS COMPLETE")
                .font(Theme.Typography.overline)
                .foregroundStyle(Theme.Colors.inkSecondary)
                .kerning(1)
            Text("Nothing is due.")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    @ViewBuilder
    private var upcoming: some View {
        let others = store.sessions
            .filter { $0.status != .complete && $0.id != store.nextSession?.id }
            .sorted { $0.dueDate < $1.dueDate }
        if !others.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("UPCOMING")
                    .font(Theme.Typography.overline)
                    .foregroundStyle(Theme.Colors.inkSecondary)
                    .kerning(1)
                ForEach(others) { session in
                    SessionRow(session: session) { path.append(.session(session.id)) }
                }
            }
        }
    }

    @ViewBuilder
    private var completed: some View {
        let done = store.completedSessions
        if !done.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("COMPLETED")
                    .font(Theme.Typography.overline)
                    .foregroundStyle(Theme.Colors.inkSecondary)
                    .kerning(1)
                ForEach(done) { session in
                    SessionRow(session: session) { path.append(.complete(session.id)) }
                }
            }
        }
    }
}

private struct NextSessionCard: View {
    let session: StudySession
    let open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("NEXT SESSION")
                    .font(Theme.Typography.overline)
                    .foregroundStyle(Theme.Colors.inkSecondary)
                    .kerning(1)
                Spacer()
                Chip(text: dueLabel, tone: session.isDueToday ? .warning : .info)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(session.participant.displayName)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.ink)
                Text("\(session.visitLabel) · \(session.imagingProtocol.name)")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }
            Divider().overlay(Theme.Colors.divider)
            HStack(spacing: 14) {
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "eye")
                        Image(systemName: "eye")
                    }
                    .font(.system(size: 13))
                    Text(eyesLabel)
                }
                Rectangle().fill(Theme.Colors.divider).frame(width: 1, height: 18)
                HStack(spacing: 8) {
                    Image(systemName: "doc.text").font(.system(size: 13))
                    Text("Protocol assigned")
                }
            }
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Colors.inkSecondary)
            Button(action: open) {
                HStack(spacing: 8) {
                    Text(session.status == .inProgress ? "Resume session" : "Open session")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 4)
        }
        .glassCard()
    }

    private var dueLabel: String {
        if session.isDueToday { return "Due today" }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: session.dueDate)).day ?? 0
        if days == 1 { return "Due tomorrow" }
        if days < 0 { return "Overdue" }
        return "Due in \(days) days"
    }

    private var eyesLabel: String {
        let eyes = session.imagingProtocol.eyes
        if eyes.count == 2 { return "Right + left eye" }
        return eyes.map(\.displayName).joined(separator: " + ")
    }
}

private struct SessionRow: View {
    let session: StudySession
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                IconBubble(systemName: session.status == .complete ? "checkmark" : "calendar", size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.participant.displayName)
                        .font(Theme.Typography.bodyMedium)
                        .foregroundStyle(Theme.Colors.ink)
                    Text("\(session.visitLabel) · \(session.dueDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.inkTertiary)
            }
            .glassCard(padding: 14, radius: 22)
        }
        .buttonStyle(.plain)
    }
}
