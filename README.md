#  IoT Authentication Demo - iOS

Let's setup an iOS app to review the types of secure connections to AWS IoT.  This demo demonstrates the use of the AWS IoT API's to securely connect to IoT Core and publish or subscribe to an MQTT topic.  

This sample uses Cognito authentication, client certificates and a custom authorizer.

## Requirements

* Xcode 9.2 and later
* iOS 9 and later
* Existing CMS implementation in your AWS account

## Using the demo

1. Open Xcode. From the menu bar, select “File -> New -> Project…”

2. Select Single View App, and then select the Next button. 

3. Fill in the following for your project:

* Product Name: Todo
* Interface: SwiftUI
* Life Cycle: SwiftUI App (only relevant if Xcode 12 is being used)
* Language: Swift
* Select the Next button

4. After selecting Next, select where you would like to save your project, and then select Create.

You should now have an empty iOS project.

5. The AWS Mobile SDK for iOS is available through CocoaPods. If you have not installed CocoaPods, install CocoaPods: 

```
brew install cocoapods
brew link cocoapods
```

6. To initialize your project with the Cocoapods package manager, run the command:

```
pod init

vim Podfile
```

7. After doing this, you should see a newly created file called Podfile. This file is used to describe the packages your project depends on.

Open Podfile in the file editing tool of your choice, and replace the contents of the file so that your Podfile looks like the following:

```
target 'cms-mobility-demo' do
  Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  pod 'AWSIoT'
  pod 'AWSMobileClient'

end
```
8. To download and install the IoT pod into your project, run the command:

```
pod install --repo-update
```

9. After running the previous command, you should see the file named aws-iot-ios-authentication-demo.xcworkspace in your project directory. You are required to use this file from now on instead of the .xcodeproj file. To open your newly generated aws-iot-ios-authentication-demo.xcworkspace in Xcode, run the command:

            xed .

10. Open the constants.swift file and edit the ```IOT_ENDPOINT``` to IoT endpoint that is listed in the IoT Console under ```Settings``` and ```Endpoint```

## AWS Credentials-based Authentication

1. This sample requires Cognito to authorize to AWS IoT in order to create a device certificate. Use Amazon Cognito to create a new identity pool:

    * In the Amazon Cognito Console, press the ```Manage Federated Identities``` button and on the resulting page press the ```Create new identity pool``` button.

    * Give the identity pool a name and ensure that ```Enable access to unauthenticated identities ```under the ```Unauthenticated identities``` section is checked. This allows the sample application to assume the unauthenticated role associated with this identity pool. Press the ```Create Pool``` button to create your identity pool.

    * As part of creating the identity pool, Cognito will setup two roles in [Identity and Access Management (IAM)](https://console.aws.amazon.com/iam/home#roles). These roles will be named similar to: Cognito_PoolNameAuth_Role and Cognito_PoolNameUnauth_Role. You can view them by pressing the ```View Details``` button. Now press the ```Allow``` button to create the roles.

    * Save the Identity pool ID in the constants.swift file under the constant ```IDENTITY_POOL_ID```, it should look similar to: `us-east-1:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" and also replace the region that is being used. These will be used in the application code later.

2. At this point, we need to allow the Unauth_Role in Cognito to access IoT Core, so we need to modified the permissions associated with that role.  To do that, navigate to the  [Identity and Access Management (IAM) console](https://console.aws.amazon.com/iam/home#roles).  Click on ```Roles``` on the leftside menu and then search for the Unauth Cognito role that was created when the new identity pool was added.  **Note:

3.  Add the folllowing role ```AWSIoTDataAccess``` to the Unauth by pressing the ```Attach policies``` button and searching for the Role Name and pressing ```Attach policy``` in the bottom corner.

4. Now that your backend configuration is complete, you can start the application from xCode.  

5. When the application runs, click on the ```Connect``` button next to ```AWS Credentials based Authentication``` and you should see a message that says ```Connected to AWS IoT Core```.  Congratulations!  You can now subscribe and publish messages to the MQTT topic through the application.

## AWS Certificate-based Mutual Authentication

For some use cases, a customer may currently be using mutual authentication from iOS into an existing application and would like to use that same certificate in the keychain to access IoT Core.  In this example, we will use AWS X.509 certificates, but a customer can bring their own Certificate Authority (CA) and their own Private Key Infrastructure (PKI), but those specific use cases are outside the scope of this example.  In the below, you will connect to IoT core with a certificate that is created in AWS IoT, the simplest way of connecting to the AWS backend.

1. This sample requires a certificate created in AWS IoT, and an IoT Policy associated with that certificate to connect to IoT Core.  

2. To begin, in the AWS IoT Console, press the ```Certificates``` link under the ```Secure``` header.  Press the ```Create``` button and select ```One-click certificate creation``` .  This will create a public/private key that you can download on the next screen.  Make sure you click ```Activate``` to activate the certificate!  Download the public and private key to your local file system.

3. Next click ```Attach Policy``` and either select an existing policy that will allow the resource to Connect, Publish and Subscribe, or use the one included below:

    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": "iot:*",
          "Resource": "*"
        }
      ]
    }

3. Once the policy and certificate have been created, you need to create a p12 file that xCode can use.  Run the below command after replacing the certificate names with the ones you just downloaded.  This will create a p12 file called awsiot-identity.p12

    openssl pkcs12 -export -in [your cert name]-certificate.pem.crt -inkey [your cert name]-private.pem.key -out awsiot-identity.p12

4. Drop the p12 file into your xCode workspace and apply it to all targets.  The sample will search for a p12 file in the bundle and select the first one, so modifications will be necessary if needing to connect with multiple certificates.

5. Build and run the sample app on two different simulators or devices. After you connect then changes in one devices publish panel will show up in the other devices subscribe panel.

## AWS Custom Authoriser Authentication

Other use cases for authentication to AWS IoT could be an existing authentication implementation on a mobile device using OAuth via JWT or SAML tokens.  Using a Custom Authorizer enables you to use these tokens for access control.  The below sample is a very simple example of a signed token with a single word "allow" but this example can be extended to support standard JWT  bearer tokens with specific access rights within to token.  The below sample will help you setup an end to end authoriser to control access privlieges on the connection to AWS IoT.

1. The first step is creating a Lambda function which will take the authorization token in the input and verify it.  The token signature is verified and the token is decrypted before invoking the Lambda, so there will not be code in the Lamdba to validate the token signature, only validating the contents of the token.  Once validated, a policy will be returned authorizing the user to connect to AWS IoT.  

2. From the Lambda Console, press the ```Create function``` button, name your function and select a runtime of Node.js 14.x.  Press ```Create function``` and paste the below in the ```Function code``` section.  Replace the region and account number the below, save your changes, then push the ```Deploy``` button.


        exports.handler =  async (event, context, callback) => {
            console.log(`event: ${JSON.stringify(event)}\n`)
                var token = event.token; 
                switch (token.toLowerCase()) { 
                    case 'allow': 
                        var authresponse = generateAuthResponse(token, 'Allow')
                        console.log(`token: ${JSON.stringify(authresponse)}\n`)
                        callback(null, authresponse); 
                    case 'deny': 
                        callback(null, generateAuthResponse(token, 'Deny')); 
                    default: 
                        callback("Error: Invalid token"); 
                }
        };


        var generateAuthResponse = function(token, effect) {
         
             var authResponse = {};
             authResponse.isAuthenticated = true;
             authResponse.principalId = 'principalId';

             var policyDocument = {};
             policyDocument.Version = '2012-10-17';
             policyDocument.Statement = [];
             var statement = {};
             statement.Action = 'iot:Connect'; 
             statement.Effect = effect; 
             statement.Resource = "*"; 
             policyDocument.Statement[0] = statement;
             var statement2 = {};
             statement2.Action = 'iot:Publish'; 
             statement2.Effect = effect; 
             statement2.Resource = "*"; 
             policyDocument.Statement[1] = statement2;
             authResponse.policyDocuments = [policyDocument];
             authResponse.disconnectAfterInSeconds = 3600;
             authResponse.refreshAfterInSeconds = 600;

            return authResponse;
        }

2. From the IoT Core Console, select ```Authorizers``` under the ```Secure``` menu.

3. Push ```Create``` button and name your Authorizer.  This will be used in the constants.swift file after created.  Select the Lambda function you just created in the previous step.

4. To sign the token we will use a RSA key pair, the private key will be used in our XCode app and the public key will be used to decrypted the token in the IoT Authoriser.  To create this key pair, go to your command line and use OpenSSL to create the pem.

        openssl genrsa -out private.pem 2048

5. Run the following to create the public key from the key pair

        openssl rsa -in private.pem -outform PEM -pubout -out public.pem

5. Ensure ```Enable token signing``` is checked.  As noted, this will help prevent excess triggering of your Lambda by unauthorized clients.  Select a token header name, a key name and paste in the public key from public.pem that was generated in the previous step.  Note: Make sure the value includes ```-----BEGIN PUBLIC KEY------``` and ```------END PUBLIC KEY------``` Check ```Activate authorizer``` and then press the ```Create authoriser``` button.

6. Drop the private.pem into your XCode workspace and update the constants with the values you just created.

7.  Build and run the app and press the ```Connect``` button next to ```Custom Authoriser```  

