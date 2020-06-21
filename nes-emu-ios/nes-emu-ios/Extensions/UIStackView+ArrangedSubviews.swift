//
//  UIStackView+ArrangedSubviews.swift
//  October
//
//  Created by Tom Salvo on 4/8/19.
//  Copyright © 2019 Tom Salvo. All rights reserved.
//

import UIKit

extension UIStackView
{
    func safelyRemoveArrangedSubviews()
    {
        // Remove all the arranged subviews and save them to an array
        let removedSubviews = arrangedSubviews.reduce([]) { (sum, next) -> [UIView] in
            self.removeArrangedSubview(next)
            return sum + [next]
        }
        
        // Deactive all constraints at once
        NSLayoutConstraint.deactivate(removedSubviews.flatMap({ $0.constraints }))
        
        // Remove the views from self
        removedSubviews.forEach({ $0.removeFromSuperview() })
    }
}
