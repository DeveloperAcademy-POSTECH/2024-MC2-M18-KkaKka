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
            
            let db = Firestore.firestore()
            db.collection("Users").document(currentUserUID).getDocument { (document, error) in
                if let document = document, document.exists {
                    if let code = document.data()?["code"] as? String {
                        db.collection("Users").whereField("code", isEqualTo: code)
                            .getDocuments { (querySnapshot, error) in
//                                if let error = error {
//                                    print("Error getting documents: \(error)")
//                                } else {
//                                    let filteredDocuments = querySnapshot?.documents.filter { $0.documentID != currentUserUID }
//                                    if let partnerDocument = filteredDocuments?.first {
//                                        self.partnerUID = partnerDocument.documentID
//                                    }
//                                    print("파트너 uid : \(String(describing: partnerUID))")
//                                } 
                                
                                /** 주의 해주세요!! 아래 코드를 사용할 시, 계정 하나로도 테스트 가능합니다. 하지만, 아래 코드로 다른 두 계정을 테스트하면 사용자를 잘 못 찾아 오류가 생길 수 있습니다. 두 계정으로 테스트할 시에는 위에 코드를 사용해주세요! 커밋 시 기본적인 세팅은 위 코드로 부탁드립니다. **/
                                
                                if let error = error {
                                    print("Error getting documents: \(error)")
                                } else if let querySnapshot = querySnapshot, !querySnapshot.documents.isEmpty {
                                    let document = querySnapshot.documents.first
                                    if let uidB = document?["uid"] as? String {
                                        self.partnerUID = uidB
                                        if let nonOptionalUID = self.partnerUID {
                                            print("파트너 uid: \(nonOptionalUID)")
                                        }
                                    }
                                } else {
                                    print("사용자를 찾을 수 없습니다.")
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
