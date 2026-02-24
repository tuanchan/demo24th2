//
//  ShareViewController.swift
//  Share Extension
//
//  Created by Kasem Mohamed on 2019-05-30.
//  Copyright © 2019 The Chromium Authors. All rights reserved.
//

import UIKit
import receive_sharing_intent_swift

class ShareViewController: RSIShareViewController {

    override func shouldAutoRedirect() -> Bool {
        return false
    }

    override func presentationAnimationDidFinish() {
        super.presentationAnimationDidFinish()
        navigationController?.navigationBar.topItem?.rightBarButtonItem?.title = "Send"
    }
}
