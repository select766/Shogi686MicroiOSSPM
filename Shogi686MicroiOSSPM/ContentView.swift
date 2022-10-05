//
//  ContentView.swift
//  Shogi686MicroiOSSPM
//
//  Created by Masatoshi Hidaka on 2022/10/05.
//

import SwiftUI
import Network
import Shogi686MicroSPM

// qos指定がないと"Investigate ways to avoid priority inversions"というエラーが生じる
let tcpQueue = DispatchQueue(label: "usiClient", qos: .default)
var connection: NWConnection?
var recvItems: [[CChar]] = []
let recvSemaphore = DispatchSemaphore(value: 1)
var _cb: (String) -> Void = {_ in}
func registerCallback(cb: @escaping (String) -> Void) {
    _cb = cb
}
func _connsend(data: Data) {
    connection?.send(content: data, completion: .contentProcessed{ error in
        if let error = error {
            print("Error in send", error)
        }
    })
}

func usiWrite(messagePtr: UnsafePointer<CChar>?) -> Void {
    // 思考スレッドから呼ばれる
    // 改行が含まれている。複数行の場合もある。
    // USIクライアント->USIサーバへの送信
    guard let messagePtr = messagePtr else {
        return
    }
    var bytes: [UInt8] = []
    var i = 0
    while true {
        let item = messagePtr[i]
        if item == 0 {
            break
        }
        bytes.append(UInt8(clamping: item))
        i += 1
    }
    let data = Data(bytes)
    print("sending")
    tcpQueue.async {
        _connsend(data: data)
    }
}

func usiRead(messagePtr: UnsafeMutablePointer<CChar>?) -> Int32 {
    // 思考スレッドから呼ばれる
    // 改行は含まずに渡す
    // USIサーバ->USIクライアントへの受信
    var item: [CChar]?
    while true {
        recvSemaphore.wait()
        if recvItems.count > 0 {
            item = recvItems.removeFirst()
            recvSemaphore.signal()
            break
        } else {
            recvSemaphore.signal()
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
    
    // TODO: マシなコピー方法があるはず
    print(item!)
    guard let item = item else { return 0 }
    if let messagePtr = messagePtr {
        for i in 0..<item.count {
            messagePtr[i] = item[i]
        }
        messagePtr[item.count] = 0
    }
    print("returning read")
    return Int32(item.count)
}

var recvBuffer: Data = Data()
func startRecv() {
    connection?.receive(minimumIncompleteLength: 0, maximumLength: 65535, completion: {(data,context,flag,error) in
        if let error = error {
            print("receive error", error)
        } else {
            if let data = data {
                recvBuffer.append(data)
                while true {
                    if let lfPos = recvBuffer.firstIndex(of: 0x0a) {
                        var lineEndPos = lfPos
                        // CRをカット
                        if lineEndPos > 0 && recvBuffer[lineEndPos - 1] == 0x0d {
                            lineEndPos -= 1
                        }
                        var copied: [CChar] = []
                        let bufSlice = recvBuffer[..<lineEndPos]
                        for elem in bufSlice {
                            copied.append(CChar(clamping: elem))
                        }
                        print("received")
                        recvSemaphore.wait()
                        recvItems.append(copied)
                        recvSemaphore.signal()
                        
                        // Data()で囲わないと、次のfirstIndexで返る値が接続開始時からの全文字列に対するindexになる？バグか仕様か不明
                        recvBuffer = Data(recvBuffer[(lfPos+1)...])
                    } else {
                        break
                    }
                }
                startRecv()
            } else {
                // コネクション切断で発生
                print("USI disconnected")
            }
        }
    })
}

func connectToServer() {
    // TODO: IP指定
    connection = NWConnection(to: NWEndpoint.hostPort(host: "127.0.0.1", port: 8090), using: .tcp)
    connection?.stateUpdateHandler = {(newState) in
        print("stateUpdateHandler", newState)
        switch newState {
        case .ready:
            startRecv()
            break
        default:
            break
        }
    }
    connection?.start(queue: tcpQueue)
}

struct ContentView: View {
    var body: some View {
        Button(action: {
            registerCallback(cb: {
                        message in DispatchQueue.main.async {
                            print(message)
                        }
                    })
            connectToServer()
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
