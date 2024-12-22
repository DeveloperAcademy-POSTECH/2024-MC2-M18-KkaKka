//
//  ContentView.swift
//  DDooing
//
//  Created by Doran on 5/14/24.
//

import SwiftUI
import Firebase

struct MainView: View {
    @State private var partnerUID: String?
    
    var body: some View {
        TabView {
            HomeView(partnerUID: partnerUID)
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("DDooing")
                }
            TextEditView()
                .tabItem {
                    Image(systemName: "pencil")
                    Text("메세지 문구")
                }
            ShowMessageView(partnerUID: partnerUID)
                .tabItem {
                    Image(systemName: "archivebox.fill")
                    Text("수신함")
                }
        }
        .onAppear {
            fetchPartnerUID()
        }
    }
    
    private func fetchPartnerUID() {
        guard let currentUser = Auth.auth().currentUser else { return }
        let currentUserUID = currentUser.uid
        let defaults = UserDefaults(suiteName: "group.com.KkaKka.DDooing")!
        defaults.set(currentUserUID,forKey: "currentUserUID")
        
        let db = Firestore.firestore()
        db.collection("Users").document(currentUserUID).getDocument { (document, error) in
            if let document = document, document.exists {
                if let code = document.data()?["code"] as? String {
                    db.collection("Users").whereField("code", isEqualTo: code)
                        .getDocuments { (querySnapshot, error) in
                            if let error = error {
                                print("Error getting documents: \(error)")
                            } else {
                                let filteredDocuments = querySnapshot?.documents.filter { $0.documentID != currentUserUID }
                                if let partnerDocument = filteredDocuments?.first {
                                    self.partnerUID = partnerDocument.documentID
                                    
                                    defaults.set(partnerUID,forKey: "partnerUID")
                                }
                            }
                        }
                }
            }
        }
    }
}

#Preview {
    MainView()
}
