# Installation

To install this Hyperpay helper you need to :

1- download the latest framework they provided to you, they usually send the link to download via email.

2- drag and drop this helper to your code

3- add this code in your "AppDelegate.swift" file
```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        let hyperH = HyperpayHelpers.shared
        if url.scheme?.caseInsensitiveCompare("\(hyperH.appIdentifire).payments") == .orderedSame {
            HyperpayHelpers.shared.checkPaymentStatusFromRedirect()
        }
        return true
    }
```

4- In Xcode, click on your project in the Project Navigator and navigate to App Target > Info > URL Types
Click [+] to add a new URL type
Under URL Schemes, enter your app switch return URL scheme. This scheme must start with your app's Bundle ID. For example, if the app bundle ID is com.companyname.appname, then your URL scheme could be com.companyname.appname.payments.
Add scheme URL to a whitelist in your app's Info.plist:
```
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>com.companyname.appname.payments</string>
</array>
```

5- if you need to use ApplePay you need to follow this instruction: [ApplePay instructions](https://developer.apple.com/library/archive/ApplePay_Guide/Configuration.html)

6- after you finish all these steps you need to change the strings in "HyperpayHelpers.swift"

7- the last point you need to do for this helper is to replace the RequestWrapper in "HyperpayHelpers.swift" with your requests in your app


## Usage

```swift
HyperpayHelpers.shared.openHyperpayVC(amount: amount, couponCode: self.txtCopon.text, parentVC: self) { payment_order_id, responceCodeNumber in
                
            }
```

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate.