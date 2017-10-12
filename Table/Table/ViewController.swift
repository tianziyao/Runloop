//
//  ViewController.swift
//  Table
//
//  Created by 田子瑶 on 2017/10/9.
//  Copyright © 2017年 田子瑶. All rights reserved.
//

import UIKit

typealias RunloopBlock = () -> (Bool)

class ViewController: UIViewController {
    
    /// 是否使用 Runloop 优化
    fileprivate let useRunloop: Bool = true
    
    /// cell 的高度
    fileprivate let rowHeight: CGFloat = 120
    
    /// runloop 空闲时执行的代码
    fileprivate var runloopBlockArr: [RunloopBlock] = [RunloopBlock]()
    
    /// runloopBlockArr 中的最大任务数
    fileprivate var maxQueueLength: Int {
        return (Int(UIScreen.main.bounds.height / rowHeight) + 2)
    }
    
    fileprivate lazy var tableView: UITableView = {
        let table = UITableView(frame: self.view.frame)
        table.delegate = self
        table.dataSource = self
        table.register(TableViewCell.self, forCellReuseIdentifier: "tableViewCell")
        return table
    }()
    
    fileprivate lazy var fpsLabel: V2FPSLabel = {
        return V2FPSLabel(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        addRunloopObserver()
        view.addSubview(tableView)
        view.addSubview(fpsLabel)
    }
    
    /// 注册 Runloop 观察者
    fileprivate func addRunloopObserver() {
        // 获取当前的 Runloop
        let runloop = CFRunLoopGetCurrent()
        // 需要监听 Runloop 的哪个状态
        let activities = CFRunLoopActivity.beforeWaiting.rawValue
        // 创建 Runloop 观察者
        let observer = CFRunLoopObserverCreateWithHandler(nil, activities, true, 0) { [weak self] (ob, ac) in
            guard let `self` = self else { return }
            guard self.runloopBlockArr.count != 0 else { return }
            // 是否退出任务组
            var quit = false
            // 如果不退出且任务组中有任务存在
            while quit == false && self.runloopBlockArr.count > 0 {
                // 执行任务
                guard let block = self.runloopBlockArr.first else { return }
                // 是否退出任务组
                quit = block()
                // 删除已完成的任务
                let _ = self.runloopBlockArr.removeFirst()
            }
        }
        // 注册 Runloop 观察者
        CFRunLoopAddObserver(runloop, observer, .defaultMode)
    }
    
    /// 添加代码块到数组，在 Runloop BeforeWaiting 时执行
    ///
    /// - Parameter block: <#block description#>
    fileprivate func addRunloopBlock(block: @escaping RunloopBlock) {
        runloopBlockArr.append(block)
        // 快速滚动时，没有来得及显示的 cell 不会进行渲染，只渲染屏幕中出现的 cell
        if runloopBlockArr.count > maxQueueLength {
           let _ = runloopBlockArr.removeFirst()
        }
    }
}

extension ViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return rowHeight
    }
}

extension ViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 20
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if useRunloop {
            return loadCellWithRunloop()
        }
        else {
            return loadCell()
        }
    }
    
    func loadCellWithRunloop() -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "tableViewCell") as? TableViewCell else {
            return UITableViewCell()
        }
        addRunloopBlock { () -> (Bool) in
            let path = Bundle.main.path(forResource: "rose", ofType: "jpg")
            let image = UIImage(contentsOfFile: path ?? "") ?? UIImage()
            cell.config(image: image)
            return false
        }
        return cell
    }
    
    func loadCell() -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "tableViewCell") as? TableViewCell else {
            return UITableViewCell()
        }
        let path = Bundle.main.path(forResource: "rose", ofType: "jpg")
        let image = UIImage(contentsOfFile: path ?? "") ?? UIImage()
        cell.config(image: image)
        return cell
    }
    
}

