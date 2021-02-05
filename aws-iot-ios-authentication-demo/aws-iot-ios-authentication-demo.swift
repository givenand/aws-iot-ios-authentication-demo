//
//  aws-iot-ios-authentication-demo.swift
//  aws-iot-ios-authentication-demo
//
//  Created by Givens, Andrew on 1/21/21.
//

import SwiftUI
import AWSIoT
import AWSMobileClient

@main
struct aws_iot_ios_authentication_demoApp: App {
    var ch = connectionHandler()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(ch)
        }
    }
}
