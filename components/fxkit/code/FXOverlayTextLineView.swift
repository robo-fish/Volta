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

public class FXOverlayTextLineView : NSView
{
  @objc var text = ""
  @objc var showsFlippedText = false

  public override init(frame frameRect: NSRect)
  {
    super.init(frame: frameRect)
  }

  public required init?(coder decoder: NSCoder)
  {
    super.init(coder: decoder)
  }

  public override var isOpaque: Bool
  {
    return false
  }

  static private let kTextAttributes : [NSAttributedStringKey:AnyObject] = [
    NSAttributedStringKey.font : NSFont(name:"Lucida Grande", size:18.0)!,
    NSAttributedStringKey.foregroundColor : NSColor(deviceWhite:0.8, alpha:0.7)
  ]

  public override func draw(_ dirtyRect: NSRect)
  {
    let textSize = self.text.size(withAttributes:FXOverlayTextLineView.kTextAttributes)
    let textPosition = NSMakePoint(0.5 * (dirtyRect.size.width - textSize.width), (self.showsFlippedText ? 0.4 : 0.6) * dirtyRect.size.height)
    self.text.draw(at:textPosition, withAttributes:FXOverlayTextLineView.kTextAttributes)
  }
}
