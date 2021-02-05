//
//  constants.swift
//  cms-mobility-demo
//
//  Created by Givens, Andrew on 1/21/21.
//

import Foundation
import AWSCore

//WARNING: To run this sample correctly, you must set the following constants.

let POLICY_NAME = "myIOTPolicy"

// This is the endpoint in your AWS IoT console. eg: https://xxxxxxxxxx.iot.<region>.amazonaws.com
let AWS_REGION = AWSRegionType.USWest2 //<- Change if necessary

let IOT_ENDPOINT = "https://[replace_me]-ats.iot.us-west-2.amazonaws.com"

// This is the identity of your Cognito Identity pool
let IDENTITY_POOL_ID = "us-west-2:[replace_me]"

//Used as keys to look up a reference of each manager
let AWS_IOT_DATA_MANAGER_KEY = "MyIotDataManager"
let AWS_IOT_MANAGER_KEY = "MyIotManager"

let AWS_CUSTOM_AUTHORIZER_NAME = "[replace_me]"
let AWS_AUTHORIZER_TOKEN_NAME = "[replace_me]"
let AWS_TOKEN_VALUE = "allow"
