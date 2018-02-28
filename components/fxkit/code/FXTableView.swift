/**
This file is part of the Volta project.
Copyright (C) 2018 Kai Berk Oezer
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


@objc open class FXTableView : NSTableView
{
  public static let DeleteKeyNotification = "FXTableViewDeleteKeyNotification"

  public var dragImage : NSImage?

  open override func keyDown(with keyEvent: NSEvent)
  {
    if let firstChar = keyEvent.charactersIgnoringModifiers?.unicodeScalars.first
    {
      if (firstChar == Unicode.Scalar(NSDeleteCharacter)) || (firstChar == Unicode.Scalar(NSBackspaceCharacter))
      {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue:FXTableView.DeleteKeyNotification), object: self)
        return
      }
    }
    super.keyDown(with:keyEvent)
  }

  open override func dragImageForRows(with dragRows: IndexSet, tableColumns: [NSTableColumn], event dragEvent: NSEvent, offset dragImageOffset: NSPointPointer) -> NSImage
  {
    if self.dragImage != nil
    {
      return self.dragImage!
    }
    return super.dragImageForRows(with: dragRows, tableColumns: tableColumns, event: dragEvent, offset: dragImageOffset)
  }
}
