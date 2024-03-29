//
//  StorageManager.swift
//  Messenger
//
//  Created by Николай Никитин on 13.05.2022.
//

import Foundation
import FirebaseStorage

/// Allows you to get, fetch and upload files to firebase storage
final class StorageManager {

  //MARK: - Properties
  /// Shared instance
  static let shared = StorageManager()
  public typealias UploadPictureCompletion = (Result<String, Error>) -> Void
  public enum StorageErrors: Error {
    case failedToUpload
    case failedToGetDownloaderUrl
  }
  private let storage = Storage.storage().reference()

  private init() {}

  //MARK: - Methods
  /// Uploads picture to firebase storage and returns completion with url string to download
  public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
    storage.child("images/\(fileName)").putData(data, metadata: nil) { [weak self] metadata, error in
      guard let strongSelf = self else { return }
      guard error == nil else {
        //failed
        print("Failed to upload data to firebase for picture")
        completion(.failure(StorageErrors.failedToUpload))
        return
      }
      strongSelf.storage.child("images/\(fileName)").downloadURL { url, error in
        guard let url = url else {
          print("Failed to get download URL.")
          completion(.failure(StorageErrors.failedToGetDownloaderUrl))
          return
        }
        let urlString = url.absoluteString
        print("Download URL returned: \(urlString)")
        completion(.success(urlString))
      }
    }
  }

  /// Return url for download asynchronously
  public func downloadURL(for path: String, completion: @escaping (Result<URL, Error>) -> Void) {
    let reference = storage.child(path)
    reference.downloadURL { url, error in
      guard let url = url, error == nil else {
        completion(.failure(StorageErrors.failedToGetDownloaderUrl))
        return
      }
      completion(.success(url))
    }
  }

  /// Upload image that will bee sent in a conversation message
  public func uploadMessagePhoto(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
    storage.child("message_images/\(fileName)").putData(data, metadata: nil) { [weak self] metadata, error in
      guard error == nil else {
        //failed
        print("Failed to upload data to firebase for picture")
        completion(.failure(StorageErrors.failedToUpload))
        return
      }
      self?.storage.child("message_images/\(fileName)").downloadURL { url, error in
        guard let url = url else {
          print("Failed to get download URL.")
          completion(.failure(StorageErrors.failedToGetDownloaderUrl))
          return
        }
        let urlString = url.absoluteString
        print("Download URL returned: \(urlString)")
        completion(.success(urlString))
      }
    }
  }

  /// Upload video that will bee sent in a conversation message
  public func uploadMessageVideo(with fileURL: URL, fileName: String, completion: @escaping UploadPictureCompletion) {
    storage.child("message_videos/\(fileName)").putFile(from: fileURL, metadata: nil) { [weak self] metadata, error in
      guard error == nil else {
        //failed
        print("Failed to upload video file to firebase for picture")
        completion(.failure(StorageErrors.failedToUpload))
        return
      }
      self?.storage.child("message_videos/\(fileName)").downloadURL { url, error in
        guard let url = url else {
          print("Failed to get download URL.")
          completion(.failure(StorageErrors.failedToGetDownloaderUrl))
          return
        }
        let urlString = url.absoluteString
        print("Download URL returned: \(urlString)")
        completion(.success(urlString))
      }
    }
  }
}
