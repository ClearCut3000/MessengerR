//
//  NewConversationCell.swift
//  Messenger
//
//  Created by Николай Никитин on 01.06.2022.
//

import Foundation
import SDWebImage

class NewConversationCell: UITableViewCell {

  //MARK: - Properties
  static let identifier = "NewConversationCell"

  //MARK: - Subview's
  private let userImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFill
    imageView.layer.cornerRadius = 35
    imageView.layer.masksToBounds = true
    return imageView
  }()

  private let userNameLabel: UILabel = {
    let label = UILabel()
    label.font = .systemFont(ofSize: 21, weight: .semibold)
    return label
  }()

  //MARK: - Init's
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    contentView.addSubview(userImageView)
    contentView.addSubview(userNameLabel)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  //MARK: - Layout
  override func layoutSubviews() {
    super.layoutSubviews()
    userImageView.frame   = CGRect(x: 10,
                                   y: 10,
                                   width: 70,
                                   height: 70 )
    userNameLabel.frame    = CGRect(x: userImageView.right + 10,
                                    y: 20,
                                    width: contentView.width - 20 - userImageView.width,
                                    height: 50)
  }

  //MARK: - Methods
  public func configure(with model: SearchResult) {
    userNameLabel.text = model.name
    let path = "images/\(model.email)_profile_picture.png"
    StorageManager.shared.downloadURL(for: path) { [weak self] result in
      switch result {
      case .success(let url):
        DispatchQueue.main.async {
          self?.userImageView.sd_setImage(with: url, completed: nil)
        }
      case .failure(let error):
        print("Failed to get image URL - \(error)")
      }
    }
  }
}
