//
//  ChatViewController.swift
//  Messenger
//
//  Created by Николай Никитин on 11.05.2022.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import AVFoundation
import AVKit
import CoreLocation

final class ChatViewController: MessagesViewController {

  //MARK: - Properties
  public static let  dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd-MM-YYYY"
    formatter.dateStyle = .medium
    formatter.timeStyle = .long
    formatter.locale = .current
    return formatter
  }()
  public var isNewConversation = false
  public let otherUserEmail: String

  private var senderPhotoURL: URL?
  private var otherUserPhotoURL: URL?
  private var conversationId: String?
  private var messages = [Message]()
  private var selfSender: Sender? {
    guard let email = UserDefaults.standard.value(forKey: "email") as? String else { return nil }
    let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
    return Sender(photoURL: "", senderId: safeEmail, displayName: "Me")
  }

  //MARK: - Init's
  init(with email: String, id: String?) {
    self.conversationId = id
    self.otherUserEmail = email
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  //MARK: - View Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    messagesCollectionView.messagesDataSource = self
    messagesCollectionView.messagesLayoutDelegate = self
    messagesCollectionView.messagesDisplayDelegate = self
    messagesCollectionView.messageCellDelegate = self
    messageInputBar.delegate = self
    setupInputButton()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    messageInputBar.inputTextView.becomeFirstResponder()
    if let conversationId = conversationId {
      listenForMessages(id: conversationId, shouldScrollToBottom: true)
    }
  }

  //MARK: - Methods
  private func setupInputButton() {
    let button = InputBarButtonItem()
    button.setSize(CGSize(width: 35, height: 35), animated: false)
    button.setImage(UIImage(systemName: "paperclip"), for: .normal)
    button.onTouchUpInside { [weak self] _ in
      self?.presentInputActionSheet()
    }
    messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false, animations: nil)
    messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
  }

  private func presentInputActionSheet() {
    let actionSheet = UIAlertController(title: "Attach Media", message: "What would you like to attach?", preferredStyle: .actionSheet)
    actionSheet.addAction(UIAlertAction(title: "Photo", style: .default, handler: { [weak self] _ in
      self?.presentPhotoInputActionSheet()
    }))
    actionSheet.addAction(UIAlertAction(title: "Video", style: .default, handler: { [weak self] _ in
      self?.presentVideoInputActionSheet()
    }))
    actionSheet.addAction(UIAlertAction(title: "Audio", style: .default, handler: {  _ in

    }))
    actionSheet.addAction(UIAlertAction(title: "Location", style: .default, handler: { [weak self] _ in
      self?.presentLocationPicker()
    }))
    actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    present(actionSheet, animated: true)
  }

  private func presentLocationPicker() {
    let vc = LocationPickerViewController(coordinates: nil)
    vc.title = "Pick Location"
    vc.navigationItem.largeTitleDisplayMode = .never
    vc.completion = { [weak self] selectedCoordinates in

      guard let strongSelf = self else { return }

      guard let messageID = strongSelf.createMessageID(),
            let conversationID = strongSelf.conversationId,
            let name = strongSelf.title,
            let selfSender = strongSelf.selfSender else { return }

      let longitude: Double = selectedCoordinates.longitude
      let latitude: Double = selectedCoordinates.latitude
      print("Longitude:\(longitude), Latitude:\(latitude)")

      let location = Location(location: CLLocation(latitude: latitude,
                                                   longitude: longitude),
                              size: .zero)

      let message = Message(sender: selfSender,
                            messageId: messageID,
                            sentDate: Date(),
                            kind: .location(location))

      DatabaseManager.shared.sendMessage(to: conversationID, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message) { success in
        if success {
          print("Sent location message")
        } else {
          print("Failed to send location message")
        }
      }
    }
    navigationController?.pushViewController(vc, animated: true)
  }

  private func presentVideoInputActionSheet() {
    let actionSheet = UIAlertController(title: "Attach Video", message: "Where would  you like to attach video from?", preferredStyle: .actionSheet)
    actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] _ in
      let picker = UIImagePickerController()
      picker.sourceType = .camera
      picker.delegate = self
      picker.mediaTypes = ["public.movie"]
      picker.videoQuality = .typeMedium
      picker.allowsEditing = true
      self?.present(picker, animated: true)
    }))
    actionSheet.addAction(UIAlertAction(title: "Library", style: .default, handler: { [weak self] _ in
      let picker = UIImagePickerController()
      picker.sourceType = .photoLibrary
      picker.delegate = self
      picker.mediaTypes = ["public.movie"]
      picker.videoQuality = .typeMedium
      picker.allowsEditing = true
      self?.present(picker, animated: true)
    }))
    actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    present(actionSheet, animated: true)
  }

  private func presentPhotoInputActionSheet() {
    let actionSheet = UIAlertController(title: "Attach Photo", message: "Where would  you like to attach photo from?", preferredStyle: .actionSheet)
    actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] _ in
      let picker = UIImagePickerController()
      picker.sourceType = .camera
      picker.delegate = self
      picker.allowsEditing = true
      self?.present(picker, animated: true)
    }))
    actionSheet.addAction(UIAlertAction(title: "Photo library", style: .default, handler: { [weak self] _ in
      let picker = UIImagePickerController()
      picker.sourceType = .photoLibrary
      picker.delegate = self
      picker.allowsEditing = true
      self?.present(picker, animated: true)
    }))
    actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    present(actionSheet, animated: true)
  }

  private func listenForMessages(id: String, shouldScrollToBottom: Bool) {
    DatabaseManager.shared.getAllMessagesForConversation(with: id) { [weak self] result in
      switch result {
      case .success(let messages):
        guard !messages.isEmpty else { return }
        self?.messages = messages
        DispatchQueue.main.async {
          self?.messagesCollectionView.reloadDataAndKeepOffset()
          if shouldScrollToBottom {
            self?.messagesCollectionView.scrollToLastItem()
          }
        }
      case .failure(let error):
        print("Failed to get messages - \(error)")
      }
    }
  }
}

//MARK: - ImagePicker Controller
extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true, completion: nil)
  }

  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    picker.dismiss(animated: true, completion: nil)
    guard let messageID = createMessageID(),
          let conversationID = conversationId,
          let name = self.title,
          let selfSender = selfSender else { return }

    //If there is image in imageData
    if let image = info[.editedImage] as? UIImage,
       let imageData = image.pngData() {

      let fileName = "photo_message_" + messageID.replacingOccurrences(of: " ", with: "-") + ".png"
      //Upload image
      StorageManager.shared.uploadMessagePhoto(with: imageData, fileName: fileName, completion: { [weak self] result in
        guard let strongSelf = self else { return }
        switch result {
        case .success(let urlString):
          //Ready to sent message
          print("Uploaded message Photo - \(urlString)")

          guard let url = URL(string: urlString),
                let placeholder = UIImage(systemName: "plus") else { return }

          let media = Media(url: url, image: nil, placeholderImage: placeholder, size: .zero)

          let message = Message(sender: selfSender,
                                messageId: messageID,
                                sentDate: Date(),
                                kind: .photo(media))

          DatabaseManager.shared.sendMessage(to: conversationID, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message) { success in
            if success {
              print("Sent photo message")
            } else {
              print("Failed to send photo message")
            }
          }
        case .failure(let error):
          print("Failed to upload message photo with error - \(error)")
        }
      })
    } else if let videoURL = info[.mediaURL] as? URL {
      // If there's no any image data, we assuming it's video message
      let fileName = "photo_message_" + messageID.replacingOccurrences(of: " ", with: "-") + ".mov"
      //Upload video
      StorageManager.shared.uploadMessageVideo(with: videoURL, fileName: fileName, completion: { [weak self] result in
        guard let strongSelf = self else { return }
        switch result {
        case .success(let urlString):
          //Ready to sent message
          print("Uploaded message Video - \(urlString)")

          guard let url = URL(string: urlString),
                let placeholder = UIImage(systemName: "plus") else { return }

          let media = Media(url: url, image: nil, placeholderImage: placeholder, size: .zero)

          let message = Message(sender: selfSender,
                                messageId: messageID,
                                sentDate: Date(),
                                kind: .video(media))

          DatabaseManager.shared.sendMessage(to: conversationID, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message) { success in
            if success {
              print("Sent photo message")
            } else {
              print("Failed to send photo message")
            }
          }
        case .failure(let error):
          print("Failed to upload message photo with error - \(error)")
        }
      })
    }
  }
}

//MARK: - InputBarAccessoryView Delegate
extension ChatViewController: InputBarAccessoryViewDelegate {
  func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
    guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
          let selfSender = self.selfSender,
          let messageID = createMessageID() else { return }
    let message = Message(sender: selfSender,
                          messageId: messageID,
                          sentDate: Date(),
                          kind: .text(text))
    //Send message
    if isNewConversation {
      // create conversation in database
      DatabaseManager.shared.createNewConversation(with: otherUserEmail,
                                                   name: self.title ?? "User",
                                                   firstMessage: message) { [weak self] success in
        if success {
          print("Message sent!")
          self?.isNewConversation = false
          let newConversationID = "conversation_\(message.messageId)"
          self?.conversationId = newConversationID
          self?.listenForMessages(id: newConversationID, shouldScrollToBottom: true)
          self?.messageInputBar.inputTextView.text = nil
        } else {
          print("Failed to send a message!")
        }
      }
    } else {
      guard let conversationId = conversationId, let name = self.title else { return }
      //Appent to existing conversation
      DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: otherUserEmail, name: name, newMessage: message) { [weak self] success in
        if success {
          self?.messageInputBar.inputTextView.text = nil
          print("Message send!")
        } else {
          print("Failed to send message.")
        }
      }
    }
  }

  func createMessageID() -> String? {
    //date + otherUserEmail + senderEmail + randomInt = totallyRandomString for ID
    guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else { return nil }
    let safeCurrentEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
    let dateString = Self.dateFormatter.string(from: Date())
    let identifier = "\(otherUserEmail)_\(safeCurrentEmail)_\(dateString)"
    return identifier
  }
}

//MARK: - Messages DataSource & LayoutDelegate & DisplayDelegate
extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
  func currentSender() -> SenderType {
    if let sender = selfSender {
      return sender
    }
    fatalError("Self sender is nil, email should be cached!")
  }

  func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
    return messages[indexPath.section]
  }

  func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
    return messages.count
  }

  func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
    guard let message = message as? Message else { return }
    switch message.kind {
    case .photo(let media):
      guard let imageURL = media.url else { return }
      imageView.sd_setImage(with: imageURL, completed: nil)
    default:
      break
    }
  }

  func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
    let sender = message.sender
    if sender.senderId == selfSender?.senderId {
      return .link
    }
    return .secondarySystemBackground
  }

  func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
    let sender = message.sender
    if sender.senderId == selfSender?.senderId {
      //Show our profile image
      if let currentUserImageURL = self.senderPhotoURL {
        avatarView.sd_setImage(with: currentUserImageURL, completed: nil)
      } else {
        //Fetch self photo URL
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else { return }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        let path = "images/\(safeEmail)_profile_picture.png"
        StorageManager.shared.downloadURL(for: path) { [weak self] result in
          switch result {
          case .success(let url):
            self?.senderPhotoURL = url
            DispatchQueue.main.async {
              avatarView.sd_setImage(with: url, completed: nil)
            }
          case .failure(let error):
            print("Error occured while fetching self photo URL for message bubbles - \(error)")
          }
        }
      }
    } else {
      //Show other user profile photo image
      if let otherUserPhotoURL = self.otherUserPhotoURL {
        avatarView.sd_setImage(with: otherUserPhotoURL, completed: nil)
      } else {
        //Fetch other user photo URL
        let email = otherUserEmail
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        let path = "images/\(safeEmail)_profile_picture.png"
        StorageManager.shared.downloadURL(for: path) { [weak self] result in
          switch result {
          case .success(let url):
            self?.otherUserPhotoURL = url
            DispatchQueue.main.async {
              avatarView.sd_setImage(with: url, completed: nil)
            }
          case .failure(let error):
            print("Error occured while fetching other user photo URL for message bubbles - \(error)")
          }
        }
      }
    }
  }
}

//MARK: - MessageCellDelegate
extension ChatViewController: MessageCellDelegate {
  func didTapMessage(in cell: MessageCollectionViewCell) {
    guard let indexPath = messagesCollectionView.indexPath(for: cell) else { return }
    let message = messages[indexPath.section]

    switch message.kind {
    case .location(let locationData):
      let coordinates = locationData.location.coordinate
      let vc = LocationPickerViewController(coordinates: coordinates)
      vc.title = "Location"
      navigationController?.pushViewController(vc, animated: true)
    default:
      break
    }
  }

  func didTapImage(in cell: MessageCollectionViewCell) {
    guard let indexPath = messagesCollectionView.indexPath(for: cell) else { return }
    let message = messages[indexPath.section]

    switch message.kind {
    case .photo(let media):
      guard let imageURL = media.url else { return }
      let vc = PhotoViewerViewController(with: imageURL)
      navigationController?.pushViewController(vc, animated: true)
    case .video(let media):
      guard let videoURL = media.url else { return }
      let vc = AVPlayerViewController()
      vc.player = AVPlayer(url: videoURL)
      present(vc, animated: true)
    default:
      break
    }
  }
}
