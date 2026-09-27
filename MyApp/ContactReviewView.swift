import SwiftUI
import Contacts

struct ContactReviewView: View {
    @Bindable var contactsEngine: ContactsEngine
    
    var body: some View {
        ZStack {
            ThemeBackground()
            
            if contactsEngine.duplicateGroups.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                    Text("NO DUPLICATES FOUND")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                        .tracking(1)
                }
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        ForEach(contactsEngine.duplicateGroups) { group in
                            ContactGroupCard(group: group, engine: contactsEngine)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationTitle("Duplicate Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(red: 0.1, green: 0.1, blue: 0.3), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct ContactGroupCard: View {
    let group: DuplicateContactGroup
    let engine: ContactsEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 24))
                    .foregroundStyle(.indigo)
                Text("\(group.mainContact.givenName) \(group.mainContact.familyName)".trimmingCharacters(in: .whitespaces).uppercased())
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(1)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("1 Main Contact, \(group.duplicates.count) Duplicate(s)")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 16) {
                Button(action: {
                    Task { await engine.delete(duplicates: group.duplicates, from: group.id) }
                }) {
                    Text("DELETE DUPES")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.red.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(WeightlessButtonStyle())
                
                Button(action: {
                    Task { await engine.merge(group: group) }
                }) {
                    Text("MERGE ALL")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.indigo)
                        .cornerRadius(20)
                }
                .buttonStyle(WeightlessButtonStyle())
            }
        }
        .padding(20)
        .glassCard()
        .padding(.horizontal, 20)
    }
}
