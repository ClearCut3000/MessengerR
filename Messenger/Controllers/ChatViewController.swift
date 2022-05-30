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

struct Message: MessageType {
  public var sender: SenderType
  public var messageId: String
  public var sentDate: Date
  public var kind: MessageKind
}

extension MessageKind {
  var messageKindString: String {
    switch self {
    case .text(_):
      return "text"
    case .attributedText(_):
      return "attributed_text"
    case .photo(_):
      return "photo"
    case .video(_):
      return "video"
    case .location(_):
      return "location"
    case .emoji(_):
      return "emoji"
    case .audio(_):
      return "audio"
    case .contact(_):
      return "contact"
    case .linkPreview(_):
      return "link_preview"
    case .custom(_):
      return "custom"
    }
  }
}

struct Sender: SenderType {
  public var photoURL: String
  public var senderId: String
  public var displayName: String
}

struct Media: MediaItem {
  var url: URL?
  var image: UIImage?
  var placeholderImage: UIImage
  var size: CGSize
}

class ChatViewController: MessagesViewController {

  //MARK: - Properties
  public static let  dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .long
    formatter.locale = .current
    return formatter
  }()
  public var isNewConversation = false
  public let otherUserEmail: String
  private let conversationId: String?

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
    messageInputBar.delegate = self
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
    actionSheet.addAction(UIAlertAction(title: "Video", style: .default, handler: {  _ in

    }))
    actionSheet.addAction(UIAlertAction(title: "Audio", style: .default, handler: {  _ in

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
    guard let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage,
          let imageData = image.pngData(),
          let messageID = createMessageID(),
          let conversationID = conversationId,
          let name = self.title,
          let selfSender = selfSender else { return }
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
        } else {
          print("Failed to send a message!")
        }
      }
    } else {
      guard let conversationId = conversationId, let name = self.title else { return }
      //Appent to existing conversation
      DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: otherUserEmail, name: name, newMessage: message) { success in
        if success {
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
}
