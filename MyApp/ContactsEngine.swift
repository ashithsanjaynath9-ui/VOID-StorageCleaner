import SwiftUI
import Contacts

struct DuplicateContactGroup: Identifiable {
    let id = UUID()
    let mainContact: CNContact
    let duplicates: [CNContact]
}

@Observable
final class ContactsEngine {
    var duplicateGroups: [DuplicateContactGroup] = []
    var isScanning = false
    var totalDuplicatesFound = 0
    
    func scanContacts() async {
        await MainActor.run { isScanning = true }
        
        let store = CNContactStore()
        let keys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey
        ] as [CNKeyDescriptor]
        
        let request = CNContactFetchRequest(keysToFetch: keys)
        
        // Push the synchronous contact enumeration to a detached background thread
        let results = await Task.detached { () -> (groups: [DuplicateContactGroup], count: Int)? in
            var allContacts: [CNContact] = []
            
            do {
                try store.enumerateContacts(with: request) { contact, _ in
                    if !contact.givenName.isEmpty || !contact.familyName.isEmpty {
                        allContacts.append(contact)
                    }
                }
                
                let grouped = Dictionary(grouping: allContacts) { contact in
                    "\(contact.givenName.lowercased()) \(contact.familyName.lowercased())".trimmingCharacters(in: .whitespaces)
                }.filter { $0.value.count > 1 }
                
                var currentGroups: [DuplicateContactGroup] = []
                var duplicateCount = 0
                
                for (_, contacts) in grouped {
                    if let main = contacts.first {
                        let duplicates = Array(contacts.dropFirst())
                        duplicateCount += duplicates.count
                        currentGroups.append(DuplicateContactGroup(mainContact: main, duplicates: duplicates))
                    }
                }
                
                return (currentGroups, duplicateCount)
            } catch {
                print("Failed to fetch contacts: \(error)")
                return nil
            }
        }.value
        
        await MainActor.run {
            if let results = results {
                self.duplicateGroups = results.groups
                self.totalDuplicatesFound = results.count
            }
            self.isScanning = false
        }
    }
    
    func delete(duplicates: [CNContact], from groupID: UUID) async {
        let store = CNContactStore()
        let saveRequest = CNSaveRequest()
        
        for contact in duplicates {
            guard let mutableContact = contact.mutableCopy() as? CNMutableContact else { continue }
            saveRequest.delete(mutableContact)
        }
        
        do {
            try store.execute(saveRequest)
            await MainActor.run {
                if let index = duplicateGroups.firstIndex(where: { $0.id == groupID }) {
                    duplicateGroups.remove(at: index)
                    totalDuplicatesFound -= duplicates.count
                }
            }
        } catch {
            print("Failed to delete contacts: \(error)")
        }
    }
    
    func merge(group: DuplicateContactGroup) async {
        let store = CNContactStore()
        let saveRequest = CNSaveRequest()
        
        guard let mainMutable = group.mainContact.mutableCopy() as? CNMutableContact else { return }
        
        var existingPhones = Set(mainMutable.phoneNumbers.map { $0.value.stringValue })
        var existingEmails = Set(mainMutable.emailAddresses.map { $0.value as String })
        
        for duplicate in group.duplicates {
            for phone in duplicate.phoneNumbers {
                if !existingPhones.contains(phone.value.stringValue) {
                    mainMutable.phoneNumbers.append(phone)
                    existingPhones.insert(phone.value.stringValue)
                }
            }
            
            for email in duplicate.emailAddresses {
                if !existingEmails.contains(email.value as String) {
                    mainMutable.emailAddresses.append(email)
                    existingEmails.insert(email.value as String)
                }
            }
            
            guard let dupMutable = duplicate.mutableCopy() as? CNMutableContact else { continue }
            saveRequest.delete(dupMutable)
        }
        
        saveRequest.update(mainMutable)
        
        do {
            try store.execute(saveRequest)
            await MainActor.run {
                if let index = duplicateGroups.firstIndex(where: { $0.id == group.id }) {
                    duplicateGroups.remove(at: index)
                    totalDuplicatesFound -= group.duplicates.count
                }
            }
        } catch {
            print("Failed to merge contacts: \(error)")
        }
    }
}
