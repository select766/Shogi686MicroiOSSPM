//
//  ContentView.swift
//  Shogi686MicroiOSSPM
//
//  Created by Masatoshi Hidaka on 2022/10/05.
//

import SwiftUI
import Shogi686MicroSPM

var _cb: (String) -> Void = {_ in}
func registerCallback(cb: @escaping (String) -> Void) {
    _cb = cb
}
func usiWrite(messagePtr: UnsafePointer<CChar>?) -> Void {
    // 思考スレッドから呼ばれる
    // 改行が含まれている。複数行の場合もある。
    // USIクライアント->USIサーバへの送信
    // TODO: TCP送信
    let messageString = (CFStringCreateWithCString(kCFAllocatorDefault, messagePtr, kCFStringEncodingASCII) ?? "" as CFString) as String
    _cb(messageString)
}

var isFirstRead = true
func usiRead(messagePtr: UnsafeMutablePointer<CChar>?) -> Int32 {
    // 思考スレッドから呼ばれる
    // 改行は含まずに渡す
    // USIサーバ->USIクライアントへの受信
    // TODO: TCP受信
    let msg = isFirstRead ? "usi" : "quit"
    print("read \(msg)")
    // TODO: マシなコピー方法があるはず
    let cst = msg.utf8CString
    if let messagePtr = messagePtr {
        for i in 0..<cst.count {
            messagePtr[i] = cst[i]
        }
    }
    isFirstRead = false
    return Int32(cst.count)
}

struct ContentView: View {
    var body: some View {
        Button(action: {
                    registerCallback(cb: {
                        message in DispatchQueue.main.async {
                            print(message)
                        }
                    })
            // 内部で思考スレッドを生成しすぐreturnする
            Shogi686MicroSPM.micro_main(usiRead, usiWrite);
                }) {
                    Text("RUN")
                }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
