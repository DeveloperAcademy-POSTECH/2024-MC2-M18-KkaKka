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
    @State var partnerName: String = ""
    @Environment(\.modelContext) private var modelContext
    @Query private var messages: [MessageModel]
    @State private var pushMessage : String = ""
    @State private var showContextMenu = false
    let partnerUID: String!
    @GestureState private var isPressed = false
    @State private var isLongPressed = false
    @Query<NotificationDataModel> private var notificationDataList: [NotificationDataModel]
    @State var partnerDeviceToken = ""
    @State private var isButtonToggle: [Bool] = [false, false]
    @Environment(\.colorScheme) var colorScheme //현재 색상 모드 가져오기
    
    init(partnerUID: String?) {
        self.partnerUID = partnerUID
        if messages.randomElement() != nil {
            _pushMessage = State(initialValue: pushMessage)
        } else {
            _pushMessage = State(initialValue: "")
        }
    }
    
    var body: some View {
        NavigationStack{
            VStack {
                HStack {
                    Image(colorScheme == .dark ? "Title-dark" : "Title-white") // 색상 모드에 따라 이미지 변경
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 160)
                    Spacer()
                }
                .padding(.vertical)
                
                
                Spacer()
                
                Image("Heart button")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.trailing,10)
                    .scaleEffect(isPressed ? 1.0 : 0.8) // 작아지는 효과
                    .animation(.easeInOut(duration: 0.3), value: isPressed) // 애니메이션 추가
                    .gesture(
                        LongPressGesture(minimumDuration: 0.5)
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
                                    pushMessage = mess.message
                                    sendMessage(messageText: pushMessage, isStarred: true)
                                    fetchAccessTokenAndSendPushNotification()
                                    isButtonToggle[1].toggle()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        isButtonToggle[1].toggle()
                                    }
                                }, label: {
                                    Text(mess.message)
                                })
                            }}
                    })
                    .simultaneousGesture(
                        TapGesture()
                                .onEnded { _ in
                                    if !isLongPressed {
                                        print("짧게누름")
                                        if let randomMessage = messages.randomElement() {
                                            pushMessage = randomMessage.message
                                        }
                                        print("메시지 입력")
                                        sendMessage(messageText: pushMessage, isStarred: false)
                                        fetchAccessTokenAndSendPushNotification()
                                        isButtonToggle[0].toggle()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            isButtonToggle[0].toggle()
                                        }
                                    }
                                    isLongPressed = false
                                }
                    )
                    .modifier(ParticleModifier(systemImage: "star.fill", font: Font.headline, status: isButtonToggle[1], activeTint: Color.yellow.opacity(0.8), inActiveTint: Color.gray))
                    .modifier(ParticleModifier(systemImage: "suit.heart.fill", font: Font.headline, status: isButtonToggle[0], activeTint: Color.red.opacity(0.8), inActiveTint: Color.gray))
                Text("\(postPositionText(name)) 생각하며 눌러보세요.")
                    .font(.headline)
                    .padding(.bottom,60)
                Spacer()
            }
            .padding()
            .onAppear {
                fetchMyConnectedNickname { fetchedName in
                    name = fetchedName
                    
                }

            }
        }
    }
    
    func fetchPartnerDeviceToken(completion: @escaping (String) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.KkaKka.DDooing")!
        let db = Firestore.firestore()
        
        db.collection("Users").document(partnerUID).getDocument { document, error in
            if let document = document, document.exists {
                partnerDeviceToken = document.data()?["deviceToken"] as? String ?? "Unknown"
                
                defaults.set(partnerDeviceToken,forKey: "partnerDeviceToken")
                
                completion(partnerDeviceToken)
            } else {
                completion("Unknown")
            }
        }
    }
    
    func fetchPartnerConnectedNickname(completion: @escaping (String) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.KkaKka.DDooing")!
        let db = Firestore.firestore()
        db.collection("Users").document(partnerUID).getDocument { document, error in
            if let document = document, document.exists {
                partnerName = document.data()?["ConnectedNickname"] as? String ?? "Unknown"
                
                defaults.set(partnerName,forKey: "partnerName")
                
                completion(partnerName)
            } else {
                completion("Unknown")
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
                name = document.data()?["ConnectedNickname"] as? String ?? "Unknown"
                
                completion(name)
            } else {
                completion("Unknown")
            }
        }
    }
    
    func sendMessage(messageText: String, isStarred: Bool) {
        let db = Firestore.firestore()
        
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        let currentUserRef = db.collection("Received-Messages")
            .document(partnerUID).collection(currentUid).document()

        let messageId = currentUserRef.documentID
        
        let messageData: [String: Any] = [
            "fromId": partnerUID!,
            "toId": currentUid,
            "messageText": messageText,
            "timeStamp": Timestamp(date: Date()),
            "isStarred": isStarred,
            "messageId": messageId
        ]
        
        currentUserRef.setData(messageData)
    }
    
    func fetchAccessTokenAndSendPushNotification() {
        fetchPartnerDeviceToken { fetchedtoken in
            partnerDeviceToken = fetchedtoken
        }
        fetchPartnerConnectedNickname { fetchedName in
            partnerName = fetchedName
        }
        
        // 서버로부터 OAuth 2.0 액세스 토큰 가져오기
        guard let url = URL(string: "http://localhost:3000/getAccessToken") else {
            print("Invalid URL for token")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let session = URLSession(configuration: .default)
        session.dataTask(with: request) { data, response, err in
            if let err = err {
                print(err.localizedDescription)
                return
            }
            guard let data = data else {
                print("No data received")
                return
            }
            
            // 서버로부터 받은 응답을 문자열로 변환하여 출력
            if let accessToken = String(data: data, encoding: .utf8) {
                print("Access Token String: \(accessToken)")
                sendPushNotification(with: accessToken)
            } else {
                print("Invalid token response")
            }
        }.resume()
    }
    
    func sendPushNotification(with accessToken: String)  {
        guard !accessToken.isEmpty else {
            print("Access token is empty")
            return
        }
        
        // HTTP v1 API의 엔드포인트 URL
        guard let url = URL(string: "https://fcm.googleapis.com/v1/projects/ddooing-8881b/messages:send") else {
            print("Invalid URL for FCM")
            return
        }
        print("partnerdevicetoken >>> \(partnerDeviceToken)")
        print("pushMessage >>> \(pushMessage)")
        print("parname >>> \(partnerName)")
        let json: [String: Any] = [
            "message": [
                "token": partnerDeviceToken,
                "notification": [
                    "body": pushMessage,
                    "title": partnerName
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let session = URLSession(configuration: .default)
        session.dataTask(with: request) { data, response, err in
                if let err = err {
                    print("Error sending push notification: \(err.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Invalid response")
                    return
                }
                
                print("Push notification response status code: \(httpResponse.statusCode)")
            
            if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                        print("Response Body: \(responseBody)")
                    }
                
                if httpResponse.statusCode == 200 {
                    print("Push notification sent successfully")
                } else {
                    print("Failed to send push notification")
                }
        }.resume()
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

struct ParticleModel: Identifiable {
    var id: UUID = .init()
    var randomX: CGFloat = 0
    var randomY: CGFloat = 0
    var scale: CGFloat = 1
    var opacity: CGFloat = 1
    
    // Reset's all properties
    mutating func reset() {
        randomX = 0
        randomY = 0
        scale = 0
        opacity = 1
    }
}

fileprivate struct ParticleModifier: ViewModifier {
    var systemImage: String
    var font: Font
    var status: Bool
    var activeTint: Color
    var inActiveTint: Color
    
    @State private var particles: [ParticleModel] = []
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                ZStack {
                    Group {
                        ForEach(particles) { particle in
                            Image(systemName: systemImage)
                                .foregroundColor(status ? activeTint : inActiveTint)
                                .scaleEffect(particle.scale*3)
                                .offset(x: particle.randomX, y: particle.randomY+70)
                                .opacity(particle.opacity)
                                .opacity(status ? 1 : 0)
                                .animation(.none, value: status)
                        }
                    }
                }
                .onAppear {
                    if particles.isEmpty {
                        for _ in 1...15 {
                            let particle = ParticleModel()
                            particles.append(particle)
                        }
                    }
                }
                .onChange(of: status) { _, newValue in
                    if !newValue {
                        for i in particles.indices {
                            particles[i].reset()
                        }
                    } else {
                        for i in particles.indices {
                            let total = CGFloat(particles.count)
                            let progress = CGFloat(i) / total
                            let maxX: CGFloat = progress > 0.5 ? 200 : -200
                            let maxY: CGFloat = 160
                            let randomX: CGFloat = (progress > 0.5 ? progress - 0.5 : progress) * maxX
                            let randomY: CGFloat = (progress > 0.5 ? progress - 0.5 : progress) * maxY + 35
                            let randomScale: CGFloat = .random(in: 0.35...1.0)
                            
                            withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.7)) {
                                let extraRandomX: CGFloat = progress > 0.5 ? .random(in: 0...10) : .random(in: -10...0)
                                let extraRandomY: CGFloat = .random(in: 0...30)
                                
                                particles[i].randomX = randomX + extraRandomX
                                particles[i].randomY = -randomY - extraRandomY
                            }
                            
                            withAnimation(.easeInOut(duration: 0.3)) {
                                particles[i].scale = randomScale
                            }
                            
                            
                            withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.7).delay(0.25 + (Double(i) * 0.005))) {
                                particles[i].scale = 0.001
                            }
                            
                        }
                    }
                }
            }
    }
}



// Preview
#Preview {
    HomeView(partnerUID: nil)
        .modelContainer(for: MessageModel.self,  inMemory: true)
}
