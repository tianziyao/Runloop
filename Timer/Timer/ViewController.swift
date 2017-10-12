//
//  ViewController.swift
//  Timer
//
//  Created by 田子瑶 on 2017/9/21.
//  Copyright © 2017年 田子瑶. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    var num = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        @IBAction func clicked(_ sender: Any) {
        }
        
        let timer = Timer(timeInterval: 1,
                          target: self,
                          selector: #selector(self.run),
                          userInfo: nil,
                          repeats: true)
        
        RunLoop.current.add(timer, forMode: .defaultRunLoopMode)

    }
    
    func run() {
        num += 1
        print(Thread.current ,num)
        Thread.sleep(forTimeInterval: 3)
    }

}

