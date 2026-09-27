import SwiftUI
import EventKit

@Observable
final class CalendarEngine {
    var oldEvents: [EKEvent] = []
    var isScanning = false
    private let store = EKEventStore()
    
    func scanCalendar() async {
        await MainActor.run { isScanning = true }
        
        let startDate = Calendar.current.date(byAdding: .year, value: -5, to: Date()) ?? Date()
        let endDate = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        
        await MainActor.run {
            self.oldEvents = events
            self.isScanning = false
        }
    }
    
    func delete(events: [EKEvent]) async -> Bool {
        do {
            for event in events {
                try store.remove(event, span: .thisEvent, commit: false)
            }
            try store.commit()
            
            await MainActor.run {
                let deletedIds = Set(events.map { $0.eventIdentifier })
                self.oldEvents.removeAll { deletedIds.contains($0.eventIdentifier) }
            }
            return true
        } catch {
            print("Failed to delete calendar events: \(error)")
            return false
        }
    }
}

struct CalendarReviewView: View {
    @Bindable var engine: CalendarEngine
    @State private var selectedItems: Set<String> = []
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            ThemeBackground()
            
            if engine.oldEvents.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                    Text("NO OLD EVENTS FOUND")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                        .tracking(1)
                }
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(engine.oldEvents, id: \.eventIdentifier) { event in
                                EventCard(event: event, isSelected: selectedItems.contains(event.eventIdentifier ?? ""))
                                    .onTapGesture {
                                        Haptics.impact(.light)
                                        let id = event.eventIdentifier ?? ""
                                        if selectedItems.contains(id) {
                                            selectedItems.remove(id)
                                        } else {
                                            selectedItems.insert(id)
                                        }
                                    }
                            }
                        }
                        .padding(.vertical, 20)
                    }
                    
                    if !selectedItems.isEmpty {
                        Button(action: {
                            Haptics.impact(.medium)
                            let itemsToDelete = engine.oldEvents.filter { selectedItems.contains($0.eventIdentifier ?? "") }
                            Task {
                                let success = await engine.delete(events: itemsToDelete)
                                if success {
                                    await MainActor.run {
                                        selectedItems.removeAll()
                                        if engine.oldEvents.isEmpty {
                                            dismiss()
                                        }
                                    }
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("DELETE \(selectedItems.count) EVENT(S)")
                            }
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .tracking(1)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(Color.red)
                                .cornerRadius(20)
                        }
                        .antigravityButton()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                        .background(.ultraThinMaterial)
                    }
                }
            }
        }
        .navigationTitle("Old Events")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(red: 0.1, green: 0.1, blue: 0.3), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct EventCard: View {
    let event: EKEvent
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)
                
                if isSelected {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(event.title ?? "Untitled Event")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(event.startDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(20)
        .glassCard()
        .padding(.horizontal, 20)
        .opacity(isSelected ? 0.8 : 1.0)
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}
