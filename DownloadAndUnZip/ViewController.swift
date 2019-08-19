//
//  ViewController.swift
//  DownloadAndUnZip
//
//  Created by Daisuke T on 2019/08/19.
//  Copyright © 2019 DaisukeT. All rights reserved.
//

import UIKit

import ZipArchive

class ViewController: UIViewController,
  URLSessionTaskDelegate,
  URLSessionDownloadDelegate {
  
  static let zipURL = "https://raw.githubusercontent.com/daisuke-t-jp/DownloadAndUnZip/master/image.zip"
  static let imageDir = "image"
  static let imageFile = "melon.png"
  static let imageFile2 = "lemon.png"
  
  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var imageView2: UIImageView!
  @IBOutlet weak var button: UIButton!
  
  let lock = NSLock()
  var isDownloading = false
  
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    button.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
  }
  
  @objc func buttonAction(_ sender: AnyObject) {
    download()
  }
  
  func clearImageView() {
    imageView.image = nil
    imageView2.image = nil
  }
  
  func updateImageView() {
    let unzipPath = ViewController.unzipPath() as NSString
    let unzipPath2 = unzipPath.appendingPathComponent(ViewController.imageDir) as NSString
    let imagePath = unzipPath2.appendingPathComponent(ViewController.imageFile)
    let imagePath2 = unzipPath2.appendingPathComponent(ViewController.imageFile2)
    let image = UIImage.init(contentsOfFile: imagePath)
    imageView.image = image
    
    let image2 = UIImage.init(contentsOfFile: imagePath2)
    imageView2.image = image2
  }
  
  func download() {
    defer {
      lock.unlock()
    }
    
    lock.lock()
    
    guard !isDownloading else {
      // ダウンロード中
      return
    }
    isDownloading = true  // ダウンロード中にマークする
    
    clearImageView()  // イメージビューをクリアする
    
    /**
     * セッション構成を準備する
     */
    let config = URLSessionConfiguration.default
    config.isDiscretionary = true // バッテリー・通信状態により、優先度を下げる
    config.requestCachePolicy = .reloadIgnoringLocalCacheData // キャッシュを使用しない
    config.timeoutIntervalForRequest = 10 // 転送開始までのタイムアウト時間(s)
    config.timeoutIntervalForResource = 60 * 60 // すべての転送が完了するまでのタイムアウト時間(s)
    
    
    /**
     * セッションを準備する
     */
    let session = URLSession.init(configuration: config,
                                  delegate: self,
                                  delegateQueue: OperationQueue.main)
    
    
    /**
     * ダウンロードタスクを準備する
     */
    guard let url = URL.init(string: ViewController.zipURL) else {
      return
    }
    
    let task = session.downloadTask(with: url)
    
    // ダウンロードを開始する
    task.resume()
  }


}


// MARK: - Path
extension ViewController {
  
  /**
   * ファイル/フォルダ削除する
   */
  static func removeItem(_ path: String) {
    guard FileManager.default.fileExists(atPath: path) else {
      return
    }
    
    do {
      try FileManager.default.removeItem(atPath: path)
    }
    catch _ {
      print("removeItem error.")
      
      return
    }
  }
  
  
  /**
   * Zip ファイルの展開先のパス
   */
  static func unzipPath() -> String {
    let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0];
    
    return path
  }
  
}


// MARK: - URLSessionDelegate
extension ViewController {
  
  /**
   * セッションが完了した
   */
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    defer {
      lock.unlock()
    }
    
    lock.lock()
    isDownloading = false // ダウンロード完了にマークする
    
    
    print("URLSession didComplete")

    session.finishTasksAndInvalidate()  // セッションの終了処理

    guard error == nil else {
      // エラー発生
      print("Error \(String(describing: error))")
      return
    }
    
    
    // 成功
    print("Success")
    
    if Thread.isMainThread {
      updateImageView()
    }
    else {
      DispatchQueue.main.sync {
        updateImageView()
      }
    }
    
  }
  
}


// MARK: - URLSessionDownloadDelegate
extension ViewController {
  
  /**
   * ダウンロードタスクの書き込み処理
   */
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
    // 進捗を確認する
    print("\(totalBytesWritten) / \(totalBytesExpectedToWrite)")
  }
  
  /**
   * ダウンロードタスクが完了した
   */
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    let unzipPath = ViewController.unzipPath()
    
    // 古い展開先フォルダを削除する
    ViewController.removeItem(unzipPath)
    
    // 展開先フォルダを準備する
    do {
      try FileManager.default.createDirectory(atPath: unzipPath, withIntermediateDirectories: true, attributes: nil)
    }
    catch _ {
      print("createDirectory error.")
      return
    }
    
    // Zip を展開する
    SSZipArchive.unzipFile(atPath: location.path, toDestination: unzipPath)
    
  }

}
