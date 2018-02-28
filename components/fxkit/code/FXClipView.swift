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

public class FXClipView : NSClipView
{
  /// For enabling or disabling constrainment of the document view to a minimum size.
  /// You should turn constraining off if you use constraints based AppKit layout.
  @objc var constrainsDocumentSize = true

  @objc public var minDocumentViewHeight : CGFloat = 0
  @objc public var minDocumentViewWidth : CGFloat = 0

  // This offset is needed when the clip view is used inside of an NSScrollView.
  // It helps make the vertical scrollbar disappear.
  // If no offset is used then the height of the document view becomes stuck
  // at a few pixels (determined by NSScrollView and NSClipView) larger than
  // the content view, thus the scrollbar does not disappear.
  var verticalClipOffset : CGFloat = 0

  private var _flippedClipView : Bool

  @objc public init(frame:NSRect, flipped:Bool)
  {
    _flippedClipView = flipped
    super.init(frame: frame)
  }

  @objc public override convenience init(frame frameRect: NSRect)
  {
    self.init(frame:frameRect, flipped:false)
  }

  @objc public required init?(coder decoder: NSCoder)
  {
    _flippedClipView = decoder.decodeBool(forKey: "flipped")
    super.init(coder: decoder)
  }

  public override var documentView: NSView?
  {
    set {
      newValue?.autoresizingMask = []
      super.documentView = newValue
    }
    get {
      return super.documentView
    }
  }

  public override func setFrameSize(_ newSize: NSSize)
  {
    if constrainsDocumentSize
    {
      var newDocumentSize = newSize
      newDocumentSize.width = max( newSize.width, self.minDocumentViewWidth )
      newDocumentSize.height = ( newSize.height < (self.minDocumentViewHeight + self.verticalClipOffset) ) ? self.minDocumentViewHeight : (newSize.height - self.verticalClipOffset);
      self.documentView?.frame = CGRect(x:0,y:0,width:round(newDocumentSize.width),height:round(newDocumentSize.height))
    }
    super.setFrameSize(newSize)
  }

  public override var isFlipped: Bool
  {
    return _flippedClipView
  }

  public override func encodeRestorableState(with coder: NSCoder)
  {
    super.encodeRestorableState(with: coder)
    self.documentView?.encodeRestorableState(with: coder)
  }

  public override func restoreState(with coder: NSCoder)
  {
    super.restoreState(with: coder)
    self.documentView?.restoreState(with: coder)
  }
}
