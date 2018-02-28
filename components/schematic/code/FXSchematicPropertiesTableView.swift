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
import FXKit

class FXSchematicPropertyWrapper : NSObject
{
  var name : String?
  var value : String?
  var defaultValue : String?
  var hasMultipleValues = false

  override func isEqual(_ object: Any?) -> Bool
  {
    guard let other = object as! FXSchematicPropertyWrapper? else { return false }
    guard let name_ = name, let otherName = other.name else { return false }
    return name_ == otherName
  }
}

class FXPropertiesTableNameCell : NSTextFieldCell
{
  init()
  {
    super.init(textCell: "")
    self.type = .textCellType
    self.isBezeled = false
    self.isBordered = false
    self.isEditable = false
    self.usesSingleLineMode = true
    self.backgroundColor = NSColor(deviceRed:0.7, green:0.74, blue: 0.7, alpha:0.60)
    self.drawsBackground = true
    self.textColor = NSColor.black
  }

  convenience required init(coder: NSCoder)
  {
    self.init()
  }
}

class FXPropertiesTableValueCell : NSTextFieldCell
{
  var representsMultiValueProperty = false

  init()
  {
    super.init(textCell: "")
    self.type = .textCellType
    self.focusRingType = .none
    self.isBezeled = false
    self.isBordered = false
    self.isEditable = true
    self.usesSingleLineMode = true
    self.sendsActionOnEndEditing = true
    self.allowsEditingTextAttributes = false
    self.drawsBackground = false
    self.textColor = NSColor.black
  }

  convenience required init(coder: NSCoder)
  {
    self.init()
  }

//  override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView)
//  {
//    if self.representsMultiValueProperty
//    {
//      NSColor.yellow.set()
//      NSRectFill(cellFrame)
//    }
//    else
//    {
//      super.drawInterior(withFrame: cellFrame, in: controlView)
//    }
//  }
}


class FXSchematicPropertiesTableView : FXKit.FXTableView
{
  @objc static let NamesColumnIdentifier = "names"
  @objc static let ValuesColumnIdentifier = "values"

  override init(frame frameRect: NSRect)
  {
    super.init(frame:frameRect)
    let propertyNameTableColumn = NSTableColumn(identifier:FXSchematicPropertiesTableView.NamesColumnIdentifier)
    propertyNameTableColumn.headerCell.stringValue = FXLocString("Attribute")
    propertyNameTableColumn.resizingMask = .userResizingMask
    propertyNameTableColumn.dataCell = FXPropertiesTableNameCell()
    propertyNameTableColumn.isEditable = false
    self.addTableColumn(propertyNameTableColumn)

    let propertyValueTableColumn = NSTableColumn(identifier:FXSchematicPropertiesTableView.ValuesColumnIdentifier)
    propertyValueTableColumn.headerCell.stringValue = FXLocString("Value")
    propertyValueTableColumn.resizingMask = .autoresizingMask
    propertyValueTableColumn.dataCell = FXPropertiesTableValueCell()
    propertyValueTableColumn.isEditable = true
    self.addTableColumn(propertyValueTableColumn)

    self.headerView = nil
    self.focusRingType = .none
    self.selectionHighlightStyle = .none
    self.backgroundColor = NSColor.white
    self.intercellSpacing = NSMakeSize(1,0)
    self.allowsEmptySelection = true
    self.allowsMultipleSelection = true
  }

  required init?(coder: NSCoder)
  {
    super.init(coder: coder)
  }
}
