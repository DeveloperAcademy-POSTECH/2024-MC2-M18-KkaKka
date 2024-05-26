//
//  HomeView.swift
//  button
//
//  Created by 박하연 on 5/15/24.
//

import Firebase
import Foundation
import SwiftUI
import SwiftData

struct HomeView: View {
    @State var name: String = ""
    @Environment(\.modelContext) private var modelContext
    @Query private var messages: [MessageModel]
    @State private var randomMessages : String = ""
    @State private var showContextMenu = false
    let partnerUID: String!
    @GestureState private var isPressed = false
    @State private var isLongPressed = false
    
    init(partnerUID: String?) {
        self.partnerUID = partnerUID
        if messages.randomElement() != nil {
            _randomMessages = State(initialValue: randomMessages)
        } else {
            _randomMessages = State(initialValue: "")
        }
    }
    
    var body: some View {
        NavigationStack{
            VStack {
                Image("Heart button")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.trailing,10)
                    .scaleEffect(isPressed ? 1.0 : 0.8) // 작아지는 효과
                    .animation(.easeInOut(duration: 0.3), value: isPressed) // 애니메이션 추가
                    .gesture(
                        LongPressGesture(minimumDuration: 1.0)
                            .updating($isPressed) { currentState, gestureState, transaction in
                                gestureState = currentState
                            }
                            .onEnded { _ in
                                isLongPressed = true
                                print("길게누름")
                            }
                        
                    )
                    .contextMenu(menuItems: {
                        ForEach(messages) { mess in
                            if mess.isStarred {
                                Button (action: {
                                    sendMessage(messageText: mess.message, isStarred: true)
                                }, label: {
                                    Text(mess.message)
                                })
                            }}
                    })
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { _ in
                                if !isLongPressed {
                                    print("짧게누름")
                                    if let randomMessage = messages.randomElement() {
                                        randomMessages = randomMessage.message
                                    }
                                    saveRandomMessage()
                                    print("메시지 입력")
                                }
                                isLongPressed = false
                            }
                    )
                Text("\(postPositionText(name)) 생각하며 눌러보세요.")
                    .font(.headline)
                    .padding(.bottom,60)


                
                
                
                
                

            }
            .padding()
            .navigationTitle("DDooing")
            .onAppear {
                fetchMyConnectedNickname { fetchedName in
                    name = fetchedName
                    
                }
            }
        }
    }
    
    func saveRandomMessage() {
        guard let partnerUID = partnerUID else { return }
        sendMessage(messageText: randomMessages, isStarred: false)
    }
    
    func sendMessage(messageText: String, isStarred: Bool) {
        let db = Firestore.firestore()
        
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        let currenrUserRef = db.collection("Received-Messages")
            .document(currentUid).collection(partnerUID).document()
        
        let PartnerRef = db.collection("Received-Messages")
            .document(partnerUID).collection(currentUid)
        
//        let recentCurrentUserRef = db.collection("Received-Messages")
//            .document(currentUid).collection("recent-messages")
//            .document(partnerUID)
        
        let recentPartnerRef = db.collection("Received-Messages")
            .document(partnerUID).collection("recent-messages")
            .document(currentUid)
        
        let messageId = currenrUserRef.documentID
        
        let messageData: [String: Any] = [
            "fromId": currentUid,
            "toId": partnerUID!,
            "messageText": messageText,
            "timeStamp": Timestamp(date: Date()),
            "isStarred": isStarred,
            "messageId": messageId
        ]
        
//        currenrUserRef.setData(messageData)
        PartnerRef.document(messageId).setData(messageData)
//        recentCurrentUserRef.setData(messageData)
        recentPartnerRef.setData(messageData)
    }
    
    private func fetchMyConnectedNickname(completion: @escaping (String) -> Void) {
        let db = Firestore.firestore()
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion("Unknown")
            return
        }
        
        db.collection("Users").document(currentUid).getDocument { document, error in
            if let document = document, document.exists {
                name = document.data()?["ConnectedNickname"] as? String ?? "Unknown"
                completion(name)
            } else {
                completion("Unknown")
            }
        }
    }
    
}

// 을,를 구분
func postPositionText(_ name: String) -> String {
    // 글자의 마지막 부분을 가져옴
    guard let lastText = name.last else { return name }
    // 유니코드 전환
    let unicodeVal = UnicodeScalar(String(lastText))?.value

    guard let value = unicodeVal else { return name }
    // 한글아니면 반환
    if (value < 0xAC00 || value > 0xD7A3) { return name }
    // 종성인지 확인
    let last = (value - 0xAC00) % 28
    // 받침있으면 을 없으면 를 반환
    let str = last > 0 ? "을" : "를"
    return name + str
}


// Preview
#Preview {
    HomeView(partnerUID: nil)
        .modelContainer(for: MessageModel.self,  inMemory: true)
}


