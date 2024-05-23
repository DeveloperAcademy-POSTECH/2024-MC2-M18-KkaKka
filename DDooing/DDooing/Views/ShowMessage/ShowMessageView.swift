
//  ShowingMessageView.swift
//  DDooing_test
//
//  Created by 조우현 on 5/16/24.
//

import Firebase
import Foundation
import SwiftUI

struct RecivedMessage: Identifiable {
    let id = UUID()
    let messageId: String
    var name: String
    let text: String
    var time: Date
    var isNew: Bool = false
    var isStarred: Bool = false
}

struct ShowMessageView: View {
    let partnerUID: String!
    
    init(partnerUID: String?) {
        self.partnerUID = partnerUID
    }
    
    @State private var recivedMessages = [RecivedMessage]()
    
    @State private var timer: Timer?
    
    var body: some View {
        NavigationStack {
            VStack {
                
                Spacer()
                
                HStack {
                    Text("오늘의 메세지")
                        .font(.largeTitle.bold())
                    Spacer()
                }
                .padding()
                .padding(.top, 10)
                
                Spacer()
                
                ScrollView {
                    Image(imageName(for: recivedMessages.count))
                        .resizable()
                        .frame(width: 140, height: 130)
                        .scaledToFill()
                        .padding(.bottom)
                    
                    Spacer()
                    
                    ForEach(recivedMessages.reversed()) { message in
                        HStack {
                            HStack {
                                if message.isStarred {
                                    // 새로운 별+하트 이미지로 변경 예정
                                    Image("Heart with stars")
                                        .resizable()
                                        .frame(width: 35, height: 30)
                                } else {
                                    Image("Heart button")
                                        .resizable()
                                        .frame(width: 35, height: 30)
                                }
                                
                                
                                LazyVStack(alignment: .leading) {
                                    Text(message.name)
                                        .bold()
                                    
                                    Text(message.text)
                                        .frame(width: 200, height: 10, alignment: .leading)
                                }
                                .padding(.leading, 5)
                                
                            }
                            .padding(.leading)
                            
                            Spacer()
                            
                            LazyVStack(alignment: .trailing) {
                                if message.isNew {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "moonphase.new.moon")
                                            .resizable()
                                            .frame(width: 10, height: 10)
                                            .foregroundColor(.red)
                                    }
                                } else {
                                    Spacer()
                                }
                                Text(formattedTime(from: message.time))
                                    .foregroundStyle(.secondary)
                                    .font(.footnote)
                                    .padding(.trailing,18)
                            }
                        }
                        .padding(.top, 20)
                        
                    }
                }
        }
            .onAppear {
                addObserveMessages()
                
                if let user = Auth.auth().currentUser {
                    self.checkAndDeleteOldMessages(userAUID: user.uid)
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
    }
    
    // 메세지 개수에 따른 이미지 변경 함수
    func imageName(for messageCount: Int) -> String {
        switch messageCount {
        case 0...10:
            return "mailbox1"
        case 11...20:
            return "mailbox2"
        case 21...40:
            return "mailbox3"
        default:
            return "mailbox4"
        }
    }
    
    func formattedTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: date)
    }
    
    private func addObserveMessages() {
        observeMessages { messageData in
            if let text = messageData["messageText"] as? String,
                let timestamp = messageData["timeStamp"] as? Timestamp,
                let isStarred = messageData["isStarred"] as? Bool,
                let messageId = messageData["messageId"] as? String {
                    self.fetchMyConnectedNickname { nickname in
                        // 중복 체크: 이미 추가된 메시지인지 확인
                        if !self.recivedMessages.contains(where: { $0.messageId == messageId }) {
                            let message = RecivedMessage(messageId: messageId, name: nickname, text: text, time: timestamp.dateValue(), isStarred: isStarred)
                            self.recivedMessages.append(message)
                        }
                    }
                }
        }
        
        // db에서 메세지가 삭제되면 뷰에서도 삭제되게 하기
        observeMessages { messageData, documentID, changeType in
            if let text = messageData["messageText"] as? String,
                let timestamp = messageData["timeStamp"] as? Timestamp,
                let isStarred = messageData["isStarred"] as? Bool,
                let messageId = messageData["messageId"] as? String {
                    self.fetchMyConnectedNickname { nickname in
                        switch changeType {
                        case .added:
                            if !self.recivedMessages.contains(where: { $0.messageId == messageId }) {
                                let message = RecivedMessage(messageId: messageId, name: nickname, text: text, time: timestamp.dateValue(), isStarred: isStarred)
                                self.recivedMessages.append(message)
                            }
                        case .removed:
                            if let index = self.recivedMessages.firstIndex(where: { $0.messageId == messageId }) {
                                self.recivedMessages.remove(at: index)
                            }
                        default:
                            break
                        }
                    }
                }
        }
    }
    
    
    func observeMessages(completion: @escaping ([String: Any]) -> Void) {
        let db = Firestore.firestore()
        
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        let query = db.collection("Received-Messages")
            .document(currentUid)
            .collection(partnerUID)
            .order(by: "timeStamp", descending: true)
        
        query.addSnapshotListener { snapshot, _ in
            guard let changes = snapshot?.documentChanges.filter({ $0.type == .added
            }) else { return }
            
            let messages = changes.map { $0.document.data() }
            
            for message in messages {
                completion(message)
            }
        }
    }
    
    private func fetchMyConnectedNickname(completion: @escaping (String) -> Void) {
        let db = Firestore.firestore()
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion("Unknown")
            return
        }
        
        db.collection("Users").document(currentUid).getDocument { document, error in
            if let document = document, document.exists {
                let nickname = document.data()?["ConnectedNickname"] as? String ?? "Unknown"
                completion(nickname)
            } else {
                completion("Unknown")
            }
        }
    }
    
    // 메세지 삭제 관찰 메서드
    func observeMessages(completion: @escaping ([String: Any], String, DocumentChangeType) -> Void) {
        let db = Firestore.firestore()
        
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        let query = db.collection("Received-Messages")
            .document(currentUid)
            .collection(partnerUID)
            .order(by: "timeStamp", descending: true)
        
        query.addSnapshotListener { snapshot, _ in
            guard let changes = snapshot?.documentChanges else { return }
            
            for change in changes {
                let data = change.document.data()
                let documentID = change.document.documentID
                completion(data, documentID, change.type)
            }
        }
    }
    
    // 어제의 메세지가 삭제되도록 하는 메서드
    private func checkAndDeleteOldMessages(userAUID: String) {
        let db = Firestore.firestore()
        let docRef = db.collection("Received-Messages").document(userAUID).collection(userAUID)
        
        docRef.getDocuments { snapshot, error in
            if let error = error {
                print("Error getting documents: \(error)")
            } else {
                let now = Date()
                let calendar = Calendar.current
                
                for document in snapshot!.documents {
                    if let timestamp = document.get("timeStamp") as? Timestamp {
                        let messageDate = timestamp.dateValue()
                        if calendar.isDateInYesterday(messageDate) || messageDate < calendar.startOfDay(for: now) {
                            // 메시지가 어제거나 이전이면 삭제
                            document.reference.delete { error in
                                if let error = error {
                                    print("Error deleting document: \(error)")
                                } else {
                                    print("Document successfully deleted")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}




#Preview {
    ShowMessageView(partnerUID: nil)
}
