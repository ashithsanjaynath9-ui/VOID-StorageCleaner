import SwiftUI
import Photos
import Contacts
import EventKit

@Observable
final class PermissionManager {
    var photoStatus: PHAuthorizationStatus = .notDetermined
    var contactsStatus: CNAuthorizationStatus = .notDetermined
    var calendarStatus: EKAuthorizationStatus = .notDetermined
    
    init() {
        Task {
            let pStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            let cStatus = CNContactStore.authorizationStatus(for: .contacts)
            let calStatus = EKEventStore.authorizationStatus(for: .event)
            await MainActor.run {
                self.photoStatus = pStatus
                self.contactsStatus = cStatus
                self.calendarStatus = calStatus
            }
        }
    }
    
    var hasDeniedAccess: Bool {
        photoStatus == .denied || photoStatus == .restricted ||
        contactsStatus == .denied || contactsStatus == .restricted ||
        calendarStatus == .denied || calendarStatus == .restricted
    }
    
    func requestPhotoAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run { self.photoStatus = status }
        return status == .authorized || status == .limited
    }
    
    func requestContactsAccess() async -> Bool {
        do {
            let granted = try await CNContactStore().requestAccess(for: .contacts)
            await MainActor.run { self.contactsStatus = granted ? .authorized : .denied }
            return granted
        } catch {
            await MainActor.run { self.contactsStatus = .denied }
            return false
        }
    }
    
    func requestCalendarAccess() async -> Bool {
        do {
            let store = EKEventStore()
            var granted = false
            if #available(iOS 17.0, *) {
                granted = try await store.requestFullAccessToEvents()
                await MainActor.run { self.calendarStatus = granted ? .fullAccess : .denied }
            } else {
                granted = try await store.requestAccess(to: .event)
                await MainActor.run { self.calendarStatus = granted ? .authorized : .denied }
            }
            return granted
        } catch {
            await MainActor.run { self.calendarStatus = .denied }
            return false
        }
    }
    
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
