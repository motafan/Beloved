//
//  LoginPage.swift
//  Beloved
//
//  Created by 风起兮 on 2024/7/29.
//

import SwiftUI
import AuthenticationServices

struct LoginPage: View {
    @State private var phone: String = ""
    @State private var code: String = ""
    @State private var selection: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    private var disabledPhoneLogin: Bool {
        phone.isEmpty || code.isEmpty
    }
    
    var body: some View {
        
        VStack(spacing: 0) {
            
            loginTop
                .padding(.top, 140)
                .background(alignment: .top) {
                    Image(uiImage: .loginTopSlogan)
                        .resizable()
                        .frame(height: 210)
                        .aspectRatio(contentMode: .fit)
                        .ignoresSafeArea(edges: .top)
                }
            
            
            VStack(spacing: 20) {
                
                Group {
                    Button(action: {}) {
                        Text("手机登录")
                    }
                    .foregroundColor(.pink.opacity(disabledPhoneLogin ? 0.5 : 1))
                    .disabled(disabledPhoneLogin)
                    
                    Button(action: {}) {
                        Text("一键登录")
                    }
                    
                }
                .frame(width: 200, height: 40)
                .background(RoundedRectangle(cornerRadius: 8).fill(.foreground))
                
                
            }
            //            .offset(y: -20)
            .padding(.top, -20)
            
            Spacer()
            
            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    // Configure the request here, if needed
                },
                onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        // Handle successful authorization
                        handleAuthorization(authorization)
                        break
                    case .failure(let error):
                        // Handle error
                        print("Authorization failed: \(error.localizedDescription)")
                    }
                }
            )
            .signInWithAppleButtonStyle(colorScheme == .light ? .black: .white) // Change button style here
            .frame(height: 44)
            .padding()
            
            HStack(spacing: 4) {
                Button(action: { selection.toggle() }) {
                    Image(systemName: selection ? "checkmark.square" : "square")
                }
                
                //  https://forums.developer.apple.com/forums/thread/720669
                Text(makeAttributedString())
                    .font(.footnote)
                    .environment(\.openURL, OpenURLAction { url in
                        print(url) // do what you like
                        return .handled  // compiler won't launch Safari
                    })
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    var loginTop: some View {
        VStack(spacing: 30) {
            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 20, topTrailing: 20))
                .fill(colorScheme == .light ? .primary : .secondary)
                .frame(height: 40)
                .overlay {
                    HStack {
                        ZStack {
                            Circle()
                                .foregroundColor(.green)
                                .frame(width: 16, height: 16)
                            
                            Circle()
                                .foregroundColor(.black)
                                .frame(width: 8, height: 8)
                        }
                        
                        Text("未注册的手机号注册后自动创建用户")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(colorScheme == .light ? .white : .primary)
                    }
                }
            
            
            Group {
                HStack {
                    Image(systemName: "iphone.gen1")
                    
                    TextField(text: $phone, prompt: Text("请输入手机号")) {
                        EmptyView()
                    }
                    .keyboardType(.phonePad)
                }
                
                HStack {
                    Image(systemName: "lock")
                    
                    TextField(text: $code, prompt: Text("请输入验证码")) {
                        EmptyView()
                    }
                    .textFieldStyle(.roundedBorder)
                    .overlay(alignment: .trailing) {
                        Button(action: {}) {
                            Text("获取验证码")
                                .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.yellow)
                        .padding(.trailing, 3)
                    }
                }
            }
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal, 20)
            
            
        }
        .frame(height: 224, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .foregroundColor(.secondary.opacity(0.2))
        }
        .overlay(alignment: .topTrailing) {
            Image(uiImage: .loginPin)
                .offset(y: -35)
        }
        .padding(.horizontal, 32)
        
    }
    
    func handleAuthorization(_ authorization: ASAuthorization) {
        
    }
    
    
    func makeAttributedString() -> AttributedString {
        var attributedString = AttributedString("我已阅读并同意《用户协议》和《隐私条款政策》")
        
        if let userAgreementRange = attributedString.range(of: "《用户协议》") {
            attributedString[userAgreementRange].foregroundColor = .accentColor
            attributedString[userAgreementRange].link = URL(string: "https://www.example.com/user-agreement")!
        }
        
        if let privacyPolicyRange = attributedString.range(of: "《隐私条款政策》") {
            attributedString[privacyPolicyRange].foregroundColor = .accentColor
            attributedString[privacyPolicyRange].link = URL(string: "https://www.example.com/privacy-policy")!
        }
        return attributedString
    }
}

#Preview {
    LoginPage()
}
