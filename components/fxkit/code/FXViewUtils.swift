/**
This file is part of the Volta project.
Copyright (C) 2007-2018 Kai Berk Oezer
https://robo.fish/wiki/index.php?title=Volta
https://github.com/robo-fish/Volta

Volta is free software. You can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

import Cocoa

public class FXViewUtils : NSObject
{
  @objc static public func image(of view : NSView) -> NSImage?
  {
    let bounds = view.bounds
    guard let bitmapRep = view.bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
    bzero(bitmapRep.bitmapData, bitmapRep.bytesPerRow * bitmapRep.pixelsHigh)
    view.cacheDisplay(in: bounds, to: bitmapRep)
    let image = NSImage(size:bitmapRep.size)
    image.addRepresentation(bitmapRep)
    return image
  }

  @objc static public func layout(in view : NSView, visualFormats:[String], metricsInfo:[String:NSNumber]?, viewsInfo:[String:NSView])
  {
    viewsInfo.values.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
    for formatString in visualFormats
    {
      view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat:formatString, options:[], metrics:metricsInfo, views:viewsInfo))
    }
  }

  @objc static public func transferSubviews(from sourceView : NSView, to targetView : NSView)
  {
    let views = sourceView.subviews
    sourceView.subviews = []
    targetView.subviews = views
    FXViewUtils._recursiveTransferConstraints(from:sourceView, to:targetView, for:targetView)
  }

  static private func _recursiveTransferConstraints(from sourceView : NSView, to targetView : NSView, for currentView : NSView)
  {
    for c in currentView.constraints
    {
      if let newFirstItem = (c.firstItem === sourceView) ? targetView : c.firstItem,
        let newSecondItem = (c.secondItem === sourceView) ? targetView : c.secondItem
      {
        targetView.addConstraint(NSLayoutConstraint(item: newFirstItem, attribute: c.firstAttribute, relatedBy: c.relation, toItem: newSecondItem, attribute: c.secondAttribute, multiplier: c.multiplier, constant: c.constant))
      }
    }
    for subview in currentView.subviews
    {
      _recursiveTransferConstraints(from:sourceView, to:targetView, for:subview)
    }
  }
}
