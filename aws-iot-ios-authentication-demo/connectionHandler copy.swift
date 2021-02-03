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
        
        let controlPlaneServiceConfiguration = AWSServiceConfiguration(region:AWS_REGION, credentialsProvider:credentials)
                
        //IoT control plane seem to operate on iot.<region>.amazonaws.com
        //Set the defaultServiceConfiguration so that when we call AWSIoTManager.default(), it will get picked up
        AWSServiceManager.default().defaultServiceConfiguration = controlPlaneServiceConfiguration
        iotManager = AWSIoTManager.default()
        iot = AWSIoT.default()

        // Initialising AWS IoT And IoT DataManager
        AWSIoT.register(with: configuration!, forKey: AWS_IOT_MANAGER_KEY)  // Same configuration var as above
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
                        dataManager.connectUsingWebSocket(withClientId: clientId,
                                                          cleanSession: true,
                                                          statusCallback: mqttEventCallback)
                    case .certBased:
                        self.handleConnectViaCert
                            statusCallback: mqttEventCallback)
                    case .customBased:
                        dataManager.connectUsingWebSocket(withClientId: clientId,
                                                             cleanSession: true,
                                                             customAuthorizerName: "testAuth",
                                                             tokenKeyName: "testKey",
                                                             tokenValue: "testToken",
                                                             tokenSignature: "testSignature",
                                                             statusCallback: mqttEventCallback)
                }
                
               
            } catch {
                self.appendLogs(text:  "Error, failed to connect to device gateway => \(error)")
            }
        }
    }
    
    func handleConnectViaCert() {
           //self.connectIoTDataWebSocket.isHidden = true
           //activityIndicatorView.startAnimating()
           
           let defaults = UserDefaults.standard
           let certificateId = defaults.string( forKey: "certificateId")
           if (certificateId == nil) {
               self.appendLogs(text: "No identity available, searching bundle...")
               
               let certificateIdInBundle = searchForExistingCertificateIdInBundle()
               
               if (certificateIdInBundle == nil) {
                   self.appendLogs(text: "No identity found in bundle, creating one...")
                   
                   createCertificateIdAndStoreinNSUserDefaults(onSuccess: {generatedCertificateId in
                       let uuid = UUID().uuidString
                    self.appendLogs(text: "Using certificate: \(generatedCertificateId)")
                       self.iotDataManager.connect( withClientId: uuid, cleanSession:true, certificateId:generatedCertificateId, statusCallback: self.mqttEventCallback)
                   }, onFailure: {error in
                        self.appendLogs(text: "Received error: \(error)")
                    commpletion()
                   })
               }
           } else {
               let uuid = UUID().uuidString;
               // Connect to the AWS IoT data plane service w/ certificate
               iotDataManager.connect( withClientId: uuid, cleanSession:true, certificateId:certificateId!, statusCallback: self.mqttEventCallback)
           }
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
                DispatchQueue.main.async {
                    self.appendLogs(text: "Using certificate: \(certId))")
                    let dataManager = AWSIoTDataManager(forKey: AWS_IOT_DATA_MANAGER_KEY)
                    dataManager.connect( withClientId: uuid,
                                                 cleanSession:true,
                                                 certificateId:certId,
                                                 statusCallback: self.mqttEventCallback)
                }
            }
            
            let certificateId = defaults.string( forKey: "certificateId")
            return certificateId
        }

        func createCertificateIdAndStoreinNSUserDefaults(onSuccess:  @escaping (String)->Void,
                                                         onFailure: @escaping (Error) -> Void) {
            let defaults = UserDefaults.standard
            // Now create and store the certificate ID in NSUserDefaults
            let csrDictionary = [ "commonName": CertificateSigningRequestCommonName,
                                  "countryName": CertificateSigningRequestCountryName,
                                  "organizationName": CertificateSigningRequestOrganizationName,
                                  "organizationalUnitName": CertificateSigningRequestOrganizationalUnitName]
            
            self.iotManager.createKeysAndCertificate(fromCsr: csrDictionary) { (response) -> Void in
                guard let response = response else {
                    self.appendLogs(text: "Unable to create keys and/or certificate, check values in Constants.swift")
                    self.appendLogs(text: "No response on iotManager.createKeysAndCertificate")
                    return
                }
                defaults.set(response.certificateId, forKey:"certificateId")
                defaults.set(response.certificateArn, forKey:"certificateArn")
                let certificateId = response.certificateId
                self.appendLogs(text: "response: [\(String(describing: response))]")
                
                let attachPrincipalPolicyRequest = AWSIoTAttachPrincipalPolicyRequest()
                attachPrincipalPolicyRequest?.policyName = POLICY_NAME
                attachPrincipalPolicyRequest?.principal = response.certificateArn
                
                // Attach the policy to the certificate
                self.iot.attachPrincipalPolicy(attachPrincipalPolicyRequest!).continueWith (block: { (task) -> AnyObject? in
                    if let error = task.error {
                        print("Failed: [\(error)]")
                        onFailure(error)
                    } else  {
                        print("result: [\(String(describing: task.result))]")
                        DispatchQueue.main.asyncAfter(deadline: .now()+2, execute: {
                            
                            statusCallback: mqttEventCallback) if let certificateId = certificateId {
                                onSuccess(certificateId)
                            } else {
                                onFailure(NSError(domain: "Unable to generate certificate id", code: -1, userInfo: nil))
                            }
                        })
                    }
                    return nil
                })
            }
        }
    func mqttEventCallback( _ status: AWSIoTMQTTStatus ) {
            DispatchQueue.main.async {
               
                self.appendLogs(text: "connection status = \(status.rawValue)")

                switch status {
                case .connecting:
                    self.appendLogs(text: "Connecting...")
               
                    
                case .connected:
                    self.appendLogs(text: "Connected")
                    //self.appendLogs(text: "Using certificate:\n\(certificateId!)\n\n\nClient ID:\n\(uuid)")
                    
                case .disconnected:
                    self.appendLogs(text: "Disconnected")
                    
                case .connectionRefused:
                    self.appendLogs(text: "Connection Refused")
                    
                case .connectionError:
                    self.appendLogs(text: "Connection Error")
                    
                case .protocolError:
                    self.appendLogs(text: "Protocol Error")
                    
                default:
                    self.appendLogs(text: "Unknown State")
                }
                

            }
        }
        
}
