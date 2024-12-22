//
//  PartnerNameView.swift
//  DDooing
//
//  Created by Doran on 5/14/24.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct PartnerNameView: View {
    @State private var nickname = ""
    @State var isNicknamed : Bool = false
    
    var body: some View {
        NavigationStack{
            VStack(spacing:0){
                Text("DDooing").font(.pretendardBold40)
                    .padding(.bottom, 30)
                
                Text("파트너의 별명을 입력해주세요.").font(.pretendardBold18)
                    .padding(.bottom, 70)

                TextField("Nickname", text: $nickname)
                    .keyboardType(.namePhonePad).autocapitalization(.none)
                    .font(.pretendardBold32)
                    .padding(.leading, 32)
                    .padding(.trailing, 32)
                Rectangle()
                    .frame(height: 1)
                    .padding(.leading, 32)
                    .padding(.trailing, 32)
                    .padding(.bottom, 73)
                
                Button(action: {
                    if let user = Auth.auth().currentUser {
                        setUsersNickname(nick: nickname, userAUID: user.uid)
                    }
                }, label: {
                    Text("완료")
                        .font(.pretendardBold18)
                })
                .padding(.bottom,100)
            
                Text("추후 별명을 수정할 수 없습니다.? 나중에 하기?")
            }
            .padding(.horizontal, 16)
            .padding(.top, 165)
            Spacer()
            
            NavigationLink(
                destination: MainView().navigationBarBackButtonHidden(true),
                isActive: $isNicknamed,
                label: {
                    EmptyView()
                })
        }
        .padding(.horizontal,16)
        .navigationBarBackButtonHidden(true)
    }
    
    private func setUsersNickname(nick nickname : String, userAUID: String) {
        let db = Firestore.firestore()

        db.collection("Users").document(userAUID).updateData([
            "ConnectedNickname": nickname
        ]) { err in
            if let err = err {
                print("Error updating document: \(err)")
            } else {
                print("상대방의 닉네임이 \(nickname)으로 정해졌습니다.")
                isNicknamed = true
            }
        }
    }
}


struct PartnerNameView_Previews: PreviewProvider {
    static var previews: some View {
        PartnerNameView().preferredColorScheme(.dark)
    }
}
