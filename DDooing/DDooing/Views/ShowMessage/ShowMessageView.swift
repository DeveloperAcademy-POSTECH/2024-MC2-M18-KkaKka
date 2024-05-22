
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
            ScrollView {
                // 메세지 개수에 따른 이미지 변경
                // 새로운 우체통 이미지로 변경 예정
                Image(imageName(for: recivedMessages.count))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 140, height: 140)
                
                
                Spacer()
                
                ForEach(recivedMessages.reversed()) { message in
                    HStack {
                        HStack {
                            if message.isStarred {
                                // 새로운 별+하트 이미지로 변경 예정
                                Image("StarredHeart")
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
                        }
                    }
                    .padding(.top, 20)
                }
//                .padding(.trailing)
            }
//            .toolbar {
//                ToolbarItem {
//                    Menu {
//                        // 새로운 메세지가 왔을 때 어떻게 보이는지 테스트용 버튼
//                        Button {
//                            toggleNewMessages()
//                        } label: {
//                            Text("NewMessage test")
//                        }
//                        // 즐겨찾기 한 메세지가 왔을 때 어떻게 보이는지 테스트용 버튼
//                        Button {
//                            toggleStarredMessages()
//                        } label: {
//                            Text("StarredMessage test")
//                        }
//                    } label: {
//                        Label("test", systemImage: "ellipsis.circle")
//                    }
//                }
//            }
            .navigationTitle("오늘의 메시지")
            .onAppear {
                addObserveMessages()
                //테스트용
//                if let user = Auth.auth().currentUser {
//                    self.checkAndDeleteOldMessagesTest(userAUID: user.uid)
//                }
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
    
//    // 새로운 메세지가 왔을 때 어떻게 보이는지 테스트용 함수
//    func toggleNewMessages() {
//        for index in recivedMessages.indices {
//            recivedMessages[index].isNew.toggle()
//        }
//    }
//
//    // 즐겨찾기 한 메세지가 왔을 때 어떻게 보이는지 테스트용 함수
//    func toggleStarredMessages() {
//        for index in recivedMessages.indices {
//            recivedMessages[index].isStarred.toggle()
//        }
//    }
    
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
    
    //테스트용 함수
//    private func checkAndDeleteOldMessagesTest(userAUID: String) {
//        let db = Firestore.firestore()
//        let docRef = db.collection("Received-Messages").document(userAUID).collection(userAUID)
//        
//        docRef.getDocuments { snapshot, error in
//            if let error = error {
//                print("Error getting documents: \(error)")
//            } else {
//                let now = Date()
//                let calendar = Calendar.current
//                
//                // 특정 시간 (오전 11시 42분)을 생성
//                var components = calendar.dateComponents([.year, .month, .day], from: now)
//                components.hour = 12
//                components.minute = 30
//                let specificTime = calendar.date(from: components)!
//
//                for document in snapshot!.documents {
//                    if let timestamp = document.get("timeStamp") as? Timestamp {
//                        let messageDate = timestamp.dateValue()
//                        if messageDate < specificTime {
//                            // 특정 시간 이전의 메시지 삭제
//                            document.reference.delete { error in
//                                if let error = error {
//                                    print("Error deleting document: \(error)")
//                                } else {
//                                    print("Document successfully deleted")
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//        }
//    }
    
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
