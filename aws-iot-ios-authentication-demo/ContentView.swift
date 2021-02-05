//
//  ContentView.swift
//  cms-mobility-demo
//
//  Created by Givens, Andrew on 1/21/21.
//

import SwiftUI

struct CustomText: View {
    var text: String

    var body: some View {
        Text(text)
    }

    init(_ text: String) {
        print("Creating a new CustomText")
        self.text = text
    }
}
struct connectView: View {
    @EnvironmentObject var ch: connectionHandler
    @State var connectedTxt = "AWS IoT CMS Demo"
    @State var credentialsbuttonTxt = "Connect"
    @State var certificatebuttonTxt = "Connect"
    @State var custombuttonTxt = "Connect"
    @State var isPresentingAlert = false
    @State private var selectedTab = 0

    func connect() {
        if(credentialsbuttonTxt == "Connect") {
            DispatchQueue.main.async {
                ch.setupAWSConnection(type: connectionHandler.connectionType.credentialsBased,completion:  { connected, err in
                    if connected {
                        credentialsbuttonTxt = "Disconnect"
                    } else {
                        isPresentingAlert = true
                    }
                })
            }
        } else {
            ch.disconnectFromAWSIoT()
            credentialsbuttonTxt = "Connect"
        }
    }
    
    func connectCert() {
        if(certificatebuttonTxt == "Connect") {
                ch.setupAWSConnection(type: connectionHandler.connectionType.certBased,
                                      completion:  { connected, err in
                                        if connected {
                                            certificatebuttonTxt = "Disconnect"
                                        } else {
                                            isPresentingAlert = true
                                        }
                                      })
        } else {
            ch.disconnectFromAWSIoT()
            certificatebuttonTxt = "Connect"
        }
    }

    func connectCustom() {
        if(custombuttonTxt == "Connect") {
            ch.setupAWSConnection(type: connectionHandler.connectionType.customBased,
                                  completion:  { connected, err in
                                    if connected {
                                        custombuttonTxt = "Disconnect"
                                    } else {
                                        isPresentingAlert = true
                                    }
        })
        } else {
            ch.disconnectFromAWSIoT()
            custombuttonTxt = "Connect"
        }
    }
    var body: some View {
        VStack(alignment: .leading) {
            Text(connectedTxt)
                .padding()
                .frame(
                  width: UIScreen.main.bounds.width,
                  height: 50
                )
                .background(Color.blue)
                .foregroundColor(Color.white)
                .padding(10)
            Spacer(minLength: 10)
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical) {
                    VStack(spacing: 5) {
                        ForEach(ch.logOutput.entry) { entry in
                            return Text("   " + entry.ts + " " + entry.body)
                                .font(.custom("SFMono-Regular", size: 10))
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .topLeading
                                    )
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }.onChange(of: ch.messageIdToSetVisible) { id in
                    guard id != 0 else { return }
                    withAnimation {
                        scrollProxy.scrollTo(id)
                    }
                }
            }
            .padding(.leading, 10.0)
            HStack {
                Text("AWS Credentials Based Authentication")
                    .padding()
                    .font(.system(size: 14))
                    .frame(
                      height: 50,
                        alignment: .topLeading
                    )
                    .foregroundColor(Color.white)
                    .padding(10)
                Spacer()
                Button(
                    action: { self.connect() },
                        label: { Text(credentialsbuttonTxt) }
                      )
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.orange)
                    .cornerRadius(8)
                    .onTapGesture {
                        self.selectedTab = 1
                    }
            }.frame(maxWidth: .infinity)
            HStack {
                Text("Certificate based mutual authentication")
                    .padding()
                    .font(.system(size: 14))
                    .frame(
                      height: 50
                    )
                    .foregroundColor(Color.white)
                    .padding(10)
                Spacer()
                Button(
                    action: { self.connectCert() },
                        label: { Text(certificatebuttonTxt) }
                      )
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.orange)
                    .cornerRadius(8)
            }.frame(maxWidth: .infinity)
            HStack {
                Text("    Custom authentication")
                    .font(.system(size: 14))
                    .frame(
                      height: 50
                    )
                    .foregroundColor(Color.white)
                    .padding(10)
                Spacer()
                Button(
                    action: { self.connectCustom() },
                        label: { Text(custombuttonTxt) }
                      )
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.orange)
                    .cornerRadius(8)
            }.frame(maxWidth: .infinity)
        }
        .alert(isPresented: self.$isPresentingAlert, content: {
            Alert(title: Text("Error connecting to AWS IoT Core"))
        })
    }
}

struct subscribeView: View {
    @EnvironmentObject var ch: connectionHandler
    @State private var topic: String = "testTopic"

    var body: some View {
        VStack(spacing: 16) {
            if(ch.subscribeMessages.entry.count != 0) {
                ScrollViewReader { scrollProxy in
                ScrollView(.vertical) {
                    VStack(spacing: 5) {
                        ForEach(ch.subscribeMessages.entry) { entry in
                            return Text("   " + entry.ts + " " + entry.body)
                                .font(.custom("SFMono-Regular", size: 10))
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .topLeading
                                    )
                        }
                    }
                    .frame(maxWidth: .infinity)
                }.onChange(of: ch.msgId) { id in
                    guard id != 0 else { return }
                    withAnimation {
                        scrollProxy.scrollTo(id)
                        print(id)
                    }
                }
                }
            }
            Spacer()
            HStack() {
            Text("Subscribe to")
            TextField("Topic", text: $topic)
            Button(
                action: { ch.subscribeToTopic(topic: topic) },
                    label: { Text("Subscribe") }
                  )
                .foregroundColor(.white)
                .padding(10)
                .background(Color.orange)
                .cornerRadius(8)
            }
        }
    }
}

struct publishView: View {
    @EnvironmentObject var ch: connectionHandler
    @State private var topic: String = "testTopic"

    var body: some View {
        VStack(spacing: 16) {
            Text("Publish to")
            TextField("Topic", text: $topic)
            Button(
                action: { ch.publishToTopic(topic: topic) },
                    label: { Text("Publish") }
                  )
                .foregroundColor(.white)
                .padding(10)
                .background(Color.orange)
                .cornerRadius(8)
        }
    }
}
struct ContentView: View {
    @State private var selectedTab: Int = 0
    @EnvironmentObject var ch: connectionHandler

    //ch = connectionHandler()
    var body: some View {
        TabView {
            connectView()
             .tabItem {
                Image(systemName: "checkmark.icloud.fill")
                Text("Connect")
           }
            subscribeView()
             .tabItem {
                Image(systemName: "icloud.and.arrow.down.fill")
                Text("Subscribe")
          }
            publishView()
             .tabItem {
                Image(systemName: "icloud.and.arrow.up.fill")
                Text("Publish")
          }
        }
    }
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
