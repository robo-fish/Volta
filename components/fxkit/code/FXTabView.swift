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

private let skTabMinWidth = CGFloat(100.0)
private let skTabRowHeight = CGFloat(24.0)
private let skTitleTextSize = CGFloat(12.0)
private let skTextColor : [CGFloat] = [0.5, 0.5, 0.5, 1.0]
private let skSelectedTextColor : [CGFloat] = [0.95, 1.0, 0.95, 1.0]


public class FXTabView : NSView
{
  private var _tabs = [FXTab]()
  private var _selectedTabIndex : Int = -1
  private var _tabHeader : FXTabHeaderView?
  private var _tabContent : FXTabContentView?

  public override init(frame frameRect: NSRect)
  {
    super.init(frame: frameRect)
    _tabContent = FXTabContentView(frame:frameRect)
    _tabHeader = FXTabHeaderView(frame:frameRect)
    _tabHeader!.action = #selector(handleTabSelection(_:))
    _tabHeader!.target = self

    self.subviews = [_tabContent!, _tabHeader!]

    FXViewUtils.layout(in:self,
            visualFormats:["H:|[header]|",
                           "V:|[header(headerHeight)]-(>=0)-|",
                           "H:|[content]|",
                           "V:|-(headerHeight)-[content]|"],
              metricsInfo:["headerHeight" : NSNumber(value:Double(skTabRowHeight))],
                viewsInfo:["header" : _tabHeader!, "content" : _tabContent!])
  }

  public required init?(coder decoder: NSCoder)
  {
    super.init(coder: decoder)
  }

  deinit
  {
    _tabHeader?.removeFromSuperview()
    _tabContent?.removeFromSuperview()
  }

  @objc public func addTabView(_ view : NSView, withTitle title : String)
  {
    let newTab = FXTab(title:title, content:view)
    _tabs.append(newTab)
    if let contentView = newTab.content
    {
      _tabContent?.addContent(contentView)
    }
    _tabHeader?.addTitle(newTab.title)
    self.selectTab(at:_tabs.count, animate:false)
  }

  @objc public func selectTab(at index : Int, animate : Bool)
  {
    guard index < _tabs.count else { return }
    _selectedTabIndex = index
    if index >= 0
    {
      _tabContent?.showSubview(at:UInt(_selectedTabIndex), animate:animate)
      _tabHeader?.selectTitle(at:_selectedTabIndex)
    }
  }

  @objc public func selectTab(withTitle title : String, animate : Bool)
  {
    for (index,tab) in _tabs.enumerated()
    {
      if tab.title == title
      {
        selectTab(at:index, animate:animate)
        break
      }
    }
  }

  public var minimumSize : NSSize { return NSMakeSize(80, skTabRowHeight) }

  @objc public var headerHeight : CGFloat { return skTabRowHeight }

  static let FXResume_SelectedTabIndexKey = "FXResume_SelectedTabIndex"

  public override func encodeRestorableState(with coder: NSCoder)
  {
    super.encodeRestorableState(with: coder)
    coder.encode(_selectedTabIndex, forKey:FXTabView.FXResume_SelectedTabIndexKey)
  }

  public override func restoreState(with coder: NSCoder)
  {
    super.restoreState(with: coder)
    let selectedTab = coder.decodeInteger(forKey:FXTabView.FXResume_SelectedTabIndexKey)
    if selectedTab >= 0
    {
      selectTab(at:selectedTab, animate:false)
      self.needsDisplay = true
    }
  }

  @objc func handleTabSelection(_ sender : Any)
  {
    if let selectedTabIndex = _tabHeader?.selectedTabIndex
    {
      self.selectTab(at: selectedTabIndex, animate:true)
    }
  }
}

//MARK: -

class FXTabHeaderView : NSView
{
  var action : Selector?
  weak var target : AnyObject?

  private var _mouseDownTabIndex : Int = -1
  private(set) var selectedTabIndex : Int = -1
  private let _colorSpace = CGColorSpace(name:CGColorSpace.genericRGBLinear)!
  private var _tabTitles = [String]()
  private var _context : CGContext?

  private lazy var _gradient : CGGradient = {
    var stopColors : [CGFloat] = [
      0.80, 0.82, 0.80, 1.0,
      0.72, 0.76, 0.72, 1.0,
    ]
    var stopPositions : [CGFloat] = [0.0, 1.0]
    return CGGradient(colorSpace:_colorSpace, colorComponents:&stopColors, locations:&stopPositions, count:2)!
  }()

  private lazy var _selectedGradient : CGGradient = {
    var stopColors : [CGFloat] = [
      0.35, 0.45, 0.35, 1.0,
      0.30, 0.40, 0.30, 1.0
    ]
    var stopPositions : [CGFloat] = [0.0, 1.0]
    return CGGradient(colorSpace:_colorSpace, colorComponents:&stopColors, locations:&stopPositions, count:2)!
  }()

  override init(frame frameRect: NSRect)
  {
    super.init(frame: frameRect)
    _resetMouseHandling()
    self.wantsLayer = true // to get rid of artifacts from focus ring layers of neighboring views
  }

  required init?(coder decoder: NSCoder)
  {
    super.init(coder: decoder)
  }

  func addTitle(_ title : String)
  {
    _tabTitles.append(title)
    self.selectedTabIndex = _tabTitles.count - 1
    self.needsDisplay = true
  }

  func removeAllTitles()
  {
    _tabTitles.removeAll()
    self.selectedTabIndex = -1
    self.needsDisplay = true
  }

  func selectTitle(at index : Int)
  {
    if index < 0 || index >= _tabTitles.count
    {
      self.selectedTabIndex = -1
    }
    else
    {
      self.selectedTabIndex = Int(index)
    }
    self.needsDisplay = true
  }

  override func mouseDown(with event: NSEvent)
  {
    let mouseDownLocation = self.convert(event.locationInWindow, from:nil)
    let viewSize = self.frame.size
    _mouseDownTabIndex = -1
    if (viewSize.width > 0) && NSPointInRect(mouseDownLocation, NSMakeRect(0, viewSize.height - skTabRowHeight, viewSize.width, skTabRowHeight))
    {
      let numTabs = _tabTitles.count
      _mouseDownTabIndex = Int(floor(mouseDownLocation.x / viewSize.width * CGFloat(numTabs)))
    }
  }

  override func mouseUp(with event: NSEvent)
  {
    guard _mouseDownTabIndex != -1 else { return }
    let mouseUpTabIndex = _tabIndex(for:self.convert(event.locationInWindow, from: nil))
    if mouseUpTabIndex == _mouseDownTabIndex
    {
      selectTitle(at:_mouseDownTabIndex)
      if let target_ = self.target, let action_ = self.action
      {
        _ = target_.perform(action_, with:self)
      }
    }
    _resetMouseHandling()
  }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool
  {
    return true
  }

  override func draw(_ dirtyRect: NSRect)
  {
    guard let contextPointer = NSGraphicsContext.current?.graphicsPort else { return }
    let context : CGContext = bridge(ptr:contextPointer)
    _context = context
    context.clip(to: dirtyRect)
    context.saveGState()
    context.setFillColorSpace(_colorSpace)
    context.setStrokeColorSpace(_colorSpace)
    _drawTabs(in: dirtyRect)
    context.restoreGState()
  }

  private func _tabIndex(for location : NSPoint) -> Int
  {
    let viewSize = self.frame.size
    if (viewSize.width > 0) && NSPointInRect(location, NSMakeRect(0, viewSize.height - skTabRowHeight, viewSize.width, skTabRowHeight))
    {
      let numTabs = _tabTitles.count
      return Int(floor(location.x / viewSize.width * CGFloat(numTabs)))
    }
    return -1
  }

  private func _resetMouseHandling()
  {
    _mouseDownTabIndex = -1
  }

  private func _drawTabs(in rect : NSRect)
  {
    guard let context = _context else { return }
    let bounds = self.bounds
    let top = CGPoint(x:0, y:bounds.size.height)
    let bottom = CGPoint.zero

    context.saveGState()
    defer { context.restoreGState() }
    context.drawLinearGradient(_gradient, start: top, end: bottom, options:[])
    context.textMatrix = CGAffineTransform.identity

    // clearing the background
    context.beginPath()
    context.addRect(CGRect(x:0,y:0,width:bounds.size.width,height:bounds.size.height))
    context.drawLinearGradient(_gradient, start: top, end: bottom, options:[])

    guard bounds.size.width > skTabMinWidth else { return }

    let numTabs = _tabTitles.count
    let tabWidth = bounds.size.width / CGFloat(numTabs)
    for (index,title) in _tabTitles.enumerated()
    {
      let currentTabRect = CGRect(x:CGFloat(index) * tabWidth, y:0, width:tabWidth, height:bounds.size.height)
      let tabGradient = (index == self.selectedTabIndex) ? _selectedGradient : _gradient
      context.saveGState()
      context.beginPath()
      context.addRect(currentTabRect)
      context.clip()
      context.drawLinearGradient(tabGradient, start: top, end: bottom, options:[])
      context.restoreGState()

      context.saveGState()
      _drawTitle(title, in:currentTabRect, withHighlight:(index == self.selectedTabIndex))
      context.restoreGState()
    }
  }

  private func _drawTitle(_ title : String, in rect : CGRect, withHighlight : Bool)
  {
    guard let context = _context else { return }
    guard let titleFont = NSFont(name:"Lucida Grande", size:skTitleTextSize) else { return }
    context.clip(to: rect)
    let titleAttributes : [NSAttributedStringKey : Any] = [
      .font : titleFont,
      .foregroundColor : NSColor(deviceRed:skTextColor[0], green:skTextColor[1], blue:skTextColor[2], alpha:skTextColor[3])
    ]
    let highlightedTitleAttributes : [NSAttributedStringKey : Any] = [
      .font : titleFont,
      .foregroundColor : NSColor(deviceRed:skSelectedTextColor[0], green:skSelectedTextColor[1], blue:skSelectedTextColor[2], alpha:skSelectedTextColor[3])
    ]
    let attributes = withHighlight ? highlightedTitleAttributes : titleAttributes
    let titleSize = title.size(withAttributes: attributes)
    title.draw(at:NSMakePoint(rect.origin.x + (rect.size.width - titleSize.width)/2.0, rect.origin.y + (rect.size.height - titleSize.height)/2.0), withAttributes:attributes)
  }
}

//MARK:-

class FXTabContentView : NSView
{
  private var _viewsSavedFromResizing = [NSView]()
  private var _lastSelectedView : NSView?

  override init(frame frameRect: NSRect)
  {
    super.init(frame: frameRect)
  }

  required init?(coder decoder: NSCoder)
  {
    super.init(coder: decoder)
  }

  override func setFrameSize(_ newSize: NSSize)
  {
    if newSize.width < skTabMinWidth
    {
      for view in self.subviews
      {
        _viewsSavedFromResizing.append(view)
      }
      super.subviews = []
      self.removeConstraints(self.constraints)
    }
    else
    {
      if !_viewsSavedFromResizing.isEmpty
      {
        for view in _viewsSavedFromResizing
        {
          super.addSubview(view)
          FXViewUtils.layout(in:self, visualFormats:["H:|[view]|", "V:|[view]|"], metricsInfo:nil, viewsInfo:["view":view])
        }
        _viewsSavedFromResizing.removeAll()
      }
    }
    super.setFrameSize(newSize)
  }

  func showSubview(at index : UInt, animate: Bool)
  {
    assert(index < self.subviews.count, "the tab view does not contains a subview at the given index.")
    let newSelectedView = self.subviews[Int(index)]
    var currentSelectedView : NSView?
    for currentSubview in self.subviews
    {
      if !currentSubview.isHidden
      {
        currentSelectedView = currentSubview
        break
      }
    }
    guard let oldSelectedView = currentSelectedView else { return }
    if newSelectedView !== oldSelectedView
    {
      if animate
      {
        newSelectedView.isHidden = false
        _lastSelectedView = oldSelectedView
        _animateSwitching(from:oldSelectedView, to:newSelectedView)
      }
      else
      {
        oldSelectedView.isHidden = true
        newSelectedView.isHidden = false
      }
    }
  }

  func addContent(_ view : NSView)
  {
    if !self.subviews.contains(view)
    {
      self.subviews.forEach { $0.isHidden = true }
      self.addSubview(view)
      FXViewUtils.layout(in:self, visualFormats:["H:|[view]|", "V:|[view]|"], metricsInfo:nil, viewsInfo:["view":view])
    }
  }

  private func _animateSwitching(from oldView : NSView, to newView : NSView)
  {
    let fadeInEffect : [NSViewAnimation.Key:Any] = [NSViewAnimation.Key.target : newView, NSViewAnimation.Key.effect : NSViewAnimation.EffectName.fadeIn ]
    let fadeOutEffect : [NSViewAnimation.Key:Any] = [NSViewAnimation.Key.target : oldView, NSViewAnimation.Key.effect : NSViewAnimation.EffectName.fadeOut ]
    let switchAnimation = NSViewAnimation(viewAnimations:[fadeInEffect, fadeOutEffect])
    switchAnimation.animationBlockingMode = .nonblockingThreaded
    switchAnimation.duration = 0.12;
    switchAnimation.frameRate = 0.0;
    switchAnimation.animationCurve = .linear
    switchAnimation.delegate = self
    switchAnimation.start()
  }
}

extension FXTabContentView : NSAnimationDelegate
{
  func animationDidEnd(_ animation: NSAnimation)
  {
    DispatchQueue.main.async() {
      self._lastSelectedView?.isHidden = true
    }
  }
}

//MARK:-

struct FXTab
{
  var title : String
  var content : NSView?
}
