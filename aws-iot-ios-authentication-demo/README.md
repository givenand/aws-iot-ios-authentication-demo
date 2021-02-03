#  IoT Authentication Demo - iOS

Let's setup a phone app to track bikes, people and urban movement utilizing CMS.  No certificates, so we'll use cognito federated identities

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

9. After running the previous command, you should see the file named Todo.xcworkspace in your project directory. You are required to use this file from now on instead of the .xcodeproj file. To open your newly generated Todo.xcworkspace in Xcode, run the command:

10. This sample requires Cognito to authorize to AWS IoT in order to create a device certificate. Use Amazon Cognito to create a new identity pool:

    * In the Amazon Cognito Console, press the Manage Federated Identities button and on the resulting page press the Create new identity pool button.

    * Give your identity pool a name and ensure that Enable access to unauthenticated identities under the Unauthenticated identities section is checked. This allows the sample application to assume the unauthenticated role associated with this identity pool. Press the Create Pool button to create your identity pool.

    * As part of creating the identity pool, Cognito will setup two roles in Identity and Access Management (IAM). These will be named something similar to: Cognito_PoolNameAuth_Role and Cognito_PoolNameUnauth_Role. You can view them by pressing the View Details button. Now press the Allow button to create the roles.

    * Save the Identity pool ID in the awsconfiguration.xcconfig file that shows up in red in the "Getting started with Amazon Cognito" page, it should look similar to: `us-east-1:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" and also replace the region that is being used. These will be used in the application code later.

```
"CognitoIdentity": {
    "Default": {
        "PoolId": "REPLACE_ME",
        "Region": "REPLACE_ME"
    }
}
```
