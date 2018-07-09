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

    
    @IBAction func toggleDemoMode(_ sender: UISwitch) {
        ExampleServiceManager.shared().useDemoMode = sender.isOn
    }
    
    @IBAction func getResources(_ sender: Any) {
        ExampleServiceManager.shared().getResources { (response) in
        }
    }
    
    @IBAction func postResource(_ sender: Any) {
        let resource = Resource(id: "1", name: "name1", boolean: true, double: 1.1, nestedObjects: [NestedObject(id: "101", name: "nested101")])
        ExampleServiceManager.shared().postResource(resource) { (response) in

        }
    }
    
    @IBAction func getResourceById(_ sender: Any) {
        ExampleServiceManager.shared().getResource(with: 1) { (response) in
        }
    }
    
    @IBAction func uploadFile(_ sender: Any) {
        ExampleServiceManager.shared().uploadImage { (response) in
        }
    }
    
    @IBAction func downloadImage(_ sender: Any) {
        ExampleServiceManager.shared().downloadImage { (response) in
            
        }
    }
    
}

