//
//  connectionHandler.swift
//  cms-mobility-demo
//
//  Created by Givens, Andrew on 1/21/21.
//

import Foundation
import AWSCore
import AWSIoT
import AWSMobileClient

class connectionHandler : ObservableObject {
    
    var connectionStatus: String = "Disconnected"
    var messageIdToSetVisible: Int = 0
    var logOutput = Logs()

    @objc var iotDataManager: AWSIoTDataManager!
    @objc var iotManager: AWSIoTManager!
    @objc var iot: AWSIoT!
    
    struct Logs: Hashable, Codable {
        var entry: [Entry] = []
    }

    struct Entry: Hashable, Codable, Identifiable {
        public var id: Int
        let body: String
        let ts : String
    }
    
    enum connectionType {
        case certBased, credentialsBased, customBased
        
    }
    
    func appendLogs(text: String) {
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let newMessageId = messageIdToSetVisible + 1
        let newLog = Entry(id: newMessageId, body: text, ts: formatter.string(from: now) )
        self.logOutput.entry.append(newLog)
        messageIdToSetVisible = newMessageId
    }
    
    func disconnectFromAWSIoT() {
        do {
            appendLogs(text: "Attempting to disconnect from IoT Core gateway with ID ")
            
            let dataManager = AWSIoTDataManager(forKey: AWS_IOT_DATA_MANAGER_KEY)
            dataManager.disconnect()
            
        } catch {
            appendLogs(text: "Error, failed to disconnect from device gateway => \(error)")
        }
    }
    func setupAWSConnection(type: connectionType, completion: @escaping (_ connected: Bool, _ error: String?) -> Void) {
        // Create AWS credentials and configuration
        let credentials = AWSCognitoCredentialsProvider(regionType:AWS_REGION, identityPoolId: IDENTITY_POOL_ID)
        let configuration = AWSServiceConfiguration(region:AWS_REGION, credentialsProvider: credentials)
        self.appendLogs(text: "Connecting to AWS IoT in region -> \(AWS_REGION)")
        self.appendLogs(text: "Using Cognito Identity Pool Id ->  \(IDENTITY_POOL_ID)")
        let controlPlaneServiceConfiguration = AWSServiceConfiguration(region:AWS_REGION, credentialsProvider:credentials)
                
        //IoT control plane seem to operate on iot.<region>.amazonaws.com
        //Set the defaultServiceConfiguration so that when we call AWSIoTManager.default(), it will get picked up
        AWSServiceManager.default().defaultServiceConfiguration = controlPlaneServiceConfiguration
        iotManager = AWSIoTManager.default()
        
        // Initialising AWS IoT And IoT DataManager
        AWSIoT.register(with: configuration!, forKey: AWS_IOT_MANAGER_KEY)  // Same configuration var as above
        iot = AWSIoT.default()
        let iotEndPoint = AWSEndpoint(urlString: IOT_ENDPOINT) // Access from AWS IoT Core --> Settings
        let iotDataConfiguration = AWSServiceConfiguration(region: AWS_REGION,     // Use AWS typedef .Region
                                                           endpoint: iotEndPoint,
                                                           credentialsProvider: credentials)  // credentials is the same var as created above

        AWSIoTDataManager.register(with: iotDataConfiguration!, forKey: AWS_IOT_DATA_MANAGER_KEY)
        self.iotDataManager = AWSIoTDataManager(forKey: AWS_IOT_DATA_MANAGER_KEY)
        // Access the AWSDataManager instance as follows:
        getAWSClientID(completion: { clientId, error in
            if let clientId = clientId {
                self.appendLogs(text: "Connecting to AWS IoT with clientId -> \(clientId)")
                self.connectToAWSIoT(clientId: clientId, connectionType: type, completion: { connected, ee in
                    if let connected = connected {
                        completion(connected, ee)
                    }
                })
            }
            if let error = error {
                print("Error occured => \(error)")
            }
         })
    }
    
    func getAWSClientID(completion: @escaping (_ clientId: String?,_ error: Error? ) -> Void) {
            // Depending on your scope you may still have access to the original credentials var
            let credentials = AWSCognitoCredentialsProvider(regionType:AWS_REGION, identityPoolId: IDENTITY_POOL_ID)
            
            credentials.getIdentityId().continueWith(block: { (task:AWSTask<NSString>) -> Any? in
                if let error = task.error as NSError? {
                    self.appendLogs(text:  "Failed to get client ID => \(error)")
                    completion(nil, error)
                    return nil  // Required by AWSTask closure
                }
                
                let clientId = task.result! as String
                self.appendLogs(text:  "Got client ID => \(clientId)")
                completion(clientId, nil)
                return nil // Required by AWSTask closure
            })
        }

    func connectToAWSIoT(clientId: String!, connectionType: connectionType, completion: @escaping (_ connected: Bool?,_ error: String? ) -> Void) {
        
        func mqttEventCallback(_ status: AWSIoTMQTTStatus ) {
            switch status {
                case .connecting: self.appendLogs(text:  "Connecting to AWS IoT")
                case .connected:
                    self.appendLogs(text:  "Connected to AWS IoT")
                    self.connectionStatus = "Connected"
                    // Publish a boot message if required
                    completion(true, nil)
                case .connectionError:
                    self.appendLogs(text:  "AWS IoT connection error")
                    let dataManager = AWSIoTDataManager(forKey: AWS_IOT_DATA_MANAGER_KEY)
                    dataManager.disconnect()
                    completion(false, "AWS IoT connection error")
                case .connectionRefused: self.appendLogs(text: "AWS IoT connection refused")
                case .protocolError: self.appendLogs(text: "AWS IoT protocol error")
                case .disconnected: self.appendLogs(text: "AWS IoT disconnected")
                    self.appendLogs(text:  "AWS IoT certificate does not exist")
                    completion(false, "AWS IoT connection error")
                case .unknown: self.appendLogs(text: "AWS IoT unknown state")
                default: self.appendLogs(text: "Error - unknown MQTT state")
            }
        }
        
        // Ensure connection gets performed background thread (so as not to block the UI)
        DispatchQueue.global(qos: .background).async {
            do {
                self.appendLogs(text:  "Attempting to connect to IoT device gateway with ID = \(clientId!)")
                let dataManager = AWSIoTDataManager(forKey: AWS_IOT_DATA_MANAGER_KEY)
                switch connectionType {
                    case .credentialsBased:
                        self.iotDataManager.connectUsingWebSocket(withClientId: clientId,
                                                          cleanSession: true,
                                                          statusCallback: mqttEventCallback)
                    case .certBased:
                        let defaults = UserDefaults.standard
                        let certificateId = defaults.string( forKey: "certificateId")
                        if (certificateId == nil) {
                            self.appendLogs(text: "No identity available, searching bundle...")
                            
                            let certificateIdInBundle = self.searchForExistingCertificateIdInBundle()
                            
                            if (certificateIdInBundle == nil) {
                                self.appendLogs(text: "No identity found in bundle, please create one...")
                                mqttEventCallback(AWSIoTMQTTStatus.connectionRefused)
                            }
                        } else {
                            let uuid = UUID().uuidString;
                            // Connect to the AWS IoT data plane service w/ certificate
                            self.iotDataManager.connect( withClientId: uuid,
                                                         cleanSession:true,
                                                         certificateId:certificateId!,
                                                         statusCallback: mqttEventCallback)
                        }
                    case .customBased:
                        var sig = self.signToken(tokenValue: AWS_TOKEN_VALUE)
                        dataManager.connectUsingWebSocket(withClientId: clientId,
                                                             cleanSession: true,
                                                             customAuthorizerName: AWS_CUSTOM_AUTHORIZER_NAME,
                                                             tokenKeyName: AWS_AUTHORIZER_TOKEN_NAME,
                                                             tokenValue: AWS_TOKEN_VALUE,
                                                             tokenSignature: sig!,
                                                             statusCallback: mqttEventCallback)
                }
                
               
            } catch {
                self.appendLogs(text:  "Error, failed to connect to device gateway => \(error)")
            }
        }
    }
    
    func signToken(tokenValue: String!) -> String? {
        let defaults = UserDefaults.standard
        let myBundle = Bundle.main
        let myImages = myBundle.paths(forResourcesOfType: "pem" as String, inDirectory:nil)
        var error: Unmanaged<CFError>?
         
        guard let pKeyFile = myImages.first else {
            let privateKey = defaults.string(forKey: "private.key")
            return privateKey
        }
        
        // A private key file should exist in the bundle.  Attempt to load the first one
        // into the keychain (the others are ignored), and set the certificate ID in the
        // user defaults as the filename.  If the PKCS12 file requires a passphrase,
        // you'll need to provide that here; this code is written to expect that the
        // PKCS12 file will not have a passphrase.
        guard let rawdata = try? Data(contentsOf: URL(fileURLWithPath: pKeyFile)) else {
            print("[ERROR] Found PEM File in bundle, but unable to use it")
            let privateKey = defaults.string( forKey: "private.key")
            return privateKey
        }
        
        var certStr = String(decoding: rawdata, as: UTF8.self)

        let offset = String("-----BEGIN RSA PRIVATE KEY-----").count
        let index = certStr.index(certStr.startIndex, offsetBy: offset+1)
        certStr = String(certStr.suffix(from: index))
       // remove end of line chars
        certStr = certStr.replacingOccurrences(of: "\n", with: "")
        // remove the tail string
        let tailWord = "-----END RSA PRIVATE KEY-----"
        if let lowerBound = certStr.range(of: tailWord)?.lowerBound {
            certStr = String(certStr.prefix(upTo: lowerBound))
        }
        
        let data = NSData(base64Encoded: certStr,
           options:NSData.Base64DecodingOptions.ignoreUnknownCharacters)!
        
        let value = tokenValue.data(using: .utf8)!
           
        let attributes: [NSObject:NSObject] = [
                    kSecAttrKeyClass: kSecAttrKeyClassPrivate,
                    kSecAttrKeyType: kSecAttrKeyTypeRSA,
                    kSecAttrKeySizeInBits: NSNumber(value: 256),
                    ]
        
        guard let privatekey: SecKey = SecKeyCreateWithData(data as CFData,
                                                      attributes as CFDictionary,
                                                      &error) else
        {
            return nil
        }
        guard let signedData = SecKeyCreateSignature(privatekey,
                                                     .rsaSignatureMessagePKCS1v15SHA256,
                                                         value as CFData,
                                                         &error) as Data? else
            {
                return nil
            }
        
        return signedData.base64EncodedString()
    }
    
    func searchForExistingCertificateIdInBundle() -> String? {
            let defaults = UserDefaults.standard
            // No certificate ID has been stored in the user defaults; check to see if any .p12 files
            // exist in the bundle.
            let myBundle = Bundle.main
            let myImages = myBundle.paths(forResourcesOfType: "p12" as String, inDirectory:nil)
            let uuid = UUID().uuidString

            guard let certId = myImages.first else {
                let certificateId = defaults.string(forKey: "certificateId")
                return certificateId
            }
            
            // A PKCS12 file may exist in the bundle.  Attempt to load the first one
            // into the keychain (the others are ignored), and set the certificate ID in the
            // user defaults as the filename.  If the PKCS12 file requires a passphrase,
            // you'll need to provide that here; this code is written to expect that the
            // PKCS12 file will not have a passphrase.
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: certId)) else {
                print("[ERROR] Found PKCS12 File in bundle, but unable to use it")
                let certificateId = defaults.string( forKey: "certificateId")
                return certificateId
            }
            
            self.appendLogs(text: "found identity \(certId), importing...")
            
            if AWSIoTManager.importIdentity( fromPKCS12Data: data, passPhrase:"", certificateId:certId) {
                // Set the certificate ID and ARN values to indicate that we have imported
                // our identity from the PKCS12 file in the bundle.
                defaults.set(certId, forKey:"certificateId")
                defaults.set("from-bundle", forKey:"certificateArn")
    
                self.appendLogs(text: "Using certificate: \(certId))")
            }
            
            let certificateId = defaults.string( forKey: "certificateId")
            return certificateId
        }

    func publishToTopic(topic: String) -> Void {
        self.iotDataManager.publishString("Hello from iOS",
                                     onTopic:topic,
                                     qoS:.messageDeliveryAttemptedAtMostOnce)
    }
}
