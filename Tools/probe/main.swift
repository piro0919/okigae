// 判定結果を連続で観測して、鍵が安定しているかを確かめる調査用。
import AppKit

var samples: [String] = []
for _ in 0..<20 {
    let doll = StatusItems.resolved()
        .filter { $0.key.contains("Doll") && $0.frame.minX > 0 }
        .sorted { $0.frame.minX < $1.frame.minX }
        .map { "\(Int($0.frame.minX)):\($0.key)" }
        .joined(separator: " ")
    samples.append(doll)
    usleep(300_000)
}
var previous = ""
for (index, state) in samples.enumerated() where state != previous {
    print(String(format: "%4.1f秒  %@", Double(index) * 0.3, state as NSString))
    previous = state
}
print("--- \(Set(samples).count) 通り / 20 回 ---")
