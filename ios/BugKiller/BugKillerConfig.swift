import Foundation

/// BugKiller iOS 骨架入口常量
enum BugKillerConfig {
    static let tag = "BugKiller"
    /// 模拟器访问本机：127.0.0.1；真机请改为 Mac 局域网 IP
    static let apiBase = URL(string: "http://127.0.0.1:8787")!

    static var pingURL: URL { apiBase.appendingPathComponent("api/ping") }
}
