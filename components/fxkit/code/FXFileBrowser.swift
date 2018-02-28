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

public class FXFileBrowser : NSViewController
{
  private(set) var _fileBrowserIdentifier : String
  private var _files = [FXFileBrowserFileData]()
  var _fileEventStream : FSEventStreamRef?
  var _handlingDeleteKey = false

  @objc var rootFolderLocation : URL?
  {
    didSet { refresh(); _setUpFolderMonitoring() }
  }


  @IBOutlet var fileTable : FXFileBrowserTableView?

  private enum TableColumnIdentifier : String
  {
    case name = "name"
    case size = "size"
    case lastModified = "modified"

    var uiItemID : NSUserInterfaceItemIdentifier {
      return NSUserInterfaceItemIdentifier(rawValue:self.rawValue)
    }
  }

  @objc init(identifier : String)
  {
    _fileBrowserIdentifier = identifier
    super.init(nibName:NSNib.Name(rawValue:"FXFileBrowser"), bundle:Bundle(for:FXFileBrowser.self))
  }

  public required init?(coder: NSCoder)
  {
    _fileBrowserIdentifier = (coder.decodeObject(forKey: "ID") as? NSNumber)?.stringValue ?? ""
    super.init(coder: coder)
  }

  deinit
  {
    NotificationCenter.default.removeObserver(self)
    rootFolderLocation = nil
  }

  public override func loadView()
  {
    super.loadView()
    _initializeUI()
  }

  func refresh()
  {
    _buildFolderData()
    self.fileTable?.reloadData()
  }

  @objc func highlight(_ fileNames : [String]?)
  {
    guard let fileNames_ = fileNames else { return }
    var highlightedItems = IndexSet()
    for (index,fileData) in _files.enumerated()
    {
      guard let fn = fileData.fileName else { continue }
      if fileNames_.contains(fn)
      {
        highlightedItems.insert(index)
      }
      if highlightedItems.count > 0
      {
        self.fileTable?.selectRowIndexes(highlightedItems, byExtendingSelection:false)
      }
    }
  }

  @objc func handleTableViewDeleteKey(notification : Notification)
  {
    guard let selectedRows = self.fileTable?.selectedRowIndexes else { return }
    guard selectedRows.count > 0 else { return }
    _handlingDeleteKey = true
    _showAlert(message: FXLocString("FileBrowserAlert_DeleteSelected_Message"),
               acceptTitle: FXLocString("FileBrowserAlert_DeleteSelected_Accept"),
               abortTitle: FXLocString("FileBrowserAlert_Cancel"),
               info: nil)
  }

  let eventStreamCallback : FSEventStreamCallback = { (stream, info, numEvents, eventPaths, eventFlags, eventIDs) in
    if let info_ = info
    {
      let fileBrowserInstance : FXFileBrowser = bridge(ptr:info_)
      fileBrowserInstance.refresh()
    }
  }

}

extension FXFileBrowser
{
  private enum ColumnWidthKey : String
  {
    case name = "Name column width"
    case size = "Size column width"
    case date = "Date column width"
  }

  public override func encodeRestorableState(with coder: NSCoder)
  {
    super.encodeRestorableState(with:coder)
    self.fileTable?.encodeRestorableState(with:coder)
    if let col1 = self.fileTable?.tableColumn(withIdentifier: TableColumnIdentifier.name.uiItemID)?.width
    {
      coder.encode(col1, forKey:ColumnWidthKey.name.rawValue)
    }
    if let col2 = self.fileTable?.tableColumn(withIdentifier: TableColumnIdentifier.lastModified.uiItemID)?.width
    {
      coder.encode(col2, forKey:ColumnWidthKey.date.rawValue)
    }
    if let col3 = self.fileTable?.tableColumn(withIdentifier: TableColumnIdentifier.size.uiItemID)?.width
    {
      coder.encode(col3, forKey:ColumnWidthKey.size.rawValue)
    }
  }

  public override func restoreState(with coder: NSCoder)
  {
    super.restoreState(with: coder)
    self.fileTable?.restoreState(with: coder)
    if coder.containsValue(forKey: ColumnWidthKey.name.rawValue)
    {
      self.fileTable?.tableColumn(withIdentifier: TableColumnIdentifier.name.uiItemID)?.width = CGFloat(coder.decodeFloat(forKey: ColumnWidthKey.name.rawValue))
    }
    if coder.containsValue(forKey: ColumnWidthKey.size.rawValue)
    {
      self.fileTable?.tableColumn(withIdentifier: TableColumnIdentifier.size.uiItemID)?.width = CGFloat(coder.decodeFloat(forKey: ColumnWidthKey.name.rawValue))
    }
    if coder.containsValue(forKey: ColumnWidthKey.date.rawValue)
    {
      self.fileTable?.tableColumn(withIdentifier: TableColumnIdentifier.lastModified.uiItemID)?.width = CGFloat(coder.decodeFloat(forKey: ColumnWidthKey.name.rawValue))
    }
  }
}

extension FXFileBrowser : FXFileBrowserTableViewClient
{
  func handleDroppedFiles(_ files : [URL]) -> Bool
  {
    var handled = false
    let fm = FileManager.default
    var isDir : ObjCBool = false
    for file in files
    {
      if fm.fileExists(atPath: file.path, isDirectory: &isDir) && !isDir.boolValue
      {
        let sourceFileName = file.lastPathComponent
        guard let destination = self.rootFolderLocation?.appendingPathComponent(sourceFileName) else { continue }
        if fm.fileExists(atPath: destination.path)
        {
          _handlingDeleteKey = false
          let alertHandlerInfo = CFURLCreateWithString(nil, file.absoluteString as CFString, nil)
          _showAlert(message:String(format:FXLocString("FileBrowserAlert_OverwriteFile_Message"), sourceFileName),
                     acceptTitle:FXLocString("FileBrowserAlert_OverwriteFile_Accept"),
                     abortTitle:FXLocString("FileBrowserAlert_Cancel"),
                     info:alertHandlerInfo)
        }
        else
        {
          _copyFile(file)
        }
        handled = true
      }
    }
    refresh()
    return handled
  }
}

extension FXFileBrowser : NSTableViewDataSource, NSTableViewDelegate
{
  public func numberOfRows(in tableView: NSTableView) -> Int
  {
    return _files.count
  }

  public func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation
  {
    guard let draggedItems = info.draggingPasteboard().pasteboardItems else { return [] }
    guard draggedItems.count > 0 else { return [] }
    guard info.draggingSourceOperationMask().contains(.copy) else { return [] }
    guard let source = info.draggingSource() as? NSTableView?, let table = self.fileTable else { return [] }
    guard source === table else { return [] }
    return _validateDroppedItems(draggedItems) ? .copy : []
  }

  public func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any?
  {
    guard tableView === self.fileTable else { return nil }
    guard (row >= 0) && (row < _files.count) else { return nil }
    let fileData = _files[row]
    guard let columnIdentifier = tableColumn?.identifier else { return nil }
    if columnIdentifier == TableColumnIdentifier.name.uiItemID
    {
      return fileData.fileName
    }
    else if columnIdentifier == TableColumnIdentifier.size.uiItemID
    {
      return _fileSizeString(for: fileData.sizeInBytes)
    }
    else if columnIdentifier == TableColumnIdentifier.lastModified.uiItemID
    {
      guard let date = fileData.lastModified else { return nil }
      return _dateString(for:date)
    }
    return nil
  }

  public func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting?
  {
    return _files[row]
  }

  public func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forRowIndexes rowIndexes: IndexSet)
  {
    session.enumerateDraggingItems(options:[], for:self.fileTable, classes: [FXFileBrowserFileData.self, NSPasteboardItem.self], searchOptions:[:]) { (draggingItem, int, stopPointer) in
      if draggingItem.item is FXFileBrowserFileData
      {
        guard let tableCellView = self.fileTable?.makeView(withIdentifier: TableColumnIdentifier.name.uiItemID, owner: self) as? NSTableCellView else { return }
        tableCellView.textField?.stringValue = (draggingItem.item as! FXFileBrowserFileData).fileName ?? ""
        draggingItem.imageComponentsProvider = {
          return tableCellView.draggingImageComponents
        }
      }
      else
      {
        // Something went wrong. The dragged item should be a FXFileBrowserFileData instance.
        draggingItem.imageComponentsProvider = nil
      }
    }
  }

  public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
  {
    guard let column = tableColumn else { return nil }
    guard let cellView = tableView.makeView(withIdentifier: column.identifier, owner: self) as? NSTableCellView else { return nil }
    let fileData = _files[row]
    if column.identifier == TableColumnIdentifier.name.uiItemID
    {
      cellView.textField?.stringValue = fileData.fileName ?? ""
      cellView.textField?.isEditable = true
      cellView.textField?.delegate = self
    }
    else if column.identifier == TableColumnIdentifier.size.uiItemID
    {
      cellView.textField?.stringValue = _fileSizeString(for: fileData.sizeInBytes)
    }
    else if column.identifier == TableColumnIdentifier.lastModified.uiItemID
    {
      if let lastMod = fileData.lastModified
      {
        cellView.textField?.stringValue = _dateString(for:lastMod)
      }
      else
      {
        cellView.textField?.stringValue = ""
      }
    }
    return cellView
  }
}

extension FXFileBrowser : NSTextFieldDelegate
{
  public override func controlTextDidEndEditing(_ notification: Notification)
  {
    guard let editedTextField = notification.object as? NSTextField else { return }
    guard let rowIndex = self.fileTable?.row(for: editedTextField) else { return }
    guard rowIndex >= 0 else { return }
    let fileData = _files[rowIndex]
    guard let filename = fileData.fileName else { return }
    guard filename != editedTextField.stringValue else { return }
    guard let originalLocation = self.rootFolderLocation?.appendingPathComponent(filename) else { return }
    guard let newLocation = self.rootFolderLocation?.appendingPathComponent(editedTextField.stringValue) else { return }
    do
    {
      try FileManager.default.moveItem(at: originalLocation, to: newLocation)
      refresh()
    }
    catch let err
    {
      self.view.window?.presentError(err)
    }
  }
}

private extension FXFileBrowser
{
  func _showAlert(message : String, acceptTitle : String, abortTitle : String, info : Any?)
  {
    let alert = NSAlert()
    alert.addButton(withTitle: acceptTitle)
    alert.addButton(withTitle: abortTitle)
    alert.messageText = message
    alert.alertStyle = .warning
    alert.beginSheetModal(for: self.view.window!) { (returnCode) in
      alert.window.orderOut(self)
      guard returnCode == .alertFirstButtonReturn else { return }
      if self._handlingDeleteKey
      {
        self._deleteSelectedFiles()
      }
      else if let contextInfo = info
      {
        let sourceFileLocation = contextInfo as! CFURL
        self._copyFile(sourceFileLocation as URL)
      }
    }
  }

  func _copyFile(_ fileLocation : URL)
  {
    let fm = FileManager.default
    guard let destinationLocation = self.rootFolderLocation?.appendingPathComponent(fileLocation.lastPathComponent) else { return }
    do
    {
      if fm.fileExists(atPath: destinationLocation.path)
      {
        try fm.removeItem(at: destinationLocation)
      }
      try fm.copyItem(at: fileLocation, to: destinationLocation)
    }
    catch let err { self.view.window?.presentError(err) }
  }

  func _initializeUI()
  {
    guard let table = self.fileTable else { return }
    table.tableColumn(withIdentifier: TableColumnIdentifier.name.uiItemID)?.headerCell.stringValue = FXLocString("FileBrowserColumnTitle_Name")
    table.tableColumn(withIdentifier: TableColumnIdentifier.lastModified.uiItemID)?.headerCell.stringValue = FXLocString("FileBrowserColumnTitle_LastModified")
    table.tableColumn(withIdentifier: TableColumnIdentifier.size.uiItemID)?.headerCell.stringValue = FXLocString("FileBrowserColumnTitle_Size")
    table.columnAutoresizingStyle = .noColumnAutoresizing
    table.delegate = self
    table.dataSource = self
    table.client = self
    NotificationCenter.default.addObserver(self, selector: #selector(handleTableViewDeleteKey), name:Notification.Name(rawValue:FXTableView.DeleteKeyNotification), object: table)
  }

  func _buildFolderData()
  {
    _files.removeAll()
    guard let root = self.rootFolderLocation else { return }
    let fm = FileManager.default
    do
    {
      let files = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [])
      for file in files
      {
        if file.isFileURL
        {
          let fileName = file.lastPathComponent
          if !fileName.hasPrefix(".") // hidden file
          {
            var fileSize : UInt = 0
            var modificationDate = Date.distantPast
            do
            {
              let fileAttributes = try fm.attributesOfItem(atPath: file.path)
              fileSize = (fileAttributes[.size] as! NSNumber).uintValue
              modificationDate = (fileAttributes[.modificationDate] as! NSDate) as Date
            }
            catch _ { }
            let fileData = FXFileBrowserFileData(fileLocation: file, modificationDate: modificationDate, fileSize: fileSize)
            _files.append(fileData)
          }
        }
      }
      _files.sort { $0.compare($1) == .orderedAscending }
    }
    catch let err
    {
      NSLog("\(err.localizedDescription)")
    }
  }

  func _fileSizeString(for fileSize : UInt) -> String
  {
    let KiloByte = UInt(1024)
    let MegaByte = KiloByte * KiloByte
    if fileSize < KiloByte
    {
      return "\(fileSize)"
    }
    if fileSize < MegaByte
    {
      let kiloBytes = fileSize / KiloByte
      return "\(kiloBytes) KB"
    }
    let megaBytes = fileSize / MegaByte
    return "\(megaBytes) MB"
  }

  func _dateString(for date : Date) -> String
  {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    formatter.locale = NSLocale.current
    return formatter.string(from:date)
  }

  func folderChangeHandler()
  {

  }

  func _setUpFolderMonitoring()
  {
    if let evenStream = _fileEventStream
    {
      FSEventStreamStop(evenStream)
      FSEventStreamInvalidate(evenStream)
      FSEventStreamRelease(evenStream)
    }
    guard let root = self.rootFolderLocation else { return }
    let folderPath = root.path as CFString
    let monitoredFolders = [folderPath] as CFArray
    let eventDelay = CFTimeInterval(0.1)
    let streamContextPointer = UnsafeMutablePointer<FSEventStreamContext>.allocate(capacity: 1) // FSEventStreamCreate crashes in Release build if the context is not a heap variable
    defer { streamContextPointer.deallocate(capacity: 1) }
    var context = FSEventStreamContext()
    context.info = bridge(obj:self)
    streamContextPointer.pointee = context
    _fileEventStream = FSEventStreamCreate(kCFAllocatorDefault, eventStreamCallback,
      streamContextPointer, monitoredFolders, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), eventDelay, FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone))
    if let eventStream = _fileEventStream
    {
      FSEventStreamScheduleWithRunLoop(eventStream, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
      FSEventStreamStart(eventStream)
    }
  }

  func _deleteSelectedFiles()
  {
    guard let root = self.rootFolderLocation else { return }
    guard let selectedRows = self.fileTable?.selectedRowIndexes else { return }
    let fm = FileManager.default
    for index in selectedRows.reversed()
    {
      if let filename = _files[index].fileName
      {
        do { try fm.removeItem(at: root.appendingPathComponent(filename)) }
        catch _ { /* ignore */ }
      }
    }
    refresh()
  }

  func _validateDroppedItems(_ items : [NSPasteboardItem]) -> Bool
  {
    var hasValidItem = false
    var isDir = ObjCBool(false)
    let fm = FileManager.default
    for item in items
    {
      if item.availableType(from:[.fileURL]) != nil
      {
        if let fileURLString = item.string(forType:.fileURL), let fileURL = URL(string: fileURLString)
        {
          if (fm.fileExists(atPath:fileURL.path, isDirectory:&isDir) && isDir.boolValue)
          {
            hasValidItem = true
            break
          }
        }
      }
    }
    return hasValidItem
  }
}

class FXFileBrowserFileData : NSObject, NSCoding, NSCopying, NSPasteboardWriting, NSPasteboardReading
{
  var fileName : String?
  var lastModified : Date?
  var sizeInBytes : UInt = 0
  var location : URL?

  init(fileLocation: URL?, modificationDate : Date?, fileSize : UInt)
  {
    super.init()
    location = fileLocation
    fileName = location?.lastPathComponent
    lastModified = modificationDate
    sizeInBytes = fileSize
  }

  override var description : String { return location?.path ?? "" }

  //MARK: Comparable

  func compare(_ other : FXFileBrowserFileData) -> ComparisonResult
  {
    guard let fn_l = fileName else { return .orderedAscending }
    guard let fn_r = other.fileName else { return .orderedDescending }
    return fn_l.localizedCaseInsensitiveCompare(fn_r)
  }

  //MARK: NSPasteboardWriting

  func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType]
  {
    guard let loc = (location as NSURL?) else { return [] }
    return loc.writableTypes(for: pasteboard)
  }

  func writingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.WritingOptions
  {
    guard let loc = (location as NSURL?) else { return [] }
    return loc.writingOptions(forType:type, pasteboard:pasteboard)
  }

  func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any?
  {
    guard let loc = (location as NSURL?) else { return nil }
    return loc.pasteboardPropertyList(forType:type)
  }

  //MARK: NSPasteboardReading

  static func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType]
  {
    return [.fileURL, .URL]
  }

  static func readingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.ReadingOptions
  {
    return .asString
  }

  required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType)
  {
    super.init()
    location = NSURL(pasteboardPropertyList:propertyList, ofType:type) as URL?
    lastModified = nil
    sizeInBytes = 0
  }

  //MARK: NSCoding
  func encode(with coder: NSCoder)
  {
    coder.encode(fileName, forKey:"file name")
    coder.encode(lastModified, forKey:"last modified")
    coder.encode(location, forKey:"location")
    coder.encode(sizeInBytes, forKey:"size")
  }

  required init?(coder decoder: NSCoder)
  {
    super.init()
    fileName = decoder.decodeObject(forKey:"file name") as! String?
    lastModified = decoder.decodeObject(forKey:"last modified") as! Date?
    location = decoder.decodeObject(forKey:"location") as! URL?
    sizeInBytes = UInt(decoder.decodeInteger(forKey:"size"))
  }

  //MARK: NSCopying
  func copy(with zone: NSZone? = nil) -> Any
  {
    return FXFileBrowserFileData(fileLocation:location, modificationDate:lastModified, fileSize:sizeInBytes)
  }

}

protocol FXFileBrowserTableViewClient : NSObjectProtocol
{
  func handleDroppedFiles(_ files : [URL]) -> Bool
}

class FXFileBrowserTableView : NSTableView
{
  weak var client : FXFileBrowserTableViewClient?

  override func awakeFromNib()
  {
    registerForDraggedTypes([.fileURL])
    setDraggingSourceOperationMask(.copy, forLocal: false)
  }

  override func prepareForDragOperation(_ info: NSDraggingInfo) -> Bool
  {
    guard let droppedItems = info.draggingPasteboard().pasteboardItems else { return false }
    var fileIsDragged = false
    for item in droppedItems
    {
      for utiType in item.types
      {
        if utiType == .fileURL
        {
          fileIsDragged = true
          break
        }
      }
      if fileIsDragged
      {
        break
      }
    }
    return fileIsDragged
  }

  override func performDragOperation(_ info: NSDraggingInfo) -> Bool
  {
    guard let droppedItems = info.draggingPasteboard().pasteboardItems else { return false }
    var fileURLs = [URL]()
    for item in droppedItems
    {
      var itemIsFile = false
      for utiType in item.types
      {
        if utiType == .fileURL
        {
          itemIsFile = true
          break
        }
      }
      if itemIsFile
      {
        if let urlString = item.string(forType:.fileURL),
          let location = URL(string:urlString)
        {
          fileURLs.append(location)
        }
      }
    }
    if let client = self.client, !fileURLs.isEmpty
    {
      return client.handleDroppedFiles(fileURLs)
    }
    return false
  }

}
