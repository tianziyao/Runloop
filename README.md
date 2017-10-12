关于 Runloop，这篇文章写的非常棒，[深入理解RunLoop](https://blog.ibireme.com/2015/05/18/runloop/)。我写这篇文章在深度上是不如它的，但是为什么还想写一下呢？

Runloop 是一个偏门的东西，在我的工作经历中，几乎没有使用到它的地方，在我当时学习它时，因为本身对 iOS 整个生态了解不够，很多概念让我非常头疼。

因此这篇文章我希望可以换一下因果关系，先不要管 Runloop 是什么，让我们从需求入手，看看 Runloop 能做什么，当你实现过一次之后，回头看这些高屋建瓴的文章，可能会更有启发性。

本文涉及的代码托管在：

首先先记下 Runloop 负责做什么事情：

- 保证程序不退出；
- 负责监听事件，如触摸事件，计时器事件，网络事件等；
- 负责渲染屏幕上所有的 UI，一次 Runloop 循环，需要渲染屏幕上所有变化的像素点；
- 节省 CPU 的开销，让程序该工作时工作，改休息时休息；

保证程序不退出和监听应该比较容易理解，用伪代码来表示，大致是这样：

```swift
// 退出
var exit = false

// 事件
var event: UIEvent? = nil

// 事件队列
var events: [UIEvent] = [UIEvent]()

// 事件分发/响应链
func handle(event: UIEvent) -> Bool {
    return true
}

// 主线程 Runloop
repeat {
    // 出现新的事件
    if event != nil {
        // 将事件加入队列
        events.append(event!)
    }
    // 如果队列中有事件
    if events.count > 0 {
        // 处理队列中第一个事件
        let result = handle(event: events.first!)
        // 处理完成移除第一个事件
        if result {
            events.removeFirst()
        }
    }
    // 再次进入发现事件->添加到队列->事件分发->处理事件->移除事件
    // 直到 exit=true，主线程退出
} while exit == false
```

负责渲染屏幕上所有的 UI，也就是在一次 Runloop 中，事件引起了 UI 的变化，再通过像素点的重绘表现出来。

上面讲到的，全部是 Runloop 在系统层面的用处，那么在应用层面，Runloop 能做什么，以及应用在什么地方呢？首先我们从一个计时器开始。



## 基本概念

当我们使用计时器的时候，应该有了解过 timer 的几种构造方法，有的需要加入到 Runloop 中，有的不需要。

实际上，就算我们不需要手动将 timer 加入到 Runloop，它也是在 Runloop 中，下面的两种初始化方式是等价的：

```swift
let timer = Timer(timeInterval: 1,
                  target: self,
                  selector: #selector(self.run),
                  userInfo: nil,
                  repeats: true)

RunLoop.current.add(timer, forMode: .defaultRunLoopMode)

///////////////////////////////////////////////////////////////////////////

let scheduledTimer = Timer.scheduledTimer(timeInterval: 1,
                                 target: self,
                                 selector: #selector(self.run),
                                 userInfo: nil,
                                 repeats: true)
```

现在新建一个项目，添加一个 `TextView`，你的 ViewController 文件应该是这样：

```swift
class ViewController: UIViewController {
    
    var num = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
    }
}
```

按照直觉，当 App 运行后，控制台会每秒打印一次，**但是当你滚动 `TextView` 时，会发现打印停止了，`TextView` 停止滚动时，打印又继续进行。**

这是什么原因呢？在学习线程的时候我们知道，主线程的优先级是最高的，主线程也叫做 UI 线程，UI 的变化不允许在子线程进行。因此在 iOS 中，UI 事件的优先级是最高的。

Runloop 也有一样的概念，Runloop 分为几种模式：

```swift
// App 的默认 Mode，通常主线程是在这个 Mode 下运行
public static let defaultRunLoopMode: RunLoopMode
// 这是一个占位用的Mode，不是一种真正的Mode，用于区分 defaultMode 
public static let commonModes: RunLoopMode
// 界面跟踪 Mode，用于 ScrollView 追踪触摸滑动，保证界面滑动时不受其他 Mode 影响
public static let UITrackingRunLoopMode: RunLoopMode
```

看到这里大家应该可以明白，我们的 timer 是在 `defaultRunLoopMode` 中，而 `TextView ` 的滚动则处于 `UITrackingRunLoopMode` 中，因此两者不能同时进行。

这个问题会在什么场景下出现呢？比如你使用定时器做了轮播，当下面的列表滚动时，轮播图停住了。

那么现在将 timer 的 `Mode` 修改为 `commonModes` 和 `UITrackingRunLoopMode` 再试一下，看看会发生什么有趣的事情？

`commonModes` 模式下，`run` 方法会持续进行，不受 `TextView` 滚动和静止的影响，`UITrackingRunLoopMode` 模式下，当 `TextView` 滚动时，`run` 方法执行，当 `TextView` 静止时，`run` 方法停止执行。



### 阻塞

如果看过一些关于 Runloop 的介绍，我们应该知道，每个线程都有 Runloop，主线程默认开启，子线程需手动开启，在上面的例子中，当 Mode 是 `commonModes` 时，定时器和 UI 滚动同时进行，看起来像是在同时进行，但实际上无论 Runloop Mode 如何变化，它始终是在这条线程上循环往复。

大家都知道，在 iOS 开发中有一条铁律，永远不能阻塞主线程。因此，在主线程的任何 Mode 上，也不能进行耗时操作，现在将 `run` 方法改成下面这样试下：

```swift
func run() {
    num += 1
    print(Thread.current ,num)
    Thread.sleep(forTimeInterval: 3)
}
```



## 应用 Runloop 的思路

现在我们了解了 Runloop 是怎样运行的，以及运行的几种 Mode，下面我们尝试解决一个实际的问题，`TableCell` 的内容加载。

在日常的开发中，我们大致会将 `TableView` 的加载分为两部分处理：

1. 将网络请求、缓存读写、数据解析、构造模型等耗时操作放在子线程处理；
2. 模型数组准备完毕，回调主线程刷新 `TableView`，使用模型数据填充 `TableCell`；

为什么我们大多会这样处理？实际上还是上面的原则：永远不能阻塞主线程。因此，为了 UI 的流畅，我们会想方设法将耗时操作从主线程中剥离，才有了上面的方案。

但是有一点，UI 的操作是必须在主线程中完成的，那么，如果**使用模型数据填充 `TableCell`** 也是一个耗时操作，该怎么办？

比如像下面这种操作：

```swift
let path = Bundle.main.path(forResource: "rose", ofType: "jpg")
let image = UIImage(contentsOfFile: path ?? "") ?? UIImage()
cell.config(image: image)
```

在这个例子中，`rose.jpg` 是一张很大的图片，每个 `TableCell` 上有 3 张这样的图片，我们当然可以将图片在子线程中读取完毕后再更新，不过我们需要模拟一个耗时的 UI 操作，因此先这样处理。

大家可以下载代码运行一下，滚动 `TableView`，FPS 最低会降到 40 以下，这种现象是如何产生的呢？

**上面我们讲到过，Runloop 负责渲染屏幕的 UI 和监听触摸事件，手指滑动时，`TableView` 随之移动，触发屏幕上的 UI 变化，UI 的变化触发 Cell 的复用和渲染，而 Cell 的渲染是一个耗时操作，导致 Runloop 循环一次的时间变长，因此造成 UI 的卡顿。**

那么针对这个过程，我们怎样改善呢？既然 Cell 的渲染是耗时操作，那么需要把 Cell 的渲染剥离出来，使其不影响 `TableView` 的滚动，保证 UI 的流畅后，在合适的时机再执行 Cell 的渲染，总结一下，也就是下面这样的过程：

1. 声明一个数组，用来存放渲染 Cell 的代码；
2. 在 `cellForRowAtIndexPath` 代理中直接返回 Cell；
3. 监听 Runloop 的循环，循环完成，进入休眠后取出数组中的代码执行；

数组存放代码大家应该可以理解，也就是一个 Block 的数组，但是 Runloop 如何监听呢？



## 监听 Runloop

我们需要知道 Runloop 循环在何时开始，在何时结束，Demo 如下：

```swift
fileprivate func addRunLoopObServer() {
    do {
        let block = { (ob: CFRunLoopObserver?, ac: CFRunLoopActivity) in
            if ac == .entry {
                print("进入 Runloop")
            }
            else if ac == .beforeTimers {
                print("即将处理 Timer 事件")

            }
            else if ac == .beforeSources {
                print("即将处理 Source 事件")

            }
            else if ac == .beforeWaiting {
                print("Runloop 即将休眠")

            }
            else if ac == .afterWaiting {
                print("Runloop 被唤醒")

            }
            else if ac == .exit {
                print("退出 Runloop")
            }
        }
        let ob = try createRunloopObserver(block: block)

        /// - Parameter rl: 要监听的 Runloop
        /// - Parameter observer: Runloop 观察者
        /// - Parameter mode: 要监听的 mode
        CFRunLoopAddObserver(CFRunLoopGetCurrent(), ob, .defaultMode)
    }
    catch RunloopError.canNotCreate {
        print("runloop 观察者创建失败")
    }
    catch {}
}

fileprivate func createRunloopObserver(block: @escaping (CFRunLoopObserver?, CFRunLoopActivity) -> Void) throws -> CFRunLoopObserver {

    /*
     *
     allocator: 分配空间给新的对象。默认情况下使用NULL或者kCFAllocatorDefault。

     activities: 设置Runloop的运行阶段的标志，当运行到此阶段时，CFRunLoopObserver会被调用。

         public struct CFRunLoopActivity : OptionSet {
             public init(rawValue: CFOptionFlags)
             public static var entry             //进入工作
             public static var beforeTimers      //即将处理Timers事件
             public static var beforeSources     //即将处理Source事件
             public static var beforeWaiting     //即将休眠
             public static var afterWaiting      //被唤醒
             public static var exit              //退出RunLoop
             public static var allActivities     //监听所有事件
         }

     repeats: CFRunLoopObserver是否循环调用

     order: CFRunLoopObserver的优先级，正常情况下使用0。

     block: 这个block有两个参数：observer：正在运行的run loop observe。activity：runloop当前的运行阶段。返回值：新的CFRunLoopObserver对象。
     */
    let ob = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, CFRunLoopActivity.allActivities.rawValue, true, 0, block)
    guard let observer = ob else {
        throw RunloopError.canNotCreate
    }
    return observer
}
```



## 利用 Runloop 休眠

根据上面的 Demo，我们可以监听到 Runloop 的开始和结束了，现在在控制器中加入一个 `TableView`，和一个 Runloop 的观察者，你的控制器现在应该是这样的：

```swift
class ViewController: UIViewController {
        
    override func viewDidLoad() {
        super.viewDidLoad()
        addRunloopObserver()
        view.addSubview(tableView)
    }
    
    fileprivate func addRunloopObserver() {
        // 获取当前的 Runloop
        let runloop = CFRunLoopGetCurrent()
        // 需要监听 Runloop 的哪个状态
        let activities = CFRunLoopActivity.beforeWaiting.rawValue
        // 创建 Runloop 观察者
        let observer = CFRunLoopObserverCreateWithHandler(nil, activities, true, Int.max - 999, runLoopBeforeWaitingCallBack)
        // 注册 Runloop 观察者
        CFRunLoopAddObserver(runloop, observer, .defaultMode)
    }
    
    fileprivate let runLoopBeforeWaitingCallBack = { (ob: CFRunLoopObserver?, ac: CFRunLoopActivity) in
        print("runloop 循环完毕")
    }
    
    fileprivate lazy var tableView: UITableView = {
        let table = UITableView(frame: self.view.frame)
        table.delegate = self
        table.dataSource = self
        table.register(TableViewCell.self, forCellReuseIdentifier: "tableViewCell")
        return table
    }()
}
```

现在运行起来，打印信息如下：

```
runloop 循环完毕
runloop 循环完毕
runloop 循环完毕
runloop 循环完毕
```

从这里我们看到，从控制器的 `viewDidLoad` 开始，经过几次 Runloop，`TableView` 成功在屏幕出现，然后进入休眠，当我们滑动屏幕或者触发陀螺仪、耳机等事件发生时，Runloop 进入工作，处理完毕后再次进入休眠。

**而我们的目的是利用 Runloop 的休眠时间，在用户没有产生事件的时候，可以处理 Cell 的渲染任务。本文的开头我们提到 Runloop 负责的事情，触摸和网络等事件一般是由用户触发，且执行完 Runloop 会再次进入休眠，那么合适的的事件，也就是时钟了。**

因此我们监听了 `defaultMode`，并需要在观察者的回调中启动一个时钟事件，让 Runloop 始终保持在活动状态，但是这个时钟也不需要它执行什么事情，所以我开启了一个 `CADisplayLink`，用来显示 FPS。不了解 `CADisplayLink` 的同学，将它想象为一个大约 1/60 秒执行一次的定时器就可以了，执行的动作是输出一个数字。



## 实现 Runloop 应用

首先我们声明几个变量：

```swift
/// 是否使用 Runloop 优化
fileprivate let useRunloop: Bool = false

/// cell 的高度
fileprivate let rowHeight: CGFloat = 120

/// runloop 空闲时执行的代码
fileprivate var runloopBlockArr: [RunloopBlock] = [RunloopBlock]()

/// runloopBlockArr 中的最大任务数
fileprivate var maxQueueLength: Int {
    return (Int(UIScreen.main.bounds.height / rowHeight) + 2)
}
```

修改 `addRunloopObserver` 方法：

```swift
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
```

创建 `addRunloopBlock` 方法：

```swift
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
```

最后将渲染 cell 的 Block 丢进 `runloopBlockArr`:

```swift
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
```



## Demo 地址

https://github.com/tianziyao/Runloop