//
//  RandomCodeView.swift
//  DDooing
//
//  Created by Doran on 5/14/24.
//

import SwiftUI
import Firebase

struct RandomCodeView: View {
    @StateObject private var viewModel = UserStatusViewModel()
    @State private var isConnectionMode = true
    @State private var code = ""
    @State private var randomCode = ""
    
    var body: some View {
        NavigationStack{
            VStack(spacing:0){
                Text("DDooing").font(.pretendardBold40)
                    .padding(.bottom, 30)
                
                Picker(selection: $isConnectionMode, label: Text("Picker here")){
                    Text("나의 코드 공유").tag(true)
                    Text("파트너 코드 입력").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 70)
                
                if isConnectionMode {
                    Text(randomCode)
                        .font(.pretendardBold32)
                        .padding(.bottom, 73)
                    
                    ShareLink(
                        item: randomCode,
                        subject: Text("DDooing"),
                        message: Text("DDooing Code")) {
                            HStack{
                                Image(systemName: "square.and.arrow.up")
                                Text("공유하기")
                            } .font(.pretendardBold18)
                        }
                    .padding(.bottom,100)
                }
                else{
                    TextField("Code", text: $code)
                        .keyboardType(.asciiCapable)
                        .font(.pretendardBold32)
                        .padding(.leading, 32)
                        .padding(.trailing, 32)
                    Rectangle()
                        .frame(height: 1)
                    //                    .foregroundColor(.white)
                        .padding(.leading, 32)
                        .padding(.trailing, 32)
                        .padding(.bottom, 73)
                    
                    Button(action: {
                        if let user = Auth.auth().currentUser {
                            connectUsers(with: code, userAUID: user.uid)
                        }
                    }, label: {
                        Text("연결하기")
                            .font(.pretendardBold18)
                        //                        .foregroundStyle(.white)
                    })
                    .padding(.bottom,100)
                }
                
                Text("파트너 연결이 완료되면 홈으로 이동됩니다.")
            }
            .padding(.horizontal, 16)
            .padding(.top, 165)
            Spacer()
            
            NavigationLink(
                destination: PartnerNameView(),
                isActive: $viewModel.isConnected,
                label: {
                    EmptyView()
                })
        }
    .padding(.horizontal,16)
    .onAppear{
        randomCode = generateRandomCode(length: 6).uppercased()
        if let user = Auth.auth().currentUser {
            sendRandomCodeToFirebase(for: user, with: randomCode)
            viewModel.observeUserConnectionStatus(userId: user.uid)
        }
    }
    .navigationBarBackButtonHidden(true)
}
    private func generateRandomCode(length: Int) -> String {
        let lettersAndDigits = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).compactMap { _ in lettersAndDigits.randomElement() })
    }
}


func sendRandomCodeToFirebase(for user: User, with code: String) {
    let db = Firestore.firestore()
    let docRef = db.collection("Users").document(user.uid)
    docRef.setData([
        "uid": user.uid,
        "code": code,
        "isConnected" : false,
    ], merge: true) { error in
        if let error = error {
            print("Error writing document: \(error)")
        } else {
            print("Document successfully written!")
        }
    }
}

func connectUsers(with code: String, userAUID: String) {
    let db = Firestore.firestore()
    db.collection("Users").whereField("code", isEqualTo: code)
        .getDocuments { (querySnapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else if let querySnapshot = querySnapshot, !querySnapshot.documents.isEmpty {
                let document = querySnapshot.documents.first
                if let uidB = document?["uid"] as? String {
                    connectUsersInDB(userAUID: userAUID, uidB: uidB, newCode: code)
                }
            } else {
                print("사용자를 찾을 수 없습니다.")
            }
    }
}

func connectUsersInDB(userAUID: String, uidB: String, newCode: String) {
    let db = Firestore.firestore()
    db.collection("Users").document(userAUID).updateData([
        "code": newCode,
        "isConnected": true,
    ]) { err in
        if let err = err {
            print("Error updating document: \(err)")
        } else {
            print("사용자1이 연결되었습니다.")
        }
    }
    
    db.collection("Users").document(uidB).updateData([
        "isConnected": true,
    ]) { err in
        if let err = err {
            print("Error updating document: \(err)")
        } else {
            print("사용자2가 연결되었습니다.")
        }
    }
}

struct LoadingView: View {
    var body: some View {
        Text("로딩중인 화면입니다.")
    }
}


struct RandomCodeView_Previews: PreviewProvider {
    static var previews: some View {
        RandomCodeView().preferredColorScheme(.dark)
    }
}
