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

/// This customization of NSOutlineView provides enhancements like
/// - sending a notification when the delete key is pressed,
/// - collapsing/expanding items when double clicked on,
/// - ability to set a custom image for dragging
public class FXOutlineView : NSOutlineView
{
  /// Sent when the delete key is pressed on the outline view.
  /// Notification object: The FXOutlineView instance that sends the notification
  public static let DeleteKeyNotification = "FXOutlineViewDeleteKeyNotification"

  @objc var dragImage : NSImage?

  public override func keyDown(with keyEvent: NSEvent)
  {
    if let key = keyEvent.charactersIgnoringModifiers?.unicodeScalars.first
    {
      if key == Unicode.Scalar(NSDeleteCharacter) || key == Unicode.Scalar(NSBackspaceCharacter)
      {
        NotificationCenter.default.post(name:NSNotification.Name(rawValue:FXOutlineView.DeleteKeyNotification), object: self)
        return
      }
    }
    super.keyDown(with: keyEvent)
  }

  public override func dragImageForRows(with dragRows: IndexSet, tableColumns: [NSTableColumn], event dragEvent: NSEvent, offset dragImageOffset: NSPointPointer) -> NSImage
  {
    if self.dragImage != nil
    {
      return self.dragImage!
    }
    return super.dragImageForRows(with: dragRows, tableColumns: tableColumns, event: dragEvent, offset: dragImageOffset)
  }
}
