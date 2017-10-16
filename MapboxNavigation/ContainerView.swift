//
//  ContainerView.swift
//  MapboxNavigation
//
//  Created by Jerrad Thramer on 10/12/17.
//  Copyright © 2017 Mapbox. All rights reserved.
//

import Foundation

// :nodoc:
protocol ContainerView: class {
    weak var containerView: UIView? { get set }
}
