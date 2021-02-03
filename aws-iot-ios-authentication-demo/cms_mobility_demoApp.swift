//
//  cms_mobility_demoApp.swift
//  cms-mobility-demo
//
//  Created by Givens, Andrew on 1/21/21.
//

import SwiftUI
import AWSIoT

@main
struct cms_mobility_demoApp: App {
    var ch = connectionHandler()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(ch)
        }
    }
}
