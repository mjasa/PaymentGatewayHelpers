//
//  HyperpayHelpers.swift
//  EasyCare
//
//  Created by Mo'min J.Abusaada on 3/23/21.
//

import UIKit
enum TPaymentWayType:Int {
    case visa = 1
    case mada = 2
    case apple_pay
    case stc
    
    var s_title:String{
        switch self {
            case .apple_pay:
                return "TPaymentWayType_apple_pay".localize_
            case .stc:
                return "TPaymentWayType_stc".localize_
            case .visa:
                return "TPaymentWayType_visa".localize_
            case .mada:
                return "TPaymentWayType_mada".localize_
        }
    }
    
    static var allCases:[TPaymentWayType] = [.apple_pay,.visa,.mada]
}

class HyperpayHelpers: NSObject {
    static let shared = HyperpayHelpers()

    var lastType: TPaymentWayType?
    var lastTransactionId: String?
    var lastPaymentOrderId: String?
    var sendCheckRequestAfterApplePay = false

    var checkoutProvider: OPPCheckoutProvider?
    let provider = OPPPaymentProvider(mode: GlobalConstants.KHyperpayEnviroment)
    let applePaymentRequest = PKPaymentRequest()
    var appleTransaction: OPPTransaction?

    var parentViewController: UIViewController?

    var openHyperpayVCCompletionBlock: (_ payment_order_id:String?,_ responceCodeNumber: NSNumber?) -> Void = { _,_  in}

    
    ///Strings///
    var appIdentifire = "com.app"
    var appName = "Your App"
    var applePayNotSupport = "Apple Pay not supported.".localize_
    var errorMSG = "An error occurred".localize_
    var selectPaymentTypeTitle = "HyperpayHelpers_Alert_selectPaymentWay_title".localize_
    var selectPaymentTypeMSG = "HyperpayHelpers_Alert_selectPaymentWay_message".localize_
    var cancelBtn = "Cancel".localize_
    var currencyCode = "SAR"
    var countryCode = "SA"
    ///Strings///
    
    
    func openHyperpayVC(amount: NSNumber?,couponCode:String?, parentVC: UIViewController, completionBlock: @escaping (_ payment_order_id:String?,_ responceCodeNumber: NSNumber?) -> Void) {
        self.parentViewController = parentVC
        self.openHyperpayVCCompletionBlock = completionBlock
        
        self.selectPaymentType(parentVC: parentVC) { (type) in
            self.initCheckout(type: type, amount: amount,couponCode:couponCode) { (transaction_id,payment_order_id,responceCodeNumber) in
                if responceCodeNumber != nil || transaction_id == nil{
                    completionBlock(nil, responceCodeNumber)
                    return
                }
                self.lastPaymentOrderId = payment_order_id
                
                let checkoutSettings = OPPCheckoutSettings()
                if type == .mada {
                    checkoutSettings.paymentBrands = ["MADA"]
                    checkoutSettings.storePaymentDetails = .prompt
                } else if type == .visa{
                    checkoutSettings.paymentBrands = ["VISA","MASTER"]
                }  else if type == .stc{
                    checkoutSettings.paymentBrands = ["STC_PAY"]
                } else if type == .apple_pay {
                    let Decimalamount = NSDecimalNumber(value: amount?.doubleValue ?? 0.0)
                    
                    let paymentItem = PKPaymentSummaryItem(label: self.appName, amount: Decimalamount.round(2))
                    let paymentNetworks: [PKPaymentNetwork]!
                    if #available(iOS 12.1.1, *) {
                        paymentNetworks = [PKPaymentNetwork.amex, .discover, .masterCard, .visa, .mada]
                    } else {
                        paymentNetworks = [PKPaymentNetwork.amex, .discover, .masterCard, .visa]
                    }
                    
                    self.applePaymentRequest.currencyCode = self.currencyCode
                    self.applePaymentRequest.countryCode = self.countryCode
                    self.applePaymentRequest.merchantIdentifier = "merchant.\(self.appIdentifire)"
                    self.applePaymentRequest.merchantCapabilities = PKMerchantCapability.capability3DS
                    self.applePaymentRequest.supportedNetworks = paymentNetworks
                    self.applePaymentRequest.paymentSummaryItems = [paymentItem]
                    
                    let request = OPPPaymentProvider.paymentRequest(withMerchantIdentifier: self.applePaymentRequest.merchantIdentifier, countryCode: self.applePaymentRequest.countryCode)
                    request.currencyCode = self.applePaymentRequest.currencyCode
                    request.countryCode = self.applePaymentRequest.countryCode
                    request.paymentSummaryItems = self.applePaymentRequest.paymentSummaryItems
                    request.supportedNetworks = self.applePaymentRequest.supportedNetworks
                    request.merchantCapabilities = self.applePaymentRequest.merchantCapabilities
                    if OPPPaymentProvider.canSubmitPaymentRequest(request) {
                        if let vc = PKPaymentAuthorizationViewController(paymentRequest: request) as PKPaymentAuthorizationViewController? {
                            vc.delegate = self
                            parentVC.present(vc, animated: true, completion: nil)
                        } else {
                            parentVC.showErrorMessage(message: self.applePayNotSupport)
                        }
                    } else {
                        parentVC.showErrorMessage(message: self.applePayNotSupport)
                    }
                    return
                }
                checkoutSettings.shopperResultURL = "\(self.appIdentifire).payments://result"
                
                checkoutSettings.storePaymentDetails = .always
                self.checkoutProvider = OPPCheckoutProvider(paymentProvider: self.provider, checkoutID: transaction_id ?? "", settings: checkoutSettings)
                self.checkoutProvider?.presentCheckout(forSubmittingTransactionCompletionHandler: { transaction, error in
                    if let errorStr = error?.localizedDescription {
                        self.checkoutProvider?.dismissCheckout(animated: true, completion: {
                            parentVC.showErrorMessage(message: errorStr)
                        })
                        return
                    }
                    if transaction?.redirectURL != nil {
                        // Request from AppDelegate
                    } else {
                        self.checkPaymentStatus(type: type, transaction_id: transaction_id) {
                            completionBlock(payment_order_id, nil)
                            self.clearHyper()
                        }
                    }
                }, cancelHandler: {
                    //User press cancel button
                })
            }
        }
        
    }
    func selectPaymentType(parentVC: UIViewController,_ completionBlock: @escaping (_ type: TPaymentWayType) -> Void){
        let alertController = UIAlertController(title: self.selectPaymentTypeTitle, message: self.selectPaymentTypeMSG , preferredStyle:.alert)
        for paymentType in TPaymentWayType.allCases {
            alertController.addAction(UIAlertAction(title: paymentType.s_title, style:.default, handler: { (action) in
                completionBlock(paymentType)
            }))
        }
        alertController.addAction(UIAlertAction(title: self.cancelBtn, style:.cancel, handler: { (action) in
            
        }))
        parentVC.present(alertController, animated: true, completion: nil)
    }
    func initCheckout(type: TPaymentWayType, amount: NSNumber?,couponCode:String?, completionBlock: @escaping (_ transaction_id: String?,_ payment_order_id:String?,_ responceCodeNumber: NSNumber?) -> Void) {
        //Here you need to make a request to server to get the transaction id base on type of payment you need
        let request = HyperRequest(.initCheckout(amount: amount, couponCode:couponCode, type: type))
        RequestWrapper.sharedInstance.makeRequest(request: request).didComplete({ (res, error) in
            switch res?.result {
            case .success(let data):
                if data is NSDictionary {
                    let responseJson = BaseResponse(data as! NSDictionary)
                    if responseJson.status?.codeNumber?.intValue != 200 {
                        completionBlock(nil,nil, responseJson.status?.codeNumber)
                    }
                }
                break
            case .none,.failure(_):
                break
            }
        }).executeWithCheckResponse(showLodaer: true, showMsg: true) { responce in
            if let transaction_id = responce.transaction_id {
                self.lastTransactionId = transaction_id
                self.lastType = type
                completionBlock(transaction_id,responce.payment_order_id, nil)
            }
        }
    }

    func checkPaymentStatus(type: TPaymentWayType, transaction_id: String?, completionBlock: @escaping () -> Void) {
        //Here you need to make a request to server to check payment status
        let request = HyperRequest(.checkStatus(hyperpay_id: transaction_id, type: type))
        RequestWrapper.sharedInstance.makeRequest(request: request).executeWithCheckResponse(showLodaer: true, showMsg: true) { _ in
            completionBlock()
        }
    }

    func checkPaymentStatusFromRedirect() {
        self.checkoutProvider?.dismissCheckout(animated: true, completion: {
            //Here you need to make a request to server to check payment status
            self.checkPaymentStatus(type: self.lastType ?? .visa, transaction_id: self.lastTransactionId) {
                self.openHyperpayVCCompletionBlock(self.lastPaymentOrderId, nil)
                self.clearHyper()
            }
        })
    }

    func clearHyper() {
        self.lastTransactionId = nil
        self.lastType = nil
        self.openHyperpayVCCompletionBlock = { _,_ in}
    }
}

// MARK: PKPaymentAuthorizationViewControllerDelegate
extension HyperpayHelpers: PKPaymentAuthorizationViewControllerDelegate, OPPCheckoutProviderDelegate {
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        controller.dismiss(animated: true, completion: {
            if self.sendCheckRequestAfterApplePay == true {
                self.sendCheckRequestAfterApplePay = false
                self.checkPaymentStatus(type: self.lastType ?? .visa, transaction_id: self.lastTransactionId) {
                    self.openHyperpayVCCompletionBlock(self.lastPaymentOrderId, nil)
                    self.clearHyper()
                }
            }
        })
    }

    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        let asyncSuccessful = payment.token.paymentData.count != 0
        guard let transactionId = self.lastTransactionId else {
            self.parentViewController?.showErrorMessage(message: self.errorMSG)
            return
        }
        if asyncSuccessful {
            if let params = try? OPPApplePayPaymentParams(checkoutID: transactionId, tokenData: payment.token.paymentData) as OPPApplePayPaymentParams? {
                self.appleTransaction = OPPTransaction(paymentParams: params!)
                params?.shopperResultURL = "\(self.appIdentifire).payments://result"
                self.provider.submitTransaction(OPPTransaction(paymentParams: params!), completionHandler: { _, error in
                    if error != nil {
                        self.parentViewController?.showErrorMessage(message: error?.localizedDescription ?? self.errorMSG)
                        self.sendCheckRequestAfterApplePay = false
                        completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                    } else {
                        self.provider.requestCheckoutInfo(withCheckoutID: transactionId) { _, _ in
                            self.sendCheckRequestAfterApplePay = true
                            completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
                        }
                    }
                })
            }
        } else {
            self.parentViewController?.showErrorMessage(message: self.errorMSG)
            self.sendCheckRequestAfterApplePay = false
            completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
        }
    }
}
