//
//  TableViewCell.swift
//  Table
//
//  Created by 田子瑶 on 2017/10/9.
//  Copyright © 2017年 田子瑶. All rights reserved.
//

import UIKit

class TableViewCell: UITableViewCell {
    
    let w = UIScreen.main.bounds.size.width / 3
    var imageViews: [UIImageView] = [UIImageView]()

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        for i in 0 ..< 3 {
            let imageView = UIImageView(frame: CGRect(x: CGFloat(i) * w, y: 0, width: w, height: w / 4 * 3))
            imageView.layer.borderWidth = 2
            imageView.layer.borderColor = UIColor.blue.cgColor
            imageViews.append(imageView)
            contentView.addSubview(imageView)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func config(image: UIImage) {
        for imageView in imageViews {
            imageView.image = image
        }
    }
    
    func configWithRunloop(image: UIImage, index: Int) {
        imageViews[index].image = image
    }
}
