//
//  ViewController.swift
//  Example
//
//  Created by Paolo Ardia on 18/06/18.
//  Copyright © 2018 Paolo Ardia. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    @IBAction func callService(_ sender: Any) {
        ExampleServiceManager.shared.callService()
        
    }
}

