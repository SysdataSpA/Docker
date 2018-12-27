//
//  ViewController.swift
//  Example
//
//  Created by Paolo Ardia on 18/06/18.
//  Copyright © 2018 Paolo Ardia. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    let serviceManager = ExampleServiceManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    @IBAction func toggleDemoMode(_ sender: UISwitch) {
        serviceManager.useDemoMode = sender.isOn
    }
    
    @IBAction func getResources(_ sender: Any) {
        serviceManager.getResources { (response) in
            
        }
    }
    
    @IBAction func postResource(_ sender: Any) {
        let resource = Resource(id: "1", name: "name1", boolean: true, double: 1.1, nestedObjects: [NestedObject(id: "101", name: "nested101")])
            serviceManager.postResource(resource) { (response) in

        }
    }
    
    @IBAction func getResourceById(_ sender: Any) {
        serviceManager.getResource(with: 1) { (response) in
        }
    }
    
    @IBAction func uploadFile(_ sender: Any) {
        serviceManager.uploadImage { (response) in
        }
    }
    
    @IBAction func downloadImage(_ sender: Any) {
        serviceManager.downloadImage { (response) in
            
        }
    }
    
}

