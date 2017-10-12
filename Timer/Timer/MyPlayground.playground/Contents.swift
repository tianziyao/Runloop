//: Playground - noun: a place where people can play

import UIKit

//// 退出
//var exit = false
//
//// 事件
//var event: UIEvent? = nil
//
//// 事件队列
//var events: [UIEvent] = [UIEvent]()
//
//
//// 事件分发/响应链
//func handle(event: UIEvent) -> Bool {
//    return true
//}
//
//// 主线程 Runloop
//repeat {
//    // 出现新的事件
//    if event != nil {
//        // 将事件加入队列
//        events.append(event!)
//    }
//    
//    // 如果队列中有事件
//    if events.count > 0 {
//        // 处理队列中第一个事件
//        let result = handle(event: events.first!)
//        
//        // 处理完成移除第一个事件
//        if result {
//            events.removeFirst()
//        }
//    }
//    // 再次进入发现事件->添加到队列->事件分发->处理事件->移除事件
//    // 直到 exit=true，主线程退出
//} while exit == false
