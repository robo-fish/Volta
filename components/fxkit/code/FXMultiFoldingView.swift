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

public class FXMultiFoldingView : NSView
{
  private var _splitter : NSSplitView
  private var _foldingSubviews = [FXMultiFoldingSubview]()

  public override init(frame frameRect: NSRect)
  {
    _splitter = NSSplitView(frame:frameRect)
    _splitter.dividerStyle = .paneSplitter
    _splitter.isVertical = false
    super.init(frame: frameRect)
    _splitter.delegate = self
    addSubview(_splitter)
    FXViewUtils.layout(in: self, visualFormats:["H:|[splitter]|", "V:|[splitter]|"], metricsInfo:nil, viewsInfo:["splitter":_splitter])
  }

  public convenience required init?(coder decoder: NSCoder)
  {
    self.init(frame: .zero)
  }

  /// Appends the given view to the bottom of the receiver.
  @objc public func addSubview(_ view : NSView, withTitle title : String)
  {
    let foldingSubview = _newFoldingSubview(title:title)
    _splitter.addSubview(foldingSubview)
    foldingSubview.contentView = view
    FXViewUtils.layout(in:_splitter,
              visualFormats:["V:[foldingSubview(>=minHeight)]"],
                metricsInfo:["minHeight":NSNumber(value:Double(foldingSubview.minDocumentViewHeight))],
                  viewsInfo:["foldingSubview":foldingSubview])
    _foldingSubviews.append(foldingSubview)
  }

  @objc func handleFoldingAction(_ sender : Any)
  {
  }

  private func _newFoldingSubview(title : String) -> FXMultiFoldingSubview
  {
    let foldingBox = FXMultiFoldingSubview(title: title)
    foldingBox.action = #selector(handleFoldingAction(_:))
    foldingBox.target = self
    return foldingBox
  }
}

let FXResume_SplitterPositions = "FXResume_SplitterPositions"

extension FXMultiFoldingView
{
  public override func restoreState(with coder: NSCoder)
  {
    super.restoreState(with: coder)
    guard let subviewHeights = coder.decodeObject(forKey: FXResume_SplitterPositions) as? [NSNumber] else { return }
    _splitter.subviews.forEach({ $0.restoreState(with:coder) })
    _splitter.adjustSubviews()
    var currentPos = CGFloat(0)
    for (index, item) in subviewHeights.enumerated()
    {
      if index < (self._splitter.subviews.count - 1)
      {
        currentPos += CGFloat(item.doubleValue) + CGFloat(index)*_splitter.dividerThickness
        _splitter.setPosition(currentPos, ofDividerAt: index)
      }
    }
    self.needsDisplay = true
  }

  public override func encodeRestorableState(with coder: NSCoder)
  {
    super.encodeRestorableState(with: coder)
    var subviewHeights = [NSNumber]()
    _splitter.subviews.forEach {
      $0.encodeRestorableState(with: coder)
      subviewHeights.append(NSNumber(value:Double($0.frame.size.height)))
    }
    coder.encode(subviewHeights, forKey:FXResume_SplitterPositions)
  }
}

extension FXMultiFoldingView : NSSplitViewDelegate
{
  public func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool
  {
    return true
  }

  public func splitView(_ splitView: NSSplitView, shouldCollapseSubview subview: NSView, forDoubleClickOnDividerAt dividerIndex: Int) -> Bool
  {
    return true
  }

//  func splitView(_ splitView: NSSplitView, shouldAdjustSizeOfSubview subview: NSView) -> Bool
//  {
//    let totalDividerThickness = max(CGFloat(_foldingSubviews.count - 1), 0) * _splitter.dividerThickness;
//    let totalHeight = self.frame.size.height
//    let subviewHeight = subview.frame.size.height
//    let allOtherSubviewsAreCollapsed = ( ( totalHeight - subviewHeight - totalDividerThickness) < 1 )
//    return allOtherSubviewsAreCollapsed
//  }
}

let skFoldingSubviewHeaderHeight = CGFloat(18.0)

class FXMultiFoldingSubview : FXClipView
{
  private var _triangleButton : NSButton?
  private var _titleField : NSTextField
  private var _minSize = CGSize.zero
  private var _containerView : FXClipView

  var action : Selector?
  weak var target : AnyObject?
  var isFolded : Bool {
    return _triangleButton?.state == .off
  }

  var title : String
  {
    set { _titleField.stringValue = newValue }
    get { return _titleField.stringValue }
  }

  init(title : String)
  {
    let dummyFrame = CGRect(x:0, y:0, width:200, height:200)

    _titleField = NSTextField(frame:dummyFrame)
    _titleField.stringValue = title
    _titleField.isBordered = false
    _titleField.backgroundColor = NSColor(deviceRed:0.4, green: 0.42, blue: 0.4, alpha: 1.0)
    _titleField.drawsBackground = true
    _titleField.textColor = NSColor(deviceWhite:0.9, alpha:1.0)
    _titleField.font = NSFont(name:"Lucida Grande", size:12.0)
    _titleField.isSelectable = false
    _titleField.isEditable = false
    _titleField.focusRingType = .none
    _titleField.alignment = .center

    _containerView = FXClipView(frame:dummyFrame)

    let view = NSView(frame:dummyFrame)
    view.subviews = [_titleField, _containerView]

    FXViewUtils.layout(in:view,
      visualFormats:["H:|[title]|", "H:|[container]|", "V:|[title(titleHeight)][container(>=32)]|"],
      metricsInfo:["titleHeight": NSNumber(value:Double(skFoldingSubviewHeaderHeight))],
      viewsInfo:["container":_containerView, "title":_titleField])

    super.init(frame: dummyFrame, flipped:false)
    self.title = title
    self.documentView = view
    self.minDocumentViewHeight = skFoldingSubviewHeaderHeight
  }

  required convenience init?(coder decoder: NSCoder)
  {
    let title = (decoder.decodeObject(forKey: "Title") as? String) ?? ""
    self.init(title:title)
  }

  var contentView : NSView?
  {
    set {
      _containerView.documentView = newValue
      _containerView.removeConstraints(_containerView.constraints)
      if let view = newValue
      {
        FXViewUtils.layout(in:_containerView, visualFormats:["H:|[view]|", "V:|[view]|"], metricsInfo:nil, viewsInfo:["view":view])
        self.minDocumentViewHeight = skFoldingSubviewHeaderHeight + view.fittingSize.height
      }
    }
    get {
      return _containerView.documentView
    }
  }

  func handleDisclosureAction(sender : AnyObject)
  {
    assert(sender === _triangleButton, "Action sent from unknown control.")
    if let target_ = self.target, let action_ = self.action
    {
      target_.performSelector(onMainThread: action_, with: nil, waitUntilDone: false)
    }
  }

  override func encodeRestorableState(with coder: NSCoder)
  {
    _containerView.encodeRestorableState(with: coder)
    super.encodeRestorableState(with: coder)
  }

  override func restoreState(with coder: NSCoder)
  {
    super.restoreState(with: coder)
    _containerView.restoreState(with: coder)
  }
}
